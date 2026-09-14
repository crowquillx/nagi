{
  lib,
  pkgs,
  config,
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
  gtkConfigHome = config.xdg.configHome;
  materializeGtkPath = path: ''
    if [ -L ${lib.escapeShellArg path} ]; then
      run install -m 644 -T ${lib.escapeShellArg path} ${lib.escapeShellArg "${path}.materialized"}
      run mv -f ${lib.escapeShellArg "${path}.materialized"} ${lib.escapeShellArg path}
    fi
  '';
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
      # stateVersion < 26.05 still defaults gtk4.theme to gtk.theme, which
      # injects a file:///nix/store adw-gtk3 import Flatpak cannot read and
      # which blocks Noctalia's GTK 4 colors. Null keeps only the user CSS.
      gtk4 = {
        theme = null;
        extraConfig.gtk-application-prefer-dark-theme = preferDark;
        extraCss = noctaliaImport;
      };
    };

    xdg.configFile = {
      "gtk-3.0/gtk.css".force = true;
      "gtk-3.0/settings.ini".force = true;
      "gtk-4.0/gtk.css".force = true;
      "gtk-4.0/settings.ini".force = true;
    };

    # Home Manager writes gtk.css and settings.ini as store symlinks. Flatpak
    # bind-mounts the directory but cannot follow those targets, so copy them
    # into regular files after link generation.
    home.activation.materializeGtkThemeForFlatpak = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${materializeGtkPath "${gtkConfigHome}/gtk-3.0/gtk.css"}
      ${materializeGtkPath "${gtkConfigHome}/gtk-3.0/settings.ini"}
      ${materializeGtkPath "${gtkConfigHome}/gtk-4.0/gtk.css"}
      ${materializeGtkPath "${gtkConfigHome}/gtk-4.0/settings.ini"}
    '';

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
