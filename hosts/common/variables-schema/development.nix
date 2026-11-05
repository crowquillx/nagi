{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    packageToggle
    strictSubmodule
    ;
in
{
  options.features = {
    codingTools = mkOption {
      type = types.submodule (codingToolsArgs: {
        options = {
          enable = enableOption "Enable coding tools." true;
          paseo = mkOption {
            type = packageToggle "Paseo" codingToolsArgs.config.enable;
            default = { };
          };
          editors = mkOption {
            type = types.submodule {
              options = {
                enable = mkOption {
                  type = types.bool;
                  default = codingToolsArgs.config.enable;
                  description = "Enable editor packages.";
                };
                t3code = mkOption {
                  type = types.submodule {
                    options = {
                      enable = enableOption "Enable T3 Code." true;
                      service = mkOption {
                        type = strictSubmodule {
                          enable = enableOption "Run a headless `t3 serve` user unit. Leave off when using the desktop app; both write the same ~/.t3 state." false;
                          extraArgs = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "Extra arguments forwarded to `t3 serve`.";
                          };
                        };
                        default = { };
                      };
                    };
                  };
                  default = { };
                };
                cursor = mkOption {
                  type = packageToggle "Cursor" true;
                  default = { };
                };
                zed = mkOption {
                  type = packageToggle "Zed" true;
                  default = { };
                };
              };
            };
            default = { };
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
                  type = strictSubmodule {
                    enable = enableOption "Enable Codex." aiCliArgs.config.enable;
                    installMethod = mkOption {
                      type = types.enum [
                        "nix"
                        "native"
                      ];
                      default = "nix";
                      description = "Use the Nix CLI package or an existing user installation from OpenAI's standalone installer.";
                    };
                  };
                  default = { };
                };
                claude = mkOption {
                  type = strictSubmodule {
                    enable = enableOption "Enable Claude Code." aiCliArgs.config.enable;
                    installMethod = mkOption {
                      type = types.enum [
                        "nix"
                        "native"
                      ];
                      default = "nix";
                      description = "Use the Nix package or an existing user installation from Anthropic's native installer.";
                    };
                  };
                  default = { };
                };
                cliProxyApi = mkOption {
                  type = packageToggle "CLI Proxy API" aiCliArgs.config.enable;
                  default = { };
                };
                opencode = mkOption {
                  type = packageToggle "OpenCode" aiCliArgs.config.enable;
                  default = { };
                };
                opencode2 = mkOption {
                  type = packageToggle "OpenCode 2 beta" false;
                  default = { };
                };
                gemini = mkOption {
                  type = packageToggle "Gemini CLI" aiCliArgs.config.enable;
                  default = { };
                };
                grok = mkOption {
                  type = packageToggle "Grok Build" aiCliArgs.config.enable;
                  default = { };
                };
                pi = mkOption {
                  type = strictSubmodule {
                    enable = enableOption "Enable Pi." aiCliArgs.config.enable;
                    installMethod = mkOption {
                      type = types.enum [
                        "nix"
                        "native"
                      ];
                      default = "nix";
                      description = "Use the Nix package or an existing user installation from Pi's managed installer.";
                    };
                  };
                  default = { };
                };
                ohMyPi = mkOption {
                  type = packageToggle "Oh My Pi" aiCliArgs.config.enable;
                  default = { };
                };
                herdr = mkOption {
                  type = packageToggle "Herdr" aiCliArgs.config.enable;
                  default = { };
                };
                primeAgent = mkOption {
                  type = packageToggle "Prime Agent" aiCliArgs.config.enable;
                  default = { };
                };
              };
            });
            default = { };
          };
          nixTools = mkOption {
            type = types.submodule {
              options.enable = mkOption {
                type = types.bool;
                default = codingToolsArgs.config.enable;
                description = "Enable Nix development tools.";
              };
            };
            default = { };
          };
        };
      });
      default = { };
    };
    mcp = mkOption {
      type = types.submodule {
        options.nixos = mkOption {
          type = types.submodule {
            options.enable = mkOption {
              type = types.bool;
              default = config.features.codingTools.aiCli.enable;
              description = "Enable the NixOS MCP package.";
            };
          };
          default = { };
        };
        options.computerUseLinux = mkOption {
          type = packageToggle "computer-use-linux desktop MCP" false;
          default = { };
        };
      };
      default = { };
    };
  };
}
