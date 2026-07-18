{ lib, config, ... }:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  killProcessesOnLogout = get [ "desktop" "session" "killProcessesOnLogout" ] false;
in
{
  config = lib.mkIf (desktopEnabled && killProcessesOnLogout) {
    services.logind.settings.Login.KillUserProcesses = true;
  };
}
