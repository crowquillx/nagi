{ lib, pkgs, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  fishEnable = get [ "features" "shell" "fish" "enable" ] true;
  starshipEnable = get [ "features" "shell" "starship" "enable" ] true;
in
{
  config = lib.mkIf (fishEnable || starshipEnable) {
    users.defaultUserShell = lib.mkIf fishEnable pkgs.fish;

    programs.fish.enable = fishEnable;

    programs.starship = {
      enable = starshipEnable;
    };
  };
}
