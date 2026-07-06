{
  self,
  inputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  combined = import ../combined/stacks.nix;
  hosts = {
    tandesk = {
      system = "x86_64-linux";
      module = ../../hosts/tandesk/default.nix;
      variables = [
        ../../hosts/tandesk/variables.nix
        ../../hosts/tandesk/advanced.nix
      ];
    };
    default = {
      system = "x86_64-linux";
      module = ../../hosts/default/default.nix;
      variables = [
        ../../hosts/default/variables.nix
        ../../hosts/default/advanced.nix
      ];
    };
    tanlappy = {
      system = "x86_64-linux";
      module = ../../hosts/tanlappy/default.nix;
      variables = [
        ../../hosts/tanlappy/variables.nix
        ../../hosts/tanlappy/advanced.nix
      ];
    };
  };
  homeModule = import ../../users/default/home.nix;
  noctaliaHmModule = lib.attrByPath ["noctalia" "homeModules" "default"] null inputs;
  codexDesktopHmModule = lib.attrByPath ["codex-desktop-linux" "homeManagerModules" "default"] null inputs;
  hostPlatforms = lib.mapAttrs (_: spec: spec.system) hosts;
  importVariables = files:
    lib.foldl' lib.recursiveUpdate { } (map import files);
  hostVars = lib.mapAttrs (_: spec: importVariables spec.variables) hosts;
  nixosHostModules = lib.mapAttrs (_: spec: import spec.module) hosts;

  niriOverlay = lib.attrByPath ["niri" "overlays" "niri"] null inputs;
  niriNixosModule = lib.attrByPath ["niri" "nixosModules" "niri"] null inputs;
  niriHmConfigModule = lib.attrByPath ["niri" "homeModules" "config"] null inputs;
  # mcp-nixos-2.4.3 ships a flaky store test that scans /nix/store and
  # asserts a random text file does not contain the word "Error". The
  # upstream package disables it on Darwin but not Linux. Mirror the
  # same skip here so the install check phase passes.
  mcpNixosOverlay = final: prev: {
    mcp-nixos = prev.mcp-nixos.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or []) ++ ["test_read_text_file"];
    });
  };

  # Use llm-agents.nix's default overlay so packages come from its binary
  # cache instead of being rebuilt against our nixpkgs revision.
  llmAgentsOverlay = lib.attrByPath ["llm-agents" "overlays" "default"] null inputs;
  sharedOverlays = vars:
    lib.optionals (niriOverlay != null) [niriOverlay]
    ++ lib.optional (millenniumEnabled vars) inputs.millennium.overlays.default
    ++ lib.optionals (nixosMcpEnabled vars) [mcpNixosOverlay]
    ++ lib.optional (llmAgentsOverlay != null) llmAgentsOverlay;
  sharedHomeModules = vars:
    lib.optionals (niriHmConfigModule != null) [niriHmConfigModule]
    ++ lib.optionals (noctaliaHmModule != null) [noctaliaHmModule]
    ++ lib.optionals (codexDesktopHmModule != null) [codexDesktopHmModule];

  millenniumEnabled = vars: lib.attrByPath ["features" "gaming" "steam" "millennium" "enable"] false vars;
  nixosMcpEnabled = vars:
    lib.attrByPath ["features" "mcp" "nixos" "enable"] (
      lib.attrByPath ["features" "codingTools" "aiCli" "enable"] (
        lib.attrByPath ["features" "codingTools" "enable"] true vars
      )
      vars
    )
    vars;
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
          homeModule
          combined
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
        [
          homeModule
          {
            home.username = primaryUser;
            home.homeDirectory = "/home/${primaryUser}";
          }
        ]
        ++ sharedHomeModules vars;
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
