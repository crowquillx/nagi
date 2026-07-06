# Host Variables Reference

Primary host configuration is composed from `hosts/<host>/variables.nix` and
`hosts/<host>/advanced.nix`.

- `variables.nix` is for core host identity, boot, graphics, desktop/session,
  users, core maintenance toggles, and security settings.
- `advanced.nix` is for niche or optional feature toggles such as chat,
  coding tools, Flatpak, gaming, virtualisation, AI, MCP, LocalSend, Mullvad,
  terminals, theme extras, portals, Tailscale, laptop extras, printing,
  Bluetooth, networking, and service toggles.

The files are merged into the same `config.nagi.variables` attrset before
modules consume them. Later fragments override earlier fragments for duplicate
scalar values.

## Key switches

- `desktop.compositor = "niri" | "plasma"`
- `desktop.extraCompositors = [ "niri" "plasma" ... ]` (optional additional installed sessions; first login default still comes from `desktop.compositor`)
- `desktop.displayManager = "auto" | "sddm"`
- `desktop.sddm.wayland.enable = true | false`
- `desktop.sddm.background = <path> | null` (SDDM astronaut theme background image; uses the embedded theme default when `null`)
- `desktop.browser.default = "zen" | "helium" | "mullvadBrowser"`
- `desktop.browser.<name>.enable = true | false` for `zen`, `helium`, and `mullvadBrowser`
- `desktop.niri.outputs = { "<output-name>" = { scale, position = { x, y; }, mode = { width, height, refresh; }, focusAtStartup, transform = { rotation, flipped; }, variableRefreshRate }; ... }`
- `desktop.niri.settings = { ... }`
- `desktop.noctalia = { enable, command, systemd.enable, assistantPanel.secrets }`
- `graphics.profile = "auto" | "none" | "amd" | "intel" | "nvidia" | "vm"`
- `graphics.enable32Bit = true | false`
- `graphics.nvidia = { modesetting.enable, powerManagement.enable, open, nvidiaSettings, useLatestDriver }`
- `graphics.extraPackages = [ "pkgAttr.path" ... ]`
- `storage.mounts = [ { device, mountPoint, fsType ? "auto", options ? [ ] } ... ]`
- `boot.secureBoot = { enable, includeMicrosoftKeys, autoEnroll, pkiBundle }` (Lanzaboote-based secure boot)
- `desktop.shellStartupCommand = "<command>"`
- `desktop.startup.backend = "systemd" | "niri"`
- `desktop.startup.apps = [ "<cmd>" ... ]`
- `desktop.session.polkit.enable = true | false`
- `desktop.session.keyring.enable = true | false`
- `desktop.session.lock = { enable, command, idleSeconds, beforeSleep, onLidClose }`
- `users.git = { name, email }`
- `users.flakeDirectory = "<absolute-path>" | null` (defaults to `/home/<primary>/nagi` when `null`)
- `users.extraPackages = [ "pkgName" "python3Packages.pip" ... ]`
- `desktop.enable = true | false`
- `features.stylix = { enable, variant }`
- `features.shell = { fish.enable, starship.enable }`
- `features.nh = { enable, clean.enable, clean.extraArgs }`
- `features.swap = { zram.enable, zram.memoryPercent, disk.enable, disk.path, disk.sizeMiB, swappiness }`
- `features.nixMaintenance = { gc.enable, gc.dates, gc.options, optimise.enable, optimise.dates }`
- `features.chat = { client = "none" | "discord" | "equibop"; startup.enable; discord.forceXwayland; discord.equicord = { enable; startupDelaySeconds; } }`
- `features.localsend = { package.enable, openFirewall }`
- `features.mullvad = { package = "none" | "cli" | "gui"; service.enable }`
- `features.terminals.<name>.enable = true | false` for `alacritty`, `foot`, and `kitty`
- `features.theme.gtk = { enable, iconTheme.name, iconTheme.package }`
- `features.theme.qt.enable = true | false`
- `features.zoxide.enable = true | false`
- `features.bluetooth.enable = true | false`
- `features.portals.enable = true | false`
- `features.codingTools.enable = true | false`
- `features.codingTools.editors.enable = true | false`
- `features.codingTools.editors.<name>.enable = true | false` for `vscode`, `antigravity`, `t3code`, `cursor`, and `zed`
- `features.codingTools.aiCli.enable = true | false`
- `features.codingTools.aiCli.codex.enable = true | false`
- `features.codingTools.aiCli.opencode.enable = true | false`
- `features.codingTools.aiCli.gemini.enable = true | false`
- `features.codingTools.aiCli.droid.enable = true | false`
- `features.codingTools.nixTools.enable = true | false`
- `features.mcp.nixos.enable = true | false`
- `features.tailscale = { enable, acceptDns, exitNode }`
- `features.ssh = { enable, openFirewall, port, passwordAuthentication, permitRootLogin, authorizedKeys }`
  - `enable` (bool, default `true`): enable the OpenSSH daemon.
  - `openFirewall` (bool, default `true`): open the SSH port in the firewall.
  - `port` (int 1–65535, default `22`): the SSH listen port.
  - `passwordAuthentication` (bool, default `true`): allow password auth. **Set `false` for key-only mode.** An assertion forbids `false` unless `authorizedKeys` is non-empty (lockout guard).
  - `permitRootLogin` (one of `prohibit-password`, `without-password`, `forced-commands-only`, `no`; default `prohibit-password`): root login policy. `yes` is never allowed (root stays no less restrictive than the NixOS default).
  - `authorizedKeys` (list of non-empty string public keys, default `[]`): authorized for the primary user. Required when `passwordAuthentication = false`.
