{ lib, config, ... }:
let
  v = config.nagi.variables;
  isVm = v.host.isVm;
in
{
  config = lib.mkIf isVm {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
  };
}
