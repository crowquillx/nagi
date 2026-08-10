{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  fishEnable = v.features.shell.fish.enable;
  zshEnable = v.features.shell.zsh.enable;
  starshipEnable = v.features.shell.starship.enable;
in
{
  config = lib.mkIf (fishEnable || (starshipEnable && !zshEnable)) {
    users.defaultUserShell = lib.mkIf fishEnable pkgs.fish;

    programs.fish.enable = fishEnable;

    programs.starship = {
      enable = starshipEnable && !zshEnable;
    };
  };
}
