{ lib, config, ... }:
let
  v = config.nagi.variables;
  sessionShell = v.desktop.sessionShell or "none";
  quickshellLock = builtins.elem sessionShell [
    "inir"
    "ii"
  ];
in
{
  config = lib.mkIf (v.desktop.enable && quickshellLock) {
    security.pam.services.quickshell = { };
  };
}
