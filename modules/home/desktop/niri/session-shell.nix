{
  lib,
  vars,
  plain,
  leaf,
  colors,
  ...
}:
let
  shell = import ../session-shell/lib.nix { inherit lib vars; };
  spawn = lib.optionals (shell.startupArgs != null) [
    (leaf "spawn-at-startup" shell.startupArgs)
  ];
  noctaliaRules = lib.optionals shell.noctaliaEnable [
    (plain "layer-rule" [
      (leaf "match" { namespace = "^noctalia-backdrop"; })
      (leaf "place-within-backdrop" true)
    ])
    (plain "layer-rule" [
      (leaf "match" { namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"; })
      (plain "background-effect" [
        (leaf "xray" false)
      ])
    ])
  ];
  dmsRules = lib.optionals shell.dmsEnable [
    (plain "layer-rule" [
      (leaf "match" { namespace = "^quickshell$"; })
      (leaf "place-within-backdrop" true)
    ])
    (plain "layer-rule" [
      (leaf "match" { namespace = "dms:blurwallpaper"; })
      (leaf "place-within-backdrop" true)
    ])
  ];
  caelestiaRules = lib.optionals shell.caelestiaEnable [
    (plain "layer-rule" [
      (leaf "match" { namespace = "^caelestia-"; })
    ])
  ];
  inirRules = lib.optionals shell.inirEnable [
    (plain "layer-rule" [
      (leaf "match" { namespace = "^quickshell"; })
      (leaf "place-within-backdrop" true)
    ])
  ];
in
spawn
++ noctaliaRules
++ dmsRules
++ caelestiaRules
++ inirRules
++ [
  (plain "recent-windows" [
    (plain "highlight" [
      (leaf "active-color" colors.active)
      (leaf "urgent-color" colors.urgent)
    ])
  ])
]
