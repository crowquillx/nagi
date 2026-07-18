{lib, ...}: let
  inherit (lib) mkOption types;
  strictSubmodule = options: types.submodule {inherit options;};
  enableOption = description: default:
    mkOption {
      type = types.bool;
      inherit default description;
    };
  packageToggle = name: default: strictSubmodule {
    enable = enableOption "Enable ${name}." default;
  };
  nullableString = description:
    mkOption {
      type = types.nullOr types.str;
      default = null;
      inherit description;
    };
  portOption = description: default:
    mkOption {
      type = types.port;
      inherit default description;
    };
  niriTransform = types.either (types.enum [
    "normal"
    "90"
    "180"
    "270"
    "flipped"
    "flipped-90"
    "flipped-180"
    "flipped-270"
  ]) (strictSubmodule {
    rotation = mkOption {
      type = types.ints.unsigned;
      default = 0;
    };
    flipped = enableOption "Flip the output horizontally." false;
  });
  niriOutputSubmodule = strictSubmodule {
    enable = enableOption "Enable this output." true;
    mode = mkOption {
      type = strictSubmodule {
        width = mkOption {type = types.ints.positive;};
        height = mkOption {type = types.ints.positive;};
        refresh = mkOption {
          type = types.number;
          default = 60.0;
        };
      };
      default = {};
    };
    scale = mkOption {
      type = types.number;
      default = 1.0;
    };
    transform = mkOption {
      type = niriTransform;
      default = {
        rotation = 0;
        flipped = false;
      };
    };
    position = mkOption {
      type = types.nullOr (strictSubmodule {
        x = mkOption {type = types.int;};
        y = mkOption {type = types.int;};
      });
      default = null;
    };
    variableRefreshRate = mkOption {
      type = types.enum ["off" "on" "on-demand"];
      default = "off";
    };
    focusAtStartup = enableOption "Focus this output when Niri starts." false;
  };
  mountSubmodule = strictSubmodule {
    device = mkOption {type = types.nonEmptyStr;};
    mountPoint = mkOption {type = types.nonEmptyStr;};
    fsType = mkOption {
      type = types.nonEmptyStr;
      default = "auto";
    };
    options = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };
  flatpakPackage = types.either types.nonEmptyStr (strictSubmodule {
    appId = mkOption {type = types.nonEmptyStr;};
    bundle = mkOption {
      type = types.nullOr (strictSubmodule {
        url = mkOption {type = types.nonEmptyStr;};
        hash = mkOption {type = types.nonEmptyStr;};
      });
      default = null;
    };
  });