- `features.fileManager.thunar.enable = true | false`
- `features.services = { fstrim.enable, resolved.enable, powerProfilesDaemon.enable }`
- `features.flatpak = { enable, packages = [ "<app-id>" ... ] }`
- `features.gaming = { enable, steam.gamescopeSession.enable, steam.remotePlay.openFirewall, steam.dedicatedServer.openFirewall, steam.localNetworkGameTransfers.openFirewall }`
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

### Fish + starship + zoxide

```nix
features = {
  shell = {
    fish.enable = true;
    starship.enable = true;
  };
  zoxide.enable = true;
};
```

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
Use `features.chat.startup.enable` to start the selected chat client instead of adding it directly to `desktop.startup.apps`.

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

### Niri monitor configuration

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

  settings = {
    "prefer-no-csd" = true;
  };
};
```

Use `niri msg outputs` from inside a running Niri session to discover the output names and supported modes.

### Install both Niri and Plasma sessions

```nix
desktop = {
  # Default selected in SDDM.
  compositor = "niri";

  # Also install Plasma so both sessions are available at login.
  extraCompositors = [ "plasma" ];
};
```

### Noctalia shell

```nix
desktop.noctalia = {
  enable = true;
  command = "nagi-noctalia-shell";
  systemd.enable = false;
  assistantPanel.secrets = {
    googleApiKey = "noctalia-ap-google-api-key";
  };
};
```

This enables Home Manager's current `programs.noctalia.*` module. Only `enable` and `systemd.enable` are forwarded directly; `desktop.noctalia.command` is used by Niri startup and Noctalia IPC keybinds.
When `desktop.noctalia.command` is set to a wrapper such as `nagi-noctalia-shell`, Niri startup and keybinds use that command instead of plain `noctalia`.

`desktop.noctalia.assistantPanel.secrets` names optional `sops-nix` secrets that are exposed to the plugin through its documented environment variables. Set only the ones you actually use:

- `NOCTALIA_AP_GOOGLE_API_KEY`
- `NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY`
- `NOCTALIA_AP_DEEPL_API_KEY`

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
    service.enable = true;
  };
};
```

LocalSend is installed through Home Manager; `openFirewall` independently owns
TCP and UDP port 53317. Mullvad `package = "cli"` installs `mullvad` without
starting the system daemon. The daemon requires `package = "gui"` and uses
`mullvad-vpn`, preventing both package variants from being installed together.
Remove legacy `localsend`, `mullvad`, and `mullvad-vpn` entries from
`users.extraPackages` when migrating to these variables.

### Flatpak

```nix
features.flatpak = {
  enable = true;
  packages = [
    "com.spotify.Client"
    "md.obsidian.Obsidian"
  ];
};
```

Declared `features.flatpak.packages` entries are installed declaratively via `nix-flatpak`. Removing an entry converges the system-wide Flatpak set back to the declared list on the next rebuild.

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
};
```

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
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
  ];
};
```

The SSH daemon is owned by `modules/nixos/services/ssh.nix` and is fully host-configurable. The lockout-guard assertion fails the build if `passwordAuthentication = false` is set without any `authorizedKeys`, so flipping to key-only is safe.

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
