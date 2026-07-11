{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "portals" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
in
{
  config = lib.mkIf enabled {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = lib.optionals hasNiri [
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [ "gtk" ];
      }
      // lib.optionalAttrs hasNiri {
        niri = {
          default = [ "gnome" "gtk" ];
          "org.freedesktop.impl.portal.Access" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      }
      // lib.optionalAttrs hasPlasma {
        kde.default = [ "kde" "gtk" ];
      };
    };
  };
}
