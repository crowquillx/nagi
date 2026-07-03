# sops-nix Setup

This repo uses `sops-nix` with an age key stored on each target machine.
A `home/security/ssh-key.nix` HM module materializes the user's SSH key from
sops into `~/.ssh/` for hosts that opt in via `security.sops.sshKey.enable`.

## 1) Generate host age key (if missing)

```bash
sudo mkdir -p /var/lib/sops-nix
sudo nix shell nixpkgs#age --command age-keygen -o /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt
sudo cat /var/lib/sops-nix/key.txt | grep "^# public key:" | cut -d' ' -f4
```

Copy that public key into `.sops.yaml` recipients.

## 2) Create encrypted host secret file

```bash
mkdir -p secrets
sops secrets/<host>.yaml
```

Example:

```bash
sops secrets/default.yaml
```

To store the user's SSH key in sops, add the key as a sops secret. The
example below is what the host module expects when
`security.sops.sshKey.enable = true`:

```yaml
ssh_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
ssh_key_pub: ssh-rsa AAAA... user@host
```

## 3) Point host variables to that file

In `hosts/<host>/variables.nix`, set:

```nix
security.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/<host>.yaml;
  ageKeyFile = "/var/lib/sops-nix/key.txt";
  sshKey = {
    enable = true;
    name = "ssh_key";
    pubName = "ssh_key_pub";
  };
};
```

## 4) Apply config

```bash
sudo ./install/bootstrap.sh <host> --user <user> --hostname <hostname> --flake-dir /home/<user>/nagi
```

or:

```bash
tcli rebuild switch <host>
```

## Optional: passphrase-protected age key ("password" option)

To make `sops` CLI usage work via a passphrase (independent of any PGP
Yubikey), generate a passphrase-protected age key and add it as a second
key group in `.sops.yaml`:

```bash
nix shell nixpkgs#age --command age-keygen -p -o ~/.config/sops/age-passphrase.key
chmod 600 ~/.config/sops/age-passphrase.key
age-keygen -y ~/.config/sops/age-passphrase.key
```

Then in `.sops.yaml`, add a second `age` key group containing the new
public key. sops will encrypt to both groups; you can decrypt with either.

Note: `sops-nix`'s runtime `sops.age.keyFile` does not prompt for a
passphrase at boot, so a passphrase-protected age key only works for
manual `sops` CLI usage, not for runtime secret materialization.

## Optional: Yubikey PGP ("yubikey" option)

This repo has first-class Yubikey support. The same setup works on every
host because the PGP key lives on the Yubikey itself; only the public
key is committed to the repo.

### Design

`security.sops` runtime uses **one** source per host. sops-nix
explicitly rejects combining `gnupgHome` and `ageKeyFile` in the same
manifest — they are mutually exclusive at boot. So the practical split
is:

- **Yubikey for sops CLI** (interactive): `gpg-agent` in your user
  session talks to the Yubikey via `pcscd`. The sops file is encrypted
  to a `pgp` key group containing the Yubikey's fingerprint, and `sops`
  will tap the Yubikey (or fall through to the age key if the Yubikey
  isn't plugged in / hasn't been tapped).
- **Age key for unattended boot**: `sops-install-secrets` reads
  `/var/lib/sops-nix/key.txt` and decrypts without any human
  interaction. This is what makes reboots work even when you're not at
  the keyboard or have forgotten the Yubikey.

Hosts where you want unattended boot use `ageKeyFile` only. The Yubikey
is purely a CLI / manual-decrypt option on those hosts. If you want the
Yubikey to be the *only* way to decrypt (no fallback), set
`gnupgHome` and unset `ageKeyFile` — but the host will not boot without
the Yubikey plugged in.

### One-time: generate a PGP key on the Yubikey

1. Plug in the Yubikey.
2. Initialize the OpenPGP applet (default admin PIN is `12345678`):
   ```bash
   ykman openpgp info
   ykman openpgp keys reset
   ```
3. Generate the key directly on the Yubikey. The private key never
   leaves the device:
   ```bash
   gpg --card-edit
   # inside the card-edit prompt:
   #   admin
   #   generate
   # answer the prompts (no expiry recommended for a long-lived key)
   ```
4. Note the long fingerprint:
   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```
5. Export the armored public key into the repo (safe to commit):
   ```bash
   gpg --armor --export <FINGERPRINT> > secrets/yubikey-pgp-pub.asc
   ```

### Wire the Yubikey into the repo

In `.sops.yaml`, add a `pgp` key group alongside the existing `age`
group. Each key group is an OR (any one can decrypt), and the keys
within a group are an AND (all must be present to use that group):

```yaml
creation_rules:
  - path_regex: secrets/.*\.ya?ml$
    key_groups:
      - age:
          - age16x7tq5ndgm3hr55gqfh2ujecq4hypyjn3vrmm36vam7y0fu5ffes7qt20s
      - pgp:
          - <FINGERPRINT>
