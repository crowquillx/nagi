{ lib, config, ... }:
let
  v = config.nagi.variables;
in
{
  config = lib.mkIf (v.desktop.enable && v.features.bluetooth.enable) {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = v.features.bluetooth.powerOnBoot;
    };
    services.blueman.enable = true;
  };
}
