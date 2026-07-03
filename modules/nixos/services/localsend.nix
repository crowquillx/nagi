{ lib, config, ... }:
let
  cfg = config.nagi.variables.features.localsend;
in
{
  config = lib.mkIf cfg.openFirewall {
    networking.firewall.allowedTCPPorts = [ 53317 ];
    networking.firewall.allowedUDPPorts = [ 53317 ];
  };
}
