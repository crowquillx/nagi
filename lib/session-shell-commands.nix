{
  sessionShell,
  noctaliaCommand ? "nagi-noctalia-shell",
}:
let
  mkCommands =
    {
      startupArgs,
      lockCommand,
      restart,
    }:
    {
      inherit startupArgs lockCommand restart;
      startupCommand = if startupArgs == null then null else builtins.concatStringsSep " " startupArgs;
    };

  commands = {
    noctalia = mkCommands {
      startupArgs = [ noctaliaCommand ];
      lockCommand = "${noctaliaCommand} msg session lock";
      restart = {
        service = "noctalia.service";
        process = {
          exact = true;
          value = "noctalia";
        };
        command = "nagi-noctalia-shell";
      };
    };
    dms = mkCommands {
      startupArgs = [
        "dms"
        "run"
      ];
      lockCommand = "dms ipc call lock lock";
      restart = {
        service = "dms.service";
        process = {
          exact = false;
          value = "dms run";
        };
        command = "dms run";
      };
    };
    caelestia = mkCommands {
      startupArgs = [
        "caelestia"
        "shell"
        "-d"
      ];
      lockCommand = "caelestia shell lock lock";
      restart = {
        service = "caelestia.service";
        process = {
          exact = false;
          value = "caelestia-shell";
        };
        command = "caelestia shell -d";
      };
    };
    inir = mkCommands {
      startupArgs = [
        "inir"
        "run"
      ];
      lockCommand = "inir lock activate";
      restart = {
        service = "inir.service";
        process = {
          exact = false;
          value = "inir run";
        };
        command = "inir run";
      };
    };
    ii = mkCommands {
      startupArgs = [ "ii" ];
      lockCommand = "ii ipc call lock activate";
      restart = {
        service = null;
        process = {
          exact = false;
          value = "qs -c ii";
        };
        command = "ii";
      };
    };
    none = mkCommands {
      startupArgs = null;
      lockCommand = "loginctl lock-session";
      restart = null;
    };
  };

  selected =
    if builtins.isString sessionShell && builtins.hasAttr sessionShell commands then
      commands.${sessionShell}
    else
      commands.none;
in
selected
