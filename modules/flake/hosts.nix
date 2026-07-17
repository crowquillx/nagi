{
  self,
  inputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  combined = import ../combined/stacks.nix;
  hosts = import ../../lib/host-registry.nix;
  inherit (import ../../lib/package-overlays.nix { inherit lib inputs; }) sharedOverlays;

  homeModule = import ../../users/default/home.nix;
  noctaliaHmModule = lib.attrByPath ["noctalia" "homeModules" "default"] null inputs;
  codexDesktopHmModule = lib.attrByPath ["codex-desktop-linux" "homeManagerModules" "default"] null inputs;
  hostPlatforms = lib.mapAttrs (_: spec: spec.system) hosts;
  importVariables = files:
    lib.foldl' lib.recursiveUpdate { } (map import files);
  # Validate each host's raw variables against the schema and materialise
  # fully defaulted attrs before any nixosSystem/homeManagerConfiguration
  # call. Overlay gates and specialArgs must see the resolved shape, not
  # the sparse host file tree.
  resolveVariables = raw:
    (lib.evalModules {
      modules = [
        ../../hosts/common/variables-schema.nix
        {nagi.variables = raw;}
      ];
    }).config.nagi.variables;
  hostVars = lib.mapAttrs (_: spec: resolveVariables (importVariables spec.variables)) hosts;
  nixosHostModules = lib.mapAttrs (_: spec: import spec.module) hosts;

  niriNixosModule = lib.attrByPath ["niri" "nixosModules" "niri"] null inputs;
  niriHmConfigModule = lib.attrByPath ["niri" "homeModules" "config"] null inputs;
  stylixHmModule = lib.attrByPath ["stylix" "homeModules" "stylix"] null inputs;

  # Niri and Stylix NixOS modules inject their Home Manager modules,
  # so standalone Home Manager appends those two modules below.
  sharedHomeModules =
    lib.optionals (noctaliaHmModule != null) [noctaliaHmModule]
    ++ lib.optionals (codexDesktopHmModule != null) [codexDesktopHmModule];
  homeModulesFor = {standalone ? false}:
    [homeModule]
    ++ sharedHomeModules
    ++ lib.optionals (standalone && niriHmConfigModule != null) [niriHmConfigModule]
    ++ lib.optionals (standalone && stylixHmModule != null) [stylixHmModule];

  comfyuiEnabled = vars:
    (lib.attrByPath ["features" "ai" "enable"] false vars)
    && (lib.attrByPath ["features" "ai" "comfyui" "enable"] false vars);

  mkHost = hostName: hostPlatform: let
    vars = hostVars.${hostName};
    niriNixosModule' = niriNixosModule;
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
      modules =
        [
          {
            nixpkgs.hostPlatform = hostPlatform;
            nixpkgs.overlays = sharedOverlays vars;
          }
          inputs.home-manager.nixosModules.home-manager
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
          inputs.lanzaboote.nixosModules.lanzaboote
          nixosHostModules.${hostName}
        ]
        ++ lib.optionals (comfyuiEnabled vars) [inputs.comfyui-nix.nixosModules.default]
        ++ lib.optionals (niriNixosModule' != null) [niriNixosModule'];
    };

  mkCiHost = hostName: hostPlatform:
    (mkHost hostName hostPlatform).extendModules {
      modules = [
        (
          {lib, ...}: {
            fileSystems."/" = lib.mkDefault {
              device = "none";
              fsType = "tmpfs";
            };
          }
        )
      ];
    };

  mkHome = hostName: hostPlatform: let
    vars = hostVars.${hostName};
    primaryUser = lib.attrByPath ["users" "primary"] "nagi" vars;
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
        homeModulesFor {standalone = true;}
        ++ [
          {
            home.username = primaryUser;
            home.homeDirectory = "/home/${primaryUser}";
          }
        ];
    };

  nixosConfigs = lib.mapAttrs mkHost hostPlatforms;
  ciNixosConfigs = lib.mapAttrs mkCiHost hostPlatforms;
  homeConfigs = lib.mapAttrs mkHome hostPlatforms;
in {
  systems = ["x86_64-linux"];

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (pkgs) lib;
    # Standard checks.x86_64-linux.* output. Each entry is a build-only
    # derivation; no live activation or privileged commands run here.
    # Reuses the same builders as the published configurations so the host
    # list stays DRY and the checks never drift from real outputs.
    nixosChecks = lib.mapAttrs' (
      hostName: _:
        lib.nameValuePair "nixos-${hostName}" ciNixosConfigs.${hostName}.config.system.build.toplevel
    ) ciNixosConfigs;

    homeChecks = lib.mapAttrs' (
      hostName: _:
        lib.nameValuePair "home-${hostName}" homeConfigs.${hostName}.activationPackage
    ) homeConfigs;

    # Blocking lint: statix over the flake source. Copies the source so
    # statix.toml (ignore rules) is honored the same as a local run.
    statixCheck = pkgs.runCommandLocal "statix-check" {
      nativeBuildInputs = [pkgs.statix];
    } ''
      cp -r --no-preserve=mode ${self}/. .
      statix check .
      touch $out
    '';
  in {
    checks = nixosChecks // homeChecks // {
      statix = statixCheck;
    };
  };

  flake = {
    nixosModules = nixosHostModules;

    homeModules.default = homeModule;

    nixosConfigurations = nixosConfigs;
    ciNixosConfigurations = ciNixosConfigs;
    homeConfigurations = homeConfigs;
  };
}
