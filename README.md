# 凪 nagi

Multi-host NixOS flake with integrated Home Manager. Sessions: Hyprland, Niri, or Plasma behind SDDM. Theming via Stylix, secrets via `sops-nix`, rebuilds via `tcli`/`nh`. Targets `nixpkgs-unstable` and Determinate Nix.

## Hosts

- `default`: generic VM-safe reference profile for new installs
- `tandesk`: physical desktop profile
- `tanlappy`: Niri laptop profile with power/lid/battery defaults

The flake profile name and installed machine hostname are separate. For example, `default` can build a machine whose hostname is `alice-pc`.

## Layout

- `flake.nix`: parts-wrapped flake entrypoint via `flake-parts`
- `modules/flake/*`: host registry, external module injection (including Determinate Nix), packages, and outputs
- `modules/combined/stacks.nix`: shared NixOS and Home Manager stack wiring
- `lib/host-registry.nix`: authoritative host profiles, platforms, entry modules, and ordered variable fragments
- `hosts/common/variables-schema/*`: typed `config.nagi.variables` schema by domain
- `hosts/profiles/*`: ordered variable fragments shared by selected hosts
- `hosts/<host>/variables.nix`: host identity, toggles, and values
- `hosts/<host>/default.nix`: host-specific system wiring
- `modules/nixos/*`: NixOS modules
- `modules/home/*`: Home Manager modules
- `users/default/home.nix`: generic primary-user Home Manager entrypoint

## Quick Start

This repo assumes base NixOS is already installed.

1. Clone this repo anywhere on the target machine.
2. Pick a profile: `default`, `tandesk`, or `tanlappy`.
3. Run bootstrap with your own user, hostname, and checkout path:

```bash
sudo ./install/bootstrap.sh default --user alice --hostname alice-pc --flake-dir /home/alice/nagi
```

Bootstrap validates the profile through `lib/host-registry.nix`, writes those values into `hosts/<profile>/variables.nix`, generates hardware config when needed, and activates the system plus integrated Home Manager through one `nixos-rebuild` path.

The standalone `homeConfigurations.<profile>` outputs remain available for manual recovery:

```bash
home-manager switch --flake .#default
```

## Determinate Nix and FlakeHub

Every NixOS host imports Determinate Systems' official NixOS module. It provides:

- Determinate Nix, including parallel evaluation and lazy trees
- `determinate-nixd` for daemon management and FlakeHub authentication
- `fh`, the FlakeHub CLI
- Determinate Nix compatibility for both integrated and standalone Home Manager

The flake keeps custom daemon settings in the declaratively generated `/etc/nix/nix.custom.conf`; Determinate Nixd owns `/etc/nix/nix.conf`. The Determinate installer is not used on NixOS.

Authenticate after activation when FlakeHub access is needed:

```bash
determinate-nixd login
determinate-nixd status
```

Common FlakeHub commands:

```bash
fh search "nixos"
fh add nixos/nixpkgs
```

## tcli

`tcli` is installed via Home Manager and is the recommended day-to-day command for this repo. It handles system rebuilds through `nh os`; Home Manager is applied through the NixOS `home-manager` module.

Commands:

- `tcli` defaults to `switch` on the current host
- `tcli rebuild [switch|build|test|boot] [host]`
- `tcli update [host]`
- `tcli gc`
- `tcli nh home [switch|build] [host]`
- `tcli check`
- `nix fmt -- --check`

Defaults:

- host defaults to current machine hostname
- flake path resolves from `NAGI_FLAKE_DIR`, current git root, current directory, then `$HOME/nagi`

## Core Commands

- Bootstrap with full system and Home Manager activation:
  - `sudo ./install/bootstrap.sh <profile> --user <user> --hostname <hostname> --flake-dir <absolute-path>`
- System build:
  - `sudo nixos-rebuild build --flake .#<profile>`
- System switch:
  - `sudo nixos-rebuild switch --flake .#<profile>`
- Home Manager only:
  - `home-manager switch --flake .#<profile>`

## Installing Apps

Most user-facing apps should be installed through Home Manager by adding package names to `users.extraPackages` in `hosts/<host>/variables.nix`.

```nix
users = {
  primary = "nagi";
  flakeDirectory = "/home/nagi/nagi";
  extraPackages = [
    "obsidian"
    "mpv"
    "python3Packages.ipython"
  ];
};
```

Package names resolve from `pkgs`, so nested attributes such as `"python3Packages.ipython"` work. Wrong package names fail evaluation with an assertion.

For Flatpak apps, use `features.flatpak.packages` in the host variables file:

```nix
features.flatpak = {
  enable = true;
  packages = [
    "com.spotify.Client"
    "md.obsidian.Obsidian"
  ];
};
```

## CI

Pull requests run a fast, unprivileged validation tier with Determinate Nix:

- Nix formatting, Statix, ShellCheck, and syntax parsing for every tracked Nix file
- focused tcli, repo-sync, orphan-scanner, and Codex Desktop transformation tests
- `nix flake check --no-build --accept-flake-config`, which evaluates every published NixOS and standalone Home Manager configuration

The workflow runs only for pull requests. Pushes to `main` and manual dispatches do not start CI.

## Updating local binary packages

MO2-LINT exposes `passthru.updateScript` and can be updated reproducibly with `nix-update`:

```bash
nix run nixpkgs#nix-update -- --flake mo2-lint
nix build .#mo2-lint
```

The T3 Code CLI comes from `llm-agents`. The desktop comes from the independently
pinned `t3code-nightly-nix` input, whose automation checks upstream every six
hours, validates the newest nightly AppImage, and publishes it to Cachix.
`tcli update` moves the local lock to the newest validated package revision.

## Documentation

- Host variable reference: `docs/VARIABLES.md`
- `tcli` behavior: `docs/TCLI.md`
- repository synchronization: `docs/REPO_SYNC.md`
- sops key and secret setup: `docs/SOPS.md`
- adding a host: `docs/NEW_HOST.md`
- flake-parts structure: `docs/DENDRITIC.md`
- secure boot setup: `docs/SECURE_BOOT.md`
- local compatibility patches and upstream trackers: `docs/WORKAROUNDS.md`

## Notes

- `default` is intended as a buildable reference host, not a private machine profile.
- `hardware-configuration.nix` placeholders are overwritten by bootstrap when needed.
- The shared host data model is `config.nagi.variables`.
- This setup targets `nixpkgs-unstable` and uses Determinate Nix as its only Nix distribution.
- Niri uses the compositor from host `nixpkgs` for Mesa/ABI alignment while `sodiboo/niri-flake` supplies only the KDL/Home Manager configuration API.
- Hyprland uses the native scrolling layout and Home Manager Lua config; per-host monitor, HDR, and monitor-local workspace ranges live under `desktop.hyprland.outputs`.
