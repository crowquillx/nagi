{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "bluetooth" "enable" ] true;
  powerOnBoot = get [ "features" "bluetooth" "powerOnBoot" ] false;
in
{
  config = lib.mkIf (desktopEnabled && enabled) {
    hardware.bluetooth = {
      enable = true;
      inherit powerOnBoot;
    };
    services.blueman.enable = true;
  };
}
