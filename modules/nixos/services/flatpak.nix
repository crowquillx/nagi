{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "flatpak" "enable" ] false;
  packageRefs = get [ "features" "flatpak" "packages" ] [ ];
  isNonEmptyString = value: lib.isString value && value != "";
  isBundleRef =
    ref:
    lib.isAttrs ref
    && isNonEmptyString (ref.appId or null)
    && lib.isAttrs (ref.bundle or null)
    && isNonEmptyString (ref.bundle.url or null)
    && isNonEmptyString (ref.bundle.hash or null);
  validPackageRef = ref: isNonEmptyString ref || isBundleRef ref;
  normalizePackageRef =
    ref:
    if lib.isString ref then
      ref
    else
      {
        inherit (ref) appId;
        sha256 = ref.bundle.hash;
        bundle = toString (
          pkgs.fetchurl {
            inherit (ref.bundle) url hash;
          }
        );
      };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.all validPackageRef packageRefs;
          message = "features.flatpak.packages entries must be non-empty app IDs or bundle declarations with appId, bundle.url, and bundle.hash.";
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
        packages = map normalizePackageRef packageRefs;
        uninstallUnmanaged = true;
      };
    })
  ];
}
