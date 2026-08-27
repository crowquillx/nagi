{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    nullableString
    packageToggle
    strictSubmodule
    ;
in
{
  options = {
    security = mkOption {
      type = strictSubmodule {
        sops = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable sops-nix secret management." true;
            defaultSopsFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Default encrypted SOPS file; required when enabled.";
            };
            ageKeyFile = mkOption {
              type = types.nullOr types.nonEmptyStr;
              default = "/var/lib/sops-nix/key.txt";
              description = "Age identity path; mutually exclusive with gnupgHome.";
            };
            agePublicKey = nullableString "Host age public key.";
            gnupgHome = mkOption {
              type = types.nullOr types.nonEmptyStr;
              default = null;
              description = "GnuPG home; mutually exclusive with ageKeyFile.";
            };
            gnupgPublicKey = nullableString "GnuPG public key file.";
            administrativeGroup = mkOption {
              type = types.nullOr types.nonEmptyStr;
              default = null;
            };
            sshKey = mkOption {
              type = strictSubmodule {
                enable = enableOption "Manage SSH keys from SOPS." false;
                name = mkOption {
                  type = types.nonEmptyStr;
                  default = "ssh_key";
                };
                pubName = mkOption {
                  type = types.nonEmptyStr;
                  default = "ssh_key_pub";
                };
                privateMode = mkOption {
                  type = types.strMatching "0[0-7]{3}";
                  default = "0600";
                };
                publicMode = mkOption {
                  type = types.strMatching "0[0-7]{3}";
                  default = "0644";
                };
              };
              default = { };
            };
            signingKey = mkOption {
              type = strictSubmodule {
                enable = enableOption "Manage SSH commit-signing keys from SOPS." false;
                name = mkOption {
                  type = types.nonEmptyStr;
                  default = "ssh_signing_key";
                };
                pubName = mkOption {
                  type = types.nonEmptyStr;
                  default = "ssh_signing_key_pub";
                };
                privateMode = mkOption {
                  type = types.strMatching "0[0-7]{3}";
                  default = "0600";
                };
                publicMode = mkOption {
                  type = types.strMatching "0[0-7]{3}";
                  default = "0644";
                };
              };
              default = { };
            };
            kotomi = mkOption {
              type = packageToggle "the Kotomi target secret" true;
              default = { };
            };
          };
          default = { };
        };
        sudo = mkOption {
          type = strictSubmodule {
            passwordless = enableOption "Allow wheel users to sudo without a password." false;
          };
          default = { };
        };
        yubikey = mkOption {
          type = packageToggle "YubiKey support" false;
          default = { };
        };
      };
      default = { };
    };
    home = mkOption {
      type = strictSubmodule {
        security = mkOption {
          type = strictSubmodule {
            yubikey = mkOption {
              type = strictSubmodule {
                pgpPublicKey = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to the user's PGP public key.";
                };
              };
              default = { };
            };
          };
          default = { };
        };
      };
      default = { };
    };
  };
}
