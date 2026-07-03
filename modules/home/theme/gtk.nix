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
  stylixEnabled = get [ "features" "stylix" "enable" ] true;
  stylixVariant = get [ "features" "stylix" "variant" ] "moon";
  preferDark = stylixEnabled && stylixVariant != "dawn";

  iconThemeName = get [ "features" "theme" "gtk" "iconTheme" "name" ] "MoreWaita";
  iconThemePkgPath = get [ "features" "theme" "gtk" "iconTheme" "package" ] "morewaita-icon-theme";
  fallbackIconThemePkgPath = "papirus-icon-theme";
  gtkThemeName = if preferDark then "adw-gtk3-dark" else "adw-gtk3";
  gtkThemePkg = pkgs.adw-gtk3;

  resolvePkg = name: lib.attrByPath (lib.splitString "." name) null pkgs;
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
