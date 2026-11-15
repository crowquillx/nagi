# tandesk reinstall scripts

Scripts for wiping and reinstalling tandesk (Windows first, then NixOS in the remaining space) without losing state. The step-by-step runbook is in the private `tandesk-reinstall` repo and on the backup HDD.

| Script | Where it runs | What it does |
|---|---|---|
| `backup.sh` | current system, `sudo` | Unlocks the BitLocker HDD and writes `home.tar.zst` (filtered by `home-excludes.txt`), `steam.tar.zst`, `system.tar.zst` (`system-paths.txt`) and a signed Nix binary cache of the system closure to `<HDD>/tandesk-reinstall/` |
| `install.sh` | NixOS live ISO, root | Creates and formats the LUKS2 `nixos-root` partition in the free space, restores the archives into `/mnt`, rewrites the UUIDs in `hosts/tandesk/hardware-configuration.nix`, builds `install-system.nix` from the HDD cache, runs `nixos-install`, sets the user password |
| `post-install.sh` | new system, as the user | Stage 1 enrolls FIDO2, commits the UUIDs and rebuilds with measured boot. Stage 2 (after a reboot) enrolls the TPM2 pcrlock policy. `verify` runs a health check |

`install-system.nix` is `nixosConfigurations.tandesk` with `boot.lanzaboote.measuredBoot.enable` forced off. systemd-pcrlock can only build a policy from a real boot of the installed system.

The LUKS mapping is always named `cryptroot`. `install.sh` changes only the line after each `nagi-*-uuid` marker in `hardware-configuration.nix`, so keep those markers.
