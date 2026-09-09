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

    };
}
