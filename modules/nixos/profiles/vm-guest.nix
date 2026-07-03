{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  isVm = get [ "host" "isVm" ] false;
in
{
  config = lib.mkIf isVm {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
  };
}
