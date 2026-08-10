{
  lib,
  pkgs,
  config,
  ...
}:
let
  zshEnable = config.nagi.variables.features.shell.zsh.enable;
in
{
  config = lib.mkIf zshEnable {
    users.defaultUserShell = pkgs.zsh;

    programs.zsh.enable = true;

    # Make completions from system packages visible to Home Manager's compinit.
    environment.pathsToLink = [ "/share/zsh" ];
  };
}
