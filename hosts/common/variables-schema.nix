{ lib, ... }:
{
  options.nagi.variables = lib.mkOption {
    type = lib.types.submodule {
      imports = [
        ./variables-schema/host.nix
        ./variables-schema/graphics.nix
        ./variables-schema/desktop.nix
        ./variables-schema/features-core.nix
        ./variables-schema/development.nix
        ./variables-schema/services.nix
        ./variables-schema/gaming-virtualisation.nix
        ./variables-schema/security.nix
      ];
    };
    default = { };
    description = "Strict, fully typed host variables.";
  };
}
