{ lib, pkgs, vars ? { }, config, ... }:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (desktopEnabled && compositor == "niri");
  noctaliaIdleManage = noctaliaEnable && compositor == "niri";
  sessionEnabled = get [ "desktop" "session" "enable" ] desktopEnabled;
  waylandTarget = config.wayland.systemd.target;

  polkitEnable = get [ "desktop" "session" "polkit" "enable" ] true;
  lockEnable = get [ "desktop" "session" "lock" "enable" ] true;
  lockCommand = get [ "desktop" "session" "lock" "command" ] "loginctl lock-session";
  idleSeconds = get [ "desktop" "session" "lock" "idleSeconds" ] 600;
  lockBeforeSleep = get [ "desktop" "session" "lock" "beforeSleep" ] true;
  startupCommand = get [ "desktop" "shellStartupCommand" ] null;
  defaultStartupApps = [
    "wl-paste --watch cliphist store"
  ];
  startupBackend = get [ "desktop" "startup" "backend" ] "systemd";
  startupApps = get [ "desktop" "startup" "apps" ] defaultStartupApps;
  chatClient = get [ "features" "chat" "client" ] "none";
  chatStartupEnable = get [ "features" "chat" "startup" "enable" ] (chatClient != "none");
  equicordEnabled = get [ "features" "chat" "discord" "equicord" "enable" ] false;
  chatCommands =
    if chatClient == "discord" then
      [ "sleep 5 && discord" ]
    else if chatClient == "equibop" then
      [ "sleep 5 && equibop" ]
    else
      [ ];
  effectiveStartupApps =
    startupApps
    ++ lib.optionals chatStartupEnable chatCommands;
  effectiveShellStartupCommand = startupCommand;
  shellStartupEnable = effectiveShellStartupCommand != null;
  appStartupEnable = effectiveStartupApps != [ ];
  appStartupSystemdEnable = appStartupEnable && startupBackend == "systemd";

  mkStartupService = index: command: {
    name = "nagi-startup-app-${toString index}";
    value = {
      Unit = {
        Description = "Tanos Startup App ${toString index}";
        PartOf = [ waylandTarget ];
        After = [ waylandTarget ];
      };
      Service = {
        ExecStart = "${pkgs.bash}/bin/bash -lc ${lib.escapeShellArg command}";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ waylandTarget ];
      };
    };
  };

  startupAppServices = builtins.listToAttrs (lib.imap0 mkStartupService effectiveStartupApps);

  lockScript = pkgs.writeShellScript "nagi-lock-session" ''
    exec ${lockCommand}
  '';

  swayidleArgs =
    [
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
        {
          assertion = builtins.all (cmd: lib.isString cmd && cmd != "") startupApps;
          message = "desktop.startup.apps must be a list of non-empty command strings.";
        }
        {
          assertion = builtins.elem startupBackend [ "systemd" "niri" ];
          message = "desktop.startup.backend must be one of: systemd, niri.";
        }
        {
          assertion = !equicordEnabled || chatClient == "discord";
          message = "features.chat.discord.equicord.enable requires features.chat.client = \"discord\"; Equicord cannot be used with Equibop.";
        }
        {
          assertion = !(appStartupEnable && startupBackend == "niri") || compositor == "niri";
          message = "desktop.startup.backend = \"niri\" requires desktop.compositor = \"niri\".";
        }
      ];
    }
    (lib.mkIf (desktopEnabled && sessionEnabled) {
      systemd.user.services = lib.mkMerge [
        (lib.mkIf polkitEnable {
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
        (lib.mkIf (lockEnable && !noctaliaIdleManage) {
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
        (lib.mkIf appStartupSystemdEnable startupAppServices)
      ];
    })
  ];
}
