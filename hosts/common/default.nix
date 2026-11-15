{
  lib,
  pkgs,
  config,
  vars,
  self,
  inputs,
  combined,
  homeModulesFor,
  ...
}:
let
  v = config.nagi.variables;
  primaryUser = v.users.primary;
  hasUmbriel = v.desktop.enable && v.desktop.compositor == "umbriel";
  hmBackupCommand = pkgs.writeShellScript "home-manager-backup" ''
    set -eu

    target_path="$1"
    timestamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    backup_path="${"$"}{target_path}.hm-backup-${"$"}timestamp"

    while [ -e "$backup_path" ]; do
      timestamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-$RANDOM"
      backup_path="${"$"}{target_path}.hm-backup-${"$"}timestamp"
    done

    exec ${pkgs.coreutils}/bin/mv "$target_path" "$backup_path"
  '';
in
{
  imports = [
    ./variables-schema.nix
  ]
  ++ combined.nixosModules;

  nagi.variables = vars;
  networking.hostName = v.host.name;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = hmBackupCommand;
    # Pass the module-resolved nagi.variables (not the specialArg) so
    # embedded HM sees the same defaults as NixOS consumers. Keep
    # inputs/combined/self; avoid inheriting the specialArg vars.
    extraSpecialArgs = {
      vars = config.nagi.variables;
      inherit self inputs combined;
    };
    users.${primaryUser} = {
      imports = homeModulesFor {
        umbriel = hasUmbriel;
      };
      home.username = lib.mkForce primaryUser;
      home.homeDirectory = lib.mkForce "/home/${primaryUser}";
      xdg.configHome = lib.mkForce "/home/${primaryUser}/.config";
    };
  };

  # Boot-time HM activation runs dconf/xfconf in a throwaway dbus-run-session
  # without XDG_RUNTIME_DIR. GIO then autostarts gvfsd, whose gvfsd-fuse falls
  # back to ~/.gvfs and crashes when the bus closes, leaving a dead FUSE mount
  # that breaks file managers listing $HOME. Keep GIO on the local VFS here.
  systemd.services."home-manager-${primaryUser}".environment.GIO_USE_VFS = "local";
}
