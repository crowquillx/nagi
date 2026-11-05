# Local compatibility patches. Each workaround documents its removal condition.
{ lib, inputs }:
let
  # Remove when the pinned Equicord includes the 2026-10-05 AudioPlayerAPI fix.
  equicordAudioPlayer = final: prev: {
    equicord = prev.equicord.overrideAttrs (old: {
      patches =
        (old.patches or [ ])
        ++ lib.optional (lib.versionOlder old.version "2026-10-05") (
          final.fetchpatch {
            url = "https://github.com/Equicord/Equicord/commit/c5fb124e496bdc364deb28eb026e29422d35bd19.patch";
            hash = "sha256-032qjpja9i/E0tCEjRCNQug/+GuLoON6M4ZZ4AzrzA8=";
          }
        );
    });
  };

  # Hydra's bundled UMU launcher needs Python to start Proton. Remove when
  # nixpkgs includes Python in Hydra's AppImage environment.
  hydraLauncher = final: prev: {
    hydralauncher = prev.hydralauncher.override {
      appimageTools = final.appimageTools // {
        wrapType2 =
          args:
          final.appimageTools.wrapType2 (
            args
            // {
              extraPkgs = pkgs: (args.extraPkgs or (_: [ ])) pkgs ++ [ pkgs.python3 ];
            }
          );
      };
    };
  };

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
  # cheatengine.org re-serves the Linux zip in place, so the live 7.71
  # archive hash/layout can differ from a given cheatengine-flake pin.
  # The cap-bearing security wrapper also requires DT_RPATH because
  # capability execution strips LD_LIBRARY_PATH. Remove only after
  # upstream packages the live archive and preserves runtime library
  # discovery through the NixOS security wrapper.
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
          url = old.src.url or "https://cheatengine.org/download/CheatEngineLinux771.zip";
          hash = "sha256-D7DZBDroVqzeA7W4caLzYn689nSurNBF+G1W2RoH8Xc=";
        };
        dontAutoPatchelf = true;
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.patchelf ];
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/opt/cheatengine"
          if [ -d CheatEngineLinux771 ]; then
            cp -r CheatEngineLinux771/* "$out/opt/cheatengine/"
          else
            cp -r ./* "$out/opt/cheatengine/"
          fi
          chmod +x "$out/opt/cheatengine/cheatengine-x86_64"
          if [ -f "$out/opt/cheatengine/tutorial-x86_64" ]; then
            chmod +x "$out/opt/cheatengine/tutorial-x86_64"
          fi
          if [ -f "$out/opt/cheatengine/gtutorial-x86_64" ]; then
            chmod +x "$out/opt/cheatengine/gtutorial-x86_64"
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
          if [ -f "$out/opt/cheatengine/gtutorial-x86_64" ]; then
            patchelf --set-interpreter "${interpreter}" "$out/opt/cheatengine/gtutorial-x86_64"
            patchelf --force-rpath --set-rpath "${rpath}" "$out/opt/cheatengine/gtutorial-x86_64"
          fi
        '';
      }
    );
  };

  # Introduced 2026-10-20.
  # The upstream package sets makeWrapperArgs as one Nix string per flag
  # ("--prefix QT_PLUGIN_PATH : <dirs>", ...). With __structuredAttrs those
  # stay whole array elements, and wrapPythonPrograms hands each to
  # makeShellWrapper as a single argv entry, which dies with
  # "makeWrapper doesn't understand the arg --prefix ...". Split every entry
  # on spaces so each flag, variable, separator, and value is its own token
  # (store paths contain no spaces, so this is exact and idempotent).
  # Remove when upstream lists one token per element.
  # Upstream: https://github.com/loteran/Arctis-Sound-Manager (nix/package.nix)
  arctisWrapperArgs = final: prev: {
    arctis-sound-manager = prev.arctis-sound-manager.overrideAttrs (old: {
      makeWrapperArgs = lib.concatMap (s: lib.splitString " " s) (old.makeWrapperArgs or [ ]);
    });
  };

  # Introduced 2026-10-20.
  # nixos-unstable signs out-of-tree kernel modules with kmodigest at
  # install time and the *-modules aggregation concatenates every
  # module's .ko.cer into modules.cer. openrazer's custom installPhase
  # copies only driver/*.ko instead of running Kbuild modules_install,
  # so its modules are never signed and the aggregation fails with
  # missing razerkbd.ko.cer (and siblings) errors. Sign the installed
  # modules in postFixup (after stripping) to generate the certificates.
  # Remove when upstream openrazer installs .cer files itself.
  openrazerCer =
    final: prev:
    let
      kmodigestPkg = prev.buildPackages.kmodigest;
      fixOpenrazer =
        kpkgs:
        kpkgs.extend (
          _kfinal: kprev: {
            openrazer = kprev.openrazer.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ kmodigestPkg ];
              postFixup = (old.postFixup or "") + ''
                for ko in "$out"/lib/modules/*/kernel/drivers/hid/razer*.ko; do
                  if [ -f "$ko" ]; then
                    kmodigest "$ko"
                  fi
                done
              '';
            });
          }
        );
    in
    {
      linuxPackages = fixOpenrazer prev.linuxPackages;
      linuxPackages_zen = fixOpenrazer prev.linuxPackages_zen;
      linuxPackages_latest = fixOpenrazer prev.linuxPackages_latest;
    };

  # Introduced 2026-10-26.
  # nixpkgs moved python3Packages.mcp to 2.x, and fastmcp-slim is marked
  # broken against it, which blocks mcp-nixos evaluation. Build mcp-nixos
  # against the mcp_1 package nixpkgs still ships. Remove when fastmcp-slim
  # is no longer marked broken with the default mcp.
  mcpNixosMcp1 = _final: prev: {
    mcp-nixos = prev.mcp-nixos.override {
      python3Packages = prev.python3Packages.overrideScope (
        _pyFinal: pyPrev: {
          mcp = pyPrev.mcp_1;
        }
      );
    };
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
  inherit
    arctisWrapperArgs
    cheatengine
    equicordAudioPlayer
    hydraLauncher
    llmAgents
    mcpNixosMcp1
    openrazerCer
    patool
    ;
}