```

Re-encrypt existing files to include the new recipient:

```bash
sops updatekeys -y secrets/*.yaml
```

### Per-host configuration

In every host that should accept the Yubikey, set:

```nix
security.yubikey.enable = true;  # enables pcscd + yubikey-manager udev rules
security.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/<host>.yaml;
  ageKeyFile = "/var/lib/sops-nix/key.txt";  # runtime source (mutually exclusive with gnupgHome)
  sshKey = { ... };
};
home.security.yubikey.pgpPublicKey = ../../secrets/yubikey-pgp-pub.asc;
```

`modules/nixos/security/yubikey.nix` enables `services.pcscd` and the
yubikey-manager udev rules. `modules/home/security/gpg-agent.nix`
configures user-side `gpg-agent` with `pinentry-bemenu` and `scdaemon`
support, plus SSH-agent forwarding; its activation script imports the
PGP public key into `~/.gnupg` so gpg-agent can find it.

`modules/nixos/security/sops-gnupg.nix` is *not* used in the default
flow. It is available for hosts that want to use the Yubikey for
runtime decryption (no age key file at all). Set both
`security.sops.gnupgHome` and `security.sops.gnupgPublicKey` to
opt in, and unset `security.sops.ageKeyFile`.

## Sops file validation (`validateSopsFiles`)

`sops.validateSopsFiles` is **enabled** in `modules/nixos/security/sops.nix`.

With the pinned `sops-nix`, validation runs `sops-install-secrets
-check-mode=sopsfile` inside the manifest derivation's `checkPhase` at
**build time**. It:

- parses each encrypted sops file (YAML/JSON/ini/dotenv/binary),
- verifies every declared `sops.secrets.<name>` key actually exists in the
  encrypted file,
- validates mode/owner/group strings.

It does **not** decrypt secret values and does **not** need the age/GPG
key at build time, so it works in the Nix sandbox and in CI. This catches
malformed sops files and missing declared keys *before* boot instead of
failing silently at activation. Keep it on.

## Per-host recipient separation (manual migration)

Today `.sops.yaml` uses a single catch-all rule encrypted to one age key
plus the Yubikey PGP key. Every host that has a sops file can decrypt
every other host's file. True per-host recipient separation requires a
**distinct age key per host**, and only one age public key is currently
committed — so this migration is manual and must be done on each host.

The `security.sops.agePublicKey` host variable is reserved as schema
groundwork for this: set it to the host's age public key so the value is
declarative and discoverable, then mirror it into `.sops.yaml`.

### Steps (per host, one at a time)

1. **Ensure the host has its own age key** (skip if it already has a
   distinct one you want to keep):
   ```bash
   sudo mkdir -p /var/lib/sops-nix
   sudo nix shell nixpkgs#age --command age-keygen -o /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   sudo grep '^# public key:' /var/lib/sops-nix/key.txt | cut -d' ' -f4
   ```
2. **Record the public key** in that host's `variables.nix`:
   ```nix
   security.sops.agePublicKey = "age1<...that host's public key...>";
   ```
3. **Add a per-host rule** in `.sops.yaml`, with the host's age key and the
   Yubikey PGP fingerprint as separate `key_groups` (OR semantics — either
   recipient can decrypt):
   ```yaml
   creation_rules:
     - path_regex: secrets/tandesk\.ya?ml$
       key_groups:
         - age:
             - age1<...tandesk public key...>
         - pgp:
             - B7873777D243B2011C50F7B83DF8B7D2772745D9
     - path_regex: secrets/default\.ya?ml$
       key_groups:
         - age:
             - age1<...default public key...>
         - pgp:
             - B7873777D243B2011C50F7B83DF8B7D2772745D9
     # ...one rule per host...
   ```
4. **Re-encrypt each host's file to its new recipient set**:
   ```bash
   sops updatekeys -y secrets/<host>.yaml
   ```
5. **Boot the host once** and confirm unattended decrypt still works
   (`/run/secrets` populated, services start) **before** removing any old
   recipient from `.sops.yaml`. Do not rotate or remove a recipient until
   every host that needs it has been migrated and verified.

### Safety invariants

- Never remove a recipient without a verified migration path that
  preserves unattended boot decryption.
- `gnupgHome` and `ageKeyFile` are mutually exclusive at runtime in
  sops-nix; keep using `ageKeyFile` for unattended boot and the Yubikey
  PGP key only as a CLI/manual recipient.
- Do not commit plaintext secrets or private age keys. Only public keys
  and the armored PGP public key belong in the repo.

## Notes

- Bootstrap auto-creates `/var/lib/sops-nix/key.txt` if missing.
- Keep `.sops.yaml` in sync with all host public keys that need decryption.
- The HM module `modules/home/security/ssh-key.nix` is only active when
  both `security.sops.enable` and `security.sops.sshKey.enable` are true.
  It enforces `~/.ssh` mode 0700 and symlinks the materialized secrets
  into place.
- `sops.validateSopsFiles` is on; builds fail on malformed sops files or
  missing declared keys. See the "Sops file validation" section above.
