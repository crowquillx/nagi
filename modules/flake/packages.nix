{ inputs, self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      zenPkg = lib.attrByPath [ "packages" system "default" ] null inputs.zen-browser;
      heliumPkg =
        let
          fromPackages = lib.attrByPath [ "packages" system "default" ] null inputs.helium2nix;
          fromLegacy = lib.attrByPath [ "defaultPackage" system ] null inputs.helium2nix;
        in
        if fromPackages != null then fromPackages else fromLegacy;
      noctaliaPkg = lib.attrByPath [ "noctalia" "packages" system "default" ] null inputs;
      niriPkg = lib.attrByPath [ "niri" "packages" system "niri-unstable" ] null inputs;

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
          pkgs.nix
          pkgs.statix
        ];
        # SC2001: sed is the clear way to indent multi-line closure-diff output.
        excludeShellChecks = [ "SC2001" ];
        text = builtins.readFile ../../scripts/tcli;
      };
    in
    {
      packages = lib.filterAttrs (_: value: value != null) {
        nagi-zen = zenPkg;
        nagi-helium = heliumPkg;
        nagi-noctalia = noctaliaPkg;
        nagi-niri = niriPkg;
        inherit tcli;
      };

      # Lightweight behavior check: help text only (no flake eval / rebuild).
      checks.tcli-help = pkgs.runCommandLocal "tcli-help" {
        nativeBuildInputs = [ tcli ];
      } ''
        export NAGI_FLAKE_DIR=${self}
        tcli --help | grep -q 'nagi helper'
        tcli -h | grep -q 'Usage:'
        touch "$out"
      '';
    };
}
