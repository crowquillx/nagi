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
      # Constrained appearance-only sync without an admin prompt, limited by
      # upstream to the exact packaged helper, root target, and active local
      # sessions. Requires greeter 1.5.0+ and Noctalia 5.1.0+.
      passwordless-sync-users = [ v.users.primary ];
      settings = {
        session.default = "Umbriel";
        # "Synced" lets /var/lib/noctalia-greeter/sync.toml appearance win.
        # Pinning a builtin like "Noctalia" overrides sync.toml and hides Sync Now results.
        appearance.scheme = "Synced";
        cursor = {
          theme = cursorTheme.name;
          inherit size;
          path = "${cursorPackage}/share/icons";
        };
      };
    };
  };
}
