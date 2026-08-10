{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  inherit (v.desktop) compositor extraCompositors;
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
