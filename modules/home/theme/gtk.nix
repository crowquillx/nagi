{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "theme" "gtk" "enable" ] true;
  variant = get [ "features" "theme" "variant" ] "moon";
  preferDark = variant != "dawn";
  iconThemeName = get [ "features" "theme" "gtk" "iconTheme" "name" ] "MoreWaita";
  iconThemePkgPath = get [ "features" "theme" "gtk" "iconTheme" "package" ] "morewaita-icon-theme";
  fallbackIconThemePkgPath = "papirus-icon-theme";
  gtkThemeName = if preferDark then "adw-gtk3-dark" else "adw-gtk3";
  cursorTheme = import ../../theme/cursor-theme.nix;

  resolvePkg = name: lib.attrByPath (lib.splitString "." name) null pkgs;
  gtkThemePkg = resolvePkg "adw-gtk3";
  iconThemePkg =
    let
      preferred = resolvePkg iconThemePkgPath;
      fallback = resolvePkg fallbackIconThemePkgPath;
    in
    if preferred != null then preferred else fallback;
  noctaliaImport = ''@import url("noctalia.css");'';
in
{
  config = lib.mkIf (desktopEnabled && enabled) {
    assertions = [
      {
        assertion = iconThemePkg != null;
        message = ''
          Could not resolve icon theme package "${iconThemePkgPath}" or fallback "${fallbackIconThemePkgPath}".
        '';
      }
      {
        assertion = gtkThemePkg != null;
        message = "Could not resolve GTK theme package 'adw-gtk3'.";
      }
    ];

    gtk = {
      theme = {
        name = gtkThemeName;
        package = gtkThemePkg;
      };
      iconTheme = {
        name = iconThemeName;
        package = iconThemePkg;
      };
      gtk3 = {
        extraConfig.gtk-application-prefer-dark-theme = preferDark;
        extraCss = noctaliaImport;
      };
      gtk4 = {
        theme = {
          name = gtkThemeName;
          package = gtkThemePkg;
        };
        extraConfig.gtk-application-prefer-dark-theme = preferDark;
        extraCss = noctaliaImport;
      };
    };

    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface" = {
        color-scheme = if preferDark then "prefer-dark" else "prefer-light";
        gtk-theme = gtkThemeName;
        icon-theme = iconThemeName;
        cursor-theme = cursorTheme.name;
        cursor-size = cursorTheme.size;
      };
    };

    xfconf.settings.xsettings = {
      "Net/IconThemeName" = iconThemeName;
      "Net/ThemeName" = gtkThemeName;
      "Gtk/CursorThemeName" = cursorTheme.name;
      "Gtk/CursorThemeSize" = cursorTheme.size;
    };
  };
}
