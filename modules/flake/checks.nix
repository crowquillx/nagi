{ self, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) lib;
      nixfmtPkg = pkgs.nixfmt;
      tcli = config.packages.tcli;
      hosts = lib.filterAttrs (_: host: host.system == system) (import ../../lib/host-registry.nix);
      nixFiles = lib.fileset.fileFilter (file: file.hasExt "nix") ../..;
      nixSource = lib.fileset.toSource {
        root = ../..;
        fileset = nixFiles;
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
          nixFiles
          ../../scripts/check-orphan-modules.py
        ];
      };
      statixSource = lib.fileset.toSource {
        root = ../..;
        fileset = lib.fileset.unions [
          nixFiles
          ../../statix.toml
        ];
      };
      # Blocking lint over only Nix sources and statix.toml. In particular,
      # wallpapers and other large repository assets never enter this derivation.
      statixCheck =
        pkgs.runCommandLocal "statix-check"
          {
            nativeBuildInputs = [ pkgs.statix ];
          }
          ''
            cp -r ${statixSource}/. .
            statix check .
            touch $out
          '';
    in
    {
      checks = {
        statix = statixCheck;
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
      }
      // lib.mapAttrs' (
        name: _:
        lib.nameValuePair "nixos-${name}" self.nixosConfigurations.${name}.config.system.build.toplevel
      ) hosts
      // lib.mapAttrs' (
        name: _: lib.nameValuePair "home-${name}" self.homeConfigurations.${name}.activationPackage
      ) hosts;
    };
}
