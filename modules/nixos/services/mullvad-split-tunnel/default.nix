# Mullvad split-tunnel aggregator: explicit concern imports, one public
# host-variable surface (features.mullvad.splitTunnel.*), plus the shared
# vopono daemon used by browser mode.
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
    browserEnabled
    mullvadServiceEnabled
    sopsEnabled
    vmUuid
    ;
in
{
  imports = [
    ./tunnel.nix
    ./firewall.nix
    ./libvirt.nix
  ];

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
        {
          assertion =
            !whonixEnabled
            || (
              vmUuid != null
              && vmUuid != ""
              && builtins.match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" vmUuid != null
            );
          message = "features.mullvad.splitTunnel.whonix.vmUuid must be a non-empty Whonix-Gateway libvirt domain UUID when the split tunnel is enabled.";
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
  ];
}
