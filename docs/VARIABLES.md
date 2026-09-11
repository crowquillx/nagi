# Host Variables Reference

Host variables are composed from the ordered fragments in
`lib/host-registry.nix`. Each host normally has `hosts/<host>/variables.nix`
and `hosts/<host>/advanced.nix`; shared values live in
`hosts/profiles/tan-common.nix`. The resulting attrset is exposed as
`config.nagi.variables` and validated by `hosts/common/variables-schema.nix`.

## Desktop

All registered hosts use the same desktop path:

```nix
desktop = {
  enable = true;
  compositor = "umbriel";
  sessionShell = "noctalia";
  noctalia = {
    command = "nagi-noctalia-shell";
    settings = { };
  };
};
```

`umbriel` is the only compositor and `noctalia` is the only session shell.
Noctalia Greeter supplies the greetd login session and starts Umbriel. The
greeter owns `/var/lib/noctalia-greeter/greeter.toml`; its mutable sync state
is not managed by Nix. `programs.umbriel.settings = null` deliberately leaves
`~/.config/umbriel/config.toml` writable for Umbriel. Noctalia reads its
Home Manager baseline from the standard XDG configuration directory.
Session applications belong in that file's native `[general].autostart` list.

The session options are:

- `desktop.session.enable`: enable session helpers.
- `desktop.session.polkit.enable`: retain the repository's Polkit policy and
  authentication support. Noctalia's agent is enabled by the shared shell
  module.
- `desktop.session.keyring.enable`: unlock gnome-keyring for applications that
  use the Secret Service API.
- `desktop.session.lock = { enable, command, idleSeconds, beforeSleep,
  onLidClose }`: configure Noctalia's lock command and lock policy.
- `desktop.shellStartupCommand`: optional command run with the session.

`desktop.browser.default` accepts `zen`, `helium`, or `mullvadBrowser`; each
browser has a matching `.enable` toggle. `desktop.hushmic.deviceId` selects a
PipeWire node for the HushMic tray.

## Static package and theme ownership

Nix remains the owner of packages, fonts, cursor packages, icon packages,
environment variables, and stable application settings. Set the default light
or dark application preference with:

```nix
features.theme = {
  variant = "moon"; # moon and main are dark; dawn is light
  gtk.enable = true;
  qt.enable = true;
};
```

Home Manager declares the GTK theme and icon theme, imports Noctalia's
generated `noctalia.css` for GTK 3/4, selects the generated `noctalia` Qt
color scheme, and selects the generated Noctalia themes for Ghostty and Kitty.
Noctalia is the runtime color owner. Its safe built-in templates are limited
to `kcolorscheme` and `umbriel`; user templates for GTK, Qt, Ghostty, and
Kitty have no mutating hooks. Starship keeps the repository's static Rose Pine
preset and is not a Noctalia built-in target. The Noctalia launcher uses the
standard XDG configuration directory even when a mutable Umbriel profile has
an older private `NOCTALIA_CONFIG_HOME`; it preserves Umbriel's separate
Noctalia state directory.

Other theme options are explicit and declarative:

- `features.theme.fonts`: package and font-family choices.
- `features.theme.cursor`: cursor package, name, and size.
- `features.theme.gtk.iconTheme`: icon package and name.
- `features.terminals.<name>`: terminal enablement and Kitty opacity.
- `features.shell`: Fish, Zsh, and Starship enablement.

## Common feature groups

- `graphics.profile`, `graphics.enable32Bit`, `graphics.nvidia`, and
  `graphics.extraPackages` control hardware graphics.
- `users.primary`, `users.flakeDirectory`, `users.extraPackages`, and
  `users.git` control the primary account and package inventory.
- `features.audio`, `features.bluetooth`, `features.portals`, `features.nh`,
  `features.swap`, and `features.nixMaintenance` control system services.
- `features.ssh` controls OpenSSH (port, auth policy, authorized keys) and its
  optional mosh companion at `features.ssh.mosh`; mosh requires
  `features.ssh.enable` and opens its UDP port range when
  `features.ssh.mosh.openFirewall` is true.
- `features.chat`, `features.localsend`, `features.mullvad`,
  `features.flatpak`, `features.gaming`, `features.virtualisation`, and
  `features.codingTools` enable optional applications and services.
- `features.videoEditing`, `features.blender`, and `features.ai` control
  optional creative and AI packages.

Use the schema modules as the authoritative option reference. Unknown options
are rejected by the strict submodules; package names in `users.extraPackages`
are resolved against `pkgs` and checked during evaluation.

## Adding or changing a host

1. Add or update the host's variable fragments.
2. Keep host-specific hardware in `hosts/<host>/hardware-configuration.nix`.
3. Register the host in `lib/host-registry.nix`.
4. Run `tcli rebuild build <host>` and the orphan-module check.

Build-only validation is preferred while editing. Do not use `switch`, `boot`,
or `test` as a substitute for evaluating the configuration.
