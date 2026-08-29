{
  lib,
  vars,
  plain,
  leaf,
  flag,
  optionalNode,
  ...
}:
let
  shell = import ../session-shell/lib.nix { inherit lib vars; };
  hostName = vars.host.name or "";
  isTanlappy = hostName == "tanlappy";
  toolkitLeaves = lib.mapAttrsToList (name: value: leaf name value) shell.toolkitEnv;
in
[
  # Named workspaces initially appear in declaration order.
  (optionalNode isTanlappy (leaf "workspace" "1"))
  (optionalNode isTanlappy (leaf "workspace" "2"))

  (optionalNode (toolkitLeaves != [ ]) (plain "environment" toolkitLeaves))
  (plain "hotkey-overlay" [ (flag "skip-at-startup") ])
  (flag "prefer-no-csd")
  (leaf "screenshot-path" "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png")
  (plain "animations" [ ])

  (plain "debug" [
    (flag "honor-xdg-activation-with-invalid-serial")
  ])
]
