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
Yubikey), generate a passphrase-protected age key and add its *public*
key to the same `key_groups` entry's `age:` list in `.sops.yaml`:

```bash
nix shell nixpkgs#age --command age-keygen -p -o ~/.config/sops/age-passphrase.key
chmod 600 ~/.config/sops/age-passphrase.key
age-keygen -y ~/.config/sops/age-passphrase.key
```

Within one `key_groups` entry, any listed recipient can decrypt (OR).
Add the passphrase age public key next to the host age key under the
same `age:` list — do **not** put it in a separate `key_groups`
entry, or sops will require one key from every group (AND / threshold).

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
  session talks to the Yubikey via `pcscd`. The sops file's single
  `key_groups` entry lists both the host age key and the Yubikey PGP
  fingerprint, so `sops` can use either recipient (OR). With the
  Yubikey present, CLI decrypt taps it; with only the age key available,
  that recipient decrypts instead.
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

In `.sops.yaml`, put the Yubikey PGP fingerprint in the **same**
`key_groups` entry as the host age key. Within one group, any listed
recipient can decrypt (OR). Splitting `age` and `pgp` into separate
`key_groups` entries would require one key from each group (AND) and
break unattended boot when the Yubikey is absent.

Committed shape (see `.sops.yaml`):

```yaml
creation_rules:
  - path_regex: secrets/tandesk\.ya?ml$
    key_groups:
      - age:
          - age16x7tq5ndgm3hr55gqfh2ujecq4hypyjn3vrmm36vam7y0fu5ffes7qt20s
        pgp:
          - B7873777D243B2011C50F7B83DF8B7D2772745D9
  - path_regex: secrets/tanlappy\.ya?ml$
    key_groups:
      - age:
          - age1w65nqky3ur3q9vatn984z3l6jhkpvmx9fgv0e838tug7uzfjy55qrwj49y
        pgp:
          - B7873777D243B2011C50F7B83DF8B7D2772745D9
  - path_regex: secrets/.*\.ya?ml$
    key_groups:
      - age:
          - age16x7tq5ndgm3hr55gqfh2ujecq4hypyjn3vrmm36vam7y0fu5ffes7qt20s
        pgp:
          - B7873777D243B2011C50F7B83DF8B7D2772745D9
```

After changing recipients, re-encrypt each affected file:

```bash
sops updatekeys -y secrets/<host>.yaml
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

## Per-host recipients (current `.sops.yaml`)

`.sops.yaml` already uses **per-host rules** for the hosts that have
secret files:

- `secrets/tandesk.yaml` → tandesk age key + Yubikey PGP (one `key_groups` entry)
- `secrets/tanlappy.yaml` → tanlappy age key + Yubikey PGP (one `key_groups` entry)
- catch-all `secrets/.*\.ya?ml$` → tandesk age key + Yubikey PGP, for any
  not-yet-migrated host file

There is **no** `secrets/default.yaml`; the `default` host profile sets
`security.sops.defaultSopsFile = null`.

Age and PGP for a given file live in a **single** `key_groups` entry so
either recipient can decrypt (OR). Do not split them into separate groups.

`security.sops.agePublicKey` is optional schema groundwork: set it to the
host's age public key for discoverability, then mirror that same public
key into the matching `.sops.yaml` rule. Setting the variable alone does
not change encryption recipients.

### Adding another host's recipients

1. Generate (or reuse) that host's age key at `/var/lib/sops-nix/key.txt`
   and copy its public key.
2. Optionally record it:
   ```nix
   security.sops.agePublicKey = "age1...";
   ```
3. Add a **path-specific rule above the catch-all** in `.sops.yaml`, with
   the host age key and the Yubikey fingerprint in one `key_groups` entry:
   ```yaml
   - path_regex: secrets/<host>\.ya?ml$
     key_groups:
       - age:
           - age1<...that host's public key...>
         pgp:
           - B7873777D243B2011C50F7B83DF8B7D2772745D9
   ```
4. Create/edit `secrets/<host>.yaml` with `sops`, or run
   `sops updatekeys -y secrets/<host>.yaml` after changing recipients.
5. Boot once and confirm `/run/secrets` populates **before** removing any
   old recipient the host still needs.

### Safety invariants

- Never remove a recipient without a verified path that preserves
  unattended boot decryption.
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
