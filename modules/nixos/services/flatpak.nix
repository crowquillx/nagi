{
  lib,
  config,
  pkgs,
  ...
}:
let
  v = config.nagi.variables;
  enabled = v.features.flatpak.enable;
  packageRefs = v.features.flatpak.packages;
  gtkTheming = v.features.theme.gtk.enable;
  gtkThemeRuntimes = [
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
  ];
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
        packages = (lib.optionals gtkTheming gtkThemeRuntimes) ++ map normalizePackageRef packageRefs;
        uninstallUnmanaged = true;
        overrides = lib.mkIf gtkTheming {
          global.Context.filesystems = [
            "xdg-config/gtk-3.0:ro"
            "xdg-config/gtk-4.0:ro"
            "xdg-data/color-schemes:ro"
          ];
        };
      };
    })
    (lib.mkIf (enabled && v.features.networking.networkmanager.enable) {
      systemd.services.flatpak-managed-install = {
        wants = [ "NetworkManager-wait-online.service" ];
        after = [ "NetworkManager-wait-online.service" ];
      };
    })
  ];
}
