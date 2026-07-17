{ plain, leaf, flag, cursorTheme, ... }:
[
  (plain "cursor" [
    (leaf "xcursor-theme" cursorTheme.name)
    (leaf "xcursor-size" cursorTheme.size)
    (flag "hide-when-typing")
  ])
]
