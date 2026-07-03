{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "portals" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
in
{
  config = lib.mkIf enabled {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ] ++ lib.optionals hasPlasma [
        pkgs.kdePackages.xdg-desktop-portal-kde
      ];
      config = {
        common.default = [ "gtk" ];
        niri.default = [ "gtk" ];
        niri."org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      } // lib.optionalAttrs hasPlasma {
        kde.default = [ "kde" "gtk" ];
        KDE.default = [ "kde" "gtk" ];
        plasma.default = [ "kde" "gtk" ];
      };
      configPackages = lib.optionals hasPlasma [
        pkgs.kdePackages.xdg-desktop-portal-kde
      ];
    };
  };
}
