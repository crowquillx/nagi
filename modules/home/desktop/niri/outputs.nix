{
  lib,
  vars,
  mkOutput,
  ...
}:
let
  outputs = lib.attrByPath [ "desktop" "niri" "outputs" ] { } vars;
in
lib.mapAttrsToList mkOutput outputs
