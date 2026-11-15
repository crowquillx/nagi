#!/usr/bin/env bash
# Finish a tandesk reinstall on the new system. Run as tan (not root):
#
#   ~/nagi/install/reinstall/post-install.sh [first-boot|tpm|verify]
#
# No argument picks the next stage automatically:
#   first-boot  enroll the YubiKey (FIDO2) into LUKS, commit the new
#               hardware-configuration.nix, rebuild with measured boot on
#               -> reboot
#   tpm         enroll the TPM2 pcrlock policy into LUKS, then verify
#   verify      read-only health check
set -euo pipefail

FLAKE_DIR="${HOME}/nagi"
HOST="tandesk"
PCRLOCK_POLICY="/var/lib/systemd/pcrlock.json"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok() { printf '  \033[1;32mok\033[0m   %s\n' "$*"; }
bad() { printf '  \033[1;31mFAIL\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}
confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

[[ "${EUID}" -ne 0 ]] || die "run as your user, not root"

LUKS_MAPPER="${LUKS_MAPPER:-cryptroot}"
luks_dev="$(sudo cryptsetup status "${LUKS_MAPPER}" 2>/dev/null | awk '/device:/{print $2}' || true)"
[[ -n "${luks_dev}" ]] || die "${LUKS_MAPPER} is not open; is this the reinstalled system?"

has_token() { [[ "$(sudo cryptsetup luksDump "${luks_dev}" | sed -n '/^Tokens:/,/^Digests:/p')" == *"$1"* ]]; }
secure_boot_on() { [[ "$(bootctl status 2>/dev/null || true)" == *"Secure Boot: enabled"* ]]; }
measured_boot_on() { [[ -e /etc/pcrlock.d ]]; }

require_secure_boot() {
  secure_boot_on && return 0
  bootctl status 2>/dev/null | grep -E 'Secure Boot|Setup Mode' || true
  die "Secure Boot is not enabled. Reboot into the firmware setup, enable Secure Boot, boot NixOS and re-run.
If NixOS then refuses to boot, the firmware lost the custom keys: see README > Troubleshooting."
}

stage_first_boot() {
  require_secure_boot

  if has_token systemd-fido2; then
    ok "FIDO2 token already enrolled"
  else
    log "Enrolling the YubiKey into LUKS: enter the disk passphrase, then touch the key"
    sudo systemd-cryptenroll --fido2-device=auto \
      --fido2-with-client-pin=no --fido2-with-user-presence=yes "${luks_dev}"
  fi

  cd "${FLAKE_DIR}"
  if ! git diff --quiet -- hosts/tandesk/hardware-configuration.nix; then
    log "Committing the new disk UUIDs"
    git add hosts/tandesk/hardware-configuration.nix
    git commit -m "tandesk: update disk UUIDs after reinstall"
    if confirm "Push to origin now?"; then
      git push || warn "push failed; push later"
    fi
  fi

  log "Rebuilding with measured boot enabled (boot, not switch)"
  if command -v tcli >/dev/null; then
    tcli rebuild boot "${HOST}"
  else
    sudo nixos-rebuild boot --accept-flake-config --flake "path:${FLAKE_DIR}#${HOST}"
  fi

  cat <<EOF

Reboot now. After logging back in run:
  ${FLAKE_DIR}/install/reinstall/post-install.sh
(it continues with the TPM2 enrollment)
EOF
}

stage_tpm() {
  require_secure_boot
  measured_boot_on || die "measured boot is not active in this generation; run the first-boot stage and reboot"
  [[ -f "${PCRLOCK_POLICY}" ]] || die "${PCRLOCK_POLICY} missing; check: systemctl status systemd-pcrlock-make-policy"

  if has_token systemd-tpm2; then
    confirm "A TPM2 token already exists. Replace it?" || { stage_verify; return; }
    sudo systemd-cryptenroll --wipe-slot=tpm2 "${luks_dev}"
  fi
  log "Enrolling TPM2 (pcrlock policy) into LUKS: enter the disk passphrase or touch the YubiKey"
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrlock="${PCRLOCK_POLICY}" "${luks_dev}"
  log "Done. On the next reboot the disk should unlock without a prompt."
  stage_verify
}

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "${desc}"; else bad "${desc}"; fi
}

stage_verify() {
  log "Health check"
  check "Secure Boot enabled" secure_boot_on
  check "measured boot active" measured_boot_on
  check "LUKS FIDO2 token" has_token systemd-fido2
  check "LUKS TPM2 token" has_token systemd-tpm2
  check "sops secrets in /run/secrets" sudo test -s /run/secrets/ssh_key
  check "SSH key linked in ~/.ssh" test -e "${HOME}/.ssh/ssh_key"
  check "GitHub SSH auth" bash -c 'ssh -o BatchMode=yes -T git@github.com 2>&1 | grep -q "successfully authenticated"'
  check "Home Manager activation" systemctl is-active --quiet "home-manager-${USER}.service"
  check "tailscale up" bash -c 'tailscale status --peers=false'
  check "/mnt/games mounted" findmnt /mnt/games
  check "/mnt/games1 mounted" findmnt /mnt/games1
  check "claude (native)" "${HOME}/.local/bin/claude" --version
  check "codex (native)" "${HOME}/.local/bin/codex" --version
  check "pi (native)" "${HOME}/.local/bin/pi" --version
  check "system flatpaks installed" bash -c 'flatpak list --system --app --columns=application | grep -q .'
  check "no failed system units" bash -c '[ -z "$(systemctl --failed --no-legend)" ]'
  check "no failed user units" bash -c '[ -z "$(systemctl --user --failed --no-legend)" ]'
  echo
  echo "Failed units (if any):"
  systemctl --failed --no-legend || true
  systemctl --user --failed --no-legend || true
}

stage="${1:-auto}"
if [[ "${stage}" == auto ]]; then
  if ! has_token systemd-fido2 || ! measured_boot_on; then
    stage="first-boot"
  elif ! has_token systemd-tpm2; then
    stage="tpm"
  else
    stage="verify"
  fi
  log "Stage: ${stage}"
fi

case "${stage}" in
  first-boot) stage_first_boot ;;
  tpm) stage_tpm ;;
  verify) stage_verify ;;
  *) die "unknown stage: ${stage}" ;;
esac
