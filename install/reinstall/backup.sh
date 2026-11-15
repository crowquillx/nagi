#!/usr/bin/env bash
# Back up tandesk to the BitLocker HDD before a reinstall.
#
#   sudo ./backup.sh [--no-nix-cache] [--keep-mounted] [--readme PATH]
#
# Writes <HDD>/tandesk-reinstall/:
#   home.tar.zst     /home/tan minus caches/re-downloadable data (home-excludes.txt)
#   steam.tar.zst    ~/.local/share/Steam/{config,userdata} only
#   system.tar.zst   host identity + secrets keys (system-paths.txt)
#   nix-cache/       signed binary cache of the full tandesk system closure
#   scripts/         copy of these scripts; README.md; MANIFEST.txt
# Re-running replaces the archives (each is written to .tmp and renamed only
# after it verifies); the nix cache is incremental.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NIX_CACHE="true"
KEEP_MOUNTED="false"
README_SRC="/home/${PRIMARY_USER}/REPOS/tandesk-reinstall/README.md"
FLAKE_DIR="/home/${PRIMARY_USER}/nagi"
HOME_DIR="/home/${PRIMARY_USER}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-nix-cache) NIX_CACHE="false"; shift ;;
    --keep-mounted) KEEP_MOUNTED="true"; shift ;;
    --readme) README_SRC="$2"; shift 2 ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_root
[[ "$(hostname)" == tandesk ]] || warn "hostname is $(hostname), expected tandesk"

as_user() { sudo -u "${PRIMARY_USER}" -- "$@"; }

# --- preflight -------------------------------------------------------------
log "Preflight checks"
running=()
for p in zen zen-bin brave discord Discord equibop steam spotify chromium helium; do
  pgrep -x "${p}" >/dev/null 2>&1 && running+=("${p}")
