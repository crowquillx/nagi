{
  lib,
  vars,
  plain,
  leaf,
  colors,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  compositor = get [ "desktop" "compositor" ] "niri";
  extraCompositors = get [ "desktop" "extraCompositors" ] [ ];
  hasNiri = builtins.elem "niri" ([ compositor ] ++ extraCompositors);
  noctaliaEnable = get [ "desktop" "noctalia" "enable" ] (desktopEnabled && hasNiri);
  noctaliaCommand = get [ "desktop" "noctalia" "command" ] "nagi-noctalia-shell";
in
lib.optionals noctaliaEnable [
  (leaf "spawn-at-startup" [ noctaliaCommand ])

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

  (plain "recent-windows" [
    (plain "highlight" [
      (leaf "active-color" colors.active)
      (leaf "urgent-color" colors.urgent)
    ])
  ])
]
