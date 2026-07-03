{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  nmEnabled = get [ "features" "networking" "networkmanager" "enable" ] true;
  fstrimEnabled = get [ "features" "services" "fstrim" "enable" ] true;
  resolvedEnabled = get [ "features" "services" "resolved" "enable" ] nmEnabled;
  tlpEnabled = get [ "features" "laptop" "tlp" "enable" ] false;
  powerProfilesEnabled = get [ "features" "services" "powerProfilesDaemon" "enable" ] (!tlpEnabled);
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
