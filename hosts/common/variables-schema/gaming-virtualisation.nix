{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    packageToggle
    strictSubmodule
    ;
in
{
  options.features = {
    gaming = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable gaming packages." false;
        steam = mkOption {
          type = strictSubmodule {
            gamescopeSession = mkOption {
              type = packageToggle "Gamescope session" false;
              default = { };
            };
            remotePlay = mkOption {
              type = strictSubmodule {
                openFirewall = enableOption "Open Steam Remote Play ports." true;
              };
              default = { };
            };
            dedicatedServer = mkOption {
              type = strictSubmodule {
                openFirewall = enableOption "Open Steam dedicated-server ports." true;
              };
              default = { };
            };
            localNetworkGameTransfers = mkOption {
              type = strictSubmodule {
                openFirewall = enableOption "Open Steam LAN transfer ports." true;
              };
              default = { };
            };
            millennium = mkOption {
              type = packageToggle "Millennium" false;
              default = { };
            };
          };
          default = { };
        };
        cheatengine = mkOption {
          type = packageToggle "Cheat Engine" false;
          default = { };
        };
        gamemode = mkOption {
          type = packageToggle "GameMode" false;
          default = { };
        };
      };
      default = { };
    };
    virtualisation = mkOption {
      type = strictSubmodule {
        vmHost = mkOption {
          type = strictSubmodule {
            enable = enableOption "Enable libvirt VM hosting." false;
            spiceUSBRedirection = mkOption {
              type = packageToggle "SPICE USB redirection" true;
              default = { };
            };
          };
          default = { };
        };
        containers = mkOption {
          type = strictSubmodule {
            podman = mkOption {
              type = packageToggle "Podman" false;
              default = { };
            };
            docker = mkOption {
              type = packageToggle "Docker" false;
              default = { };
            };
          };
          default = { };
        };
      };
      default = { };
    };
    ai = mkOption {
      type = strictSubmodule {
        enable = enableOption "Enable local AI services." false;
        comfyui = mkOption {
          type = packageToggle "ComfyUI" false;
          default = { };
        };
        ollama = mkOption {
          type = packageToggle "Ollama" false;
          default = { };
        };
        openWebui = mkOption {
          type = packageToggle "Open WebUI" false;
          default = { };
        };
      };
      default = { };
    };
  };
}
