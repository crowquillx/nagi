# System cursor theme so Plasma, XWayland, and other session apps can
# resolve the same theme Home Manager installs for GTK/X11.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
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

    environment.systemPackages = lib.optionals (cursorPackage != null) [ cursorPackage ];
    environment.sessionVariables = {
      XCURSOR_THEME = cursorTheme.name;
      XCURSOR_SIZE = toString cursorTheme.size;
    };
  };
}
