# Arch and NixOS unstable app update timing

Researched 2026-09-25. This note concerns app version availability on this repository's NixOS hosts. It does not estimate a universal time saving from changing distributions.

## What controls an update

An app reaches Arch's official repositories when an Arch maintainer packages and publishes it. Arch updates packages individually, but `core` packages require signoff and some `extra` updates pass through testing. Arch's FAQ says the delay from an upstream release depends on the package: it can be a few hours for a minor fix or several weeks for a large package group's major update. A chosen mirror may then take more than 24 hours to sync. [Arch official repositories](https://wiki.archlinux.org/title/Official_repositories), [Arch FAQ](https://wiki.archlinux.org/title/Frequently_asked_questions), [Arch mirrors](https://wiki.archlinux.org/title/Mirrors)

NixOS adds a different sequence. A maintainer first merges the version bump into Nixpkgs `master`. Hydra then builds and tests a snapshot before moving `nixos-unstable`. The `nixpkgs-unstable` branch follows the same `master` but has its own test job and can move at a different time. The Nixpkgs manual says both unstable branches generally trail `master` by a couple of days. A Nixpkgs merge date therefore does **not** show the date a user of `nixos-unstable` could update. Use the channel branch advancement and build availability to measure that date. [Nixpkgs manual](https://nixos.org/manual/nixpkgs/unstable/), [NixOS channel branches](https://wiki.nixos.org/wiki/Channel_branches), [NixOS channel status](https://status.nixos.org/)

This flake declares `github:NixOS/nixpkgs/nixos-unstable` as its main Nixpkgs input in [flake.nix](../../flake.nix). Nix pins that branch's commit in `flake.lock`; it does not follow the branch on each rebuild. `nix flake update` refreshes the lock. The documented [`tcli update`](../TCLI.md) command refreshes inputs and then switches the system. Thus the user's update schedule adds time after the package appears on `nixos-unstable`. The working tree's lock file was modified when this note was written, so it should not be treated as a fixed baseline for historical measurements. [Nix flakes](https://nix.dev/concepts/flakes.html), [`nix flake update` manual](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-update.html)

Arch has a similar user action after publication: `pacman -Syu` refreshes package lists and performs a full system upgrade. Arch does not support partial upgrades, and an out-of-sync mirror can delay what this command sees. [Arch system maintenance](https://wiki.archlinux.org/title/System_maintenance), [Arch FAQ](https://wiki.archlinux.org/title/Frequently_asked_questions)

## App sources in this repository

The main Nixpkgs input is only one path. [flake.nix](../../flake.nix) also declares dedicated inputs for Zen Browser, `llm-agents`, Vortex, HushMic, and others. Their updates depend on their own upstream flake revisions and this repo's lock file, so an Arch-versus-Nixpkgs comparison does not directly predict their timing. The [tandesk Flatpak declarations](../../hosts/tandesk/advanced.nix) include remote apps and a Cake Wallet bundle URL with a fixed version and hash. [Flatpak](https://docs.flatpak.org/en/latest/using-flatpak.html) updates remote apps through their Flatpak remotes; the fixed Cake Wallet bundle needs a declaration change to select another release. [nix-flatpak's update options](https://github.com/gmodena/nix-flatpak/blob/main/README.md) govern whether managed Flatpaks update on activation or on a timer.

The Arch User Repository is another path for apps absent from official repos. Its entries are user-maintained build recipes. Arch says `pacman` does not update AUR packages and users are responsible for rebuilding them. AUR availability should be compared with the matching Nix community package or upstream binary, not with Arch's official repository timing. [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository)

## Empirical package comparison

To add the measured answer, select apps the user actually installs from Nixpkgs and would install from Arch's official repositories. For each release, record upstream release time, Arch official package publication time, Nixpkgs version-bump merge time, first `nixos-unstable` commit that contains the bump, and the flake lock update time if the question is about this machine rather than repository availability. Separate package publication from mirror sync, successful Nix build/cache availability, and the user's own update. Compute per-app differences from the **same upstream release**; report a range and the exceptions instead of a single promised number. [Arch package search](https://archlinux.org/packages/), [NixOS channel status](https://status.nixos.org/)

| App and release | Arch official package available | Nixpkgs bump merged | `nixos-unstable` available | Arch lead at repository level | Notes |
| --- | --- | --- | --- | --- | --- |
| To be measured | | | | | |
