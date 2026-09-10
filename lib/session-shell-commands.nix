{
  sessionShell ? "noctalia",
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
  };

  selected =
    if builtins.isString sessionShell && builtins.hasAttr sessionShell commands then
      commands.${sessionShell}
    else
      commands.noctalia;
in
selected
