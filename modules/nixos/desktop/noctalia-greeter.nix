{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  cursorTheme = import ../../theme/cursor-theme.nix;
  inherit (cursorTheme) size;
  cursorPackage = lib.attrByPath [ cursorTheme.packageAttr ] null pkgs;
in
{
  config = lib.mkIf v.desktop.enable {
    assertions = [
      {
        assertion = cursorPackage != null;
        message = "desktop.enable requires the nixpkgs package '${cursorTheme.packageAttr}' for the Noctalia Greeter cursor.";
      }
    ];

    programs.noctalia-greeter = {
      enable = true;
      settings = {
        session.default = "Umbriel";
        appearance.scheme = "Noctalia";
        cursor = {
          theme = cursorTheme.name;
          inherit size;
          path = "${cursorPackage}/share/icons";
        };
      };
    };
  };
}
