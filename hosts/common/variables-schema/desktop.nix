{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    nullableString
    packageToggle
    strictSubmodule
    ;
  sessionCommands = import ../../../lib/session-shell-commands.nix;
in
{
  options.desktop = mkOption {
    type = types.submodule (desktopArgs: {
      options = {
        enable = enableOption "Enable a graphical desktop." true;
        compositor = mkOption {
          type = types.enum [ "umbriel" ];
          default = "umbriel";
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
        sessionShell = mkOption {
          type = types.enum [ "noctalia" ];
          default = "noctalia";
          description = "Noctalia is the only supported session shell.";
        };
        shellStartupCommand = mkOption {
          type = types.nullOr types.nonEmptyStr;
          default = null;
          description = "Optional command used to start the desktop shell. Unused; compositor spawn starts the selected sessionShell.";
        };
        session = mkOption {
          type = strictSubmodule {
            enable = mkOption {
              type = types.bool;
              default = desktopArgs.config.enable;
              description = "Enable desktop session helpers.";
            };
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
                  default =
                    (sessionCommands {
                      sessionShell = desktopArgs.config.sessionShell;
                      noctaliaCommand = desktopArgs.config.noctalia.command;
                    }).lockCommand;
                  description = "Lock command. Default follows desktop.sessionShell.";
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
            enable = enableOption "Enable Noctalia shell. Derived from desktop.sessionShell == \"noctalia\"." (
              desktopArgs.config.sessionShell == "noctalia"
            );
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
      };
    });
    default = { };
  };
}
