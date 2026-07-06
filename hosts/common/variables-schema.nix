{ lib, ... }:
let
  inherit (lib) mkOption types;

  looseSubmodule = options:
    types.submodule {
      freeformType = types.attrs;
      inherit options;
    };

  enableOption = description: default:
    mkOption {
      type = types.bool;
      inherit default description;
    };

  packageToggle = name:
    looseSubmodule {
      enable = enableOption "Install ${name}." true;
    };
in
{
  options.nagi.variables = mkOption {
    type = looseSubmodule {
      users = mkOption {
        type = looseSubmodule {
          primary = mkOption {
            type = types.nonEmptyStr;
            default = "nagi";
            description = "Primary user receiving the host Home Manager configuration.";
          };
          flakeDirectory = mkOption {
            type = types.nullOr types.nonEmptyStr;
            default = null;
            description = "Absolute path to this flake checkout for user tools. Defaults to /home/<primary>/nagi.";
          };
          extraPackages = mkOption {
            type = types.listOf types.nonEmptyStr;
            default = [ ];
            description = "Additional Home Manager package attribute paths.";
          };
        };
        default = { };
      };

      desktop = mkOption {
        type = looseSubmodule {
          browser = mkOption {
            type = looseSubmodule {
              default = mkOption {
                type = types.enum [ "zen" "helium" "mullvadBrowser" ];
                default = "zen";
                description = "Default browser and MIME handler.";
              };
              zen = mkOption {
                type = packageToggle "Zen Browser";
                default = { };
              };
              helium = mkOption {
                type = packageToggle "Helium";
                default = { };
              };
              mullvadBrowser = mkOption {
                type = packageToggle "Mullvad Browser";
                default = { };
              };
            };
            default = { };
          };
        };
        default = { };
      };

      features = mkOption {
        type = looseSubmodule {
          swap = mkOption {
            type = looseSubmodule {
              zram = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Enable compressed zram swap." true;
                  memoryPercent = mkOption {
                    type = types.ints.between 1 100;
                    default = 25;
                    description = "Maximum zram capacity as a percentage of physical memory.";
                  };
                };
                default = { };
              };
              disk = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Create a disk-backed swap file from this module." true;
                  path = mkOption {
                    type = types.strMatching "^/.*";
                    default = "/var/lib/swapfile";
                    description = "Absolute swap-file path. Disable this option on unsupported Btrfs layouts.";
                  };
                  sizeMiB = mkOption {
                    type = types.ints.positive;
                    default = 4096;
                    description = "Swap-file size in MiB.";
                  };
                };
                default = { };
              };
              swappiness = mkOption {
                type = types.ints.between 0 200;
                default = 10;
                description = "Kernel vm.swappiness value.";
              };
            };
            default = { };
          };

          nixMaintenance = mkOption {
            type = looseSubmodule {
              gc = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Enable Nix's own scheduled garbage collection." false;
                  dates = mkOption {
                    type = types.either types.str (types.listOf types.str);
                    default = "weekly";
                    description = "systemd calendar expression for Nix GC when enabled.";
                  };
                  options = mkOption {
                    type = types.str;
                    default = "";
                    description = "Additional options passed to nix-collect-garbage.";
                  };
                };
                default = { };
              };
              optimise = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Run scheduled Nix store optimisation." true;
                  dates = mkOption {
                    type = types.either types.str (types.listOf types.str);
                    default = "weekly";
                    description = "systemd calendar expression for store optimisation.";
                  };
                };
                default = { };
              };
            };
            default = { };
          };

          localsend = mkOption {
            type = looseSubmodule {
              package = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Install LocalSend through Home Manager." false;
                };
                default = { };
              };
              openFirewall = enableOption "Open TCP and UDP port 53317 for LocalSend discovery and transfers." false;
            };
            default = { };
          };

          chat = mkOption {
            type = looseSubmodule {
              client = mkOption {
                type = types.enum [ "none" "discord" "equibop" ];
                default = "none";
                description = "Chat client package and Niri mute integration.";
              };
              startup = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Start the selected chat client with the desktop session." true;
                };
                default = { };
              };
              discord = mkOption {
                type = looseSubmodule {
                  forceXwayland =
                    enableOption
                      "Run official Discord through XWayland so Discord's keybind recorder can receive focused key events."
                      true;
                  equicord = mkOption {
                    type = looseSubmodule {
                      enable = enableOption "Patch the official Discord package with Equicord." false;
                      startupDelaySeconds = mkOption {
                        type = types.ints.unsigned;
                        default = 4;
                        description = "Deprecated; Equicord is applied at build time rather than run before Discord.";
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

          mullvad = mkOption {
            type = looseSubmodule {
              package = mkOption {
                type = types.enum [ "none" "cli" "gui" ];
                default = "none";
                description = "Home Manager Mullvad package variant.";
              };
              service = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Enable the Mullvad system daemon." false;
                };
                default = { };
              };
            };
            default = { };
          };

          terminals = mkOption {
            type = looseSubmodule {
              alacritty = mkOption {
                type = packageToggle "Alacritty";
                default = { };
              };
              foot = mkOption {
                type = packageToggle "Foot";
                default = { };
              };
              kitty = mkOption {
                type = packageToggle "Kitty";
                default = { };
              };
            };
            default = { };
          };

          codingTools = mkOption {
            type = looseSubmodule {
              enable = enableOption "Enable coding tools." true;
              editors = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Enable editor packages." true;
                  vscode = mkOption {
                    type = packageToggle "Visual Studio Code";
                    default = { };
                  };
                  antigravity = mkOption {
                    type = packageToggle "Antigravity";
                    default = { };
                  };
                  t3code = mkOption {
                    type = packageToggle "T3 Code";
                    default = { };
                  };
                  cursor = mkOption {
                    type = packageToggle "Cursor and Cursor CLI";
                    default = { };
                  };
                  zed = mkOption {
                    type = packageToggle "Zed";
                    default = { };
                  };
                };
                default = { };
              };
              aiCli = mkOption {
                type = looseSubmodule {
                  enable = enableOption "Enable AI CLI agents." true;
                  codex = mkOption {
                    type = packageToggle "OpenAI Codex CLI";
                    default = { };
                  };
                  opencode = mkOption {
                    type = packageToggle "OpenCode CLI";
                    default = { };
                  };
                  gemini = mkOption {
                    type = packageToggle "Gemini CLI";
                    default = { };
                  };
                  droid = mkOption {
                    type = packageToggle "Factory AI Droid";
                    default = { };
                  };
                };
                default = { };
              };
            };
            default = { };
          };

          tailscale = mkOption {
            type = looseSubmodule {
              enable = enableOption "Enable Tailscale." true;
              acceptDns = enableOption "Accept DNS settings advertised by the tailnet." true;
              exitNode = mkOption {
                type = types.nullOr types.nonEmptyStr;
                default = null;
                description = "Optional Tailscale exit node name or IP.";
              };
            };
            default = { };
          };
        };
        default = { };
      };
    };
    default = { };
    description = "Host-scoped variables loaded from hosts/<host>/variables.nix.";
  };
}
