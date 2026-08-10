{
  lib,
  config,
  vars,
  ...
}:
let
  v = vars;
  sopsVars = v.security.sops;
  inherit (sopsVars)
    ageKeyFile
    administrativeGroup
    agePublicKey
    defaultSopsFile
    gnupgHome
    ;
  enabled = sopsVars.enable;
  primaryUser = v.users.primary;
  sshKey = {
    inherit (sopsVars.sshKey) enable name pubName;
    privMode = sopsVars.sshKey.privateMode;
    pubMode = sopsVars.sshKey.publicMode;
  };
  signingKey = {
    inherit (sopsVars.signingKey) enable name pubName;
    privMode = sopsVars.signingKey.privateMode;
    pubMode = sopsVars.signingKey.publicMode;
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !enabled || defaultSopsFile != null;
          message = "security.sops.enable = true requires security.sops.defaultSopsFile to be set to a secrets file path.";
        }
        {
          # sops-nix rejects combining age.keyFile and gnupg.home in one manifest.
          assertion = !enabled || ageKeyFile == null || gnupgHome == null;
          message = "security.sops.ageKeyFile and security.sops.gnupgHome are mutually exclusive; unset one of them (set ageKeyFile = null for GnuPG/Yubikey-only runtime decryption).";
        }
        {
          assertion =
            !enabled
            || (
              builtins.isString primaryUser
              && primaryUser != ""
              && builtins.hasAttr primaryUser config.users.users
            );
          message = "security.sops.enable = true requires users.primary (\"${toString primaryUser}\") to exist as a NixOS user.";
        }
        {
          assertion = !(enabled && sshKey.enable && sshKey.name == sshKey.pubName);
          message = "security.sops.sshKey.name and pubName must differ.";
        }
        {
          assertion = !(enabled && signingKey.enable && signingKey.name == signingKey.pubName);
          message = "security.sops.signingKey.name and pubName must differ.";
        }
        {
          assertion = agePublicKey == null || agePublicKey != "";
          message = "security.sops.agePublicKey must be null or a non-empty string (the host's age public key for future per-host .sops.yaml templating).";
        }
      ];
    }
    (lib.optionalAttrs (defaultSopsFile != null) {
      sops.defaultSopsFile = defaultSopsFile;
    })
    (lib.mkIf enabled {
      sops = {
        age = {
          keyFile = lib.mkIf (ageKeyFile != null) ageKeyFile;
          # We intentionally do not use host openssh keys for sops.
          # The host's openssh host key is unrelated to user secrets.
          sshKeyPaths = lib.mkForce [ ];
        };
        gnupg = {
          # sops-nix defaults gnupg.sshKeyPaths to the host's RSA ssh host
          # key. Loading it as a GPG identity fails decryption because the
          # host key is not a sops recipient. Disable the auto-import.
          sshKeyPaths = lib.mkForce [ ];
          home = lib.mkIf (gnupgHome != null) gnupgHome;
        };
        # Decrypt at every boot via a systemd unit so /run/secrets survives
        # across reboots. Without this, secrets are only materialized at
        # nixos-rebuild switch time, which is not enough for a workstation
        # that boots daily.
        useSystemdActivation = true;
        # Validate sops files at build time. The pinned sops-nix runs
        # `sops-install-secrets -check-mode=sopsfile` in the manifest
        # derivation's checkPhase: it parses the encrypted YAML/JSON and
        # verifies each declared secret key exists, but it does NOT decrypt
        # and does NOT need the age/GPG key at build time. This catches
        # malformed sops files and missing declared keys before boot instead
        # of failing silently at activation.
        validateSopsFiles = true;
      };
    })
    (lib.mkIf (enabled && sshKey.enable) {
      sops.secrets.${sshKey.name} = {
        owner = primaryUser;
        group = "users";
        mode = sshKey.privMode;
        path = "/run/secrets/${sshKey.name}";
      };
      sops.secrets.${sshKey.pubName} = {
        owner = primaryUser;
        group = "users";
        mode = sshKey.pubMode;
        path = "/run/secrets/${sshKey.pubName}";
      };
    })
    (lib.mkIf (enabled && signingKey.enable) {
      sops.secrets.${signingKey.name} = {
        owner = primaryUser;
        group = "users";
        mode = signingKey.privMode;
        path = "/run/secrets/${signingKey.name}";
      };
      sops.secrets.${signingKey.pubName} = {
        owner = primaryUser;
        group = "users";
        mode = signingKey.pubMode;
        path = "/run/secrets/${signingKey.pubName}";
      };
    })
    (lib.optionalAttrs (enabled && administrativeGroup != null) {
      # Grant the primary user read access to /var/lib/sops-nix/key.txt
      # so `sops` CLI usage doesn't require sudo or a /tmp copy. The
      # file stays root-owned but group-readable; the user is added to
      # the group so sops decrypts work in interactive shells.
      users.groups.${administrativeGroup} = { };
      users.users.${primaryUser}.extraGroups = [ administrativeGroup ];

      system.activationScripts.chownSopsKeyFile = {
        text = ''
          keyFile=${lib.escapeShellArg ageKeyFile}
          group=${lib.escapeShellArg administrativeGroup}
          if [ -f "$keyFile" ]; then
            chown "root:$group" "$keyFile"
            chmod 0640 "$keyFile"
          fi
        '';
        # Must run after the `groups` activation script creates the
        # administrative group, otherwise chown fails with
        # "invalid group: 'root:sops'".
        deps = [ "groups" ];
      };
    })
  ];
}
