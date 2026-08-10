{ lib, config, ... }:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  inherit (v.features.bluetooth) enable powerOnBoot;
in
{
  config = lib.mkIf (desktopEnabled && enable) {
    hardware.bluetooth = {
      enable = true;
      inherit powerOnBoot;
    };
    services.blueman.enable = true;
  };
}
