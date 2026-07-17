{ lib, vars, leaf, ... }:
let
  startup = import ../startup.nix { inherit lib vars; };
in
lib.optionals (startup.startupBackend == "niri") (
  map (command: leaf "spawn-at-startup" [ "sh" "-lc" command ]) startup.effectiveStartupApps
)
