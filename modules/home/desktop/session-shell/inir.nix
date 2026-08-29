{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  shell = import ./lib.nix { inherit lib vars; };
in
{
  programs.inir = {
    enable = true;
    service.enable = false;
    service.compositor = null;
    configSymlink.enable = false;
    extraPackages = lib.optionals (shell.hasNiri && pkgs ? niri) [ pkgs.niri ];
  };
}
