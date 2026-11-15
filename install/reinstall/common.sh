# shellcheck shell=bash
# Shared helpers for backup.sh and install.sh. Source, do not execute.

# BitLocker data drive (Toshiba 2 TB HDD) that holds the backup. The by-uuid
# link is the BitLocker volume GUID, so it survives /dev/sdX reordering.
BACKUP_BITLK_DEV="${BACKUP_BITLK_DEV:-/dev/disk/by-uuid/caf36185-d0e4-4378-9ac3-b8c8c8d5ba5b}"
BACKUP_MAPPER="${BACKUP_MAPPER:-tandesk-backup-hdd}"
# Kept outside /mnt: on the live ISO /mnt is the install target.
BACKUP_MNT="${BACKUP_MNT:-/run/tandesk-backup/hdd}"
BACKUP_DIR="${BACKUP_MNT}/tandesk-reinstall"

PRIMARY_USER="tan"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run as root (sudo $0 ...)"
}

confirm() {
  local prompt="$1" reply
  read -r -p "${prompt} [y/N] " reply
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# unlock_backup_hdd: open the BitLocker volume (prompts for the BitLocker
# passphrase or 48-digit recovery password) unless it is already open.
unlock_backup_hdd() {
  [[ -e "${BACKUP_BITLK_DEV}" ]] || die "backup HDD not found at ${BACKUP_BITLK_DEV}"
  if [[ -e "/dev/mapper/${BACKUP_MAPPER}" ]]; then
    return 0
  fi
  log "Unlocking BitLocker backup HDD (enter BitLocker passphrase or recovery password)"
  cryptsetup open --type bitlk "${BACKUP_BITLK_DEV}" "${BACKUP_MAPPER}"
}

# mount_backup_hdd rw|ro
# rw uses ntfs-3g: the volume carries a dirty flag from Windows and ntfs3
# refuses to write to it. ro falls back to the in-kernel ntfs3 driver.
mount_backup_hdd() {
  local mode="$1" dev="/dev/mapper/${BACKUP_MAPPER}"
  if findmnt -rn "${BACKUP_MNT}" >/dev/null; then
    if [[ "${mode}" == rw ]] && findmnt -rno OPTIONS "${BACKUP_MNT}" | grep -qw ro; then
      die "${BACKUP_MNT} is mounted read-only; unmount it first"
    fi
    return 0
  fi
  mkdir -p "${BACKUP_MNT}"
  if [[ "${mode}" == rw ]]; then
    command -v ntfs-3g >/dev/null || die "ntfs-3g not found"
    ntfs-3g -o "uid=0,gid=0,windows_names" "${dev}" "${BACKUP_MNT}"
  elif command -v ntfs-3g >/dev/null; then
    ntfs-3g -o ro "${dev}" "${BACKUP_MNT}"
  else
    mount -t ntfs3 -o ro "${dev}" "${BACKUP_MNT}"
  fi
  log "Backup HDD mounted ${mode} at ${BACKUP_MNT}"
}

close_backup_hdd() {
  sync
  if findmnt -rn "${BACKUP_MNT}" >/dev/null; then
    umount "${BACKUP_MNT}"
  fi
  if [[ -e "/dev/mapper/${BACKUP_MAPPER}" ]]; then
    cryptsetup close "${BACKUP_MAPPER}"
  fi
  log "Backup HDD unmounted and locked"
}
