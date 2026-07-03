{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "flatpak" "enable" ] false;
  packageRefs = get [ "features" "flatpak" "packages" ] [ ];
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.all (ref: lib.isString ref && ref != "") packageRefs;
          message = "features.flatpak.packages must be a list of non-empty Flatpak app IDs.";
        }
        {
          assertion = enabled || packageRefs == [ ];
          message = "features.flatpak.packages requires features.flatpak.enable = true.";
        }
      ];
    }
    (lib.mkIf enabled {
      services.flatpak = {
        enable = true;
        packages = packageRefs;
        uninstallUnmanaged = true;
      };
    })
  ];
}
