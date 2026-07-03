#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [profile] [--user <username>] [--hostname <hostname>] [--flake-dir <path>] [--update-hardware]

Options:
  --user <username>  Primary user to create and activate Home Manager for
  --hostname <name>  Installed machine hostname written to hosts/<profile>/variables.nix
  --flake-dir <path> Absolute flake checkout path written to users.flakeDirectory
  --update-hardware  Also regenerate and overwrite hosts/<profile>/hardware-configuration.nix
  -h, --help         Show this help
EOF
}

HOST="default"
HOST_SET="false"
PRIMARY_USER_OVERRIDE=""
HOSTNAME_OVERRIDE=""
FLAKE_DIR_OVERRIDE=""
UPDATE_HARDWARE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || {
        echo "--user requires a value"
        usage
        exit 1
      }
      PRIMARY_USER_OVERRIDE="$2"
      shift 2
      ;;
    --hostname)
      [[ $# -ge 2 ]] || {
        echo "--hostname requires a value"
        usage
        exit 1
      }
      HOSTNAME_OVERRIDE="$2"
      shift 2
      ;;
    --flake-dir)
      [[ $# -ge 2 ]] || {
        echo "--flake-dir requires a value"
        usage
        exit 1
      }
      FLAKE_DIR_OVERRIDE="$2"
      shift 2
      ;;
    --update-hardware)
      UPDATE_HARDWARE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ "${HOST_SET}" == "true" ]]; then
        echo "Only one host may be provided."
        usage
        exit 1
      fi
      HOST="$1"
      HOST_SET="true"
      shift
      ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="${REPO_ROOT}/hosts/${HOST}"
HW_FILE="${HOST_DIR}/hardware-configuration.nix"
KEY_FILE="/var/lib/sops-nix/key.txt"
NIX_EXPERIMENTAL_FEATURES="nix-command flakes"
NIRI_SUBSTITUTER="https://niri.cachix.org"
NIRI_PUBLIC_KEY="niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
DETERMIMATE_SUBSTITUTER="https://install.determinate.systems"
DETERMIMATE_PUBLIC_KEY="cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
FLAKE_PATH="path:${REPO_ROOT}"
NIXOS_FLAKE_REF="${FLAKE_PATH}#${HOST}"

if [[ ! -d "${HOST_DIR}" ]]; then
  KNOWN_HOSTS="$(find "${REPO_ROOT}/hosts" -mindepth 1 -maxdepth 1 -type d ! -name 'common' -printf '%f\n' | sort | paste -sd', ' -)"
  echo "Unknown host '${HOST}'. Expected one of: ${KNOWN_HOSTS}."
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (or with sudo) so hardware config and rebuild can run."
  exit 1
fi

VARIABLES_FILE="${HOST_DIR}/variables.nix"
read_var() {
  local name="$1"
  sed -nE "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\\1/p" "${VARIABLES_FILE}" | head -n1
}

validate_user() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] && [[ "$1" != "root" ]]
}

validate_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

write_string_assignment() {
  local name="$1"
  local value="$2"
  local file="$3"
  local escaped
  escaped="$(printf '%s' "${value}" | sed 's/[\/&]/\\&/g')"
  sed -i -E "0,/^([[:space:]]*)${name}[[:space:]]*=/s//\\1${name} = \"${escaped}\";/" "${file}"
}

insert_users_assignment() {
  local name="$1"
  local value="$2"
  local file="$3"
  local escaped
  escaped="$(printf '%s' "${value}" | sed 's/[\/&]/\\&/g')"
  sed -i -E "/^[[:space:]]*primary[[:space:]]*=/a\\    ${name} = \"${escaped}\";" "${file}"
}

CURRENT_PRIMARY_USER="$(read_var primary)"
CURRENT_HOSTNAME="$(read_var name)"
PRIMARY_USER="${PRIMARY_USER_OVERRIDE:-${CURRENT_PRIMARY_USER:-${SUDO_USER:-nagi}}}"
TARGET_HOSTNAME="${HOSTNAME_OVERRIDE:-${CURRENT_HOSTNAME:-${HOST}}}"
TARGET_FLAKE_DIR="${FLAKE_DIR_OVERRIDE:-${REPO_ROOT}}"

if ! validate_user "${PRIMARY_USER}"; then
  echo "Invalid username '${PRIMARY_USER}'."
  exit 1
fi

if ! validate_hostname "${TARGET_HOSTNAME}"; then
  echo "Invalid hostname '${TARGET_HOSTNAME}'."
  exit 1
fi

