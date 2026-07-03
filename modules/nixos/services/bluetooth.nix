{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "bluetooth" "enable" ] true;
in
{
  config = lib.mkIf (desktopEnabled && enabled) {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
