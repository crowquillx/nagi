#!/usr/bin/env bash
# Reinstall tandesk from the NixOS live ISO, after Windows is installed.
#
#   sudo bash install.sh [--disk /dev/nvme0n1] [--reuse]
#
# 1. creates a LUKS2 partition "nixos-root" in the free space after Windows
#    on the Crucial P5 (or opens the existing one with --reuse / on re-run)
# 2. restores system state + /home/tan from the BitLocker backup HDD
# 3. points hosts/tandesk/hardware-configuration.nix at the new UUIDs
# 4. builds tandesk (measured boot off for this first install) using the
#    HDD binary cache, runs nixos-install, sets tan's password
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

DISK=""
REUSE="false"
TARGET_MODEL="CT1000P5"
ROOT_PARTLABEL="nixos-root"
ESP_GUID="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
FLAKE_DIR="/mnt/home/${PRIMARY_USER}/nagi"
HW_FILE="${FLAKE_DIR}/hosts/tandesk/hardware-configuration.nix"
LOG="/tmp/tandesk-install.log"
ORIG_ARGS=("$@")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk) DISK="$2"; shift 2 ;;
    --reuse) REUSE="true"; shift ;;
    -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_root
[[ -d /sys/firmware/efi/efivars ]] || die "not booted in UEFI mode; reboot the ISO via its UEFI boot entry"

curl -fsS -o /dev/null --max-time 10 https://cache.nixos.org/nix-cache-info ||
  die "no network. Connect first (wired should just work; Wi-Fi: nmtui)"

