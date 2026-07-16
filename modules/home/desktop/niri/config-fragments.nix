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
  get = path: default: lib.attrByPath path default vars;
  qtThemeEnabled =
    get [ "features" "stylix" "enable" ] true && get [ "features" "theme" "qt" "enable" ] true;
in
[
  (optionalNode qtThemeEnabled (
    plain "environment" [
      (leaf "QT_QPA_PLATFORMTHEME" "qt5ct")
      (leaf "QT_STYLE_OVERRIDE" "kvantum")
    ]
  ))
  (plain "hotkey-overlay" [ (flag "skip-at-startup") ])
  (flag "prefer-no-csd")
  (leaf "screenshot-path" "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png")
  (plain "animations" [ ])

  (plain "debug" [
    (flag "honor-xdg-activation-with-invalid-serial")
  ])
]
