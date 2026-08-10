{ lib, config, ... }:
let
  nmEnabled = config.nagi.variables.features.networking.networkmanager.enable;
in
{
  config = lib.mkIf nmEnabled {
    networking.networkmanager.enable = true;
  };
}
