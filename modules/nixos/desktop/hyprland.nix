{
  lib,
  pkgs,
  config,
  ...
}:
let
  get = path: default: lib.attrByPath path default config.nagi.variables;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasHyprland = builtins.elem "hyprland" ([ compositor ] ++ extraCompositors);
in
{
  config = lib.mkIf (desktopEnabled && hasHyprland) {
    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
      withUWSM = true;
      xwayland.enable = true;
    };
  };
}
