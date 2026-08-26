# Host Variables Reference

Primary host configuration is composed from the ordered fragments in
`lib/host-registry.nix`. A host normally uses `hosts/<host>/variables.nix` and
`hosts/<host>/advanced.nix`; closely related hosts may place a shared profile
such as `hosts/profiles/tan-common.nix` first.

- `variables.nix` is for core host identity, boot, graphics, desktop/session,
  users, core maintenance toggles, and security settings.
- `advanced.nix` is for niche or optional feature toggles such as chat,
  coding tools, Flatpak, gaming, virtualisation, AI, MCP, LocalSend, Mullvad,
  terminals, theme extras, portals, Tailscale, laptop extras, printing,
  Bluetooth, networking, and service toggles.

The files are merged into the same `config.nagi.variables` attrset before
modules consume them. Later fragments override earlier fragments for duplicate
scalar values. This is still `lib.recursiveUpdate`, so lists replace rather
than append.

The schema entrypoint is `hosts/common/variables-schema.nix`; domain modules
live under `hosts/common/variables-schema/`. This document covers the examples
and operational behavior that the option definitions alone do not show.

## Key switches

- `host.stateVersion = { nixos = "25.05"; home = "25.05"; }` (host-specific migration baselines; copy existing values and do not casually upgrade them)
- `desktop.compositor = "hyprland" | "plasma" | "niri"` (default session selected by SDDM; default is `hyprland`. Niri uses the stable package from host `nixpkgs`.)
- `desktop.extraCompositors = [ "hyprland" "plasma" "niri" ... ]` (optional additional installed sessions)
- `desktop.displayManager = "auto" | "sddm"`
- `desktop.sddm.wayland.enable = true | false`
- `desktop.sddm.background = <path> | null` (SDDM astronaut theme background image; uses the embedded theme default when `null`)
- `desktop.browser.default = "zen" | "helium" | "mullvadBrowser"`
- `desktop.browser.<name>.enable = true | false` for `zen`, `helium`, and `mullvadBrowser`
- `desktop.browser.brave.passwordStore = "auto" | "gnome-libsecret" | "kwallet6" | "basic"` (`gnome-libsecret` provides one encrypted credential store across Plasma and Niri)
- `desktop.niri.configBuilder` (primary; default KDL builder at `modules/home/desktop/niri/default.nix`; set `null` for the settings attrset path)
- `desktop.niri.outputs = { "<output-name>" = { scale, position = { x, y; }, mode = { width, height, refresh; }, focusAtStartup, transform = { rotation, flipped; }, variableRefreshRate }; ... }` (additive; consumed by the default configBuilder)
- `desktop.niri.settings = { ... }` (additive; applied only when `configBuilder = null`)
- `desktop.hyprland.configBuilder` (primary; default Lua builder at `modules/home/desktop/hyprland/default.nix`; set `null` for the upstream Home Manager settings path)
- `desktop.hyprland.outputs = { "<output-name>" = { scale, position, mode, transform, variableRefreshRate, workspaceBase, bitDepth, colorManagement, sdrBrightness, sdrSaturation, sdrMaxLuminance, focusAtStartup }; ... }`
- `desktop.hyprland.settings = { ... }` (applied only when `configBuilder = null`)
- `desktop.noctalia = { enable, command, settings, assistantPanel.secrets }`
- `desktop.hushmic.deviceId = "<pipewire-node.name>" | null` (host-scoped; enables `nagi-hushmic-tray`)
- `desktop.hdrGame = { enable, monitor = { uuid, model, serial, fallbackConnector }, notifications.enable }` (enables the `hdr-game` wrapper)
- `graphics.profile = "auto" | "none" | "amd" | "intel" | "nvidia" | "vm"`
- `graphics.enable32Bit = true | false`
- `graphics.nvidia = { modesetting.enable, powerManagement.enable, open, nvidiaSettings, useLatestDriver }`
- `graphics.extraPackages = [ "pkgAttr.path" ... ]`
- `storage.mounts = [ { device, mountPoint, fsType ? "auto", options ? [ ] } ... ]`
- `boot.secureBoot = { enable, includeMicrosoftKeys, autoEnroll, pkiBundle }` (Lanzaboote-based secure boot)
- `desktop.shellStartupCommand = "<command>"`
- `desktop.startup.backend = "systemd" | "niri" | "hyprland"`
- `desktop.startup.apps = [ "<cmd>" ... ]`
- `desktop.session.killProcessesOnLogout = true | false` (ends unmanaged session processes on logout; also terminates `tmux`, `screen`, `nohup`, and similar jobs from that session)
- `desktop.session.polkit.enable = true | false`
- `desktop.session.keyring.enable = true | false` (unlocks gnome-keyring at login. On Plasma, `ksecretd` owns `org.freedesktop.secrets`; run `nagi-migrate-secrets-to-kwallet` once so Electron/libsecret clients such as T3 Code and Brave keep using credentials created under Hyprland/Niri. Plasma also unlocks KWallet from the SDDM login password via PAM; the wallet password must match the login password, or be empty.)
- `desktop.session.lock = { enable, command, idleSeconds, beforeSleep, onLidClose }` (Idle lock is `swayidle` except on Noctalia Niri/Hyprland hosts and on Plasma-only hosts. Plasma uses PowerDevil and the screen locker, which honor video idle inhibitors; `swayidle` does not.)
- `users.git = { name, email }`
- `users.flakeDirectory = "<absolute-path>" | null` (defaults to `/home/<primary>/nagi` when `null`)
- `users.extraPackages = [ "pkgName" "python3Packages.pip" ... ]`
- `desktop.enable = true | false`
- `features.stylix = { enable, variant }` (On pure Plasma hosts Stylix stays on for anything Plasma does not theme — Ghostty, Kitty, browsers, CLI tools, and so on. Targets Plasma already owns (`gtk`, `qt`, `kde`, `gnome`, `fontconfig`) are disabled so Klassy/Breeze/Plasma fonts keep the desktop chrome. `variant` still selects Rose Pine Moon/Main/Dawn for SDDM and the Plasma color scheme. Mixed hosts keep those desktop targets for the Niri/Hyprland session; see `modules/theme/stylix-enabled.nix`.)
- `features.shell = { fish.enable, zsh.enable, starship.enable }`
- `features.nh = { enable, clean.enable, clean.extraArgs }`
- `features.swap = { zram.enable, zram.memoryPercent, disk.enable, disk.path, disk.sizeMiB, swappiness }`
- `features.nixMaintenance = { gc.enable, gc.dates, gc.options, optimise.enable, optimise.dates }`
- `features.chat = { client = "none" | "discord" | "equibop"; startup.enable; discord.forceXwayland; discord.equicord.enable }`
- `features.localsend = { package.enable, openFirewall }`
- `features.mullvad = { package = "none" | "cli" | "gui"; service = { enable, allowLan }; }`
- `features.terminals.default = "alacritty" | "foot" | "ghostty" | "kitty"`
- `features.terminals.<name>.enable = true | false` for `alacritty`, `foot`, `ghostty`, and `kitty`
- `features.videoEditing.kdenlive.enable = true | false`
- `features.videoEditing.davinciResolve = { enable, edition = "free" | "studio" }`
- `features.theme.gtk = { enable, iconTheme.name, iconTheme.package }` (Widget theme is `adw-gtk3` when Niri or Hyprland is installed, `Breeze` on Plasma-only hosts so kde-gtk-config can export Plasma colors. `Breeze-Dark` is a static palette and is not used. Icon theme is unchanged.)
- `features.theme.qt.enable = true | false`
- `features.zoxide.enable = true | false`
- `features.bluetooth.enable = true | false` (enables BlueZ. Niri/Hyprland get Blueman; Plasma uses bluedevil and does not autostart Blueman)
- `features.portals.enable = true | false`
- `features.codingTools.enable = true | false`
- `features.codingTools.editors.enable = true | false`
- `features.codingTools.editors.<name>.enable = true | false` for `t3code`, `cursor`, and `zed`
- `features.codingTools.orca.enable = true | false`
- `features.codingTools.paseo.enable = true | false` (Paseo desktop from llm-agents.nix)
- `features.codingTools.aiCli.enable = true | false`
- `features.codingTools.aiCli.codex.enable = true | false`
- `features.codingTools.aiCli.claude.enable = true | false`
- `features.codingTools.aiCli.cliProxyApi.enable = true | false`
- `features.codingTools.aiCli.opencode.enable = true | false`
- `features.codingTools.aiCli.opencode2.enable = true | false` (OpenCode 2 beta; installs the `opencode2` command alongside v1's `opencode`)
- `features.codingTools.aiCli.gemini.enable = true | false`
- `features.codingTools.aiCli.grok.enable = true | false`
- `features.codingTools.aiCli.pi.enable = true | false`
- `features.codingTools.aiCli.ohMyPi.enable = true | false`
- `features.codingTools.aiCli.herdr.enable = true | false`
- `features.codingTools.aiCli.primeAgent.enable = true | false` (Prime Agent from llm-agents.nix)
- `features.codingTools.nixTools.enable = true | false`
- `features.codingTools.repoSync = { enable, directory, remoteHost, remotePublicKey, remoteUser, remoteName, mirrorDirectory, interval, repositories }`
  - `repositories = [ { path = "/absolute/worktree"; autoCheckpoint = true; } ]` adds repositories outside the scanned directory.
  - Synchronizes committed branches through private bare repositories on the remote host.
  - Auto-checkpoint repositories preserve dirty tracked and untracked, nonignored files under private `refs/nagi/checkpoints/<host>` refs without moving `HEAD` or changing the real Git index.
  - A clean peer restores a compatible checkpoint as uncommitted work. Dirty peers and mismatched bases are never overwritten.
  - Checkpointing refuses obvious private-key material and plaintext YAML under `secrets/`.
- `features.mcp.nixos.enable = true | false`
- `features.tailscale = { enable, acceptDns, exitNode }`
- `features.ssh = { enable, openFirewall, port, passwordAuthentication, permitRootLogin, authorizedKeys, autoTmux }`
  - `enable` (bool, default `false`): enable the OpenSSH daemon. Keep disabled until `authorizedKeys` are set.
  - `openFirewall` (bool, default `true`): open the SSH port in the firewall.
  - `port` (int 1–65535, default `22`): the SSH listen port.
  - `passwordAuthentication` (bool, default `false`): allow password auth. Keep `false` for key-only mode. An assertion forbids enabling SSH with `passwordAuthentication = false` unless `authorizedKeys` is non-empty (lockout guard).
  - `permitRootLogin` (one of `prohibit-password`, `without-password`, `forced-commands-only`, `no`; default `prohibit-password`): root login policy. `yes` is never allowed (root stays no less restrictive than the NixOS default).
  - `authorizedKeys` (list of non-empty string public keys, default `[]`): authorized for the primary user. Required when `passwordAuthentication = false`.
  - `autoTmux.enable` (bool, default `false`): attach interactive SSH logins to a persistent tmux session. Enables user lingering and runs the tmux server as a user service so disconnects and logout cleanup do not terminate work.
  - `autoTmux.sessionName` (letters, digits, `_`, or `-`; default `"ssh"`): shared tmux session name.
- `features.fileManager.thunar.enable = true | false`
- `features.services = { fstrim.enable, resolved.enable, powerProfilesDaemon.enable }`
- `features.flatpak = { enable, packages = [ "<app-id>" ... ] }`
- `features.gaming = { enable, steam.gamescopeSession.enable, steam.remotePlay.openFirewall, steam.dedicatedServer.openFirewall, steam.localNetworkGameTransfers.openFirewall, cheatengine.enable, pcsx2.enable, gamemode.enable }`
- `features.virtualisation.vmHost = { enable, spiceUSBRedirection.enable }`
- `features.virtualisation.containers = { podman.enable, docker.enable }`
- `features.laptop.enable = true | false`
- `features.laptop.tlp.enable = true | false`
- `features.laptop.thermald.enable = true | false`
- `features.laptop.upower.enable = true | false`
- `features.laptop.powertop.enable = true | false`
- `features.laptop.fwupd.enable = true | false`
- `features.laptop.logind = { lidSwitch, lidSwitchExternalPower, lidSwitchDocked }`
- `security.sops.enable = true | false`
- `security.sops.defaultSopsFile = "<path>"` (defaults to `null`; required when `enable = true`)
- `security.sops.ageKeyFile = "<path>"` (defaults to `/var/lib/sops-nix/key.txt`)
- `security.sops.agePublicKey = "<age-pubkey>"` (defaults to `null`; optional. The host's age *public* key, reserved for future per-host `.sops.yaml` templating. Setting it does not change runtime decryption — see `docs/SOPS.md` for the manual per-host recipient migration.)
- `security.sops.gnupgHome = "<path>"` (defaults to `null`; set to a GnuPG home containing a PGP key, e.g. on a Yubikey, to enable PGP/Yubikey decryption alongside age)
- `security.sops.gnupgPublicKey = "<path>"` (defaults to `null`; path to the ASCII-armored PGP public key that `sops-gnupg.nix` imports into `gnupgHome` at activation. Note: `gnupgHome` and `ageKeyFile` are mutually exclusive in sops-nix; this only applies when `gnupgHome` is set)
- `security.sops.administrativeGroup = "<group>"` (defaults to `null`. If set, creates the group, adds the primary user to it, and chown's the age key file to `root:<group>` with mode 0640. Lets `sops` CLI read the key without sudo or a `/tmp` copy.)
- `security.yubikey.enable = true | false` (enables `services.pcscd` + yubikey-manager udev rules; required for any Yubikey-based sops PGP decrypt or sops CLI gpg-agent use)
- `home.security.yubikey.pgpPublicKey = "<path>"` (HM-side: path to the PGP public key to import into `~/.gnupg` at HM activation. Works alongside `security.yubikey.enable = true` regardless of sops runtime source)
- `security.sops.sshKey.enable = true | false` (materialize the user's SSH key from sops at boot)
- `security.sops.sshKey.name = "<sops-file-key>"` (default `"ssh_key"`)
- `security.sops.sshKey.pubName = "<sops-file-key>"` (default `"ssh_key_pub"`)
- `security.sops.sshKey.privateMode = "0600"` (octal mode for the materialized private key)
- `security.sops.sshKey.publicMode = "0644"` (octal mode for the materialized public key)
- `security.sops.signingKey.enable = true | false` (materialize an SSH commit-signing key from sops; enables git SSH signing)
- `security.sops.signingKey.name = "<sops-file-key>"` (default `"ssh_signing_key"`)
- `security.sops.signingKey.pubName = "<sops-file-key>"` (default `"ssh_signing_key_pub"`)
- `security.sops.signingKey.privateMode = "0600"` (octal mode for the materialized private signing key)
- `security.sops.signingKey.publicMode = "0644"` (octal mode for the materialized public signing key)

## Common snippets

### Stylix (Rose Pine)

```nix
features.stylix = {
  enable = true;
  variant = "moon";
};
```

### Persistent storage mount

```nix
storage.mounts = [
  {
    device = "/dev/disk/by-uuid/a93a28c3-8538-45f9-9031-1d740a0993f1";
    mountPoint = "/mnt/games";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  }
];
```

### Shell + Starship + zoxide

```nix
features = {
  shell = {
    fish.enable = false;
    zsh.enable = true;
    starship.enable = true;
  };
  zoxide.enable = true;
};
```

Fish and Zsh are mutually exclusive. Disable both to use Bash as the login shell.

### Desktop startup apps

```nix
desktop.startup = {
  backend = "systemd";
  apps = [
    "wl-paste --watch cliphist store"
    "spotify"
  ];
};
```

`backend = "systemd"` manages the apps as Home Manager user services under `wayland.systemd.target`, which means they can be restarted during `rebuild switch`.

For Niri hosts, use:

```nix
desktop.startup = {
  backend = "niri";
  apps = [
    "spotify"
  ];
};
```

This uses Niri `spawn-at-startup`, so the apps start when the session starts but are not bounced by Home Manager user-service reloads during rebuilds.
Hyprland hosts can use `backend = "hyprland"` for the equivalent `hyprland.start` hook. Use `features.chat.startup.enable` to start the selected chat client instead of adding it directly to `desktop.startup.apps`.

### Chat client and Niri mute

```nix
features.chat = {
  client = "discord";
  startup.enable = true;
  discord = {
    forceXwayland = true;
    equicord = {
      enable = false;
    };
  };
};
```

`client = "discord"` installs the official Discord package and binds `MouseForward` in Niri to a PipeWire microphone mute toggle using `wpctl`. This mutes the default microphone source system-wide, so Discord's in-app mute indicator may not change. `discord.forceXwayland = true` wraps Discord so its keybind recorder can receive focused key events under Niri if you still want to configure Discord keybinds. `discord.equicord.enable = true` patches the official Discord package with Equicord at build time; Equicord does not provide a runnable `equicord` binary. `client = "equibop"` installs Equibop and uses `equibop --toggle-mic` for the same Niri bind; Equicord is rejected with Equibop. If no chat client is selected but `users.extraPackages` contains `equibop`, the Niri bind still uses Equibop's toggle-mic action.

### Niri extension contract

`desktop.niri` has one primary builder plus additive overrides:

1. **`configBuilder` (primary)** — function `{ lib, pkgs, vars, inputs } -> KDL config` written to `programs.niri.config`. Default: `modules/home/desktop/niri/default.nix`. Set to `null` to use the attrset settings path instead.
2. **`outputs` (additive)** — per-connector monitor layout. Always consumed by the default configBuilder via vars. On the settings path, merged as `settings.outputs`.
3. **`settings` (additive, settings-path only)** — opaque attrset for `programs.niri.settings` when `configBuilder = null`. Precedence: `settings` then `outputs` (outputs fully replace the `outputs` key).

```nix
desktop.niri = {
  outputs = {
    "eDP-1" = {
      scale = 2.0;
      focusAtStartup = true;
      position = {
        x = 0;
        y = 0;
      };
    };
  };
};
```

Use `niri msg outputs` from inside a running Niri session to discover the output names and supported modes.

### Hyprland extension contract

`desktop.hyprland` mirrors the Niri builder model while producing Hyprland's current Lua configuration:

1. **`configBuilder` (primary)** — function `{ lib, pkgs, vars, inputs } -> string` written to `wayland.windowManager.hyprland.extraConfig`. The default composes the scrolling layout, Niri-equivalent binds and rules, Noctalia integration, and host outputs.
2. **`outputs`** — per-connector monitor layout consumed by the default builder. `bitDepth = 10` plus `colorManagement = "auto"` enables wide-color output, while `colorManagement = "srgb"` provides an sRGB desktop; both retain Hyprland's fullscreen auto-HDR behavior. `sdrMaxLuminance` sets the SDR white level in nits while mapping SDR content to HDR. Set a unique `workspaceBase` per output to reserve 99 workspace IDs for that monitor while keeping `Mod+1` through `Mod+9` monitor-local; for example, bases `0`, `100`, and `200`.
3. **`settings` (settings-path only)** — freeform upstream Home Manager settings used when `configBuilder = null`.

The NixOS module owns the Hyprland and XDG portal packages; Home Manager owns `hyprland.lua`. Hyprnix is intentionally not used because it replaces Home Manager's maintained module and still targets the deprecated Hyprlang format.

```nix
desktop.hyprland.outputs."DP-1" = {
  mode = {
    width = 2560;
    height = 1440;
    refresh = 180.0;
  };
  position = {
    x = 0;
    y = 0;
  };
  variableRefreshRate = "on-demand";
  workspaceBase = 0;
  bitDepth = 10;
  colorManagement = "auto";
  focusAtStartup = true;
};
```

To bypass the KDL builder and drive upstream `programs.niri.settings` directly:

```nix
desktop.niri = {
  configBuilder = null;
  settings = {
    prefer-no-csd = true;
  };
  outputs = {
    "eDP-1" = {
      scale = 2.0;
    };
  };
};
```

### Select desktop sessions

Niri only:

```nix
desktop = {
  compositor = "niri";
  extraCompositors = [ ];
};
```

Hyprland only:

```nix
desktop = {
  compositor = "hyprland";
  extraCompositors = [ ];
};
```

Hyprland by default with Niri retained as a fallback:

```nix
desktop = {
  compositor = "hyprland";
  extraCompositors = [ "niri" ];
};
```

Plasma only:

```nix
desktop = {
  compositor = "plasma";
  extraCompositors = [ ];
};
```

Niri and Plasma, with Niri selected by default in SDDM:

```nix
desktop = {
  compositor = "niri";
  extraCompositors = [ "plasma" ];
};
```

To make Plasma the default while keeping Niri available, swap the two values:

```nix
desktop = {
  compositor = "plasma";
  extraCompositors = [ "niri" ];
};
```

When multiple sessions are installed, portal routing remains session-specific.
Niri uses the GNOME portal, Hyprland uses XDG Desktop Portal Hyprland, and
Plasma uses the KDE portal. Niri, Hyprland, and mixed Plasma hosts retain GTK
fallbacks. Plasma-only hosts do not install `xdg-desktop-portal-gtk`: that
backend SIGSEGVs at login when kde-gtk-config rewrites `gtk.css` (nixpkgs
[issue 523091](https://github.com/NixOS/nixpkgs/issues/523091)). Do not set
`XDG_CURRENT_DESKTOP` or `XDG_SESSION_DESKTOP` globally; SDDM sets the correct
desktop identity for the selected session.
When Niri and Plasma are both installed, Qt theming is session-scoped. The
login environment uses Plasma's native KDE integration with Breeze, while the
Niri config overrides its child processes to use Stylix's qtct/Kvantum theme.
Noctalia's `kcolorscheme` template additionally supplies KDE colors to KDE and
Kirigami applications opened under Niri. Plasma-only configurations use native
KDE integration, and Niri-only configurations use qtct/Kvantum directly.
GTK widget theming is user-global: Niri or Hyprland hosts (including mixed
Plasma) keep `adw-gtk3`, while Plasma-only hosts use the `Breeze` GTK theme
(not `Breeze-Dark`) so kde-gtk-config can write `colors.css` from the active
Plasma color scheme. Home Manager does not pin `gtk-3.0/gtk.css` or
`gtk-4.0/gtk.css` on those hosts; a store symlink would be replaced at login
and crash GTK3 file monitors. GTK 4 also ignores `gtk-theme-name` and would
otherwise keep a baked Breeze-Dark import. Icon theme selection is independent
of that split.
On Plasma-only hosts Stylix remains enabled (`autoEnable`) so anything
Plasma does not theme keeps the Rose Pine palette, but
`stylix.targets.{gtk,qt,kde,gnome,fontconfig}` are off so they do not fight
Klassy, Breeze, Plasma fonts, or write GNOME dconf. Mixed hosts leave those
desktop targets on for Niri/Hyprland.
Plasma sessions (default compositor or `extraCompositors`) also install
`pkgs.klassy`, Better Blur DX (`pkgs.kwin-effects-better-blur-dx`), and a
Rose Pine color scheme generated from `features.stylix.variant`. The scheme is
available in System Settings → Colors and is not applied automatically. Enable
Better Blur DX in System Settings → Desktop Effects and disable the stock Blur
effect. After a KWin upgrade, rebuild so the plugin matches the compositor.

### Hushmic tray

```nix
desktop.hushmic.deviceId = "alsa_input.usb-Blue_Microphones_Yeti_X_...";
desktop.startup.apps = [
  "spotify"
  "nagi-hushmic-tray"
];
```

When `deviceId` is set, Home Manager installs `nagi-hushmic-tray`, which waits for the StatusNotifier watcher and a stable PipeWire node before `exec hushmic --tray`. Keep the node name host-scoped; leave `deviceId = null` on hosts without this tray.

### HDR game wrapper

```nix
desktop.hdrGame = {
  enable = true;
  monitor = {
    uuid = "<stable KScreen UUID>";
    model = "Q27G3XMN";
    serial = "1APR3JA002499";
    fallbackConnector = "DP-3";
  };
  notifications.enable = true;
};
```

When enabled, Home Manager installs `hdr-game`, a Steam Launch Options wrapper (`hdr-game %command%`) that switches the designated display to HDR+WCG while the game runs and restores the previous display state afterwards. The output is identified by stable KScreen UUID first, then verified against live EDID model/serial, with an EDID-verified fallback connector as last resort. Concurrency is reference-counted under `flock` in `$XDG_RUNTIME_DIR/hdr-game`; use `hdr-game --status` / `--on` / `--off` / `--restore` for manual control and recovery after a SIGKILLed wrapper. Game-side variables such as `PROTON_ENABLE_HDR=1` pass through untouched.

### Noctalia shell

```nix
desktop.noctalia = {
  enable = true;
  command = "nagi-noctalia-shell";
  assistantPanel.secrets = {
    googleApiKey = "noctalia-ap-google-api-key";
  };
};
```

This enables Home Manager's current `programs.noctalia.*` module with
`systemd.enable = false`. Noctalia starts through the selected Niri or Hyprland
compositor startup hook. The module enables the `kcolorscheme` theme template
and uses `desktop.noctalia.command` (default `nagi-noctalia-shell`) for startup
and IPC keybinds.

Noctalia's GUI-managed `~/.local/state/noctalia/settings.toml` is applied after
the declarative config. If that file already contains
`theme.templates.builtin_ids`, enable `KColorScheme` once in Noctalia's theme
settings so the runtime override includes the template.

`desktop.noctalia.assistantPanel.secrets` names optional `sops-nix` secrets that are exposed to the plugin through its documented environment variables. Set only the ones you actually use:

- `NOCTALIA_AP_GOOGLE_API_KEY`
- `NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY`
- `NOCTALIA_AP_DEEPL_API_KEY`

#### Hyprland local workspaces plugin

When Hyprland is enabled and one or more `desktop.hyprland.outputs.*.workspaceBase`
values are set, nagi installs the `nagi/hyprland-local-workspaces` Noctalia bar
plugin and points the existing `workspaces` widget entry at it. Labels are
monitor-local (`globalId - workspaceBase` → `1–99`) while clicks and scrolls
dispatch the real global Hyprland IDs.

```nix
desktop.noctalia.hyprlandLocalWorkspaces = {
  # null (default) auto-enables when Hyprland + workspaceBase exist.
  # Set false to keep the built-in Noctalia workspaces widget.
  enable = null;
};
```

The plugin is installed under `~/.local/share/noctalia/plugins/` (Noctalia's
built-in local source) and does not patch or recompile the Noctalia package.

### NH

```nix
features.nh = {
  enable = true;
  clean = {
    enable = true;
    extraArgs = "--keep-since 4d --keep 3";
  };
};
```

NH cleanup remains the authoritative generation/store cleanup policy. Keep
`features.nixMaintenance.gc.enable = false` unless a host deliberately needs a
second cleanup scheduler. Store optimisation is separate: it deduplicates
identical store files but does not delete paths or generations. The default
uses scheduled optimisation instead of `nix.settings.auto-optimise-store`, so
optimisation work is not added to every store write.

### Swap and Nix maintenance

```nix
features = {
  swap = {
    zram = {
      enable = true;
      memoryPercent = 25;
    };
    disk = {
      enable = true;
      path = "/var/lib/swapfile";
      sizeMiB = 4096;
    };
    swappiness = 10;
  };

  nixMaintenance = {
    gc.enable = false; # NH clean owns cleanup.
    optimise = {
      enable = true;
      dates = "weekly";
    };
  };
};
```

Disk swap is explicit per host. Disable it for Btrfs layouts that do not
support a swap file at the selected path, or declare a suitable swap device in
the host hardware configuration. Hardware swap devices remain additive.

### LocalSend and Mullvad

```nix
features = {
  localsend = {
    package.enable = true;
    openFirewall = true;
  };

  mullvad = {
    package = "gui";
    service = {
      enable = true;
      allowLan = true;
    };
  };
};
```

LocalSend is installed through Home Manager; `openFirewall` independently owns
TCP and UDP port 53317. Mullvad `package = "cli"` installs `mullvad` without
starting the system daemon. The daemon requires `package = "gui"` and uses
the NixOS module's default daemon package with its GUI enabled, preventing both
package variants from being installed together.
Remove legacy `localsend`, `mullvad`, and `mullvad-vpn` entries from
`users.extraPackages` when migrating to these variables.

With `service.enable = true`, NixOS starts `services.mullvad-vpn` and enables
the official Mullvad GUI. Account login and tunnel control happen in the
Mullvad app (or `mullvad` CLI) after activation. `service.allowLan` owns the
app's local-network-sharing policy; enable it for libvirt networks such as
Whonix-External. This also permits access to other local subnets while Mullvad
is connected.

### Video editing

```nix
features.videoEditing = {
  kdenlive.enable = true;
  davinciResolve = {
    enable = false;
    edition = "free";
  };
};
```

Kdenlive is installed from `kdePackages.kdenlive`. DaVinci Resolve is installed
from the unfree `davinci-resolve` package for `edition = "free"` or
`davinci-resolve-studio` for `edition = "studio"`; this repo already enables
unfree packages globally.

### Flatpak

```nix
features.flatpak = {
  enable = true;
  packages = [
    "com.spotify.Client"
    "md.obsidian.Obsidian"
    {
      appId = "com.example.Bundle";
      bundle = {
        url = "https://example.com/App.flatpak";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
    }
  ];
};
```

Declared `features.flatpak.packages` entries are installed declaratively via `nix-flatpak`. Removing an entry converges the system-wide Flatpak set back to the declared list on the next rebuild.
Bundle declarations fetch and verify a standalone `.flatpak` file through Nix. Update both the URL and hash when moving to a new release; a hash mismatch fails the build.

### GTK / QT / Kitty

```nix
features = {
  terminals.kitty.enable = true;
  theme = {
    gtk = {
      enable = true;
      iconTheme = {
        name = "MoreWaita";
        package = "morewaita-icon-theme";
      };
    };
    qt.enable = true;
  };
};
```

### Steam

```nix
features.gaming = {
  enable = true;
  steam = {
    gamescopeSession.enable = false;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  gamemode.enable = true;
};
```

`features.gaming.gamemode.enable = true` installs GameMode (`gamemoderun`) and adds the primary user to the `gamemode` group. In Steam, set game launch options to `gamemoderun %command%`.

`features.gaming.pcsx2.enable = true` installs the PCSX2 emulator from nixpkgs (cached upstream; no Flatpak needed).

### Virtualization (VM host + containers)

```nix
features.virtualisation = {
  vmHost = {
    enable = false;
    spiceUSBRedirection.enable = true;
  };
  containers = {
    podman.enable = false;
    docker.enable = false;
  };
};
```

### SSH

```nix
features.ssh = {
  enable = true;
  openFirewall = true;          # keep port 22 open in the firewall
  port = 22;
  # Key-only mode: disable password + keyboard-interactive auth.
  # Requires a non-empty authorizedKeys (enforced by assertion).
  passwordAuthentication = false;
  permitRootLogin = "prohibit-password"; # "yes" is never allowed
  autoTmux = {
    enable = true;
    sessionName = "ssh";
  };
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
  ];
};
```

The SSH daemon is owned by `modules/nixos/services/ssh.nix` and is fully host-configurable. The lockout-guard assertion fails the build if `passwordAuthentication = false` is set without any `authorizedKeys`, so flipping to key-only is safe.

With `autoTmux.enable = true`, interactive SSH logins from clients such as Termius automatically attach to the named session. Fish and Bash both avoid nesting when already inside tmux, and non-interactive SSH commands, SFTP, and SCP are unaffected. The prefix is `Ctrl+A`; detach with `Ctrl+A`, then `D`. Reattach manually with `tmux-ssh attach-session -t ssh`, replacing `ssh` with `autoTmux.sessionName`.

The SSH tmux server uses a fixed absolute socket under `$XDG_RUNTIME_DIR/nagi-ssh.sock` so it stays consistent after reboot. Do not use bare `tmux` for these sessions; use `tmux-ssh` (or the automatic SSH attach).

### Firewall port reference

`modules/nixos/services/firewall.nix` pins `networking.firewall.enable = true` explicitly and documents every exposed port. No port is opened or closed by that module; each feature module owns its own ports.

| Host   | Port         | Proto          | Owner (variable)                                                |
|--------|--------------|----------------|-----------------------------------------------------------------|
| all    | 22           | tcp            | `features.ssh.openFirewall`                                     |
| all    | 41641        | udp            | `features.tailscale.enable` (`services.tailscale.openFirewall`) |
| tandesk| 27015        | tcp + udp      | `features.gaming.steam.dedicatedServer.openFirewall`            |
| tandesk| 27036        | tcp + udp      | `features.gaming.steam.remotePlay.openFirewall` + transfers     |
| tandesk| 27037        | tcp            | `features.gaming.steam.remotePlay.openFirewall`                 |
| tandesk| 27040        | tcp            | `features.gaming.steam.localNetworkGameTransfers.openFirewall`  |
| tandesk| 10400, 10401 | udp            | `features.gaming.steam.remotePlay.openFirewall`                 |
| tandesk| 27031–27035  | udp range      | `features.gaming.steam.remotePlay.openFirewall`                 |
| tandesk| 53317        | tcp + udp      | `features.localsend.openFirewall`                               |

Notes:

- Steam ports only take effect where `features.gaming.enable = true` (tandesk). On default/tanlappy gaming is disabled, so `features.gaming.steam.*.openFirewall` is inert and should be set `false` to reflect honest intent.
- The Mullvad daemon does not require a manually declared inbound firewall port.
- ollama, open-webui, and comfyui bind to `127.0.0.1` and open no firewall ports.
- ICMP echo (`allowPing`) is left at the NixOS default (`true`) for diagnostics; it is not a TCP/UDP port and can be tightened separately.
- No interface-scoped restrictions are used: NetworkManager connection names and Wi-Fi/Ethernet/VPN/Tailscale interfaces vary, so narrowing to a guessed interface name would break LAN features non-deterministically.

### Laptop defaults

```nix
features.laptop = {
  enable = true;
  upower.enable = true;
  tlp.enable = true;
  thermald.enable = true;
  powertop.enable = false;
  fwupd.enable = true;
  logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";
    lidSwitchDocked = "ignore";
  };
};
```

### Git identity

```nix
users.git = {
  name = "Tan User";
  email = "nagi.com";
};
```

Set both fields together, or leave both `null`.
