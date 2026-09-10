{
  lib,
  pkgs,
  vars ? { },
  config,
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  shell = import ./session-shell/lib.nix { inherit lib vars; };
  inherit (shell) shellOwnsIdle matePolkitEnable;
  sessionEnabled = get [ "desktop" "session" "enable" ] desktopEnabled;
  waylandTarget = config.wayland.systemd.target;

  polkitEnable = get [ "desktop" "session" "polkit" "enable" ] true;
  lockEnable = get [ "desktop" "session" "lock" "enable" ] true;
  lockCommand = get [ "desktop" "session" "lock" "command" ] shell.lockCommand;
  idleSeconds = get [ "desktop" "session" "lock" "idleSeconds" ] 600;
  lockBeforeSleep = get [ "desktop" "session" "lock" "beforeSleep" ] true;
  startupCommand = get [ "desktop" "shellStartupCommand" ] null;
  effectiveShellStartupCommand = startupCommand;
  shellStartupEnable = effectiveShellStartupCommand != null;

  lockScript = pkgs.writeShellScript "nagi-lock-session" ''
    exec ${lockCommand}
  '';

  swayidleArgs = [
    "-w"
    "timeout"
    (toString idleSeconds)
    lockScript
  ]
  ++ lib.optionals lockBeforeSleep [
    "before-sleep"
    lockScript
  ];
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(sessionEnabled && lockEnable) || (lib.isString lockCommand && lockCommand != "");
          message = "desktop.session.lock.command must be a non-empty string when desktop.session.lock.enable is true.";
        }
        {
          assertion = !(sessionEnabled && lockEnable) || (builtins.isInt idleSeconds && idleSeconds > 0);
          message = "desktop.session.lock.idleSeconds must be a positive integer.";
        }
        {
          assertion =
            !(desktopEnabled && sessionEnabled && shellStartupEnable)
            || (lib.isString effectiveShellStartupCommand && effectiveShellStartupCommand != "");
          message = "desktop.shellStartupCommand must be a non-empty string when provided.";
        }
      ];
    }
    (lib.mkIf (desktopEnabled && sessionEnabled) {
      systemd.user.services = lib.mkMerge [
        (lib.mkIf (polkitEnable && matePolkitEnable) {
          nagi-polkit-agent = {
            Unit = {
              Description = "Tanos Polkit Authentication Agent";
              PartOf = [ waylandTarget ];
              After = [ waylandTarget ];
            };
            Service = {
              ExecStart = "${pkgs.mate-polkit}/libexec/polkit-mate-authentication-agent-1";
              Restart = "on-failure";
              RestartSec = 2;
            };
            Install = {
              WantedBy = [ waylandTarget ];
            };
          };
        })
        (lib.mkIf (lockEnable && !shellOwnsIdle) {
          nagi-idle-lock = {
            Unit = {
              Description = "Tanos Idle Lock Service";
              PartOf = [ waylandTarget ];
              After = [ waylandTarget ];
            };
            Service = {
              ExecStart = lib.escapeShellArgs ([ "${pkgs.swayidle}/bin/swayidle" ] ++ swayidleArgs);
              Restart = "on-failure";
              RestartSec = 2;
            };
            Install = {
              WantedBy = [ waylandTarget ];
            };
          };
        })
        (lib.mkIf shellStartupEnable {
          nagi-shell-startup = {
            Unit = {
              Description = "Tanos Desktop Shell Startup";
              PartOf = [ waylandTarget ];
              After = [ waylandTarget ];
            };
            Service = {
              ExecStart = "${pkgs.bash}/bin/bash -lc ${lib.escapeShellArg effectiveShellStartupCommand}";
              Restart = "on-failure";
              RestartSec = 2;
            };
            Install = {
              WantedBy = [ waylandTarget ];
            };
          };
        })
      ];
    })
  ];
}
