{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      nixfmtPkg = pkgs.nixfmt;
      formatterPkg = pkgs.writeShellApplication {
        name = "nagi-format";
        runtimeInputs = [
          pkgs.findutils
          nixfmtPkg
        ];
        text = ''
          args=("$@")
          has_path=0
          for arg in "''${args[@]}"; do
            if [[ "$arg" != -* ]]; then
              has_path=1
              break
            fi
          done

          files=()
          if [[ "$has_path" -eq 0 ]]; then
            mapfile -d "" -t files < <(
              find . \
                -path './.git' -prune -o \
                -path './.direnv' -prune -o \
                -type f -name '*.nix' -print0 \
                | sort -z
            )
          fi

          exec nixfmt "''${args[@]}" "''${files[@]}"
        '';
      };
      nixSource = lib.fileset.toSource {
        root = ../..;
        fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ../..;
      };
      shellSource = lib.fileset.toSource {
        root = ../..;
        fileset = lib.fileset.unions [
          ../../install/bootstrap.sh
          ../../scripts/bg3-mode
          ../../scripts/repo-sync
          ../../scripts/repo-sync-codebox
          ../../scripts/tcli
          ../../secrets/scripts/debug-niri-eval.sh
          ../../secrets/scripts/validate-host.sh
        ];
      };
      orphanSource = lib.fileset.toSource {
        root = ../..;
        fileset = lib.fileset.unions [
          (lib.fileset.fileFilter (file: file.hasExt "nix") ../..)
          ../../scripts/check-orphan-modules.py
        ];
      };
      zenPkg = lib.attrByPath [ "packages" system "default" ] null inputs.zen-browser;
      heliumPkg =
        let
          fromPackages = lib.attrByPath [ "packages" system "default" ] null inputs.helium2nix;
          fromLegacy = lib.attrByPath [ "defaultPackage" system ] null inputs.helium2nix;
        in
        if fromPackages != null then fromPackages else fromLegacy;
      noctaliaPkg = lib.attrByPath [ "noctalia" "packages" system "default" ] null inputs;
      registeredHosts = lib.concatStringsSep " " (
        builtins.attrNames (import ../../lib/host-registry.nix)
      );
      tcliSource = builtins.readFile ../../scripts/tcli;
      tcliText = ''
        export NAGI_REGISTERED_HOSTS=${lib.escapeShellArg registeredHosts}
        ${lib.removePrefix "#!/usr/bin/env bash\n" tcliSource}
      '';

      tcli = pkgs.writeShellApplication {
        name = "tcli";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.git
          pkgs.gnugrep
          pkgs.gnused
          pkgs.inetutils
          pkgs.nh
          pkgs.python3
          inputs.determinate-nix.packages.${system}.default
          pkgs.statix
        ];
        # SC2001: sed is the clear way to indent multi-line closure-diff output.
        excludeShellChecks = [ "SC2001" ];
        text = tcliText;
      };
    in
    {
      formatter = formatterPkg;

      packages = lib.filterAttrs (_: value: value != null) {
        nagi-zen = zenPkg;
        nagi-helium = heliumPkg;
        nagi-noctalia = noctaliaPkg;
        mo2-lint = pkgs.callPackage ../../pkgs/mo2-lint { };
        computer-use-linux = pkgs.callPackage ../../pkgs/computer-use-linux { };
        nagi-noctalia-hyprland-local-workspaces =
          pkgs.callPackage ../../pkgs/noctalia-plugins/hyprland-local-workspaces
            { };
        inherit tcli;
      };

      checks = {
        actionlint =
          pkgs.runCommandLocal "actionlint-check"
            {
              nativeBuildInputs = [ pkgs.actionlint ];
            }
            ''
              actionlint \
                -config-file ${../../.github/actionlint.yaml} \
                ${../../.github/workflows/ci.yml}
              touch "$out"
            '';

        codex-desktop-config =
          pkgs.runCommandLocal "codex-desktop-config-tests"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              CODEX_CONFIGURATOR=${../../modules/home/dev/configure-codex-desktop.py} \
                python ${../../tests/test_configure_codex_desktop.py}
              touch "$out"
            '';

        orphan-modules =
          pkgs.runCommandLocal "orphan-module-check"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              python ${../../scripts/check-orphan-modules.py} ${orphanSource}
              touch "$out"
            '';

        repo-sync =
          pkgs.runCommandLocal "repo-sync-tests"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.git
                pkgs.gnugrep
                pkgs.gnused
                pkgs.openssh
                pkgs.python3
              ];
            }
            ''
              NAGI_REPO_SYNC=${../../scripts/repo-sync} \
                python ${../../tests/test_repo_sync.py}
              NAGI_REPO_SYNC=${../../scripts/repo-sync} \
              NAGI_REPO_SYNC_CODEBOX=${../../scripts/repo-sync-codebox} \
                python ${../../tests/test_repo_sync_codebox.py}
              touch "$out"
            '';

        # Lightweight behavior check: help text only (no flake eval / rebuild).
        tcli-help =
          pkgs.runCommandLocal "tcli-help"
            {
              nativeBuildInputs = [ tcli ];
            }
            ''
              tcli --help | grep -q 'nagi helper'
              tcli -h | grep -q 'Usage:'
              touch "$out"
            '';

        nix-parse =
          pkgs.runCommandLocal "nix-parse-check"
            {
              nativeBuildInputs = [ pkgs.nix ];
            }
            ''
              find ${nixSource} -type f -name '*.nix' -print0 \
                | xargs -0 -r -n1 nix-instantiate --store dummy:// --parse >/dev/null
              touch "$out"
            '';

        format =
          pkgs.runCommandLocal "nix-format-check"
            {
              nativeBuildInputs = [ nixfmtPkg ];
            }
            ''
              find ${nixSource} -type f -name '*.nix' -print0 \
                | xargs -0 -r nixfmt --check
              touch "$out"
            '';

        shellcheck =
          pkgs.runCommandLocal "shellcheck"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
            }
            ''
              find ${shellSource} -type f -print0 \
                | xargs -0 -r shellcheck --exclude=SC2001
              touch "$out"
            '';
      };
    };
}
