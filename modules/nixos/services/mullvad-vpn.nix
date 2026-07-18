{ lib, config, pkgs, ... }:
let
  cfg = config.nagi.variables.features.mullvad;
  mullvadPackage = lib.getAttr "mullvad-vpn" pkgs;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.service.enable || cfg.package == "gui";
          message = "features.mullvad.service.enable requires features.mullvad.package = \"gui\".";
        }
      ];
    }
    (lib.mkIf cfg.service.enable {
      services.mullvad-vpn = {
        enable = true;
        package = mullvadPackage;
      };

      systemd.services.mullvad-lan-sharing = {
        description = "Configure Mullvad local network sharing";
        wantedBy = [ "multi-user.target" ];
        requires = [ "mullvad-daemon.service" ];
        after = [ "mullvad-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${mullvadPackage}/bin/mullvad lan set ${if cfg.service.allowLan then "allow" else "block"}";
          RemainAfterExit = true;
        };
      };
    })
  ];
}