in {
  options.nagi.variables = mkOption {
    type = types.submodule ({config, ...}: {
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
          };
          default = {};
        };
        storage = mkOption {
          type = strictSubmodule {
            mounts = mkOption {
              type = types.listOf mountSubmodule;
              default = [];
              description = "Repo-owned extra fileSystems entries (device, mountPoint, fsType, options).";
            };
          };
          default = {};
        };
        boot = mkOption {
          type = strictSubmodule {
            systemdBoot = mkOption {
              type = packageToggle "systemd-boot" true;
              default = {};
            };
            kernel = mkOption {
              type = types.enum ["default" "zen" "latest"];
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
              default = {};
            };
          };
          default = {};
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
              default = [];
            };
            git = mkOption {
              type = strictSubmodule {
                name = nullableString "Git author name.";
                email = nullableString "Git author email.";
              };
              default = {};
            };
          };
          default = {};
        };
        graphics = mkOption {
          type = strictSubmodule {
            profile = mkOption {
              type = types.enum ["auto" "none" "vm" "amd" "intel" "nvidia"];
              default = "auto";
            };
            enable32Bit = enableOption "Enable 32-bit graphics support." false;
            extraPackages = mkOption {
              type = types.listOf types.nonEmptyStr;
              default = [];
            };
            nvidia = mkOption {
              type = strictSubmodule {
                modesetting = mkOption {
                  type = packageToggle "NVIDIA modesetting" true;
                  default = {};
                };
                powerManagement = mkOption {
                  type = packageToggle "NVIDIA power management" false;
                  default = {};
                };
                open = enableOption "Use NVIDIA open kernel modules." false;
                nvidiaSettings = enableOption "Install NVIDIA settings." true;
                useLatestDriver = enableOption "Use the latest NVIDIA driver." false;
              };
              default = {};
            };
          };
          default = {};
        };
        desktop = mkOption {
          type = types.submodule (desktopArgs: {
            options = {
              enable = enableOption "Enable a graphical desktop." true;
              compositor = mkOption {
                type = types.enum ["niri" "plasma"];
                default = "niri";
              };
              extraCompositors = mkOption {
                type = types.listOf (types.enum ["niri" "plasma"]);
                default = [];
              };
              displayManager = mkOption {
                type = types.enum ["auto" "sddm"];
                default = "auto";
              };
              sddm = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable SDDM." true;
                  wayland = mkOption {
                    type = packageToggle "SDDM Wayland" true;
                    default = {};
                  };
                  theme = mkOption {
                    type = types.nonEmptyStr;
                    default = "sddm-astronaut-theme";
                  };
                  background = mkOption {
                    type = types.nullOr types.path;
                    default = null;
                    description = "SDDM background image.";
                  };
                  themeConfig = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                  };
                };
                default = {};
              };
              browser = mkOption {
                type = strictSubmodule {
                  default = mkOption {
                    type = types.enum ["zen" "helium" "mullvadBrowser"];
                    default = "zen";
                    description = "Default browser and MIME handler.";
                  };
                  zen = mkOption {
                    type = packageToggle "Zen Browser" false;
                    default = {};
                  };
                  helium = mkOption {
                    type = packageToggle "Helium" false;
                    default = {};
                  };
                  mullvadBrowser = mkOption {
                    type = packageToggle "Mullvad Browser" false;
                    default = {};
                  };
                  brave = mkOption {
                    type = strictSubmodule {
                      passwordStore = mkOption {
                        type = types.enum ["auto" "gnome-libsecret" "kwallet6" "basic"];
                        default = "auto";
                        description = "Brave credential encryption backend; basic stores credentials without secure keyring encryption.";
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              niri = mkOption {
                type = strictSubmodule {
                  outputs = mkOption {
                    type = types.attrsOf niriOutputSubmodule;
                    default = {};
                    description = "Additive per-output Niri monitor configuration keyed by connector name. Consumed by the default configBuilder via vars; on the settings path, merged as settings.outputs.";
                  };
                  settings = mkOption {
                    type = types.attrsOf types.anything;
                    default = {};
                    description = ''
                      Upstream-owned programs.niri.settings escape hatch.
                      Freeform attrset merged only when configBuilder is null;
                      desktop.niri.outputs wins on the outputs key. Shape is
                      owned by niri-flake, not this repo.
                    '';
                  };
                  configBuilder = mkOption {
                    type = types.nullOr types.raw;
                    default = import ../../modules/home/desktop/niri/default.nix;
                    description = ''
                      Primary Niri config builder.
                      Function { lib, pkgs, vars, inputs } -> KDL config for
                      programs.niri.config. Default composes
                      modules/home/desktop/niri/*.nix. Set null to use the
                      settings attrset path instead.
                    '';
                  };
                  blur = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable Niri window blur." true;
                      passes = mkOption {
                        type = types.ints.positive;
                        default = 2;
                        description = "Blur pass count.";
                      };
                      offset = mkOption {
                        type = types.number;
                        default = 3.0;
                        description = "Blur offset.";
                      };
                      noise = mkOption {
                        type = types.number;
                        default = 0.03;
                        description = "Blur noise amount.";
                      };
                      saturation = mkOption {
                        type = types.number;
                        default = 1.0;
                        description = "Blur saturation multiplier.";
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              shellStartupCommand = mkOption {
                type = types.nullOr types.nonEmptyStr;
                default = null;
                description = "Optional command used to start the desktop shell.";
              };
              startup = mkOption {
                type = strictSubmodule {
                  backend = mkOption {
                    type = types.enum ["systemd" "niri"];
                    default = "systemd";
                    description = "Startup backend for desktop.startup.apps.";
                  };
                  apps = mkOption {
                    type = types.listOf types.nonEmptyStr;
                    default = ["wl-paste --watch cliphist store"];
                    description = "Repo-owned shell command strings started with the desktop session (systemd user units or niri spawn-at-startup).";
                  };
                };
                default = {};
              };
              session = mkOption {
                type = strictSubmodule {
                  enable = mkOption {
                    type = types.bool;
                    default = desktopArgs.config.enable;
                    description = "Enable desktop session helpers.";
                  };
                  killProcessesOnLogout = enableOption "Terminate the session process scope on logout." false;
                  polkit = mkOption {
                    type = packageToggle "desktop polkit agent" true;
                    default = {};
                  };
                  keyring = mkOption {
                    type = packageToggle "desktop keyring" true;
                    default = {};
                  };
                  lock = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable session locking." true;
                      command = mkOption {
                        type = types.nonEmptyStr;
                        default = "loginctl lock-session";
                      };
                      idleSeconds = mkOption {
                        type = types.ints.positive;
                        default = 600;
                      };
                      beforeSleep = enableOption "Lock before sleep." true;
                      onLidClose = enableOption "Lock on lid close." true;
                    };
                    default = {};
                  };
                };
                default = {};
              };
              noctalia = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable Noctalia shell." false;
                  command = mkOption {
                    type = types.nonEmptyStr;
                    default = "nagi-noctalia-shell";
                  };
                  settings = mkOption {
                    type = types.attrsOf types.anything;
                    default = {};
                    description = "Upstream-owned programs.noctalia.settings extension payload; freeform attrset whose nested schema is owned by the Noctalia flake, not this repo.";
                  };
                  assistantPanel = mkOption {
                    type = strictSubmodule {
                      secrets = mkOption {
                        type = strictSubmodule {
                          googleApiKey = nullableString "SOPS secret name for Google API access.";
                          openaiCompatibleApiKey = nullableString "SOPS secret name for OpenAI-compatible access.";
                          deeplApiKey = nullableString "SOPS secret name for DeepL access.";
                        };
                        default = {};
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              hushmic = mkOption {
                type = strictSubmodule {
                  deviceId = mkOption {
                    type = types.nullOr types.nonEmptyStr;
                    default = null;
                    description = "PipeWire node.name waited on before launching the hushmic tray. null disables the helper.";
                  };
                };
                default = {};
              };

            };
          });
          default = {};
        };
        features = mkOption {
          type = types.submodule (featuresArgs: {
            options = {
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
                    default = {};
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
                    default = {};
                  };
                  swappiness = mkOption {
                    type = types.ints.between 0 200;
                    default = 10;
                  };
                };
                default = {};
              };
              stylix = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable Stylix." true;
                  variant = mkOption {
                    type = types.enum ["moon" "main" "dawn"];
                    default = "moon";
                  };
                };
                default = {};
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
                    default = {};
                  };
                  optimise = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable automatic Nix store optimisation." true;
                      dates = mkOption {
                        type = types.either types.nonEmptyStr (types.listOf types.nonEmptyStr);
                        default = "weekly";
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              localsend = mkOption {
                type = strictSubmodule {
                  package = mkOption {
                    type = packageToggle "LocalSend" false;
                    default = {};
                  };
                  openFirewall = enableOption "Open LocalSend firewall ports." false;
                };
                default = {};
              };
              chat = mkOption {
                type = types.submodule (chatArgs: {
                  options = {
                    client = mkOption {
                      type = types.enum ["none" "discord" "equibop"];
                      default = "none";
                      description = "Chat client to install.";
                    };
                    startup = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = chatArgs.config.client != "none";
                            description = "Autostart the selected chat client.";
                          };
                        };
                      };
                      default = {};
                    };
                    discord = mkOption {
                      type = strictSubmodule {
                        forceXwayland = enableOption "Force Discord under Xwayland." true;
                        equicord = mkOption {
                          type = packageToggle "Equicord" false;
                          default = {};
                        };
                      };
                      default = {};
                    };
                  };
                });
                default = {};
              };
              mullvad = mkOption {
                type = strictSubmodule {
                  package = mkOption {
                    type = types.enum ["none" "cli" "gui"];
                    default = "none";
                  };
                  service = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable Mullvad VPN service." false;
                      allowLan = enableOption "Allow local network traffic through the Mullvad firewall." false;
                    };
                    default = {};
                  };
                };
                default = {};
              };
              terminals = mkOption {
                type = strictSubmodule {
                  alacritty = mkOption {
                    type = packageToggle "Alacritty" true;
                    default = {};
                  };
                  foot = mkOption {
                    type = packageToggle "Foot" true;
                    default = {};
                  };
                  ghostty = mkOption {
                    type = packageToggle "Ghostty" true;
                    default = {};
                  };
                  kitty = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable Kitty." true;
                      opacity = mkOption {
                        type = types.number;
                        default = 1.0;
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              videoEditing = mkOption {
                type = strictSubmodule {
                  kdenlive = mkOption {
                    type = packageToggle "Kdenlive" false;
                    default = {};
                  };
                  davinciResolve = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable DaVinci Resolve." false;
                      edition = mkOption {
                        type = types.enum ["free" "studio"];
                        default = "free";
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              codingTools = mkOption {
                type = types.submodule (codingToolsArgs: {
                  options = {
                    enable = enableOption "Enable coding tools." true;
                    editors = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = codingToolsArgs.config.enable;
                            description = "Enable editor packages.";
                          };
                          vscode = mkOption {
                            type = packageToggle "VS Code" true;
                            default = {};
                          };
                          antigravity = mkOption {
                            type = packageToggle "Antigravity" true;
                            default = {};
                          };
                          t3code = mkOption {
                            type = packageToggle "T3 Code" true;
                            default = {};
                          };
                          cursor = mkOption {
                            type = packageToggle "Cursor" true;
                            default = {};
                          };
                          zed = mkOption {
                            type = packageToggle "Zed" true;
                            default = {};
                          };
                          limux = mkOption {
                            type = packageToggle "Limux" true;
                            default = {};
                          };
                        };
                      };
                      default = {};
                    };
                    aiCli = mkOption {
                      type = types.submodule (aiCliArgs: {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = codingToolsArgs.config.enable;
                            description = "Enable AI CLI tools.";
                          };
                          codex = mkOption {
                            type = packageToggle "Codex" aiCliArgs.config.enable;
                            default = {};
                          };
                          claude = mkOption {
                            type = packageToggle "Claude Code" aiCliArgs.config.enable;
                            default = {};
                          };
                          cliProxyApi = mkOption {
                            type = packageToggle "CLI Proxy API" aiCliArgs.config.enable;
                            default = {};
                          };
                          opencode = mkOption {
                            type = packageToggle "OpenCode" aiCliArgs.config.enable;
                            default = {};
                          };
                          gemini = mkOption {
                            type = packageToggle "Gemini CLI" aiCliArgs.config.enable;
                            default = {};
                          };
                          pi = mkOption {
                            type = packageToggle "Pi" aiCliArgs.config.enable;
                            default = {};
                          };
                          ohMyPi = mkOption {
                            type = packageToggle "Oh My Pi" aiCliArgs.config.enable;
                            default = {};
                          };
                        };
                      });
                      default = {};
                    };
                    nixTools = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = codingToolsArgs.config.enable;
                            description = "Enable Nix development tools.";
                          };
                        };
                      };
                      default = {};
                    };
                  };
                });
                default = {};
              };
              mcp = mkOption {
                type = types.submodule {
                  options = {
                    nixos = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = featuresArgs.config.codingTools.aiCli.enable;
                            description = "Enable the NixOS MCP package.";
                          };
                        };
                      };
                      default = {};
                    };
                  };
                };
                default = {};
              };
              tailscale = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable Tailscale." true;
                  acceptDns = enableOption "Accept Tailscale DNS." true;
                  exitNode = nullableString "Tailscale exit-node address.";
                };
                default = {};
              };
              ssh = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable OpenSSH." false;
                  openFirewall = enableOption "Open the SSH port." true;
                  port = portOption "OpenSSH port." 22;
                  passwordAuthentication = enableOption "Allow SSH password authentication." false;
                  permitRootLogin = mkOption {
                    type = types.enum ["prohibit-password" "without-password" "forced-commands-only" "no"];
                    default = "prohibit-password";
                  };
                  authorizedKeys = mkOption {
                    type = types.listOf types.nonEmptyStr;
                    default = [];
                  };
                };
                default = {};
              };
              shell = mkOption {
                type = strictSubmodule {
                  fish = mkOption {
                    type = packageToggle "Fish" true;
                    default = {};
                  };
                  starship = mkOption {
                    type = packageToggle "Starship" true;
                    default = {};
                  };
                };
                default = {};
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
                    default = {};
                  };
                };
                default = {};
              };
              audio = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable PipeWire audio." true;
                };
                default = {};
              };
              fileManager = mkOption {
                type = types.submodule {
                  options = {
                    thunar = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = config.desktop.enable;
                            description = "Enable Thunar.";
                          };
                        };
                      };
                      default = {};
                    };
                  };
                };
                default = {};
              };
              zoxide = mkOption {
                type = packageToggle "zoxide" true;
                default = {};
              };
              bluetooth = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable Bluetooth." true;
                  powerOnBoot = enableOption "Power on Bluetooth at boot." false;
                };
                default = {};
              };
              networking = mkOption {
                type = strictSubmodule {
                  networkmanager = mkOption {
                    type = packageToggle "NetworkManager" true;
                    default = {};
                  };
                };
                default = {};
                description = "Repo-owned networking toggles currently limited to NetworkManager.";
              };
              portals = mkOption {
                type = packageToggle "desktop portals" true;
                default = {};
              };
              services = mkOption {
                type = types.submodule {
                  options = {
                    fstrim = mkOption {
                      type = packageToggle "periodic filesystem trim" true;
                      default = {};
                    };
                    resolved = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = featuresArgs.config.networking.networkmanager.enable;
                            description = "Enable systemd-resolved.";
                          };
                        };
                      };
                      default = {};
                    };
                    powerProfilesDaemon = mkOption {
                      type = types.submodule {
                        options = {
                          enable = mkOption {
                            type = types.bool;
                            default = !featuresArgs.config.laptop.tlp.enable;
                            description = "Enable power-profiles-daemon. Mutually exclusive with features.laptop.tlp.enable.";
                          };
                        };
                      };
                      default = {};
                    };
                  };
                };
                default = {};
                description = "Repo-owned host service toggles (fstrim, resolved, power-profiles-daemon).";
              };
              printing = mkOption {
                type = packageToggle "printing" false;
                default = {};
              };
              flatpak = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable declarative Flatpak." false;
                  packages = mkOption {
                    type = types.listOf flatpakPackage;
                    default = [];
                  };
                };
                default = {};
              };
              gaming = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable gaming packages." false;
                  steam = mkOption {
                    type = strictSubmodule {
                      gamescopeSession = mkOption {
                        type = packageToggle "Gamescope session" false;
                        default = {};
                      };
                      remotePlay = mkOption {
                        type = strictSubmodule {
                          openFirewall = enableOption "Open Steam Remote Play ports." true;
                        };
                        default = {};
                      };
                      dedicatedServer = mkOption {
                        type = strictSubmodule {
                          openFirewall = enableOption "Open Steam dedicated-server ports." true;
                        };
                        default = {};
                      };
                      localNetworkGameTransfers = mkOption {
                        type = strictSubmodule {
                          openFirewall = enableOption "Open Steam LAN transfer ports." true;
                        };
                        default = {};
                      };
                      millennium = mkOption {
                        type = packageToggle "Millennium" false;
                        default = {};
                      };
                    };
                    default = {};
                  };
                  cheatengine = mkOption {
                    type = packageToggle "Cheat Engine" false;
                    default = {};
                  };
                };
                default = {};
              };
              virtualisation = mkOption {
                type = strictSubmodule {
                  vmHost = mkOption {
                    type = strictSubmodule {
                      enable = enableOption "Enable libvirt VM hosting." false;
                      spiceUSBRedirection = mkOption {
                        type = packageToggle "SPICE USB redirection" true;
                        default = {};
                      };
                    };
                    default = {};
                  };
                  containers = mkOption {
                    type = strictSubmodule {
                      podman = mkOption {
                        type = packageToggle "Podman" false;
                        default = {};
                      };
                      docker = mkOption {
                        type = packageToggle "Docker" false;
                        default = {};
                      };
                    };
                    default = {};
                  };
                };
                default = {};
              };
              ai = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable local AI services." false;
                  comfyui = mkOption {
                    type = packageToggle "ComfyUI" false;
                    default = {};
                  };
                  ollama = mkOption {
                    type = packageToggle "Ollama" false;
                    default = {};
                  };
                  openWebui = mkOption {
                    type = packageToggle "Open WebUI" false;
                    default = {};
                  };
                };
                default = {};
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
                        default = {};
                      };
                    };
                    default = {};
                  };
                  qt = mkOption {
                    type = packageToggle "Qt theming" true;
                    default = {};
                  };
                };
                default = {};
              };
              laptop = mkOption {
                type = strictSubmodule {
                  enable = enableOption "Enable laptop power management." false;
                  upower = mkOption {
                    type = packageToggle "UPower" true;
                    default = {};
                  };
                  tlp = mkOption {
                    type = packageToggle "TLP. Mutually exclusive with features.services.powerProfilesDaemon.enable" false;
                    default = {};
                  };
                  thermald = mkOption {
                    type = packageToggle "thermald (Intel-oriented)" false;
                    default = {};
                  };
                  powertop = mkOption {
                    type = packageToggle "powertop tuning" false;
                    default = {};
                  };
                  fwupd = mkOption {
                    type = packageToggle "firmware updates" true;
                    default = {};
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
                    default = {};
                  };
                };
                default = {};
              };
            };
          });
          default = {};
        };
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
                  default = {};
                };
                kotomi = mkOption {
                  type = packageToggle "the Kotomi target secret" true;
                  default = {};
                };
              };
              default = {};
            };
            yubikey = mkOption {
              type = packageToggle "YubiKey support" false;
              default = {};
            };
          };
          default = {};
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
                  default = {};
                };
              };
              default = {};
            };
          };
          default = {};
        };
      };
    });
    default = {};
    description = "Strict, fully typed host variables.";
  };
}
