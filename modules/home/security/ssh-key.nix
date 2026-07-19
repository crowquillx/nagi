{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  sshKeyEnabled = get [ "security" "sops" "sshKey" "enable" ] false;
  signingKeyEnabled = get [ "security" "sops" "signingKey" "enable" ] false;
  privName = get [ "security" "sops" "sshKey" "name" ] "ssh_key";
  pubName = get [ "security" "sops" "sshKey" "pubName" ] "ssh_key_pub";
  signingPrivName = get [ "security" "sops" "signingKey" "name" ] "ssh_signing_key";
  signingPubName = get [ "security" "sops" "signingKey" "pubName" ] "ssh_signing_key_pub";
  privSource = "/run/secrets/${privName}";
  pubSource = "/run/secrets/${pubName}";
  signingPrivSource = "/run/secrets/${signingPrivName}";
  signingPubSource = "/run/secrets/${signingPubName}";
  authEnabled = sopsEnabled && sshKeyEnabled;
  signingEnabled = sopsEnabled && signingKeyEnabled;
  anyEnabled = authEnabled || signingEnabled;
  gitUserEmail = get [ "users" "git" "email" ] null;

  linkSecret = source: target: mode: ''
    if [ -e "${source}" ]; then
      run ln -sfn "${source}" "${target}"
      run chmod ${mode} "${target}" 2>/dev/null || true
    else
      echo "nagi: sops secret not found at ${source}; leaving ${target} unchanged." >&2
    fi
  '';

  waitSources =
    (lib.optionals authEnabled [ privSource pubSource ])
    ++ (lib.optionals signingEnabled [ signingPrivSource signingPubSource ]);

  waitCondition = lib.concatMapStringsSep " && " (s: "[ -e '${s}' ]") waitSources;

  authLinkScript = lib.optionalString authEnabled ''
    ${linkSecret privSource "\$sshDir/${privName}" "600"}
    ${linkSecret pubSource "\$sshDir/${pubName}" "644"}
  '';

  signingLinkScript = lib.optionalString signingEnabled ''
    ${linkSecret signingPrivSource "\$sshDir/${signingPrivName}" "600"}
    ${linkSecret signingPubSource "\$sshDir/${signingPubName}" "644"}
  '';

  allowedSignersScript = lib.optionalString (signingEnabled && gitUserEmail != null) ''
    if [ -e '${signingPubSource}' ]; then
      pub="$(tr -d '\n' < '${signingPubSource}')"
      printf '%s %s\n' ${lib.escapeShellArg gitUserEmail} "$pub" > "$sshDir/allowed_signers"
      run chmod 644 "$sshDir/allowed_signers"
    else
      echo "nagi: signing pubkey missing; leaving $sshDir/allowed_signers unchanged." >&2
    fi
  '';

  activationScript = ''
    sshDir="$HOME/.ssh"

    # Wait for /run/secrets to be populated by sops-install-secrets before
    # creating the symlinks. This handles the race where HM activation runs
    # before the systemd service has finished decrypting.
    _nagiWaitForSops() {
      local deadline=$(( $(date +%s) + 30 ))
      while [ "$(date +%s)" -lt "$deadline" ]; do
        if ${waitCondition}; then
          return 0
        fi
        sleep 0.5
      done
      return 1
    }

    if ! _nagiWaitForSops; then
      echo "nagi: timed out waiting for sops secrets in /run/secrets; SSH key symlinks may be missing." >&2
    fi

    run mkdir -p "$sshDir"
    run chmod 700 "$sshDir"

    ${authLinkScript}
    ${signingLinkScript}
    ${allowedSignersScript}
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf anyEnabled {
      # Force ~/.ssh to mode 0700 at session start; ssh refuses to use a key
      # in a too-permissive directory.
      systemd.user.tmpfiles.rules = [
        "d %h/.ssh 0700"
      ];

      # Symlink the materialized sops secrets into ~/.ssh at HM activation.
      # The sops secrets only exist at boot/runtime, so we can't reference
      # their absolute paths in a pure Nix expression. The shell snippet
      # below runs at HM activation, after sops-install-secrets has run.
      home.activation.symlinkSopsSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] activationScript;
    })

    (lib.mkIf authEnabled {
      # Tell the ssh client to present the materialized sops auth key. The key
      # lives at ~/.ssh/<privName> which is not one of ssh's default
      # identity filenames (id_rsa, id_ed25519, ...), so ssh will not try
      # it unless explicitly listed. We intentionally do NOT set
      # IdentitiesOnly=yes: that would suppress default-name keys and
      # anything in ssh-agent, breaking unrelated git/server access.
      # The signing key is intentionally omitted from IdentityFile.
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*" = {
          ForwardAgent = lib.mkDefault false;
          AddKeysToAgent = lib.mkDefault "no";
          Compression = lib.mkDefault false;
          ServerAliveInterval = lib.mkDefault 0;
          ServerAliveCountMax = lib.mkDefault 3;
          HashKnownHosts = lib.mkDefault false;
          UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
          ControlMaster = lib.mkDefault "no";
          ControlPath = lib.mkDefault "~/.ssh/master-%r@%n:%p";
          ControlPersist = lib.mkDefault "no";
        };
        extraConfig = ''
          IdentityFile ~/.ssh/${privName}
        '';
      };
    })

    (lib.mkIf signingEnabled {
      programs.git = {
        enable = true;
        settings = {
          gpg.format = "ssh";
          # Private key path: OpenSSH only maps "*.pub" → private key, not "*_pub".
          user.signingkey = "~/.ssh/${signingPrivName}";
          commit.gpgsign = true;
          tag.gpgsign = true;
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        };
      };
    })
  ];
}
