# Compatibility Workarounds

Local compatibility logic is isolated in `lib/overlays/compatibility.nix`.
Ordinary package exposure lives in `lib/overlays/packages.nix`.

## Active workarounds

### Hydra Proton launcher

- Scope: gaming hosts using `hydralauncher`.
- Reason: Hydra's bundled `umu-run` needs Python, which the upstream AppImage
  environment omits. UMU exits with code 127, and Hydra falls back to system
  Wine instead of the selected Proton version. The compatibility overlay adds
  Python to Hydra's application environment.
- Remove when the pinned nixpkgs package provides Python for `umu-run`.

### Millennium bun-deps hash

- Scope: hosts with `features.gaming.steam.millennium.enable`.
- Reason: the upstream `millennium-typescript-bun-deps` fixed-output hash is
  stale. `bun install` produces a different output for the pinned source even
  on upstream's own nixpkgs pin. The overlay passes upstream's `millennium.nix`
  a `stdenv` that replaces only that derivation's `outputHash`.
- Remove when upstream `packages/nix/millennium.nix` ships the new hash.

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

### llm-agents overlay fallback

Older `llm-agents.nix` revisions expose packages without `overlays.default`.
The compatibility overlay preserves the `pkgs.llm-agents` namespace while
retaining the upstream package and cache pin. Remove it when all supported
revisions expose the standard overlay.

## Intentional independent input pins

- T3 Code uses `pkgs.llm-agents.t3code` for the optional CLI and the separately
  pinned `t3code-nightly-nix` AppImage for the desktop. The wrapper preserves
  the shared provider packages and OSCrypt alias.
- `nix-gaming` and `llm-agents` retain their upstream nixpkgs pins for tested
  package sets and cache compatibility.
- Other independent transitive nixpkgs nodes remain unchanged unless the
  package/cache audit proves that a `follows` edge is safe.

The `mcp-nixos` `test_read_text_file` skip was removed after the pinned 3.0.0
package fixed the assertion.
