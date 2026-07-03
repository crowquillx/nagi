{ lib, config, pkgs, ... }:
let
  cfg = config.nagi.variables.features.mullvad;
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
        package = lib.getAttr "mullvad-vpn" pkgs;
      };
    })
  ];
}
