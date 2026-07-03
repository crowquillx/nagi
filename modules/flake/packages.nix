{ inputs, ... }:
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
    in
    {
      packages = lib.filterAttrs (_: value: value != null) {
        nagi-zen = zenPkg;
        nagi-helium = heliumPkg;
        nagi-noctalia = noctaliaPkg;
        nagi-niri = niriPkg;
      };
    };
}
