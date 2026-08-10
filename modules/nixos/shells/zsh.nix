{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  zshEnable = get [ "features" "shell" "zsh" "enable" ] false;
in
{
  config = lib.mkIf zshEnable {
    users.defaultUserShell = pkgs.zsh;

    programs.zsh.enable = true;

    # Make completions from system packages visible to Home Manager's compinit.
    environment.pathsToLink = [ "/share/zsh" ];
  };
}
