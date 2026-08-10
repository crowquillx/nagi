{
  lib,
  pkgs,
  config,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  fishEnable = get [ "features" "shell" "fish" "enable" ] true;
  zshEnable = get [ "features" "shell" "zsh" "enable" ] false;
  starshipEnable = get [ "features" "shell" "starship" "enable" ] true;
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
