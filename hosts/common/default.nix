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
}: let
  v = config.nagi.variables;
  primaryUser = v.users.primary;
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
in {
  imports =
    [
      ./variables-schema.nix
    ]
    ++ combined.nixosModules;

  nagi.variables = vars;

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
      imports = homeModulesFor {};
      home.username = lib.mkForce primaryUser;
      home.homeDirectory = lib.mkForce "/home/${primaryUser}";
      xdg.configHome = lib.mkForce "/home/${primaryUser}/.config";
    };
  };
}
