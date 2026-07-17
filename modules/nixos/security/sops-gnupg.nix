{
  lib,
  vars ? { },
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  gnupgHome = get [ "security" "sops" "gnupgHome" ] null;
  publicKeyPath = get [ "security" "sops" "gnupgPublicKey" ] null;
  enabled = sopsEnabled && gnupgHome != null;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !sopsEnabled || ((gnupgHome != null) == (publicKeyPath != null));
          message = "security.sops.gnupgHome and security.sops.gnupgPublicKey must be set together (both set for GnuPG/Yubikey runtime decryption, or both null).";
        }
      ];
    }
    (lib.mkIf (enabled && publicKeyPath != null) {
      # Ensure the gnupg home exists, owned by root, mode 0700. The public
      # key for the Yubikey's PGP identity is imported into it so sops-nix
      # (running as root at sysinit) can find it without any user action.
      #
      # The private key never leaves the Yubikey; only the public key is in
      # this home. gpg-agent on the user's session (via pcscd) handles
      # private-key operations on the device itself.
      system.activationScripts.setupSopsGnupgHome = {
        text = ''
          home=${lib.escapeShellArg gnupgHome}
          key=${lib.escapeShellArg (toString publicKeyPath)}

          if [ ! -d "$home" ]; then
            install -d -m 0700 "$home"
          fi

          # Idempotent import: only re-import if the key isn't already in
          # the keyring. We grep the ascii-armored file for the long
          # fingerprint, then ask gpg to list it; gpg is happy to be asked
          # to import a key it already has.
          fingerprint=$(gpg --homedir "$home" --with-colons --import-options show-only --import "$key" 2>/dev/null | awk -F: '/^fpr:/ {print $10; exit}')
          if [ -z "$fingerprint" ]; then
            echo "nagi: failed to read PGP fingerprint from $key" >&2
            exit 1
          fi
          if ! gpg --homedir "$home" --list-keys "$fingerprint" >/dev/null 2>&1; then
            gpg --homedir "$home" --import "$key" >/dev/null
          fi
        '';
      };
    })
  ];
}