if [[ "${TARGET_FLAKE_DIR}" != /* ]] || [[ ! -f "${TARGET_FLAKE_DIR}/flake.nix" ]]; then
  echo "--flake-dir must be an absolute path containing flake.nix: ${TARGET_FLAKE_DIR}"
  exit 1
fi

write_string_assignment name "${TARGET_HOSTNAME}" "${VARIABLES_FILE}"
write_string_assignment primary "${PRIMARY_USER}" "${VARIABLES_FILE}"
if grep -qE '^[[:space:]]*flakeDirectory[[:space:]]*=' "${VARIABLES_FILE}"; then
  write_string_assignment flakeDirectory "${TARGET_FLAKE_DIR}" "${VARIABLES_FILE}"
else
  insert_users_assignment flakeDirectory "${TARGET_FLAKE_DIR}" "${VARIABLES_FILE}"
fi
if [[ -n "${SUDO_UID-}" ]] && [[ -n "${SUDO_GID-}" ]]; then
  chown "${SUDO_UID}:${SUDO_GID}" "${VARIABLES_FILE}"
fi

echo "Bootstrapping host: ${HOST}"
echo "Machine hostname: ${TARGET_HOSTNAME}"
echo "Primary user: ${PRIMARY_USER}"
echo "Repo root: ${REPO_ROOT}"

# Keep bootstrap self-contained even when /etc/nix/nix.conf is immutable
# (common on NixOS where /etc is declaratively managed).
export NIX_CONFIG="${NIX_CONFIG-}"$'\n'"experimental-features = ${NIX_EXPERIMENTAL_FEATURES}"
export NIX_CONFIG="${NIX_CONFIG}"$'\n'"extra-substituters = ${NIRI_SUBSTITUTER} ${DETERMIMATE_SUBSTITUTER}"
export NIX_CONFIG="${NIX_CONFIG}"$'\n'"extra-trusted-public-keys = ${NIRI_PUBLIC_KEY} ${DETERMIMATE_PUBLIC_KEY}"
echo "Using experimental features for this run: ${NIX_EXPERIMENTAL_FEATURES}"
echo "Using Niri cache for this run: ${NIRI_SUBSTITUTER}"
echo "Using Determinate cache for this run: ${DETERMIMATE_SUBSTITUTER}"

if command -v nixos-generate-config >/dev/null 2>&1; then
  TMP_HW="$(mktemp)"
  nixos-generate-config --show-hardware-config > "${TMP_HW}"

  if [[ "${UPDATE_HARDWARE}" == "true" ]] || ! grep -q 'fileSystems\."/"' "${HW_FILE}" 2>/dev/null; then
    cp "${TMP_HW}" "${HW_FILE}"
    if [[ "${UPDATE_HARDWARE}" == "true" ]]; then
      echo "Updated tracked ${HW_FILE} from current machine."
    else
      echo "Initialized ${HW_FILE} because no root filesystem was defined."
    fi
    if [[ -n "${SUDO_UID-}" ]] && [[ -n "${SUDO_GID-}" ]]; then
      chown "${SUDO_UID}:${SUDO_GID}" "${HW_FILE}"
    fi
  else
    echo "Skipping tracked hardware config update. Use --update-hardware to regenerate ${HW_FILE}."
  fi

  rm -f "${TMP_HW}"
else
  echo "nixos-generate-config not found; keeping existing hardware config files."
fi

if [[ ! -f "${KEY_FILE}" ]]; then
  echo "Creating sops age key at ${KEY_FILE}"
  mkdir -p "$(dirname "${KEY_FILE}")"
  nix --extra-experimental-features "${NIX_EXPERIMENTAL_FEATURES}" \
    shell --accept-flake-config nixpkgs#age --command age-keygen -o "${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
else
  echo "sops age key already exists at ${KEY_FILE}"
fi

echo "Running nixos-rebuild for ${HOST}"
cd "${REPO_ROOT}"
REBUILD_ACTION="switch"
if ! findmnt -rn /boot >/dev/null 2>&1; then
  REBUILD_ACTION="test"
  echo "/boot is not mounted; using nixos-rebuild test to avoid bootloader install failure."
  echo "Fix boot mounts, then run: sudo nixos-rebuild switch --accept-flake-config --option extra-substituters ${DETERMIMATE_SUBSTITUTER} --option extra-trusted-public-keys ${DETERMIMATE_PUBLIC_KEY} --flake ${NIXOS_FLAKE_REF}"
fi
nixos-rebuild "${REBUILD_ACTION}" --accept-flake-config \
  --option extra-substituters "${DETERMIMATE_SUBSTITUTER}" \
  --option extra-trusted-public-keys "${DETERMIMATE_PUBLIC_KEY}" \
  --flake "${NIXOS_FLAKE_REF}"

echo "Running Home Manager activation for ${HOST} as ${PRIMARY_USER}"
if ! id "${PRIMARY_USER}" >/dev/null 2>&1; then
  echo "Primary user '${PRIMARY_USER}' does not exist on this system; skipping Home Manager activation."
else
  HM_OUT_LINK="/tmp/nagi-hm-${HOST}"
  rm -f "${HM_OUT_LINK}"
  sudo -H -u "${PRIMARY_USER}" \
    nix --extra-experimental-features "${NIX_EXPERIMENTAL_FEATURES}" \
    build --accept-flake-config "${FLAKE_PATH}#homeConfigurations.${HOST}.activationPackage" \
    --out-link "${HM_OUT_LINK}"
  sudo -H -u "${PRIMARY_USER}" "${HM_OUT_LINK}/activate"
fi

echo
echo "Bootstrap complete."
echo "Next:"
echo "1) Add encrypted secrets under ./secrets and update .sops.yaml recipients."
echo "2) Re-run: sudo nixos-rebuild switch --accept-flake-config --option extra-substituters ${DETERMIMATE_SUBSTITUTER} --option extra-trusted-public-keys ${DETERMIMATE_PUBLIC_KEY} --flake ${NIXOS_FLAKE_REF}"
