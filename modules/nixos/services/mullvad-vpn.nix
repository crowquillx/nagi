{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.nagi.variables.features.mullvad;
  mullvadCliPackage = lib.getAttr "mullvad" pkgs;
  lanMode = if cfg.service.allowLan then "allow" else "block";
  # mullvad-daemon reports active before the management socket is ready.
  setLanSharing = pkgs.writeShellScript "mullvad-lan-sharing" ''
    set -eu
    mullvad="${mullvadCliPackage}/bin/mullvad"
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if "$mullvad" lan set ${lanMode}; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.5
    done
    echo "mullvad lan set ${lanMode} failed after waiting for the management interface" >&2
    exit 1
  '';
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.service.enable || cfg.package == "gui";
          message = "features.mullvad.service.enable requires features.mullvad.package = \"gui\".";
        }
      ];
    }
    (lib.mkIf cfg.service.enable {
      services.mullvad-vpn = {
        enable = true;
        gui.enable = cfg.package == "gui";
      };

      systemd.services.mullvad-lan-sharing = {
        description = "Configure Mullvad local network sharing";
        wantedBy = [ "multi-user.target" ];
        requires = [ "mullvad-daemon.service" ];
        after = [ "mullvad-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${setLanSharing}";
          RemainAfterExit = true;
        };
      };
    })
  ];
}
