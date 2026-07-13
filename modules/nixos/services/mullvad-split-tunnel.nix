{
  config,
  lib,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  whonixEnabled = get [ "features" "mullvad" "splitTunnel" "whonix" "enable" ] false;
  browserEnabled = get [ "features" "mullvad" "splitTunnel" "browser" "enable" ] false;
  mullvadServiceEnabled = get [ "features" "mullvad" "service" "enable" ] false;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  externalInterface = get [
    "features"
    "mullvad"
    "splitTunnel"
    "whonix"
    "externalInterface"
  ] "virbr1";
  ipv4Subnet = get [ "features" "mullvad" "splitTunnel" "whonix" "ipv4Subnet" ] "10.0.2.0/24";
  ipv6Subnet = get [ "features" "mullvad" "splitTunnel" "whonix" "ipv6Subnet" ] "fd19:c33d:98bc::/64";
  interface = "mullvad-whonix";
  routingTable = "51820";
  routingMark = "0x6d76";
  secretName = "mullvad_whonix_config";
  relayCatalog = ./data/mullvad-relays.tsv;

  tunnelControl = pkgs.writeShellApplication {
    name = "mullvad-whonix-control";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.iproute2
      pkgs.wireguard-tools
    ];
    text = ''
      set -euo pipefail

      interface=${lib.escapeShellArg interface}
      table=${lib.escapeShellArg routingTable}
      mark=${lib.escapeShellArg routingMark}
      config_file=${lib.escapeShellArg config.sops.secrets.${secretName}.path}
      relay_catalog=${lib.escapeShellArg relayCatalog}

      down() {
        ip rule del priority 100 fwmark "$mark" lookup "$table" 2>/dev/null || true
        ip -6 rule del priority 100 fwmark "$mark" lookup "$table" 2>/dev/null || true
        ip route flush table "$table" 2>/dev/null || true
        ip -6 route flush table "$table" 2>/dev/null || true
        ip link delete dev "$interface" 2>/dev/null || true
      }

      case "''${1:-}" in
      up)
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
          ;;
        down)
          down
          ;;
        *)
          echo "usage: mullvad-whonix-control {up|down}" >&2
          exit 2
          ;;
      esac
    '';
  };

  firewallControl = pkgs.writeShellApplication {
    name = "mullvad-whonix-firewall";
    runtimeInputs = [ pkgs.nftables ];
    text = ''
      set -euo pipefail

      case "''${1:-}" in
        up)
          nft delete table inet nagi_mullvad_whonix 2>/dev/null || true
          nft -f - <<'EOF'
      table inet nagi_mullvad_whonix {
        chain mark_whonix {
          type filter hook prerouting priority mangle; policy accept;
          iifname "${externalInterface}" meta mark set ${routingMark}
        }

        chain whonix_kill_switch {
          type filter hook forward priority -10; policy accept;
          iifname "${externalInterface}" oifname != "${interface}" reject with icmpx type admin-prohibited
        }

        chain masquerade_whonix {
          type nat hook postrouting priority srcnat; policy accept;
          ip saddr ${ipv4Subnet} oifname "${interface}" masquerade
          ip6 saddr ${ipv6Subnet} oifname "${interface}" masquerade
        }
      }
      EOF
          ;;
        down)
          nft delete table inet nagi_mullvad_whonix 2>/dev/null || true
          ;;
        *)
          echo "usage: mullvad-whonix-firewall {up|down}" >&2
          exit 2
          ;;
      esac
    '';
  };

  libvirtHook = pkgs.writeShellScript "mullvad-whonix-libvirt-hook" ''
    set -eu

    if [ "$1" != "Whonix-Gateway" ]; then
      exit 0
    fi

    case "$2/$3" in
      prepare/begin)
        ${pkgs.systemd}/bin/systemctl restart mullvad-whonix.service
        ;;
      release/end)
        ${pkgs.systemd}/bin/systemctl stop mullvad-whonix.service
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(whonixEnabled && mullvadServiceEnabled);
          message = "The Mullvad system daemon and Whonix split tunnel cannot be enabled together; they install competing default routes.";
        }
        {
          assertion = !whonixEnabled || sopsEnabled;
          message = "The Whonix Mullvad split tunnel requires sops-nix for its WireGuard profile.";
        }
      ];
    }

    (lib.mkIf (whonixEnabled || browserEnabled) {
      environment.systemPackages = [ pkgs.vopono ];

      systemd.services.vopono = lib.mkIf browserEnabled {
        description = "vopono privileged network namespace daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = with pkgs; [
          iproute2
          nftables
          procps
          util-linux
          wireguard-tools
        ];
        serviceConfig = {
          ExecStart = "${pkgs.vopono}/bin/vopono daemon";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    })

    (lib.mkIf whonixEnabled {
      # Policy-routed replies arrive through WireGuard even though an
      # unmarked route lookup would choose the normal uplink. Strict reverse
      # path filtering drops those valid packets before the tunnel firewall
      # can process them.
      networking.firewall.checkReversePath = "loose";

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
        # nixpkgs materializes declarative hooks through this oneshot. Keep it
        # active so switches install new hooks immediately and restart it when
        # their generated configuration changes.
        libvirtd-config = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.RemainAfterExit = true;
        };

        mullvad-whonix-firewall = {
          description = "Fail-closed firewall for Whonix over Mullvad";
          requiredBy = [ "libvirtd.service" ];
          before = [
            "libvirtd.service"
            "mullvad-whonix.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${firewallControl}/bin/mullvad-whonix-firewall up";
            ExecStop = "${firewallControl}/bin/mullvad-whonix-firewall down";
          };
        };

        mullvad-whonix = {
          description = "Mullvad WireGuard tunnel for Whonix-Gateway";
          after = [
            "network-online.target"
            "mullvad-whonix-firewall.service"
            "sops-install-secrets.service"
          ];
          wants = [ "network-online.target" ];
          requires = [ "mullvad-whonix-firewall.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${tunnelControl}/bin/mullvad-whonix-control up";
            ExecStop = "${tunnelControl}/bin/mullvad-whonix-control down";
          };
        };
      };

      virtualisation.libvirtd.hooks.qemu.mullvad-whonix = libvirtHook;
    })
  ];
}
