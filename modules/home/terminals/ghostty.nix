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
        window-padding-x = 10;
        window-padding-y = 10;
      };
    };
  };
}
