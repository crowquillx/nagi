# Local compatibility patches. Each workaround documents its removal condition.
{ lib, inputs }:
let
  # Introduced 2026-07-17.
  # Recent nixos-unstable libmagic reports a different MIME type for the test
  # fixture, and helper-dependent archive tests cannot find their fixtures.
  # This affects python314Packages.patool, which Bottles consumes. Remove after
  # these tests pass unmodified in the pinned nixpkgs package.
  # Upstream: https://github.com/wummel/patool/issues/194
  patoolSkipTests = old: {
    disabledTests = (old.disabledTests or [ ]) ++ [
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
  patool = final: prev: {
    python314Packages = prev.python314Packages.overrideScope (
      _pyFinal: pyPrev: {
        patool = pyPrev.patool.overridePythonAttrs patoolSkipTests;
      }
    );
  };

  # Introduced 2026-07-17.
  # cheatengine.org currently re-serves 7.7 with a flat archive layout,
  # tutorial-x86_64 naming, and a hash different from cheatengine-flake's pin.
  # The cap-bearing security wrapper also requires DT_RPATH because capability
  # execution strips LD_LIBRARY_PATH. Remove only after upstream packages the
  # live archive layout and preserves runtime library discovery through the
  # NixOS security wrapper.
  # Upstream: https://github.com/Hy4ri/cheatengine-flake/issues/1
  cheatengine = final: prev: {
    cheatengine = prev.cheatengine.overrideAttrs (
      old:
      let
        libPath = final.lib.makeLibraryPath old.buildInputs;
        rpath = "$out/opt/cheatengine:${libPath}";
        interpreter = final.stdenv.cc.bintools.dynamicLinker;
      in
      {
        src = final.fetchurl {
          url = old.src.url or "https://cheatengine.org/download/CheatEngineLinux77.zip";
          hash = "sha256-mzbojv4sNl1xgewYH/88rZcABwSbSS7pOX8WjYHQ+Zc=";
        };
        dontAutoPatchelf = true;
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.patchelf ];
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
          cp ${
            inputs.cheatengine-flake.outPath + "/cheatengine.png"
          } "$out/share/icons/hicolor/128x128/apps/cheatengine.png"
          runHook postInstall
        '';
        # fixupPhase's shrinkRPATHs converts/strips earlier RPATH changes.
        postFixup = ''
          patchelf --set-interpreter "${interpreter}" "$out/opt/cheatengine/cheatengine-x86_64"
          patchelf --force-rpath --set-rpath "${rpath}" "$out/opt/cheatengine/cheatengine-x86_64"
          if [ -f "$out/opt/cheatengine/tutorial-x86_64" ]; then
            patchelf --set-interpreter "${interpreter}" "$out/opt/cheatengine/tutorial-x86_64"
            patchelf --force-rpath --set-rpath "${rpath}" "$out/opt/cheatengine/tutorial-x86_64"
          fi
        '';
      }
    );
  };

  # Introduced 2026-07-17.
  # Preserve the historical pkgs.llm-agents namespace when an llm-agents.nix
  # revision exposes packages but no default overlay. Direct package reuse also
  # preserves the upstream cache pin. Remove when all supported revisions
  # provide overlays.default and the fallback is no longer exercised.
  # Upstream: https://github.com/numtide/llm-agents.nix#using-overlay
  llmAgents =
    let
      upstreamOverlay = lib.attrByPath [ "llm-agents" "overlays" "default" ] null inputs;
    in
    if upstreamOverlay != null then
      upstreamOverlay
    else
      final: _prev: {
        llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system} or { };
      };
in
{
  inherit cheatengine llmAgents patool;
}
