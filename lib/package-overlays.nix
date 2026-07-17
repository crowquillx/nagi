# Overlay and package-shim construction for host configs.
# Contract:
#   { lib, inputs } -> {
#     sharedOverlays :: attrs -> [ overlay ]
#   }
# Feature gates read resolved nagi.variables. Builders stay in hosts.nix.
{ lib, inputs }: let
  niriOverlay = lib.attrByPath ["niri" "overlays" "niri"] null inputs;

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
  vortexOverlay = final: _prev: {
    vortex = inputs.vortex-nix.packages.${final.stdenv.hostPlatform.system}.vortex;
  };
  limuxOverlay = final: _prev: {
    limux = inputs.limux-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };

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

  sharedOverlays = vars:
    [
      hushmicOverlay
      vortexOverlay
      limuxOverlay
    ]
    ++ lib.optionals (niriOverlay != null) [niriOverlay]
    ++ lib.optional (millenniumEnabled vars) inputs.millennium.overlays.default
    ++ lib.optionals (cheatengineEnabled vars) [
      inputs.cheatengine-flake.overlays.default
      cheatengineShimOverlay
    ]
    ++ lib.optionals (nixosMcpEnabled vars) [mcpNixosOverlay]
    ++ lib.optional (gamingEnabled vars) patoolOverlay
    ++ [llmAgentsOverlay];
in {
  inherit sharedOverlays;
}
