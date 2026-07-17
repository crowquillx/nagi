# Tunnel lifecycle: WireGuard bring-up/down, secret materialization, and
# timer-driven handshake health recovery. systemd ordering stays explicit.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  m = import ./common.nix { inherit config lib; };
  inherit (m)
    whonixEnabled
    interface
    routingTable
    routingMark
    secretName
    secretPath
    relayCatalog
    handshakeStaleSecs
    handshakeGraceSecs
    commonHardening
    networkSyscallFilter
    ;

  tunnelControl = pkgs.writeShellApplication {
    name = "mullvad-whonix-control";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.gnused
      pkgs.iproute2
      pkgs.systemd
      pkgs.wireguard-tools
    ];
    text = ''
      set -euo pipefail

      interface=${lib.escapeShellArg interface}
      table=${lib.escapeShellArg routingTable}
      mark=${lib.escapeShellArg routingMark}
      config_file=${lib.escapeShellArg secretPath}
      relay_catalog=${lib.escapeShellArg relayCatalog}
      handshake_stale_secs=${toString handshakeStaleSecs}
      handshake_grace_secs=${toString handshakeGraceSecs}
      unit=mullvad-whonix.service

      require_secret() {
        if [[ ! -s "$config_file" ]]; then
          echo "Mullvad WireGuard secret is missing or empty: $config_file" >&2
          exit 1
        fi
      }

      down() {
        ip rule del priority 100 fwmark "$mark" lookup "$table" 2>/dev/null || true
        ip -6 rule del priority 100 fwmark "$mark" lookup "$table" 2>/dev/null || true
        ip route flush table "$table" 2>/dev/null || true
        ip -6 route flush table "$table" 2>/dev/null || true
        ip link delete dev "$interface" 2>/dev/null || true
      }

      # Exit 0 when the active tunnel still has a fresh WireGuard handshake.
      # Exit 1 when the peer looks dead so the timer unit can restart setup.
      healthy() {
        local now latest age active_enter_usec now_mono started_mono

        ip -o link show dev "$interface" up >/dev/null 2>&1 || return 1
        wg show "$interface" peers | grep -q . || return 1
        ip route show table "$table" | grep -q '^default' || return 1
        ip -6 route show table "$table" | grep -q '^default' || return 1

        now="$(date +%s)"
        latest="$(wg show "$interface" latest-handshakes | awk 'NR == 1 { print $2; exit }')"
        if [[ -z "$latest" ]]; then
          return 1
        fi
        if [[ "$latest" == 0 ]]; then
          # ActiveEnterTimestampMonotonic is usec since boot; compare with
          # /proc/uptime rather than wall-clock epoch.
          active_enter_usec="$(systemctl show -p ActiveEnterTimestampMonotonic --value "$unit" 2>/dev/null || true)"
          if [[ -z "$active_enter_usec" || "$active_enter_usec" == 0 ]]; then
            return 1
          fi
          now_mono="$(awk '{ print int($1) }' /proc/uptime)"
          started_mono=$((active_enter_usec / 1000000))
          (( now_mono - started_mono < handshake_grace_secs ))
          return
        fi
        age=$((now - latest))
        (( age < handshake_stale_secs ))
      }

      up() {
        require_secret
        down
        trap down ERR

        ip link add dev "$interface" type wireguard
        private_key="$(sed -n 's/^PrivateKey[[:space:]]*=[[:space:]]*//p' "$config_file" | head -n 1)"
        if [[ -z "$private_key" ]]; then
          echo "Mullvad profile has no Interface PrivateKey" >&2
          exit 1
        fi
        wg set "$interface" private-key <(printf '%s\n' "$private_key")
        unset private_key

        address_line="$(sed -n 's/^Address[[:space:]]*=[[:space:]]*//p' "$config_file" | head -n 1)"
        if [[ -z "$address_line" ]]; then
          echo "Mullvad profile has no Interface Address" >&2
          exit 1
        fi
        IFS=',' read -ra addresses <<< "$address_line"
        for address in "''${addresses[@]}"; do
          ip address add "''${address//[[:space:]]/}" dev "$interface"
        done

        while read -r old_peer; do
          [[ -n "$old_peer" ]] && wg set "$interface" peer "$old_peer" remove
        done < <(wg show "$interface" peers)

        IFS=$'\t' read -r relay peer endpoint < <(shuf -n 1 "$relay_catalog")
        if [[ -z "$relay" || -z "$peer" || -z "$endpoint" ]]; then
          echo "Unable to choose a Mullvad relay" >&2
          exit 1
        fi
        peer_length="''${#peer}"
        while (( peer_length % 4 != 0 )); do
          peer+="="
          ((peer_length += 1))
        done

        wg set "$interface" \
          peer "$peer" \
          allowed-ips 0.0.0.0/0,::/0 \
          endpoint "$endpoint" \
          persistent-keepalive 25
        ip link set mtu 1420 up dev "$interface"
        ip route replace default dev "$interface" table "$table"
        ip -6 route replace default dev "$interface" table "$table"
        ip rule add priority 100 fwmark "$mark" lookup "$table"
        ip -6 rule add priority 100 fwmark "$mark" lookup "$table"

        trap - ERR
        echo "Whonix is using Mullvad relay: $relay"
      }

      case "''${1:-}" in
        up)
          up
          ;;
        down)
          down
          ;;
        healthy)
          healthy
          ;;
        *)
          echo "usage: mullvad-whonix-control {up|down|healthy}" >&2
          exit 2
          ;;
      esac
    '';
  };

  healthcheck = pkgs.writeShellApplication {
    name = "mullvad-whonix-healthcheck";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      unit=mullvad-whonix.service
      control=${lib.escapeShellArg "${tunnelControl}/bin/mullvad-whonix-control"}

      # Tunnel is only up while Whonix-Gateway is running (libvirt hook).
      if ! systemctl is-active --quiet "$unit"; then
        exit 0
      fi

      if "$control" healthy; then
        exit 0
      fi

      echo "Mullvad Whonix tunnel handshake/routes unhealthy; restarting $unit" >&2
      systemctl restart "$unit"
    '';
  };
