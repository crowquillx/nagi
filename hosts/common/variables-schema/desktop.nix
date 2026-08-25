{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    hyprlandOutputSubmodule
    niriOutputSubmodule
    nullableString
    packageToggle
    strictSubmodule
    ;
in
{
  options.desktop = mkOption {
    type = types.submodule (desktopArgs: {
      options = {
        enable = enableOption "Enable a graphical desktop." true;
        compositor = mkOption {
          type = types.enum [
            "niri"
            "hyprland"
            "plasma"
          ];
          # Keep generic/new hosts on Hyprland unless they explicitly select another session.
          default = "hyprland";
        };
        extraCompositors = mkOption {
          type = types.listOf (
            types.enum [
              "niri"
              "hyprland"
              "plasma"
            ]
          );
          default = [ ];
        };
        displayManager = mkOption {
          type = types.enum [
            "auto"
            "sddm"
          ];
          default = "auto";
        };
        sddm = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable SDDM." true;
            wayland = mkOption {
              type = packageToggle "SDDM Wayland" true;
              default = { };
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
              default = { };
            };
          };
          default = { };
        };
        browser = mkOption {
          type = strictSubmodule {
            default = mkOption {
              type = types.enum [
                "zen"
                "helium"
                "mullvadBrowser"
              ];
              default = "zen";
              description = "Default browser and MIME handler.";
            };
            zen = mkOption {
              type = packageToggle "Zen Browser" false;
              default = { };
            };
            helium = mkOption {
              type = packageToggle "Helium" false;
              default = { };
            };
            mullvadBrowser = mkOption {
              type = packageToggle "Mullvad Browser" false;
              default = { };
            };
            brave = mkOption {
              type = strictSubmodule {
                passwordStore = mkOption {
                  type = types.enum [
                    "auto"
                    "gnome-libsecret"
                    "kwallet6"
                    "basic"
                  ];
                  default = "auto";
                  description = "Brave credential encryption backend; basic stores credentials without secure keyring encryption.";
                };
              };
              default = { };
            };
          };
          default = { };
        };
        niri = mkOption {
          type = strictSubmodule {
            outputs = mkOption {
              type = types.attrsOf niriOutputSubmodule;
              default = { };
              description = "Additive per-output Niri monitor configuration keyed by connector name. Consumed by the default configBuilder via vars; on the settings path, merged as settings.outputs.";
            };
            settings = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = ''
                Upstream-owned programs.niri.settings escape hatch.
                Freeform attrset merged only when configBuilder is null;
                desktop.niri.outputs wins on the outputs key. Shape is
                owned by niri-flake, not this repo.
              '';
            };
            configBuilder = mkOption {
              type = types.nullOr types.raw;
              default = import ../../../modules/home/desktop/niri/default.nix;
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
              default = { };
            };
          };
          default = { };
        };
        hyprland = mkOption {
          type = strictSubmodule {
            outputs = mkOption {
              type = types.attrsOf hyprlandOutputSubmodule;
              default = { };
              description = "Per-output Hyprland monitor configuration keyed by connector name.";
            };
            settings = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "Upstream Home Manager Hyprland settings escape hatch used when configBuilder is null.";
            };
            configBuilder = mkOption {
              type = types.nullOr types.raw;
              default = import ../../../modules/home/desktop/hyprland/default.nix;
              description = ''
                Primary Hyprland Lua config builder.
                Function { lib, pkgs, vars, inputs } -> string for
                wayland.windowManager.hyprland.extraConfig. Set null to
                use the upstream settings attrset path instead.
              '';
            };
          };
          default = { };
        };
        shellStartupCommand = mkOption {
          type = types.nullOr types.nonEmptyStr;
          default = null;
          description = "Optional command used to start the desktop shell.";
        };
        startup = mkOption {
          type = strictSubmodule {
            backend = mkOption {
              type = types.enum [
                "systemd"
                "niri"
                "hyprland"
              ];
              default = "systemd";
              description = "Startup backend for desktop.startup.apps.";
            };
            apps = mkOption {
              type = types.listOf types.nonEmptyStr;
              default = [ "wl-paste --watch cliphist store" ];
              description = "Repo-owned shell command strings started with the desktop session (systemd user units or niri spawn-at-startup).";
            };
          };
          default = { };
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
              default = { };
            };
            keyring = mkOption {
              type = packageToggle "desktop keyring" true;
              default = { };
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
              default = { };
            };
          };
          default = { };
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
              default = { };
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
                  default = { };
                };
              };
              default = { };
            };
            hyprlandLocalWorkspaces = mkOption {
              type = strictSubmodule {
                enable = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = ''
                    Install and enable the nagi/hyprland-local-workspaces Noctalia plugin.
                    null auto-enables when Hyprland is available and at least one
                    desktop.hyprland.outputs.*.workspaceBase is set.
                  '';
                };
              };
              default = { };
            };
          };
          default = { };
        };
        hushmic = mkOption {
          type = strictSubmodule {
            deviceId = mkOption {
              type = types.nullOr types.nonEmptyStr;
              default = null;
              description = "PipeWire node.name waited on before launching the hushmic tray. null disables the helper.";
            };
          };
          default = { };
        };
        hdrGame = mkOption {
          type = strictSubmodule {
            enable = enableOption "Install the hdr-game wrapper that switches the HDR gaming display to HDR+WCG while a wrapped game runs." false;
            monitor = mkOption {
              type = strictSubmodule {
                uuid = mkOption {
                  type = types.str;
                  default = "";
                  description = "Known stable KScreen UUID of the HDR display (primary identifier). Empty string skips UUID resolution.";
                };
                model = mkOption {
                  type = types.str;
                  default = "";
                  description = "EDID model string used to verify the resolved output (e.g. Q27G3XMN).";
                };
                serial = mkOption {
                  type = types.str;
                  default = "";
                  description = "EDID serial string used to verify the resolved output (e.g. 1APR3JA002499).";
                };
                fallbackConnector = mkOption {
                  type = types.str;
                  default = "";
                  description = "Last-resort connector name (e.g. DP-3); only accepted if its live EDID matches model/serial.";
                };
              };
              default = { };
            };
            notifications = mkOption {
              type = packageToggle "hdr-game desktop notifications" false;
              default = { };
            };
          };
          default = { };
        };
      };
    });
    default = { };
  };
}
