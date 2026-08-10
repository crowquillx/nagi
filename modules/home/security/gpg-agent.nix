{
  lib,
  vars ? { },
  pkgs,
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  yubikeyEnabled = get [ "security" "yubikey" "enable" ] false;
  pgpPublicKey = get [ "home" "security" "yubikey" "pgpPublicKey" ] null;
in
{
  config = lib.mkIf yubikeyEnabled {
    # User-level gpg-agent. Talks to the Yubikey via pcscd for sops CLI
    # and SSH operations.
    services.gpg-agent = {
      enable = true;
      # scdaemon handles the smartcard (Yubikey OpenPGP applet).
      enableScDaemon = true;
      # Forward SSH through gpg-agent so the Yubikey can also act as an
      # SSH key if you ever import a subkey for that purpose.
      enableSshSupport = true;
      # Sensible default cache TTLs for the desktop — touch the key once
      # per few hours, not every minute.
      defaultCacheTtl = 7200; # 2h
      defaultCacheTtlSsh = 7200; # 2h
      maxCacheTtl = 86400; # 24h hard cap
      pinentry = {
        package = pkgs.pinentry-bemenu;
        program = "pinentry-bemenu";
      };
    };

    # Import the Yubikey's PGP public key into ~/.gnupg so gpg-agent can
    # see the key and prompt you to tap when decrypting. The private key
    # never leaves the Yubikey; only the public half is imported.
    # Skips the import if the key file is a placeholder (no PGP block),
    # so this is safe to enable before you've generated the key.
    home.activation.importYubikeyPgpKey = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      if pgpPublicKey != null then
        ''
          key=${lib.escapeShellArg (toString pgpPublicKey)}
          gpgHome="$HOME/.gnupg"

          mkdir -p "$gpgHome"
          chmod 700 "$gpgHome"

          if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$key" 2>/dev/null; then
            gpg --homedir "$gpgHome" --import "$key" >/dev/null 2>&1 || true
          fi
        ''
      else
        ""
    );
  };
}
