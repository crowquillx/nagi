{
  lib,
  config,
  self,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "nh" "enable" ] true;
  cleanEnable = get [ "features" "nh" "clean" "enable" ] true;
  cleanExtraArgs = get [ "features" "nh" "clean" "extraArgs" ] "--keep-since 4d --keep 3";
in
{
  config = lib.mkIf enabled {
    programs.nh = {
      enable = true;
      flake = self.outPath;
      clean = {
        enable = cleanEnable;
        extraArgs = cleanExtraArgs;
      };
    };
  };
}
