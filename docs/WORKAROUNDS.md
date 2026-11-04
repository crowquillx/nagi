# Compatibility Workarounds

Local compatibility logic is isolated in `lib/overlays/compatibility.nix`.
Ordinary package exposure lives in `lib/overlays/packages.nix`.

## Active workarounds

### Discord stable version pin

- Scope: hosts with `features.chat.client = "discord"`.
- Reason: Discord 1.0.166 advertises H.265 decode on Linux but cannot create
  the decoder (`Could not create any video decoder, format: H265`), so H.265
  Go Live streams fail with error 2012. The compatibility overlay builds
  `discord` from the 1.0.167 distro manifest in
  `lib/overlays/discord-stable-source.json`, generated the same way as
  nixpkgs' `discord/update.py`.
- The override is skipped once the pinned nixpkgs ships that version or newer;
  remove it then.

### Equicord notification sounds

- Scope: hosts with `features.chat.discord.equicord.enable`.
- Reason: Equicord 2026-09-03 has an outdated `AudioPlayerAPI` patch. Discord
  rejects part of the patch, leaving sound calls with a missing filename.
  Deafen, mute, and call sounds fail with `Cannot find module './undefined.mp3'`.
- The compatibility overlay backports the
  [upstream October 5 fix](https://github.com/Equicord/Equicord/commit/c5fb124e496bdc364deb28eb026e29422d35bd19).
- Remove when the pinned Equicord includes that fix. The patch is skipped for
  package versions dated 2026-10-05 or later.

### Hydra Proton launcher

- Scope: gaming hosts using `hydralauncher`.
- Reason: Hydra's bundled `umu-run` needs Python, which the upstream AppImage
  environment omits. UMU exits with code 127, and Hydra falls back to system
  Wine instead of the selected Proton version. The compatibility overlay adds
  Python to Hydra's application environment.
- Remove when the pinned nixpkgs package provides Python for `umu-run`.

### Noctalia generated color files

Noctalia owns runtime colors, but its built-in GTK, Qt, Ghostty, Kitty, and
Starship templates can rewrite Home Manager's primary configuration files.
The repository therefore enables only the `kcolorscheme` and `umbriel`
built-ins. It installs Noctalia user templates without hooks and points them
at generated files under `~/.config`. GTK CSS imports, Qt color-scheme
selection, Ghostty's `theme`, and Kitty's `include` remain declarative in Home
Manager. The Noctalia launcher normalizes `NOCTALIA_CONFIG_HOME` to the XDG
configuration directory so Umbriel's legacy private shell path cannot bypass
these settings. It leaves `NOCTALIA_STATE_HOME` unchanged so Umbriel's mutable
shell state and plugins remain in place. Starship continues to use the static
Rose Pine preset.

Home Manager's GTK module writes `gtk.css` and `settings.ini` as Nix store
symlinks. Flatpak can bind-mount `xdg-config/gtk-{3,4}.0` but cannot follow
those targets, so activation copies them to regular files. GTK 4 is not given
an `adw-gtk3` theme directory; that would inject a `file:///nix/store` CSS
import that sandboxes cannot read and that blocks Noctalia's GTK 4 colors.
`features.flatpak.enable` installs the `adw-gtk3` GTK 3 theme runtimes and
grants those config directories plus `xdg-data/color-schemes` to every
Flatpak.

### Noctalia Greeter version compatibility

The greeter package comes from its pinned upstream flake and builds against the
repository's nixpkgs input. Its declarative module owns `greeter.toml`, while
`sync.toml` remains mutable. The pinned greeter (1.5.0+) and Noctalia (5.1.0+)
provide the constrained `--sync` interface, so the primary user gets
passwordless appearance sync via `passwordless-sync-users`; anything outside
that narrow action still requires administrator authentication. Automatic shell
sync remains off. The greeter still exposes the Umbriel session and uses the
existing explicit cursor package.

### Noctalia shell package

`programs.noctalia.package` uses the `noctalia` flake input (`cachix` branch)
instead of the nixpkgs release. Noctalia talks to Umbriel over its IPC socket,
and Umbriel changes that protocol without compatibility shims (for example the
typed action requests that replaced `{"cmd":"msg"}`). Update the `umbriel` and
`noctalia` inputs together.

### patool test skips

- Scope: gaming hosts using `python314Packages.patool` through Bottles.
- Reason: the pinned package's MIME detection changes leave several upstream
  list helpers unavailable for the resulting archive format.
- Remove when the pinned package builds without the local disabled-test list.
- Track: [patool issue #194](https://github.com/wummel/patool/issues/194) and
  [nixpkgs issue #540025](https://github.com/NixOS/nixpkgs/issues/540025).

### Cheat Engine archive and capability wrapper

- Scope: hosts with `features.gaming.cheatengine.enable`.
- Reason: the live archive layout is mutable and the NixOS capability wrapper
  strips `LD_LIBRARY_PATH`; the ELF therefore receives a final `DT_RPATH`.
- Remove when the upstream flake packages the current archive and runtime
  libraries resolve through `/run/wrappers/bin/cheatengine-bin`.

### openrazer module certificates

- Scope: hosts with `features.razer.openrazer.enable` (kernel modules aggregation).
- Reason: nixos-unstable signs out-of-tree modules with kmodigest and the
  `*-modules` aggregation concatenates every `.ko.cer` into `modules.cer`.
  openrazer's custom `installPhase` copies only `driver/*.ko`, dropping the
  generated certificates, so the build fails with missing
  `razerkbd.ko.cer` (and siblings) errors. The compatibility overlay installs
  the certificates alongside the modules.
- Remove when upstream openrazer installs `.cer` files itself.

### arctis-sound-manager wrapper arguments

- Scope: hosts with `features.audio.arctis.enable`.
- Reason: the upstream package sets `makeWrapperArgs` as one Nix string per
  flag (`"--prefix QT_PLUGIN_PATH : <dirs>"`). With `__structuredAttrs`
  those stay whole array elements, and `wrapPythonPrograms` hands each to
  `makeShellWrapper` as a single argument, which dies with
  "makeWrapper doesn't understand the arg --prefix ...". The compatibility
  overlay splits every entry on spaces (exact: store paths contain no
  spaces). The service is pinned to the overlay build because the flake
  module defaults to its own unpatched `self.packages` output.
- Remove when upstream lists one token per `makeWrapperArgs` element.

### mcp-nixos on mcp 1.x

- Scope: hosts with `features.mcp.nixos.enable`.
- Reason: nixpkgs moved `python3Packages.mcp` to 2.x and marks `fastmcp-slim`
  broken against it, so `mcp-nixos` refuses to evaluate.
- The compatibility overlay builds `mcp-nixos` with `mcp = mcp_1`.
- Remove when `fastmcp-slim` is no longer marked broken with the default `mcp`.

### llm-agents overlay fallback

Older `llm-agents.nix` revisions expose packages without `overlays.default`.
The compatibility overlay preserves the `pkgs.llm-agents` namespace while
retaining the upstream package and cache pin. Remove it when all supported
revisions expose the standard overlay.

## Intentional independent input pins

- T3 Code uses `pkgs.llm-agents.t3code` for both the CLI and the desktop. The
  wrapper injects the shared provider packages and aliases the old nightly
  OSCrypt key onto the stable app name.
- `nix-gaming` and `llm-agents` retain their upstream nixpkgs pins for tested
  package sets and cache compatibility.
- Other independent transitive nixpkgs nodes remain unchanged unless the
  package/cache audit proves that a `follows` edge is safe.

The `mcp-nixos` `test_read_text_file` skip was removed after the pinned 3.0.0
package fixed the assertion.
