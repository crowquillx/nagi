{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    flatpakPackage
    nullableString
    packageToggle
    portOption
    strictSubmodule
    ;
in
{
  options.features = {
    tailscale = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable Tailscale." true;
        acceptDns = enableOption "Accept Tailscale DNS." true;
        disableUpstreamLogging = enableOption "Disable sending Tailscale client logs upstream." false;
        exitNode = nullableString "Tailscale exit-node address.";
      };
      default = { };
    };
    ssh = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable OpenSSH." false;
        openFirewall = enableOption "Open the SSH port." true;
        port = portOption "OpenSSH port." 22;
        passwordAuthentication = enableOption "Allow SSH password authentication." false;
        permitRootLogin = mkOption {
          type = types.enum [
            "prohibit-password"
            "without-password"
            "forced-commands-only"
            "no"
          ];
          default = "prohibit-password";
        };
        authorizedKeys = mkOption {
          type = types.listOf types.nonEmptyStr;
          default = [ ];
        };
        autoTmux = mkOption {
          type = strictSubmodule {
            enable = enableOption "Automatically attach interactive SSH logins to a persistent tmux session." false;
            sessionName = mkOption {
              type = types.strMatching "[A-Za-z0-9][A-Za-z0-9_-]*";
              default = "ssh";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    shell = mkOption {
      type = strictSubmodule {
        fish = mkOption {
          type = packageToggle "Fish" true;
          default = { };
        };
        zsh = mkOption {
          type = packageToggle "Zsh" false;
          default = { };
        };
        starship = mkOption {
          type = packageToggle "Starship" true;
          default = { };
        };
      };
      default = { };
    };
    nh = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable nh." true;
        clean = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable nh cleanup." true;
            extraArgs = mkOption {
              type = types.nonEmptyStr;
              default = "--keep-since 4d --keep 3";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    audio = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable PipeWire audio." true;
      };
      default = { };
    };
    fileManager = mkOption {
      type = types.submodule {
        options.thunar = mkOption {
          type = types.submodule {
            options.enable = mkOption {
              type = types.bool;
              default = config.desktop.enable;
              description = "Enable Thunar.";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    zoxide = mkOption {
      type = packageToggle "zoxide" true;
      default = { };
    };
    bluetooth = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable Bluetooth." true;
        powerOnBoot = enableOption "Power on Bluetooth at boot." false;
      };
      default = { };
    };
    networking = mkOption {
      type = strictSubmodule {
        networkmanager = mkOption {
          type = packageToggle "NetworkManager" true;
          default = { };
        };
      };
      default = { };
      description = "Repo-owned networking toggles currently limited to NetworkManager.";
    };
    portals = mkOption {
      type = packageToggle "desktop portals" true;
      default = { };
    };
    razer = mkOption {
      type = strictSubmodule {
        openrazer = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable OpenRazer driver and daemon." false;
            users = mkOption {
              type = types.listOf types.nonEmptyStr;
              default = [ config.users.primary ];
              description = "Users added to the openrazer group so they can run the daemon.";
            };
          };
          default = { };
        };
        inputRemapper = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable input-remapper for mouse macros and key rebinding." false;
            enableUdevRules = enableOption "Enable input-remapper udev rules for hotplugged devices." false;
          };
          default = { };
        };
      };
      default = { };
      description = "Razer peripheral support: OpenRazer driver/daemon plus input-remapper for macros.";
    };
    services = mkOption {
      type = types.submodule {
        options = {
          fstrim = mkOption {
            type = packageToggle "periodic filesystem trim" true;
            default = { };
          };
          resolved = mkOption {
            type = types.submodule {
              options.enable = mkOption {
                type = types.bool;
                default = config.features.networking.networkmanager.enable;
                description = "Enable systemd-resolved.";
              };
            };
            default = { };
          };
          powerProfilesDaemon = mkOption {
            type = types.submodule {
              options.enable = mkOption {
                type = types.bool;
                default = !config.features.laptop.tlp.enable;
                description = "Enable power-profiles-daemon. Mutually exclusive with features.laptop.tlp.enable.";
              };
            };
            default = { };
          };
        };
      };
      default = { };
      description = "Repo-owned host service toggles (fstrim, resolved, power-profiles-daemon).";
    };
    printing = mkOption {
      type = packageToggle "printing" false;
      default = { };
    };
    flatpak = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable declarative Flatpak." false;
        packages = mkOption {
          type = types.listOf flatpakPackage;
          default = [ ];
        };
      };
      default = { };
    };
    laptop = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable laptop power management." false;
        upower = mkOption {
          type = packageToggle "UPower" true;
          default = { };
        };
        tlp = mkOption {
          type = packageToggle "TLP. Mutually exclusive with features.services.powerProfilesDaemon.enable" false;
          default = { };
        };
        thermald = mkOption {
          type = packageToggle "thermald (Intel-oriented)" false;
          default = { };
        };
        powertop = mkOption {
          type = packageToggle "powertop tuning" false;
          default = { };
        };
        fwupd = mkOption {
          type = packageToggle "firmware updates" true;
          default = { };
        };
        logind = mkOption {
          type = strictSubmodule {
            lidSwitch = mkOption {
              type = types.nonEmptyStr;
              default = "suspend";
            };
            lidSwitchExternalPower = mkOption {
              type = types.nonEmptyStr;
              default = "ignore";
            };
            lidSwitchDocked = mkOption {
              type = types.nonEmptyStr;
              default = "ignore";
            };
          };
          default = { };
        };
      };
      default = { };
    };
  };
}
