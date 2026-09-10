# Desktop-wide cursor theme, kept in Home Manager so every application sees
# the same explicit cursor configuration.
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
