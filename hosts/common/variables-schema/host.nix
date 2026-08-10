{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    mountSubmodule
    nullableString
    packageToggle
    strictSubmodule
    ;
in
{
  options = {
    host = mkOption {
      type = strictSubmodule {
        name = mkOption {
          type = types.nonEmptyStr;
          default = "nagi";
          description = "Host name.";
        };
        isVm = enableOption "Enable virtual-machine guest behavior." false;
        timeZone = mkOption {
          type = types.nonEmptyStr;
          default = "America/Chicago";
        };
        locale = mkOption {
          type = types.nonEmptyStr;
          default = "en_US.UTF-8";
        };
        stateVersion = mkOption {
          type = strictSubmodule {
            nixos = mkOption {
              type = types.nonEmptyStr;
              default = "25.05";
              description = "NixOS compatibility state version. Change only with an explicit migration.";
            };
            home = mkOption {
              type = types.nonEmptyStr;
              default = "25.05";
              description = "Home Manager compatibility state version. Change only with an explicit migration.";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    storage = mkOption {
      type = strictSubmodule {
        mounts = mkOption {
          type = types.listOf mountSubmodule;
          default = [ ];
          description = "Repo-owned extra fileSystems entries (device, mountPoint, fsType, options).";
        };
      };
      default = { };
    };
    boot = mkOption {
      type = strictSubmodule {
        systemdBoot = mkOption {
          type = packageToggle "systemd-boot" true;
          default = { };
        };
        kernel = mkOption {
          type = types.enum [
            "default"
            "zen"
            "latest"
          ];
          default = "default";
        };
        secureBoot = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable Lanzaboote Secure Boot." false;
            pkiBundle = mkOption {
              type = types.nonEmptyStr;
              default = "/var/lib/sbctl";
            };
            autoEnroll = enableOption "Automatically enroll Secure Boot keys." false;
            includeMicrosoftKeys = enableOption "Include Microsoft Secure Boot keys." true;
          };
          default = { };
        };
      };
      default = { };
    };
    users = mkOption {
      type = strictSubmodule {
        primary = mkOption {
          type = types.nonEmptyStr;
          default = "nagi";
        };
        flakeDirectory = mkOption {
          type = types.nullOr types.nonEmptyStr;
          default = null;
        };
        extraPackages = mkOption {
          type = types.listOf types.nonEmptyStr;
          default = [ ];
        };
        git = mkOption {
          type = strictSubmodule {
            name = nullableString "Git author name.";
            email = nullableString "Git author email.";
          };
          default = { };
        };
      };
      default = { };
    };
  };
}
