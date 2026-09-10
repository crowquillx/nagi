{
  self,
  inputs,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
  combined = import ../combined/stacks.nix;
  hosts = import ../../lib/host-registry.nix;
  inherit (import ../../lib/package-overlays.nix { inherit lib inputs; }) sharedOverlays;

  homeModule = import ../../users/default/home.nix;
  noctaliaHmModule = lib.attrByPath [ "noctalia" "homeModules" "default" ] null inputs;
  umbrielHmModule = inputs.umbriel.homeModules.default;
  greeterNixosModule = inputs.noctalia-greeter.nixosModules.default;
  hostPlatforms = lib.mapAttrs (_: spec: spec.system) hosts;
  importVariables = files: lib.foldl' lib.recursiveUpdate { } (map import files);
  # Validate each host's raw variables against the schema and materialise
  # fully defaulted attrs before any nixosSystem/homeManagerConfiguration
  # call. Overlay gates and specialArgs must see the resolved shape, not
  # the sparse host file tree.
  resolveVariables =
    raw:
    (lib.evalModules {
      modules = [
        ../../hosts/common/variables-schema.nix
        { nagi.variables = raw; }
      ];
    }).config.nagi.variables;
  hostVars = lib.mapAttrs (_: spec: resolveVariables (importVariables spec.variables)) hosts;
  nixosHostModules = lib.mapAttrs (_: spec: import spec.module) hosts;
  relativeToRoot = path: lib.removePrefix "${toString ../..}/" (toString path);
  hostMetadata = lib.mapAttrs (name: spec: {
    inherit name;
    inherit (spec) system;
    configuredHostName = hostVars.${name}.host.name;
    module = relativeToRoot spec.module;
    variableFragments = map relativeToRoot spec.variables;
  }) hosts;

  determinateHmModule = inputs.determinate.homeManagerModules.default;

  sharedHomeModules = lib.optionals (noctaliaHmModule != null) [ noctaliaHmModule ];
  homeModulesFor =
    {
      standalone ? false,
      umbriel ? false,
    }:
    [ homeModule ]
    ++ sharedHomeModules
    ++ lib.optionals umbriel [ umbrielHmModule ]
    ++ lib.optional standalone determinateHmModule;

  umbrielEnabled = vars: vars.desktop.enable && vars.desktop.compositor == "umbriel";
  comfyuiEnabled = vars: vars.features.ai.enable && vars.features.ai.comfyui.enable;

  mkHost =
    hostName: hostPlatform:
    let
      vars = hostVars.${hostName};
    in
    lib.nixosSystem {
      specialArgs = {
        inherit
          self
          inputs
          vars
          hostName
          combined
          homeModulesFor
          ;
      };
      modules = [
        {
          nixpkgs.hostPlatform = hostPlatform;
          nixpkgs.overlays = sharedOverlays vars;
        }
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.nix-flatpak.nixosModules.nix-flatpak
        inputs.sops-nix.nixosModules.sops
        inputs.lanzaboote.nixosModules.lanzaboote
        greeterNixosModule
        nixosHostModules.${hostName}
      ]
      ++ lib.optionals (comfyuiEnabled vars) [ inputs.comfyui-nix.nixosModules.default ];
    };

  mkHome =
    hostName: hostPlatform:
    let
      vars = hostVars.${hostName};
      primaryUser = vars.users.primary;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        system = hostPlatform;
        config.allowUnfree = true;
        overlays = sharedOverlays vars;
      };
      extraSpecialArgs = {
        inherit
          self
          vars
          inputs
          combined
          ;
      };
      modules =
        homeModulesFor {
          standalone = true;
          umbriel = umbrielEnabled vars;
        }
        ++ [
          {
            home.username = primaryUser;
            home.homeDirectory = "/home/${primaryUser}";
          }
        ];
    };

  nixosConfigs = lib.mapAttrs mkHost hostPlatforms;
  homeConfigs = lib.mapAttrs mkHome hostPlatforms;
in
{
  systems = lib.unique (lib.attrValues hostPlatforms);

  flake = {
    nixosModules = nixosHostModules;

    homeModules.default = homeModule;

    nagiHostMetadata = hostMetadata;
    nixosConfigurations = nixosConfigs;
    homeConfigurations = homeConfigs;
  };
}
