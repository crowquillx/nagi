{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  ageKeyFile = get [ "security" "sops" "ageKeyFile" ] "/var/lib/sops-nix/key.txt";
  primaryUser = get [ "users" "primary" ] "nagi";
  enabled = sopsEnabled && ageKeyFile != null;
in
{
  config = lib.mkIf enabled {
    # Symlink the host's age private key into the sops CLI default
    # search path so `sops secrets/<host>.yaml` decrypts without
    # manually exporting SOPS_AGE_KEY_FILE or plugging in a Yubikey.
    # The system sops module already declares the age key file; this
    # just makes the CLI find it. The host key file is root-owned but
    # group-readable (mode 0640) once `administrativeGroup` is set, so
    # the primary user can read it via their sops group membership.
    home.activation.symlinkSopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      sopsDir="$HOME/.config/sops/age"
      link="$sopsDir/keys.txt"
      mkdir -p "$sopsDir"
      if [ -e "${ageKeyFile}" ]; then
        run ln -sfn "${ageKeyFile}" "$link"
      else
        echo "nagi: age key not found at ${ageKeyFile}; sops CLI will not find a default key." >&2
      fi
    '';
  };
}