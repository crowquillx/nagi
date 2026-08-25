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
  stylixVariant = get [ "features" "stylix" "variant" ] "moon";
  preferDark = stylixVariant != "dawn";
  compositors = [
    (get [ "desktop" "compositor" ] "hyprland")
  ]
  ++ get [ "desktop" "extraCompositors" ] [ ];
  # GTK settings.ini is user-global, so mixed hosts keep adw-gtk3 for Niri/Hyprland.
  # Plasma-only hosts use Breeze (not Breeze-Dark): Breeze-Dark is a static
  # palette, while Breeze reads Plasma colors from kde-gtk-config's colors.css.
  hasAdwGtkCompositor = builtins.any (
    compositor:
    builtins.elem compositor [
      "niri"
      "hyprland"
    ]
  ) compositors;
  plasmaOwnsGtk = desktopEnabled && !hasAdwGtkCompositor;

  iconThemeName = get [ "features" "theme" "gtk" "iconTheme" "name" ] "MoreWaita";
  iconThemePkgPath = get [ "features" "theme" "gtk" "iconTheme" "package" ] "morewaita-icon-theme";
  fallbackIconThemePkgPath = "papirus-icon-theme";
  gtkThemeName =
    if hasAdwGtkCompositor then if preferDark then "adw-gtk3-dark" else "adw-gtk3" else "Breeze";

  resolvePkg = name: lib.attrByPath (lib.splitString "." name) null pkgs;
  adwGtkPkg = resolvePkg "adw-gtk3";
  breezeGtkPkg = resolvePkg "kdePackages.breeze-gtk";
  gtkThemePkg = if hasAdwGtkCompositor then adwGtkPkg else breezeGtkPkg;
  gtkThemePkgPath = if hasAdwGtkCompositor then "adw-gtk3" else "kdePackages.breeze-gtk";
  iconThemePkg =
    let
      preferred = resolvePkg iconThemePkgPath;
      fallback = resolvePkg fallbackIconThemePkgPath;
    in
    if preferred != null then preferred else fallback;
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
        message = ''
          Could not resolve GTK theme package "${gtkThemePkgPath}".
        '';
      }
    ];

    gtk = {
      theme = {
        name = lib.mkForce gtkThemeName;
        package = lib.mkForce gtkThemePkg;
      };
      iconTheme = {
        name = iconThemeName;
        package = iconThemePkg;
      };
      # GTK 4 ignores gtk-theme-name and only loads ~/.config/gtk-4.0/gtk.css.
      # Home Manager's gtk.gtk4.theme writes a store symlink to Breeze-Dark's
      # baked CSS, which kde-gtk-config cannot replace. Leave it unset so
      # Plasma can export colors.css and import the Breeze theme itself.
      gtk4.theme = lib.mkIf plasmaOwnsGtk (lib.mkForce null);
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = lib.mkForce preferDark;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = lib.mkForce preferDark;
      };
    };

    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface" = {
        color-scheme = if preferDark then "prefer-dark" else "prefer-light";
        gtk-theme = gtkThemeName;
        icon-theme = iconThemeName;
      };
    };

    xfconf.settings.xsettings = {
      "Net/IconThemeName" = iconThemeName;
      "Net/ThemeName" = gtkThemeName;
    };
  };
}
