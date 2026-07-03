{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  enabled = get [ "features" "fileManager" "thunar" "enable" ] desktopEnabled;
in
{
  config = lib.mkIf enabled {
    # Required for trash, network mounts, and general file manager integration.
    services = {
      gvfs.enable = true;
      # Thumbnailer used by Thunar for previews.
      tumbler.enable = true;
      # Common mount backend used by desktop file managers.
      udisks2.enable = true;
    };
  };
}
