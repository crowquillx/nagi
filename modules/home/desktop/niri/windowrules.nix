{ plain, leaf, flag, rgbaApps, vars ? { }, ... }:
let
  discordElectronMatch = {
    app-id = "(?i)^electron$";
    title = "(?i)^.*discord.*$";
  };
  discordAppMatch = {
    app-id = "(?i)^(discord|com\\.discordapp\\.Discord)$";
  };
  equibopAppMatch = {
    app-id = "(?i)^equibop$";
  };
  hostName = vars.host.name or "";
  isTandesk = hostName == "tandesk";
  spotifyRule = plain "window-rule" [
    (leaf "match" { app-id = "(?i)^spotify$"; })
    (leaf "open-on-output" "DP-2")
    (leaf "open-maximized" true)
  ];
  chatRule = plain "window-rule" [
    (leaf "match" discordAppMatch)
    (leaf "match" equibopAppMatch)
    (leaf "match" discordElectronMatch)
    (leaf "open-on-output" "DP-1")
    (leaf "open-maximized" true)
  ];
in
[
  (plain "window-rule" [
    (leaf "match" { app-id = "mullvad-browser$"; title = "^Picture-in-Picture$"; })
    (leaf "open-floating" true)
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = "zen$"; title = "^Picture-in-Picture$"; })
    (leaf "open-floating" true)
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = "dev.noctalia.Noctalia.Settings"; })
    (leaf "open-floating" true)
    (plain "default-column-width" [
      (leaf "fixed" 1080)
    ])
    (plain "default-window-height" [
      (leaf "fixed" 920)
    ])
  ])

  (plain "window-rule" [
    (leaf "geometry-corner-radius" 20)
    (leaf "clip-to-geometry" true)
  ])

  (plain "window-rule" [
    (leaf "geometry-corner-radius" 12)
    (leaf "clip-to-geometry" true)
    (leaf "tiled-state" true)
    (leaf "draw-border-with-background" false)
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = rgbaApps.terminals; })
    (leaf "match" { app-id = rgbaApps.fileManagers; })
    (leaf "match" { app-id = rgbaApps.chats; })
    (leaf "match" { app-id = rgbaApps.editors; })
    (leaf "match" { app-id = rgbaApps.mediaPlayers; })
    (leaf "match" discordElectronMatch)
    (leaf "opacity" 0.90)
    (leaf "draw-border-with-background" false)
    (plain "background-effect" [
      (leaf "blur" true)
      (leaf "xray" false)
    ])
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = rgbaApps.terminals; is-focused = true; })
    (leaf "match" { app-id = rgbaApps.fileManagers; is-focused = true; })
    (leaf "match" { app-id = rgbaApps.chats; is-focused = true; })
    (leaf "match" { app-id = rgbaApps.editors; is-focused = true; })
    (leaf "match" { app-id = rgbaApps.mediaPlayers; is-focused = true; })
    (leaf "match" (discordElectronMatch // { is-focused = true; }))
    (leaf "opacity" 0.96)
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = "^(Awakened PoE Trade|awakened-poe-trade)$"; })
    (leaf "open-floating" true)
    (leaf "draw-border-with-background" false)
    (plain "focus-ring" [
      (flag "off")
    ])
    (plain "border" [
      (flag "off")
    ])
    (plain "shadow" [
      (flag "off")
    ])
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = "^thunar$"; })
    (leaf "open-floating" true)
    (leaf "min-width" 450)
    (leaf "min-height" 225)
  ])

  (plain "window-rule" [
    (leaf "match" { app-id = "^steam$"; })
    (leaf "open-floating" true)
  ])

  (plain "window-rule" [
    (leaf "match" {
      app-id = "^steam$";
      title = "^Steam$";
    })
    (leaf "open-floating" false)
    (leaf "open-maximized" true)
  ])

  (if isTandesk then chatRule else null)

  (if isTandesk then spotifyRule else null)

]
