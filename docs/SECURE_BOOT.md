# Secure Boot (Lanzaboote) setup guide

This repo supports **optional** Secure Boot through Lanzaboote, controlled per host via:

```nix
boot.secureBoot = {
  enable = false;
  includeMicrosoftKeys = true;
  autoEnroll = false;
  pkiBundle = "/var/lib/sbctl";
};
```

## Defaults

- `enable = false` (safe default)
- `includeMicrosoftKeys = true` (keeps Microsoft keys for common dual-boot/vendor compatibility)
- `autoEnroll = false` (manual enrollment first, then optional automation)
- `pkiBundle = "/var/lib/sbctl"` (Lanzaboote/sbctl conventional PKI location)

## Before enabling Secure Boot

Do these steps first on the target machine:

1. Ensure system boots in UEFI mode and currently uses systemd-boot.
2. Set a firmware/BIOS admin password (recommended to protect Secure Boot policy changes).
3. Backup important data.
4. Build once with current config to confirm clean baseline:
   - `tcli rebuild build <host>`
5. (Recommended) Verify no pending firmware issues.

## Initial enrollment flow (recommended)

1. Keep `boot.secureBoot.enable = false`, rebuild/switch once:
   - `tcli rebuild switch <host>`
2. Generate Secure Boot keys:
   - `sudo sbctl create-keys`
3. Enroll keys including Microsoft keys:
   - `sudo sbctl enroll-keys -m`
4. Flip host variable:
   - `boot.secureBoot.enable = true;`
5. Rebuild and activate:
   - `tcli rebuild switch <host>`
6. Reboot, then enable Secure Boot in firmware UI.
7. Validate status:
   - `sbctl status`

## Optional: automatic key enrollment

After manual setup works, you can set:

```nix
boot.secureBoot.autoEnroll = true;
```

This enables Lanzaboote auto-enrollment behavior via NixOS module options.

## Recovery notes

If system fails to boot after toggling Secure Boot:

1. Disable Secure Boot in firmware.
2. Boot previous generation or installation media.
3. Rebuild/switch with `boot.secureBoot.enable = false`.
4. Re-check key enrollment and firmware key state before re-enabling.
