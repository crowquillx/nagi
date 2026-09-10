{
  lib,
  vars ? { },
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "terminals" "ghostty" "enable" ] true;
in
{
  config = lib.mkIf enabled {
    programs.ghostty = {
      enable = true;
      settings = {
        confirm-close-surface = false;
        shell-integration-features = "ssh-env,ssh-terminfo";
        # Ghostty validates this during Home Manager activation. The packaged
        # Rose Pine theme keeps first activation valid; Noctalia writes the
        # same per-user theme name after the session starts.
        theme = "Rose Pine";
        window-padding-x = 10;
        window-padding-y = 10;
      };
    };
  };
}
