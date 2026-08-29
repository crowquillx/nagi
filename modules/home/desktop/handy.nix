{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  packageNames = lib.attrByPath [ "users" "extraPackages" ] [ ] vars;
  handyEnabled = builtins.elem "handy" packageNames;
  handyToggle = pkgs.writeShellApplication {
    name = "nagi-handy-toggle-transcription";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.procps
    ];
    text = ''
      set -euo pipefail

      uid="$(id -u)"
      handy_process='/bin/handy( |$)'
      if ! pgrep -u "$uid" -f "$handy_process" >/dev/null 2>&1; then
        ${pkgs.handy}/bin/handy --start-hidden >/dev/null 2>&1 &

        for _ in $(seq 1 50); do
          if pgrep -u "$uid" -f "$handy_process" >/dev/null 2>&1; then
            break
          fi
          sleep 0.1
        done

        pgrep -u "$uid" -f "$handy_process" >/dev/null 2>&1 || exit 1
        sleep 0.25
      fi

      exec ${pkgs.procps}/bin/pkill -USR2 -u "$uid" -f "$handy_process"
    '';
  };
in
{
  config = lib.mkIf handyEnabled {
    home.packages = [ handyToggle ];
  };
}
