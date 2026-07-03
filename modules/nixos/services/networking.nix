{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  nmEnabled = get [ "features" "networking" "networkmanager" "enable" ] true;
in
{
  config = lib.mkIf nmEnabled {
    networking.networkmanager.enable = true;
  };
}
