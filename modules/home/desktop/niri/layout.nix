{ plain, leaf, flag, colors, ... }:
[
  (plain "layout" [
    (leaf "gaps" 12)
    (leaf "center-focused-column" "never")

    (plain "preset-column-widths" [
      (leaf "proportion" 0.33333)
      (leaf "proportion" 0.5)
      (leaf "proportion" 0.66667)
    ])

    (plain "default-column-width" [
      (leaf "proportion" 0.5)
    ])

    (plain "focus-ring" [
      (leaf "width" 2)
      (leaf "active-color" colors.active)
      (leaf "inactive-color" colors.inactive)
      (leaf "urgent-color" colors.urgent)
    ])

    (plain "border" [
      (flag "off")
      (leaf "width" 2)
      (leaf "active-color" colors.active)
      (leaf "inactive-color" colors.inactive)
      (leaf "urgent-color" colors.urgent)
    ])

    (plain "shadow" [
      (leaf "softness" 30)
      (leaf "spread" 5)
      (leaf "offset" { x = 0; y = 5; })
      (leaf "color" colors.shadow)
    ])

    (plain "tab-indicator" [
      (leaf "active-color" colors.active)
      (leaf "inactive-color" colors.tabInactive)
      (leaf "urgent-color" colors.urgent)
    ])

    (plain "insert-hint" [
      (leaf "color" colors.insertHint)
    ])
  ])
]
