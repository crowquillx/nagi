{ lib, config, ... }:
let
  v = config.nagi.variables;
  fstrimEnabled = v.features.services.fstrim.enable;
  resolvedEnabled = v.features.services.resolved.enable;
  tlpEnabled = v.features.laptop.tlp.enable;
  powerProfilesEnabled = v.features.services.powerProfilesDaemon.enable;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(tlpEnabled && powerProfilesEnabled);
          message = "features.services.powerProfilesDaemon.enable must be false when features.laptop.tlp.enable is true.";
        }
      ];
    }
    {
      services = {
        fstrim.enable = fstrimEnabled;
        resolved.enable = resolvedEnabled;
        power-profiles-daemon.enable = powerProfilesEnabled;
      };
    }
  ];
}