in
{
  config = lib.mkIf whonixEnabled {
    # Ensure the WireGuard module is loaded before hardened services that
    # cannot finit_module under ProtectKernelModules.
    boot.kernelModules = [ "wireguard" ];

    sops.secrets.${secretName} = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "mullvad-whonix.service" ];
    };

    environment.systemPackages = [
      pkgs.nftables
      pkgs.wireguard-tools
      tunnelControl
    ];

    systemd.services = {
      mullvad-whonix = {
        description = "Mullvad WireGuard tunnel for Whonix-Gateway";
        after = [
          "network-online.target"
          "mullvad-whonix-firewall.service"
          "sops-install-secrets.service"
        ];
        wants = [ "network-online.target" ];
        # Hard-require secret materialization and the kill switch.
        requires = [
          "mullvad-whonix-firewall.service"
          "sops-install-secrets.service"
        ];
        unitConfig.RequiresMountsFor = [ secretPath ];
        serviceConfig = commonHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${tunnelControl}/bin/mullvad-whonix-control up";
          ExecStop = "${tunnelControl}/bin/mullvad-whonix-control down";
          # Bring-up needs netlink + wireguard ioctls beyond the default filter.
          SystemCallFilter = networkSyscallFilter;
          ReadOnlyPaths = [ secretPath ];
        };
      };

      mullvad-whonix-healthcheck = {
        description = "Recover dead Mullvad Whonix WireGuard tunnel";
        after = [
          "mullvad-whonix.service"
          "sops-install-secrets.service"
        ];
        serviceConfig = commonHardening // {
          Type = "oneshot";
          ExecStart = "${healthcheck}/bin/mullvad-whonix-healthcheck";
          SystemCallFilter = networkSyscallFilter;
        };
      };
    };

    systemd.timers.mullvad-whonix-healthcheck = {
      description = "Periodically verify Mullvad Whonix WireGuard handshake";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
        Persistent = true;
        Unit = "mullvad-whonix-healthcheck.service";
      };
    };
  };
}
