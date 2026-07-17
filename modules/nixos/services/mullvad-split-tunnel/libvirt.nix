# Libvirt integration: start/stop the Mullvad Whonix tunnel from the
# Whonix-Gateway qemu lifecycle hook (UUID-matched, fail-closed).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  m = import ./common.nix { inherit config lib; };
  inherit (m) whonixEnabled vmUuid;

  libvirtHook =
    let
      hook = pkgs.writeShellApplication {
        name = "mullvad-whonix-libvirt-hook";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.libvirt
        ];
        text = ''
          set -eu

          expected_uuid=${lib.escapeShellArg (if vmUuid == null then "" else vmUuid)}
          xml="$(cat || true)"
          uuid="$(printf '%s\n' "$xml" | sed -n 's/^[[:space:]]*<uuid>\([^<]*\)<\/uuid>.*/\1/p' | head -n 1)"
          if [[ -z "$uuid" ]]; then
            uuid="$(virsh domuuid "$1" 2>/dev/null || true)"
          fi

          # Fail closed: never act without a concrete UUID match against the
          # configured Whonix-Gateway domain. Other VMs are ignored.
          if [[ -z "$uuid" || "$uuid" != "$expected_uuid" ]]; then
            exit 0
          fi

          case "$2/$3" in
            prepare/begin)
              ${pkgs.systemd}/bin/systemctl restart mullvad-whonix.service
              ;;
            release/end)
              ${pkgs.systemd}/bin/systemctl stop mullvad-whonix.service
              ;;
          esac
        '';
      };
    in
    "${hook}/bin/mullvad-whonix-libvirt-hook";
in
{
  config = lib.mkIf whonixEnabled {
    systemd.services = {
      # nixpkgs materializes declarative hooks through this oneshot. Keep it
      # active so switches install new hooks immediately and restart it when
      # their generated configuration changes.
      libvirtd-config = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.RemainAfterExit = true;
      };
    };

    virtualisation.libvirtd.hooks.qemu.mullvad-whonix = libvirtHook;
  };
}
