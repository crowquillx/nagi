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
  dmsHmModule = lib.attrByPath [ "dms" "homeModules" "default" ] null inputs;
  caelestiaHmModule =
    let
      fromHomeManager = lib.attrByPath [ "caelestia-shell" "homeManagerModules" "default" ] null inputs;
      fromHome = lib.attrByPath [ "caelestia-shell" "homeModules" "default" ] null inputs;
    in
    if fromHomeManager != null then fromHomeManager else fromHome;
  inirHmModule =
    let
      fromHome = lib.attrByPath [ "inir" "homeModules" "inir" ] null inputs;
      fromHomeManager = lib.attrByPath [ "inir" "homeManagerModules" "inir" ] null inputs;
      fromHomeDefault = lib.attrByPath [ "inir" "homeModules" "default" ] null inputs;
      fromHomeManagerDefault = lib.attrByPath [ "inir" "homeManagerModules" "default" ] null inputs;
    in
    if fromHome != null then
      fromHome
    else if fromHomeManager != null then
      fromHomeManager
    else if fromHomeDefault != null then
      fromHomeDefault
    else
      fromHomeManagerDefault;
  dmsNagiModule = ../../modules/home/desktop/session-shell/dms.nix;
  caelestiaNagiModule = ../../modules/home/desktop/session-shell/caelestia.nix;
  inirNagiModule = ../../modules/home/desktop/session-shell/inir.nix;
  iiNagiModule = ../../modules/home/desktop/session-shell/ii.nix;
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

  stylixHmModule = lib.attrByPath [ "stylix" "homeModules" "stylix" ] null inputs;
  determinateHmModule = inputs.determinate.homeManagerModules.default;
  niriHmConfigModule = inputs.niri.homeModules.config;
  niriHomeModule = import ../home/desktop/niri-user.nix;

  # Niri's configuration module is host-conditional. Stylix injects its Home
  # Manager module from NixOS, while standalone HM appends it explicitly.
  sharedHomeModules = lib.optionals (noctaliaHmModule != null) [ noctaliaHmModule ];
  homeModulesFor =
    {
      standalone ? false,
      niri ? false,
      umbriel ? false,
      sessionShell ? "none",
    }:
    [ homeModule ]
    ++ sharedHomeModules
    ++ lib.optionals (sessionShell == "dms" && dmsHmModule != null) [
      dmsHmModule
      dmsNagiModule
    ]
    ++ lib.optionals (sessionShell == "caelestia" && caelestiaHmModule != null) [
      caelestiaHmModule
      caelestiaNagiModule
    ]
    ++ lib.optionals (sessionShell == "inir" && inirHmModule != null) [
      inirHmModule
      inirNagiModule
    ]
    ++ lib.optionals (sessionShell == "ii") [ iiNagiModule ]
    ++ lib.optionals niri [
      niriHmConfigModule
      niriHomeModule
    ]
    ++ lib.optionals umbriel [ umbrielHmModule ]
    ++ lib.optional standalone determinateHmModule
    ++ lib.optionals (standalone && stylixHmModule != null) [ stylixHmModule ];

  niriEnabled =
    vars:
    vars.desktop.enable
    && builtins.elem "niri" ([ vars.desktop.compositor ] ++ vars.desktop.extraCompositors);
  umbrielEnabled =
    vars:
    vars.desktop.enable
    && builtins.elem "umbriel" ([ vars.desktop.compositor ] ++ vars.desktop.extraCompositors);
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
        inputs.stylix.nixosModules.stylix
        inputs.lanzaboote.nixosModules.lanzaboote
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
          niri = niriEnabled vars;
          umbriel = umbrielEnabled vars;
          sessionShell = vars.desktop.sessionShell;
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
