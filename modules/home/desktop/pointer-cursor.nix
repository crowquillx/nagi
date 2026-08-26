# Desktop-wide cursor theme. Niri and Hyprland used to install this only
# for their own sessions, so Plasma (and XWayland apps such as Steam) kept
# the theme name in kcminputrc/dconf without the package or XCURSOR_* env.
{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  cursorTheme = import ../../theme/cursor-theme.nix;
  cursorPackage = lib.attrByPath [ cursorTheme.packageAttr ] null pkgs;
in
{
  config = lib.mkIf desktopEnabled {
    assertions = [
      {
        assertion = cursorPackage != null;
        message = "desktop.enable requires the nixpkgs package '${cursorTheme.packageAttr}'.";
      }
    ];

    home.pointerCursor = lib.mkIf (cursorPackage != null) {
      enable = true;
      inherit (cursorTheme) name size;
      package = cursorPackage;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
