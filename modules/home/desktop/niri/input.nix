{
  plain,
  leaf,
  flag,
  ...
}:
[
  (plain "input" [
    (plain "keyboard" [
      (plain "xkb" [ ])
      (flag "numlock")
    ])

    (plain "touchpad" [
      (flag "tap")
      (flag "natural-scroll")
    ])

    (plain "mouse" [ ])
    (plain "trackpoint" [ ])
    (leaf "focus-follows-mouse" { "max-scroll-amount" = "15%"; })
  ])
]