done
if ((${#running[@]})); then
  warn "still running: ${running[*]} (their databases may be captured mid-write)"
  confirm "Continue anyway?" || die "close them and re-run"
fi

if [[ -n "$(as_user git -C "${FLAKE_DIR}" status --porcelain)" ]]; then
  warn "nagi has uncommitted changes (they are still included in the home archive):"
  as_user git -C "${FLAKE_DIR}" status --short
fi
ahead="$(as_user git -C "${FLAKE_DIR}" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
[[ "${ahead}" == 0 ]] || warn "nagi has ${ahead} unpushed commit(s)"

unpushed_repos=()
while IFS= read -r -d '' gitdir; do
  repo="$(dirname "${gitdir}")"
  if as_user git -C "${repo}" rev-parse '@{u}' >/dev/null 2>&1; then
    n="$(as_user git -C "${repo}" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    [[ "${n}" == 0 ]] || unpushed_repos+=("${repo} (${n} unpushed)")
  fi
done < <(find "${HOME_DIR}/REPOS" "${HOME_DIR}/Development" -maxdepth 3 -name .git -type d -print0 2>/dev/null)
((${#unpushed_repos[@]} == 0)) || warn "repos with unpushed commits (backed up anyway): ${unpushed_repos[*]}"

# --- mount -----------------------------------------------------------------
unlock_backup_hdd
mount_backup_hdd rw
mkdir -p "${BACKUP_DIR}"
avail_gib=$(($(df --output=avail -B1G "${BACKUP_MNT}" | tail -1)))
((avail_gib >= 150)) || die "only ${avail_gib} GiB free on the backup HDD (need ~150)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# finish_archive <name>: verify .tmp and move it into place
finish_archive() {
  local name="$1"
  log "Verifying ${name}"
  zstd -tq "${BACKUP_DIR}/${name}.tmp"
  mv -f "${BACKUP_DIR}/${name}.tmp" "${BACKUP_DIR}/${name}"
}

# tar exits 1 for "file changed as we read it"; anything above that is fatal.
check_tar() {
  local tar_rc="$1" zstd_rc="$2" name="$3"
  ((zstd_rc == 0)) || die "zstd failed for ${name}"
  ((tar_rc <= 1)) || die "tar failed (${tar_rc}) for ${name}"
  ((tar_rc == 0)) || warn "${name}: some files changed while being read (normal for live apps)"
}

TAR_FLAGS=(
  --create --file=-
  --numeric-owner --acls --xattrs --sparse
  --one-file-system
  --ignore-failed-read
  --warning=no-file-changed --warning=no-file-ignored --warning=no-file-removed
)

# --- home ------------------------------------------------------------------
log "Archiving ${HOME_DIR} (this is the long step)"
grep -vE '^[[:space:]]*(#|$)' "${SCRIPT_DIR}/home-excludes.txt" >"${WORK}/patterns"
# Home Manager links into /nix/store: dangling after reinstall, HM recreates them.
find "${HOME_DIR}" -xdev -type l -lname '/nix/store/*' -printf './%P\n' >"${WORK}/nixlinks" 2>/dev/null || true
log "Skipping $(wc -l <"${WORK}/nixlinks") Home Manager/nix store symlinks"

set +e
tar "${TAR_FLAGS[@]}" -C "${HOME_DIR}" \
  --anchored --no-wildcards --exclude-from="${WORK}/nixlinks" \
  --wildcards --exclude-from="${WORK}/patterns" \
  . | zstd -T0 -3 -q -o "${BACKUP_DIR}/home.tar.zst.tmp" -f
rc=("${PIPESTATUS[@]}")
set -e
check_tar "${rc[0]}" "${rc[1]}" home.tar.zst
finish_archive home.tar.zst

log "Archiving Steam config + userdata"
steam_paths=()
for p in .local/share/Steam/config .local/share/Steam/userdata; do
  [[ -e "${HOME_DIR}/${p}" ]] && steam_paths+=("./${p}")
done
if ((${#steam_paths[@]})); then
  set +e
  tar "${TAR_FLAGS[@]}" -C "${HOME_DIR}" "${steam_paths[@]}" |
    zstd -T0 -3 -q -o "${BACKUP_DIR}/steam.tar.zst.tmp" -f
  rc=("${PIPESTATUS[@]}")
  set -e
  check_tar "${rc[0]}" "${rc[1]}" steam.tar.zst
  finish_archive steam.tar.zst
fi

# --- system state ----------------------------------------------------------
log "Archiving system state"
sys_paths=()
while IFS= read -r p; do
  [[ "${p}" =~ ^[[:space:]]*(#|$) ]] && continue
  if [[ -e "/${p}" ]]; then sys_paths+=("${p}"); else warn "not present, skipped: /${p}"; fi
done <"${SCRIPT_DIR}/system-paths.txt"
for required in var/lib/sops-nix var/lib/sbctl; do
  [[ -e "/${required}" ]] || die "/${required} is missing; refusing to make a backup without it"
done
set +e
tar "${TAR_FLAGS[@]}" -C / --exclude=root/.cache "${sys_paths[@]}" |
  zstd -T0 -3 -q -o "${BACKUP_DIR}/system.tar.zst.tmp" -f
rc=("${PIPESTATUS[@]}")
set -e
check_tar "${rc[0]}" "${rc[1]}" system.tar.zst
finish_archive system.tar.zst
zstd -dcq "${BACKUP_DIR}/system.tar.zst" | tar -t | grep -x 'var/lib/sops-nix/key.txt' >/dev/null ||
  die "system.tar.zst does not contain the sops age key"

# --- nix binary cache ------------------------------------------------------
if [[ "${NIX_CACHE}" == true ]]; then
  log "Building tandesk (install variant + normal) for the offline binary cache"
  NIX=(nix --extra-experimental-features "nix-command flakes" --accept-flake-config)
  flake_ref="path:${FLAKE_DIR}"
  install_sys="$(as_user "${NIX[@]}" build --no-link --print-out-paths --impure \
    -f "${SCRIPT_DIR}/install-system.nix" --argstr flakePath "${flake_ref}")"
  normal_sys="$(as_user "${NIX[@]}" build --no-link --print-out-paths \
    "${flake_ref}#nixosConfigurations.tandesk.config.system.build.toplevel")"

  key="${BACKUP_DIR}/nix-cache-key.sec"
  if [[ ! -f "${key}" ]]; then
    "${NIX[@]}" key generate-secret --key-name tandesk-reinstall-1 >"${key}"
  fi
  "${NIX[@]}" key convert-secret-to-public <"${key}" >"${BACKUP_DIR}/nix-cache-key.pub"

  cache_url="file://${BACKUP_DIR}/nix-cache?compression=zstd&parallel-compression=true&secret-key=${key}"
  log "Copying system closure to the HDD cache (incremental)"
  "${NIX[@]}" copy --to "${cache_url}" "${install_sys}" "${normal_sys}"
  log "Copying flake inputs to the HDD cache"
  "${NIX[@]}" flake archive --to "${cache_url}" "${flake_ref}" || warn "flake archive failed (inputs will be fetched from the network)"
fi

# --- scripts, README, manifest ----------------------------------------------
log "Copying scripts and README"
rm -rf "${BACKUP_DIR}/scripts"
cp -r "${SCRIPT_DIR}" "${BACKUP_DIR}/scripts"
if [[ -f "${README_SRC}" ]]; then
  cp "${README_SRC}" "${BACKUP_DIR}/README.md"
else
  warn "README not found at ${README_SRC}"
fi

{
  echo "tandesk reinstall backup — $(date -Is)"
  echo "nagi: $(as_user git -C "${FLAKE_DIR}" rev-parse HEAD) ($(as_user git -C "${FLAKE_DIR}" log -1 --format=%s))"
  echo
  echo "## archives"
  ls -la "${BACKUP_DIR}"
  echo
  echo "## unpushed repos"
  printf '%s\n' "${unpushed_repos[@]:-none}"
  echo
  echo "## disks"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,MODEL
  echo
  echo "## LUKS tokens (old root)"
  root_luks="$(cryptsetup status "$(findmnt -no SOURCE /)" 2>/dev/null | awk '/device:/{print $2}' || true)"
  [[ -n "${root_luks}" ]] && cryptsetup luksDump "${root_luks}" | sed -n '/^Tokens:/,/^Digests:/p'
  echo
  echo "## system flatpaks (reinstalled declaratively by nix-flatpak)"
  flatpak list --system --app --columns=application 2>/dev/null || true
} >"${BACKUP_DIR}/MANIFEST.txt" 2>&1

sync
log "Backup complete: ${BACKUP_DIR}"
du -sh "${BACKUP_DIR}"/* 2>/dev/null || true

if [[ "${KEEP_MOUNTED}" != true ]]; then
  close_backup_hdd
fi
