{ lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./helpers.nix { inherit lib; })
    enableOption
    packageToggle
    strictSubmodule
    ;
in
{
  options.graphics = mkOption {
    type = strictSubmodule {
      profile = mkOption {
        type = types.enum [
          "auto"
          "none"
          "vm"
          "amd"
          "intel"
          "nvidia"
        ];
        default = "auto";
      };
      enable32Bit = enableOption "Enable 32-bit graphics support." false;
      extraPackages = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
      };
      nvidia = mkOption {
        type = strictSubmodule {
          modesetting = mkOption {
            type = packageToggle "NVIDIA modesetting" true;
            default = { };
          };
          powerManagement = mkOption {
            type = packageToggle "NVIDIA power management" false;
            default = { };
          };
          open = enableOption "Use NVIDIA open kernel modules." false;
          nvidiaSettings = enableOption "Install NVIDIA settings." true;
          useLatestDriver = enableOption "Use the latest NVIDIA driver." false;
        };
        default = { };
      };
    };
    default = { };
  };
}
