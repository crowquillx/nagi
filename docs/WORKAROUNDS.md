# Compatibility Workarounds

Local compatibility logic is isolated in `lib/overlays/compatibility.nix`.
Ordinary package exposure lives in `lib/overlays/packages.nix`.

## Active workarounds

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

### Noctalia Greeter version compatibility

The greeter package comes from its pinned upstream flake and builds against the
repository's nixpkgs input. Its declarative module owns `greeter.toml`, while
`sync.toml` remains mutable. Passwordless appearance
sync and automatic shell sync are intentionally disabled until the pinned
upstream version provides the required authenticated sync interface. The
greeter still exposes the Umbriel session and uses the existing explicit
cursor package.

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
