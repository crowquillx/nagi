{ lib, config, ... }:
let
  v = config.nagi.variables;
  desktopEnabled = v.desktop.enable;
  killProcessesOnLogout = v.desktop.session.killProcessesOnLogout;
in
{
  config = lib.mkIf (desktopEnabled && killProcessesOnLogout) {
    services.logind.settings.Login.KillUserProcesses = true;
  };
}
