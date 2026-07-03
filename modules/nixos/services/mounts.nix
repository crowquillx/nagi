{ lib, config, ... }:
let
  v = config.nagi.variables;
  mounts = lib.attrByPath [ "storage" "mounts" ] [ ] v;

  normalizeMount =
    mount:
    let
      fsType = mount.fsType or "auto";
      options = mount.options or [ ];
      mountPath = mount.mountPoint or null;
    in
    {
      device = mount.device or null;
      inherit fsType mountPath options;
    };

  normalizedMounts = map normalizeMount mounts;
in
{
  config = lib.mkMerge [
    {
      assertions = map (mount: {
        assertion =
          mount.device != null
          && mount.device != ""
          && mount.mountPath != null
          && mount.mountPath != "";
        message = "storage.mounts entries must set non-empty device and mountPoint values.";
      }) normalizedMounts;
    }
    {
      fileSystems = builtins.listToAttrs (
        map (mount: {
          name = mount.mountPath;
          value = {
            inherit (mount) device fsType options;
          };
        }) normalizedMounts
      );
    }
  ];
}
