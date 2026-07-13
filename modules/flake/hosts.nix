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
  # patool's pytestCheckPhase fails on recent nixos-unstable: libmagic
  # reports `application/x-bzip2` for `*.tar.bz2.foo` instead of
  # `application/x-tar`, and several tar/pytarfile tests can't locate the
  # list_bzip2/lzma/xz/lzip helpers. These are upstream test-suite issues, not
  # packaging correctness problems, so skip them to keep bottles buildable.
  # bottles depends on python314Packages.patool (the python-package-set copy),
  # not the top-level `patool` alias, so override at the package-set scope.
  patoolSkipTests = old: {
    disabledTests = (old.disabledTests or []) ++ [
      "test_mime_file"
      "test_mime_file_bzip"
      "test_tar_bz2"
      "test_tar_bz2_file"
      "test_tar_lzip"
      "test_tar_lzma"
      "test_tar_xz"
      "test_tar_xz_file"
      "test_py_tarfile_bz2"
      "test_py_tarfile_bz2_file"
    ];
  };
  patoolOverlay = final: prev: {
    python314Packages = prev.python314Packages.overrideScope (pyFinal: pyPrev: {
      patool = pyPrev.patool.overridePythonAttrs patoolSkipTests;
    });
  };
  # cheatengine-flake is currently broken against the live official download:
  # cheatengine.org re-serves 7.7 with a flat zip layout (files at the archive
  # root, binary named tutorial-x86_64) and a different sha256 than upstream
  # pinned. Upstream package.nix still expects a wrapping CheatEngineLinux77/
  # directory and gtutorial-x86_64. Patch src + installPhase locally, reusing
  # upstream's runtimeDeps (old.buildInputs) for libPath and upstream's icon.
  # The launcher's exec target is then rewritten to the security.wrappers
  # cap-bearing copy at /run/wrappers/bin/cheatengine-bin (see
  # modules/nixos/services/steam.nix): wrappers cannot target that path
  # directly (assertExecutable fails on a build-time-absent file), so build the
  # wrapper against the store ELF then substituteInPlace the exec line.
  # Must use makeShellWrapper (not makeWrapper): wrapGAppsHook propagates
  # makeBinaryWrapper, which overrides makeWrapper to emit an ELF that
  # substituteInPlace rejects ("Input null bytes").
  #
  # Patching notes: autoPatchelf is disabled because it sets DT_RUNPATH, which
  # is NOT searched by dlopen — and CE dlopens libGL.so.1. We manually set
  # DT_RPATH (--force-rpath) which IS searched by dlopen, and patch the
  # interpreter to the nixpkgs glibc ld-linux (NixOS stub-ld blocks the generic
  # one). DT_RPATH is the only lib-discovery mechanism that survives the
  # cap-wrapper exec, which strips LD_LIBRARY_PATH. Drop this overlay when the
  # upstream flake updates package.nix.
  cheatengineShimOverlay = final: prev: {
    cheatengine = prev.cheatengine.overrideAttrs (old: let
      libPath = final.lib.makeLibraryPath old.buildInputs;
      rpath = "$out/opt/cheatengine:${libPath}";
      interpreter = final.stdenv.cc.bintools.dynamicLinker;
    in {
      src = final.fetchurl {
        url = old.src.url or "https://cheatengine.org/download/CheatEngineLinux77.zip";
        hash = "sha256-mzbojv4sNl1xgewYH/88rZcABwSbSS7pOX8WjYHQ+Zc=";
      };
      dontAutoPatchelf = true;
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.patchelf ];
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/opt/cheatengine"
        cp -r ./* "$out/opt/cheatengine/"
        chmod +x "$out/opt/cheatengine/cheatengine-x86_64"
        if [ -f "$out/opt/cheatengine/tutorial-x86_64" ]; then
          chmod +x "$out/opt/cheatengine/tutorial-x86_64"
        fi
        mkdir -p "$out/bin"
        makeShellWrapper "$out/opt/cheatengine/cheatengine-x86_64" "$out/bin/cheatengine" \
          --prefix LD_LIBRARY_PATH : "$out/opt/cheatengine" \
          --prefix LD_LIBRARY_PATH : "${libPath}" \
          --chdir "$out/opt/cheatengine"
        substituteInPlace "$out/bin/cheatengine" \
          --replace-fail "$out/opt/cheatengine/cheatengine-x86_64" "/run/wrappers/bin/cheatengine-bin"
        mkdir -p "$out/share/icons/hicolor/128x128/apps"
        cp ${inputs.cheatengine-flake.outPath + "/cheatengine.png"} "$out/share/icons/hicolor/128x128/apps/cheatengine.png"
        runHook postInstall
      '';
      # Run after fixupPhase (which includes shrinkRPATHs that strips rpath
      # entries and converts DT_RPATH to DT_RUNPATH). postFixup is the last
      # chance to set ELF properties before the store path is sealed.
      postFixup = ''
        patchelf --set-interpreter "${interpreter}" "$out/opt/cheatengine/cheatengine-x86_64"
        patchelf --force-rpath --set-rpath "${rpath}" "$out/opt/cheatengine/cheatengine-x86_64"
        if [ -f "$out/opt/cheatengine/tutorial-x86_64" ]; then
          patchelf --set-interpreter "${interpreter}" "$out/opt/cheatengine/tutorial-x86_64"
          patchelf --force-rpath --set-rpath "${rpath}" "$out/opt/cheatengine/tutorial-x86_64"
        fi
      '';
    });
  };

  # Keep the former upstream overlay namespace when llm-agents.nix only
  # exposes flake packages. Referencing those packages directly preserves
  # binary-cache compatibility instead of rebuilding them with our nixpkgs.
  llmAgentsOverlay = let
    upstreamOverlay = lib.attrByPath ["llm-agents" "overlays" "default"] null inputs;
  in
    if upstreamOverlay != null
    then upstreamOverlay
    else final: _prev: {
      llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system} or {};
    };
  hushmicOverlay = final: _prev: {
    hushmic = inputs.hushmic-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };
  sharedOverlays = vars:
    [hushmicOverlay]
    ++ lib.optionals (niriOverlay != null) [niriOverlay]
    ++ lib.optional (millenniumEnabled vars) inputs.millennium.overlays.default
    ++ lib.optionals (cheatengineEnabled vars) [
      inputs.cheatengine-flake.overlays.default
      cheatengineShimOverlay
    ]
    ++ lib.optionals (nixosMcpEnabled vars) [mcpNixosOverlay]
    ++ lib.optional (gamingEnabled vars) patoolOverlay
    ++ [llmAgentsOverlay];
  sharedHomeModules = vars:
    lib.optionals (niriHmConfigModule != null) [niriHmConfigModule]
    ++ lib.optionals (noctaliaHmModule != null) [noctaliaHmModule]
    ++ lib.optionals (codexDesktopHmModule != null) [codexDesktopHmModule];

  millenniumEnabled = vars: lib.attrByPath ["features" "gaming" "steam" "millennium" "enable"] false vars;
  gamingEnabled = vars: lib.attrByPath ["features" "gaming" "enable"] false vars;
  cheatengineEnabled = vars: lib.attrByPath ["features" "gaming" "cheatengine" "enable"] false vars;
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
