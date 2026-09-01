{ config, lib, ... }:
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
    codingTools = mkOption {
      type = types.submodule (codingToolsArgs: {
        options = {
          enable = enableOption "Enable coding tools." true;
          orca = mkOption {
            type = packageToggle "Orca IDE" codingToolsArgs.config.enable;
            default = { };
          };
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
                  type = packageToggle "Codex" aiCliArgs.config.enable;
                  default = { };
                };
                claude = mkOption {
                  type = packageToggle "Claude Code" aiCliArgs.config.enable;
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
                  type = packageToggle "Pi" aiCliArgs.config.enable;
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
          repoSync = mkOption {
            type = strictSubmodule {
              enable = enableOption "Synchronize committed Git work through a remote bare repository." false;
              directory = nullableString "Absolute local repository directory. Defaults to ~/REPOS.";
              remoteHost = mkOption {
                type = types.nonEmptyStr;
                default = "codebox";
              };
              remotePublicKey = nullableString ''
                Trusted OpenSSH public host key for the private Git mirror host.
              '';
              remoteUser = mkOption {
                type = types.nonEmptyStr;
                default = config.users.primary;
              };
              remoteName = mkOption {
                type = types.nonEmptyStr;
                default = "codebox";
              };
              mirrorDirectory = mkOption {
                type = types.nonEmptyStr;
                default = "git-mirrors";
              };
              interval = mkOption {
                type = types.nonEmptyStr;
                default = "2m";
                description = "systemd calendar duration between synchronization runs.";
              };
              repositories = mkOption {
                type = types.listOf (strictSubmodule {
                  path = mkOption {
                    type = types.nonEmptyStr;
                    description = "Absolute path to an additional Git worktree.";
                  };
                  autoCheckpoint = enableOption ''
                    Preserve dirty tracked and untracked files in a private, host-specific checkpoint ref.
                  '' false;
                });
                default = [ ];
                description = "Additional repositories outside the scanned directory.";
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
      };
      default = { };
    };
  };
}
