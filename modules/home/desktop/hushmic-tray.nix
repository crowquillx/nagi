{ lib, pkgs, vars ? { }, ... }:
let
  get = path: default: lib.attrByPath path default vars;
  deviceId = get [ "desktop" "hushmic" "deviceId" ] null;
in
{
  config = lib.mkIf (deviceId != null) {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "nagi-hushmic-tray";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.hushmic
          pkgs.pipewire
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail

          until busctl --user --quiet status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do
            sleep 0.25
          done

          mic=${lib.escapeShellArg deviceId}
          stable=0
          until [ "$stable" -ge 10 ]; do
            if pw-dump 2>/dev/null | grep -Fq "\"node.name\": \"$mic\""; then
              stable=$((stable + 1))
            else
              stable=0
            fi
            sleep 1
          done

          exec hushmic --tray
        '';
      })
    ];
  };
}
