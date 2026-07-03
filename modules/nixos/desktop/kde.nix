{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
in
{
  config = lib.mkIf (desktopEnabled && hasPlasma) {
    services.desktopManager.plasma6.enable = true;
  };
}
