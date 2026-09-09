{ pkgs, restart }:
if restart == null then
  null
else
  let
    processKill =
      if restart.process.exact then
        "${pkgs.procps}/bin/pkill -u \"$USER\" -x ${restart.process.value}"
      else
        "${pkgs.procps}/bin/pkill -u \"$USER\" -f '${restart.process.value}'";
    serviceRestart =
      if restart.service == null then
        ""
      else
        ''
          if ${pkgs.systemd}/bin/systemctl --user list-unit-files ${restart.service} --no-legend 2>/dev/null | read -r _; then
            ${pkgs.systemd}/bin/systemctl --user restart ${restart.service}
            exit $?
          fi

        '';
  in
  pkgs.writeShellApplication {
    name = "nagi-restart-shell";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${serviceRestart}${processKill} 2>/dev/null || true
      nohup ${restart.command} >/dev/null 2>&1 &
      disown || true
    '';
  }
