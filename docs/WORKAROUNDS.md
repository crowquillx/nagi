# Compatibility Workarounds

Local compatibility logic is isolated in `lib/overlays/compatibility.nix`.
Ordinary package exposure lives in `lib/overlays/packages.nix`.

## Active workarounds

### Plasma-only hosts omit xdg-desktop-portal-gtk

- Introduced: 2026-08-25
- Scope: Plasma-only hosts (`desktop.compositor = "plasma"` and no Niri/Hyprland extra session)
- Reason: `xdg-desktop-portal-gtk` 1.15.3 SIGSEGVs in `g_file_monitor_source_dispatch` a second after Plasma login, when kde-gtk-config replaces `~/.config/gtk-3.0/gtk.css`. DrKonqi reports it as a service crash. The KDE portal covers file choosers, settings, screenshots, and secrets.
- Mixed Niri/Hyprland+Plasma hosts still install the GTK portal (needed for those sessions) and delay it on KDE until `gtk.css` is a regular file.
- Remove when: nixpkgs ships a GTK portal/GLib that survives kde-gtk-config's rewrite
- Track: [nixpkgs issue #523091](https://github.com/NixOS/nixpkgs/issues/523091)


### patool test skips

- Introduced: 2026-07-17
- Scope: gaming hosts only, because Bottles consumes `python314Packages.patool`
- Reason: MIME detection changes make `.tar.*` fixtures look like their compression format, and several list helpers do not exist for that resulting format
- Remove when: the pinned nixpkgs `python314Packages.patool` builds without the local disabled-test list
- Track: [patool issue #194](https://github.com/wummel/patool/issues/194) and [nixpkgs issue #540025](https://github.com/NixOS/nixpkgs/issues/540025)

### Cheat Engine archive and capability-wrapper shim

- Introduced: 2026-07-17
- Scope: hosts with `features.gaming.cheatengine.enable`
- Reason: the live 7.71 download is mutable and can differ from the flake hash/layout; the NixOS capability wrapper also strips `LD_LIBRARY_PATH`, so the ELF needs a final `DT_RPATH`
- Remove when: `cheatengine-flake` packages the current archive and its executable still finds runtime libraries through `/run/wrappers/bin/cheatengine-bin`
- Track: [cheatengine-flake issue #1](https://github.com/Hy4ri/cheatengine-flake/issues/1), [archive-layout PR #3](https://github.com/Hy4ri/cheatengine-flake/pull/3), and subsequent upstream package changes

### llm-agents overlay fallback

- Introduced: 2026-07-17
- Scope: all hosts, preserving the `pkgs.llm-agents` namespace
- Reason: older revisions exposed packages without `overlays.default`; direct package reuse retains the upstream nixpkgs pin and binary-cache compatibility
- Remove when: all revisions this repository intends to support expose `overlays.default`
- Track: [llm-agents.nix overlay documentation](https://github.com/numtide/llm-agents.nix#using-overlay)

## Intentional independent input pins

- T3 Code uses `pkgs.llm-agents.t3code` (CLI) and its `desktop` output. The desktop binary is wrapped with `--no-sandbox --password-store=gnome-libsecret`. The connection catalog is Electron OSCrypt (`application=t3code` from the AppImage era, `application=T3 Code (Alpha)` from the current desktop `setName`). Grok is injected via `providerPackages` using the local `SHELL=/bin/sh` launcher so T3's `grok agent stdio` path does not use the stock grok wrapper. `t3 serve` is opt-in; the desktop app already embeds a server, and a second unit shares `~/.t3` and starts a second tunnel.
- Hyprland does not follow the root nixpkgs input. Its package, portal, and Hyprland libraries come from the upstream overlay together so their ABI and `hyprland.cachix.org` cache remain aligned.
- nix-gaming does not follow the root nixpkgs input. Packages are reused from its flake output to retain `nix-gaming.cachix.org` compatibility.
- llm-agents keeps its own nixpkgs pin. Upstream explicitly documents that this costs a second evaluation but preserves the tested package set and cache hits.
- Other independent transitive nixpkgs nodes were left unchanged after the input-graph audit; no `follows` was added without package/cache proof.

## Removed after verification

The `mcp-nixos` `test_read_text_file` skip was removed in this cleanup.
Upstream fixed the content assertion and closed [issue #198](https://github.com/utensils/mcp-nixos/issues/198); the pinned nixpkgs now provides 3.0.0, whose unmodified package was verified to build.

## Niri package/configuration split

Niri hosts use `pkgs.niri` from the root nixpkgs input, while
`sodiboo/niri-flake` supplies only `homeModules.config` and its KDL library.
This retains the repository's structured configuration without evaluating the
incompatible package overlay affected by
[sodiboo/niri-flake issue #1851](https://github.com/sodiboo/niri-flake/issues/1851).
Reconsider the split when the upstream package overlay builds against the
repository's nixpkgs pin without the removed `libdisplay-info_0_2`.
