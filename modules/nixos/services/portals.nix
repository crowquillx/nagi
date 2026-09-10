{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  enabled = config.nagi.variables.features.portals.enable;
  umbrielPortal =
    inputs.umbriel.inputs.xdg-desktop-portal-umbriel.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf enabled {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        umbrielPortal
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [
          "umbriel"
          "gtk"
        ];
        umbriel = {
          default = [
            "umbriel"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
    };
  };
}
