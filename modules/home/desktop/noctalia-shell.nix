{ lib, vars ? { }, ... }:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (desktopEnabled && hasNiri);
in
{
  config = lib.mkIf (desktopEnabled && hasNiri && noctaliaEnable) {
    programs.noctalia = {
      enable = true;
      systemd.enable = get [ "desktop" "noctalia" "systemd" "enable" ] false;
    };
  };
}
