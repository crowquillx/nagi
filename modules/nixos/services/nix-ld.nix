{ lib, config, ... }:
let
  v = config.nagi.variables;
  enabled = v.features.nixLd.enable;
in
{
  config = lib.mkIf enabled {
    programs.nix-ld.enable = true;
  };
}
