{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get [ "features" "printing" "enable" ] false;
in
{
  config = lib.mkIf enabled {
    services.printing.enable = true;
  };
}
