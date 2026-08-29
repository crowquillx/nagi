{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  iiPkg = pkgs.callPackage ../../../../pkgs/ii { src = inputs.illogical-impulse; };
in
{
  assertions = [
    {
      assertion = pkgs ? quickshell;
      message = "desktop.sessionShell = \"ii\" requires pkgs.quickshell.";
    }
    {
      assertion = inputs ? illogical-impulse;
      message = "desktop.sessionShell = \"ii\" requires flake input illogical-impulse.";
    }
  ];

  home.packages = [
    iiPkg
    pkgs.quickshell
  ];

  xdg.configFile."quickshell/ii".source = "${iiPkg}/share/ii";
}
