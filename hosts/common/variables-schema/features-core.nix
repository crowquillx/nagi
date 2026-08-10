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
  options.features = {
    swap = mkOption {
      type = strictSubmodule {
        zram = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable compressed zram swap." true;
            memoryPercent = mkOption {
              type = types.ints.between 1 100;
              default = 25;
            };
          };
          default = { };
        };
        disk = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable a disk-backed swap file." false;
            path = mkOption {
              type = types.nonEmptyStr;
              default = "/var/lib/swapfile";
            };
            sizeMiB = mkOption {
              type = types.ints.positive;
              default = 4096;
            };
          };
          default = { };
        };
        swappiness = mkOption {
          type = types.ints.between 0 200;
          default = 10;
        };
      };
      default = { };
    };
    stylix = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable Stylix." true;
        variant = mkOption {
          type = types.enum [
            "moon"
            "main"
            "dawn"
          ];
          default = "moon";
        };
      };
      default = { };
    };
    nixMaintenance = mkOption {
      type = strictSubmodule {
        gc = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable automatic garbage collection." false;
            dates = mkOption {
              type = types.nonEmptyStr;
              default = "weekly";
            };
            options = mkOption {
              type = types.str;
              default = "";
            };
          };
          default = { };
        };
        optimise = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable automatic Nix store optimisation." true;
            dates = mkOption {
              type = types.either types.nonEmptyStr (types.listOf types.nonEmptyStr);
              default = "weekly";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    localsend = mkOption {
      type = strictSubmodule {
        package = mkOption {
          type = packageToggle "LocalSend" false;
          default = { };
        };
        openFirewall = enableOption "Open LocalSend firewall ports." false;
      };
      default = { };
    };
    chat = mkOption {
      type = types.submodule (chatArgs: {
        options = {
          client = mkOption {
            type = types.enum [
              "none"
              "discord"
              "equibop"
            ];
            default = "none";
            description = "Chat client to install.";
          };
          startup = mkOption {
            type = types.submodule {
              options.enable = mkOption {
                type = types.bool;
                default = chatArgs.config.client != "none";
                description = "Autostart the selected chat client.";
              };
            };
            default = { };
          };
          discord = mkOption {
            type = strictSubmodule {
              forceXwayland = enableOption "Force Discord under Xwayland." true;
              equicord = mkOption {
                type = packageToggle "Equicord" false;
                default = { };
              };
            };
            default = { };
          };
        };
      });
      default = { };
    };
    mullvad = mkOption {
      type = strictSubmodule {
        package = mkOption {
          type = types.enum [
            "none"
            "cli"
            "gui"
          ];
          default = "none";
        };
        service = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable Mullvad VPN service." false;
            allowLan = enableOption "Allow local network traffic through the Mullvad firewall." false;
          };
          default = { };
        };
      };
      default = { };
    };
    terminals = mkOption {
      type = strictSubmodule {
        default = mkOption {
          type = types.enum [
            "alacritty"
            "foot"
            "ghostty"
            "kitty"
          ];
          default = "kitty";
          description = "Default terminal used by desktop applications.";
        };
        alacritty = mkOption {
          type = packageToggle "Alacritty" true;
          default = { };
        };
        foot = mkOption {
          type = packageToggle "Foot" true;
          default = { };
        };
        ghostty = mkOption {
          type = packageToggle "Ghostty" true;
          default = { };
        };
        kitty = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable Kitty." true;
            opacity = mkOption {
              type = types.number;
              default = 1.0;
            };
          };
          default = { };
        };
      };
      default = { };
    };
    videoEditing = mkOption {
      type = strictSubmodule {
        kdenlive = mkOption {
          type = packageToggle "Kdenlive" false;
          default = { };
        };
        davinciResolve = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable DaVinci Resolve." false;
            edition = mkOption {
              type = types.enum [
                "free"
                "studio"
              ];
              default = "free";
            };
          };
          default = { };
        };
      };
      default = { };
    };
    theme = mkOption {
      type = strictSubmodule {
        gtk = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable GTK theming." true;
            iconTheme = mkOption {
              type = strictSubmodule {
                name = mkOption {
                  type = types.nonEmptyStr;
                  default = "MoreWaita";
                };
                package = mkOption {
                  type = types.nonEmptyStr;
                  default = "morewaita-icon-theme";
                };
              };
              default = { };
            };
          };
          default = { };
        };
        qt = mkOption {
          type = packageToggle "Qt theming" true;
          default = { };
        };
      };
      default = { };
    };
  };
}
