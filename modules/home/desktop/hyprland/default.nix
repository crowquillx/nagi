{
  lib,
  pkgs,
  vars,
  ...
}:
let
  quote = builtins.toJSON;
  context = {
    inherit
      lib
      pkgs
      vars
      quote
      ;
  };
in
lib.concatStringsSep "\n" [
  (import ./core.nix context)
  (import ./windowrules.nix context)
  (import ./workspaces.nix context)
  (import ./binds.nix context)
]
