{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  enabled = v.features.portals.enable;
  inherit (v.desktop) compositor extraCompositors;
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  hasHyprland = builtins.elem "hyprland" ([ compositor ] ++ extraCompositors);
  hasPlasma = builtins.elem "plasma" ([ compositor ] ++ extraCompositors);
  plasmaOnly = hasPlasma && !hasNiri && !hasHyprland;
  kdePortal = pkgs.kdePackages.xdg-desktop-portal-kde;
  gtkPortal = pkgs.xdg-desktop-portal-gtk;
in
{
  config = lib.mkIf enabled {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      # Hyprland NixOS module supplies xdg-desktop-portal-hyprland itself.
      # Plasma-only hosts drop the GTK portal: xdg-desktop-portal-gtk 1.15.3
      # SIGSEGVs at login when kde-gtk-config rewrites gtk.css
      # (nixpkgs #523091). Mixed and niri/hyprland hosts keep GTK fallbacks.
      extraPortals =
        if plasmaOnly then
          lib.mkForce [ kdePortal ]
        else
          lib.optionals hasNiri [ pkgs.xdg-desktop-portal-gnome ]
          ++ lib.optionals hasPlasma [ kdePortal ]
          ++ [ gtkPortal ];
      config = {
        common.default = if plasmaOnly then [ "kde" ] else [ "gtk" ];
      }
      // lib.optionalAttrs hasNiri {
        niri = {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      }
      // lib.optionalAttrs hasHyprland {
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      }
      // lib.optionalAttrs hasPlasma {
        # Shadowing kde-portals.conf: match xdg-desktop-portal-kde's file so
        # Secret/Notification stay on KWallet/plasmanotify. Omit gtk on
        # Plasma-only so the GTK backend is never D-Bus activated at login.
        kde = {
          default = [ "kde" ] ++ lib.optionals (!plasmaOnly) [ "gtk" ];
          "org.freedesktop.impl.portal.Settings" =
            [ "kde" ] ++ lib.optionals (!plasmaOnly) [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "kwallet" ];
          "org.freedesktop.impl.portal.Notification" = [ "plasmanotify" ];
        };
      };
    };

    systemd.user.services.xdg-desktop-portal-gtk = lib.mkIf (hasPlasma && !plasmaOnly) {
      # Mixed hosts still install the GTK portal for Niri/Hyprland. Delay it
      # on KDE until kde-gtk-config has replaced gtk.css.
      serviceConfig.ExecStartPre = pkgs.writeShellScript "wait-plasma-gtk-css" ''
        set -eu
        case ":''${XDG_CURRENT_DESKTOP-}:" in
          *:KDE:*) ;;
          *) exit 0 ;;
        esac
        gtk_css="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css"
        i=0
        while [ "$i" -lt 50 ]; do
          if [ -f "$gtk_css" ] && [ ! -L "$gtk_css" ]; then
            exit 0
          fi
          i=$((i + 1))
          ${pkgs.coreutils}/bin/sleep 0.1
        done
      '';
    };
  };
}
