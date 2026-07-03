{
  lib,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  sshKeyEnabled = get [ "security" "sops" "sshKey" "enable" ] false;
  privName = get [ "security" "sops" "sshKey" "name" ] "ssh_key";
  pubName = get [ "security" "sops" "sshKey" "pubName" ] "ssh_key_pub";
  privSource = "/run/secrets/${privName}";
  pubSource = "/run/secrets/${pubName}";
  enabled = sopsEnabled && sshKeyEnabled;

  linkSecret = source: target: mode: ''
    if [ -e "${source}" ]; then
      run ln -sfn "${source}" "${target}"
      run chmod ${mode} "${target}" 2>/dev/null || true
    else
      echo "nagi: sops secret not found at ${source}; leaving ${target} unchanged." >&2
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
        if [ -e '${privSource}' ] && [ -e '${pubSource}' ]; then
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

    ${linkSecret privSource "\$sshDir/${privName}" "600"}
    ${linkSecret pubSource "\$sshDir/${pubName}" "644"}
  '';
in
{
  config = lib.mkIf enabled {
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
  };
}
