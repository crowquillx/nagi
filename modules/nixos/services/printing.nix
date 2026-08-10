{ lib, config, ... }:
let
  enabled = config.nagi.variables.features.printing.enable;
in
{
  config = lib.mkIf enabled {
    services.printing.enable = true;
  };
}
