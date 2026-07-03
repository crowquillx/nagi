# 凪 nagi

Minimal multi-host NixOS flake with Home Manager, `nixpkgs-unstable`, Niri via `sodiboo/niri-flake`, Noctalia shell, SDDM, Stylix, fish + starship, NH, and `sops-nix`.

## Hosts

- `default`: generic VM-safe reference profile for new installs
- `tandesk`: physical desktop profile
- `tanlappy`: laptop profile with power/lid/battery defaults

The flake profile name and installed machine hostname are separate. For example, `default` can build a machine whose hostname is `alice-pc`.

## Layout

- `flake.nix`: parts-wrapped flake entrypoint via `flake-parts`
- `modules/flake/*`: host registry, external module injection, packages, and outputs
- `modules/combined/stacks.nix`: shared NixOS and Home Manager stack wiring
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

Bootstrap writes those values into `hosts/<profile>/variables.nix`, generates hardware config when needed, runs `nixos-rebuild`, and activates Home Manager for the primary user.

## tcli

`tcli` is installed via Home Manager and is the recommended day-to-day command for this repo. It handles system rebuilds through `nh os`; Home Manager is applied through the NixOS `home-manager` module.

Commands:

- `tcli` defaults to `switch` on the current host
- `tcli rebuild [switch|build|test|boot] [host]`
- `tcli update [host]`
- `tcli gc`
- `tcli nh home [switch|build] [host]`
- `tcli check`

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

## Documentation

- Host variable reference: `docs/VARIABLES.md`
- `tcli` behavior: `docs/TCLI.md`
- sops key and secret setup: `docs/SOPS.md`
- adding a host: `docs/NEW_HOST.md`
- flake-parts structure: `docs/DENDRITIC.md`
- secure boot setup: `docs/SECURE_BOOT.md`

## Notes

- `default` is intended as a buildable reference host, not a private machine profile.
- `hardware-configuration.nix` placeholders are overwritten by bootstrap when needed.
- The shared host data model is `config.nagi.variables`.
- This setup targets `nixpkgs-unstable`.
- Niri support is intentional; per-host monitor layout lives under `desktop.niri.outputs`.
