{
  config,
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  enabled = get [ "features" "mullvad" "splitTunnel" "browser" "enable" ] false;
  # Reconstructs argv from a NUL-delimited file so runtime arguments never enter
  # vopono's single APPLICATION shellwords string.
  runner = pkgs.writeShellApplication {
    name = "mullvad-browser-vpn-run";
    text = ''
      set -euo pipefail
      argv_file="''${1:?missing argv file}"
      mapfile -d $'\0' -t args < "$argv_file"
      rm -f "$argv_file"
      exec "''${args[@]}"
    '';
  };
  launcher = pkgs.writeShellApplication {
    name = "mullvad-browser-vpn";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.libnotify
      pkgs.mullvad-browser
      pkgs.vopono
      runner
    ];
    text = ''
      set -euo pipefail

      server="$(${pkgs.vopono}/bin/vopono servers mullvad 2>/dev/null \
        | awk 'tolower($2) == "wireguard" { sub(/\.conf$/, "", $3); print $3 }' \
        | shuf -n 1)"

      if [[ -z "$server" ]]; then
        notify-send \
          "Mullvad Browser VPN is not initialized" \
          "Run: vopono sync --protocol wireguard"
        exit 1
      fi

      argv_file="$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/mullvad-browser-vpn-argv.XXXXXX")"
      {
        printf '%s\0' ${pkgs.mullvad-browser}/bin/mullvad-browser
        printf '%s\0' "$@"
      } >"$argv_file"

      # Only the trusted runner path and argv-file path enter APPLICATION.
      # Desktop/runtime arguments stay as separate NUL-delimited entries.
      printf -v application '%q %q' ${runner}/bin/mullvad-browser-vpn-run "$argv_file"

      exec ${pkgs.vopono}/bin/vopono exec \
        --provider mullvad \
        --protocol wireguard \
        --firewall nftables \
        --server "$server" \
        --no-proxy \
        "$application"
    '';
  };
in
{
  config = lib.mkIf enabled {
    home.packages = [
      launcher
      pkgs.vopono
    ];

    # This user-level entry takes precedence over the package entry with the
    # same filename, so menus and URL handlers cannot bypass the VPN wrapper.
    xdg.desktopEntries.mullvad-browser = {
      name = "Mullvad Browser (VPN)";
      genericName = "Privacy Web Browser";
      comment = "Browse through a randomly selected Mullvad WireGuard relay";
      exec = "${launcher}/bin/mullvad-browser-vpn %U";
      icon = "mullvad-browser";
      terminal = false;
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };
  };
}