# The ISO may lack some tools; re-exec once inside a nix shell that has them.
if [[ -z "${NAGI_REINSTALL_TOOLS:-}" ]]; then
  missing=()
  for c in zstd sgdisk ntfs-3g jq; do command -v "$c" >/dev/null || missing+=("$c"); done
  if ((${#missing[@]})); then
    log "Fetching missing tools: ${missing[*]}"
    exec nix --extra-experimental-features "nix-command flakes" shell \
      nixpkgs#zstd nixpkgs#gptfdisk nixpkgs#ntfs3g nixpkgs#jq \
      -c env NAGI_REINSTALL_TOOLS=1 bash "$0" "${ORIG_ARGS[@]}"
  fi
fi

exec > >(tee -a "${LOG}") 2>&1
log "Logging to ${LOG}"

# --- target disk -------------------------------------------------------------
if [[ -z "${DISK}" ]]; then
  DISK="$(lsblk -dnpo NAME,MODEL | awk -v m="${TARGET_MODEL}" '$2 ~ m && !f {print $1; f=1}')"
  [[ -n "${DISK}" ]] || die "no disk with model ${TARGET_MODEL}; pass --disk /dev/nvmeXn1"
fi
log "Target disk: ${DISK} ($(lsblk -dno MODEL,SIZE "${DISK}"))"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,PARTTYPENAME "${DISK}"

esp="$(lsblk -lnpo NAME,PARTTYPE "${DISK}" | awk -v g="${ESP_GUID}" 'tolower($2) == g && !f {print $1; f=1}')"
[[ -n "${esp}" ]] || die "no EFI system partition on ${DISK}; install Windows first (see README)"
esp_mib=$(($(blockdev --getsize64 "${esp}") / 1024 / 1024))
((esp_mib >= 500)) || die "ESP ${esp} is only ${esp_mib} MiB; it must be >= 500 MiB (README: Windows step)"
((esp_mib >= 1000)) || warn "ESP is ${esp_mib} MiB; it works, but 1 GiB+ was the plan"
log "ESP: ${esp} (${esp_mib} MiB)"

root_part=""
if [[ -e "/dev/disk/by-partlabel/${ROOT_PARTLABEL}" ]]; then
  root_part="$(readlink -f "/dev/disk/by-partlabel/${ROOT_PARTLABEL}")"
  if [[ "${REUSE}" != true ]]; then
    warn "${root_part} already has partlabel ${ROOT_PARTLABEL} (from an earlier run?)"
    if confirm "Reuse it as-is (no format, keep restored data)?"; then
      REUSE="true"
    else
      confirm "Reformat ${root_part}? This destroys its contents." || die "aborted"
    fi
  fi
else
  [[ "${REUSE}" != true ]] || die "--reuse given but no ${ROOT_PARTLABEL} partition exists"
  log "Free space on ${DISK}:"
  sgdisk -p "${DISK}" | sed -n '/Total free space/p'
  confirm "Create the NixOS partition in the largest free block of ${DISK}?" || die "aborted"
  sgdisk -n 0:0:0 -t 0:8309 -c "0:${ROOT_PARTLABEL}" "${DISK}"
  partprobe "${DISK}" 2>/dev/null || true
  udevadm settle
  root_part="$(readlink -f "/dev/disk/by-partlabel/${ROOT_PARTLABEL}")"
  [[ -b "${root_part}" ]] || die "new partition did not appear"
fi
root_gib=$(($(blockdev --getsize64 "${root_part}") / 1024 / 1024 / 1024))
log "NixOS partition: ${root_part} (${root_gib} GiB)"
((root_gib >= 150)) || die "NixOS partition is only ${root_gib} GiB; check the Windows partition size"

# --- LUKS + filesystems -------------------------------------------------------
if [[ "${REUSE}" != true ]]; then
  log "Formatting ${root_part} as LUKS2. Choose your disk passphrase (recovery fallback)."
  cryptsetup luksFormat --type luks2 --label "${ROOT_PARTLABEL}" "${root_part}"
fi
if [[ ! -e /dev/mapper/cryptroot ]]; then
  log "Opening LUKS (enter the disk passphrase)"
  cryptsetup open "${root_part}" cryptroot
fi
if [[ "${REUSE}" != true ]]; then
  mkfs.ext4 -F -L nixos /dev/mapper/cryptroot
fi

findmnt -rn /mnt >/dev/null || mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
findmnt -rn /mnt/boot >/dev/null || mount -o fmask=0077,dmask=0077 "${esp}" /mnt/boot

# --- restore from the backup HDD ---------------------------------------------
unlock_backup_hdd
mount_backup_hdd ro
for a in home.tar.zst system.tar.zst; do
  [[ -f "${BACKUP_DIR}/${a}" ]] || die "missing ${BACKUP_DIR}/${a}"
done

UNTAR=(tar -x -C /mnt --numeric-owner --same-permissions --xattrs --acls --sparse)
if [[ "${REUSE}" == true && -f /mnt/var/lib/sops-nix/key.txt && -d "${FLAKE_DIR}" ]]; then
  log "Restored data already present; skipping extraction (delete /mnt/home/${PRIMARY_USER} to force)"
else
  log "Restoring system state"
  zstd -dcq "${BACKUP_DIR}/system.tar.zst" | "${UNTAR[@]}"

  log "Restoring /home/${PRIMARY_USER} (long step)"
  mkdir -p "/mnt/home/${PRIMARY_USER}"
  UNTAR[3]="/mnt/home/${PRIMARY_USER}"
  zstd -dcq "${BACKUP_DIR}/home.tar.zst" | "${UNTAR[@]}"
  if [[ -f "${BACKUP_DIR}/steam.tar.zst" ]]; then
    zstd -dcq "${BACKUP_DIR}/steam.tar.zst" | "${UNTAR[@]}"
  fi
fi
[[ -f "${FLAKE_DIR}/flake.nix" ]] || die "nagi checkout missing at ${FLAKE_DIR}"
[[ -d /mnt/var/lib/sbctl/keys ]] || die "Secure Boot keys missing at /mnt/var/lib/sbctl"

# --- hardware-configuration.nix ----------------------------------------------
luks_uuid="$(blkid -s UUID -o value "${root_part}")"
esp_uuid="$(blkid -s UUID -o value "${esp}")"
log "New UUIDs: LUKS ${luks_uuid}, ESP ${esp_uuid}"
sed -i -E \
  -e "/# nagi-luks-uuid/{n;s|(/dev/disk/by-uuid/)[^\"]*|\1${luks_uuid}|}" \
  -e "/# nagi-esp-uuid/{n;s|(/dev/disk/by-uuid/)[^\"]*|\1${esp_uuid}|}" \
  "${HW_FILE}"
grep -q "${luks_uuid}" "${HW_FILE}" && grep -q "${esp_uuid}" "${HW_FILE}" ||
  die "failed to update ${HW_FILE}"
nixos-generate-config --root /mnt --show-hardware-config >/mnt/root/hardware-configuration.generated.nix 2>/dev/null ||
  true

# --- build + install -----------------------------------------------------------
NIX=(nix --extra-experimental-features "nix-command flakes")
mapfile -t subs < <("${NIX[@]}" eval --impure --json --expr \
  "(import ${FLAKE_DIR}/flake.nix).nixConfig.extra-substituters" | jq -r '.[]')
mapfile -t keys < <("${NIX[@]}" eval --impure --json --expr \
  "(import ${FLAKE_DIR}/flake.nix).nixConfig.extra-trusted-public-keys" | jq -r '.[]')
if [[ -f "${BACKUP_DIR}/nix-cache/nix-cache-info" && -f "${BACKUP_DIR}/nix-cache-key.pub" ]]; then
  log "Using the HDD binary cache"
  subs=("file://${BACKUP_DIR}/nix-cache" "${subs[@]}")
  keys=("$(cat "${BACKUP_DIR}/nix-cache-key.pub")" "${keys[@]}")
else
  warn "no HDD binary cache; everything comes from the network"
fi
NIX_OPTS=(
  --option extra-substituters "${subs[*]}"
  --option extra-trusted-public-keys "${keys[*]}"
  --option connect-timeout 10
)

# Newer Nix refuses world-writable build dirs (the ISO's /tmp), and /tmp is
# RAM-backed there anyway. Build on the target disk in a root-only dir.
export TMPDIR="/mnt/root/.nixos-install-build"
mkdir -p -m 0700 "${TMPDIR}"

log "Building tandesk into /mnt (measured boot off for the first boot)"
system="$("${NIX[@]}" build --store /mnt "${NIX_OPTS[@]}" --no-link --print-out-paths --impure \
  -f "${SCRIPT_DIR}/install-system.nix" --argstr flakePath "path:${FLAKE_DIR}")"
log "System: ${system}"

log "Running nixos-install"
nixos-install --root /mnt --system "${system}" --no-root-passwd --no-channel-copy "${NIX_OPTS[@]}"
rm -rf "${TMPDIR}"
export TMPDIR=/tmp

# --- fix ownership, set password ---------------------------------------------------
log "Fixing ownership of restored state"
nixos-enter --root /mnt -c "
  set -e
  chown root:sops /var/lib/sops-nix/key.txt && chmod 0640 /var/lib/sops-nix/key.txt
  if getent passwd greeter >/dev/null && [ -d /var/lib/noctalia-greeter ]; then
    chown -R greeter:greeter /var/lib/noctalia-greeter
  fi
  if [ \"\$(id -u ${PRIMARY_USER})\" != 1000 ] || [ \"\$(id -g ${PRIMARY_USER})\" != 100 ]; then
    echo 'uid/gid changed; chowning /home/${PRIMARY_USER}'
    chown -R ${PRIMARY_USER}:users /home/${PRIMARY_USER}
  fi
"

log "Set the login password for ${PRIMARY_USER}."
warn "Use the SAME password as before: the GNOME keyring (Brave passwords, app tokens) is encrypted with it."
until nixos-enter --root /mnt -c "passwd ${PRIMARY_USER}"; do
  warn "passwd failed, try again"
done

cp "${LOG}" /mnt/root/tandesk-install.log 2>/dev/null || true
sync
cat <<EOF

$(log "Install finished.")
Next:
  1. reboot, enter the firmware setup, ENABLE Secure Boot, put "Linux Boot Manager" first
  2. boot NixOS, unlock with the passphrase, log in as ${PRIMARY_USER}
  3. open a terminal and run:  ~/nagi/install/reinstall/post-install.sh
EOF
