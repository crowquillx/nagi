# Scoped firewall/routing for Whonix traffic over Mullvad: nft mark + kill
# switch + masquerade, plus a per-interface rpfilter exemption.
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
    externalInterface
    ipv4Subnet
    ipv6Subnet
    interface
    routingMark
    commonHardening
    networkSyscallFilter
    ;

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
in
{
  config = lib.mkIf whonixEnabled {
    # Keep global reverse-path filtering strict. Policy-routed replies arrive
    # on the WireGuard interface and would fail a strict FIB+iif test, so
    # exempt only that interface for the active firewall backend.
    networking.firewall = {
      extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
        ip46tables -t mangle -I nixos-fw-rpfilter 1 -i ${interface} -j RETURN
      '';
      extraStopCommands = lib.mkIf (!config.networking.nftables.enable) ''
        ip46tables -t mangle -D nixos-fw-rpfilter -i ${interface} -j RETURN 2>/dev/null || true
      '';
      extraReversePathFilterRules = lib.mkIf config.networking.nftables.enable ''
        iifname "${interface}" accept
      '';
    };

    systemd.services.mullvad-whonix-firewall = {
      description = "Fail-closed firewall for Whonix over Mullvad";
      requiredBy = [ "libvirtd.service" ];
      before = [
        "libvirtd.service"
        "mullvad-whonix.service"
      ];
      serviceConfig = commonHardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${firewallControl}/bin/mullvad-whonix-firewall up";
        ExecStop = "${firewallControl}/bin/mullvad-whonix-firewall down";
        # nft needs to talk to the kernel; keep the needed capability set.
        SystemCallFilter = networkSyscallFilter;
      };
    };
  };
}
