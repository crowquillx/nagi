{
  lib,
  config,
  self,
  ...
}:
let
  v = config.nagi.variables;
  enabled = v.features.nh.enable;
  cleanEnable = v.features.nh.clean.enable;
  cleanExtraArgs = v.features.nh.clean.extraArgs;
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
