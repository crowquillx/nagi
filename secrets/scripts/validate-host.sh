#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Validate nagi flake configuration for a selected host.

Usage:
  scripts/validate-host.sh <host> [--strict-statix] [--no-dry-run] [--flake-dir <path>]
  scripts/validate-host.sh --host <host> [--strict-statix] [--no-dry-run] [--flake-dir <path>]

Options:
  --host <host>       Host name under hosts/<host>
  --strict-statix     Fail if statix reports warnings/errors
  --no-dry-run        Skip nix build --dry-run checks
  --flake-dir <path>  Flake root (default: repo root derived from this script)
  -h, --help          Show this help
EOF
}

die() {
  printf 'validate-host: %s\n' "$1" >&2
  exit 1
}

log() {
  printf '\n==> %s\n' "$1"
}

run_cmd() {
  printf '+ %s\n' "$*"
  "$@"
}

HOST=""
STRICT_STATIX=0
DO_DRY_RUN=1
FLAKE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || die "--host requires a value"
      HOST="$2"
      shift 2
      ;;
    --strict-statix)
      STRICT_STATIX=1
      shift
      ;;
    --no-dry-run)
      DO_DRY_RUN=0
      shift
      ;;
    --flake-dir)
      [[ $# -ge 2 ]] || die "--flake-dir requires a value"
      FLAKE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      if [[ -z "$HOST" ]]; then
        HOST="$1"
      else
        die "unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -n "$HOST" ]] || die "host is required (use --host <host> or positional host)"

if [[ -z "$FLAKE_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  FLAKE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

[[ -f "${FLAKE_DIR}/flake.nix" ]] || die "flake.nix not found in ${FLAKE_DIR}"
[[ -d "${FLAKE_DIR}/hosts/${HOST}" ]] || die "unknown host '${HOST}' (expected ${FLAKE_DIR}/hosts/${HOST})"

command -v rg >/dev/null 2>&1 || die "rg is required"
command -v nil >/dev/null 2>&1 || die "nil is required"
command -v statix >/dev/null 2>&1 || die "statix is required"
command -v nix >/dev/null 2>&1 || die "nix is required"

NIX_FLAGS=(
  --extra-experimental-features
  "nix-command flakes"
  --accept-flake-config
  --no-write-lock-file
)

FLAKE_REF="path:${FLAKE_DIR}"

log "Statix"
if ! run_cmd statix check "${FLAKE_DIR}"; then
  if [[ "${STRICT_STATIX}" -eq 1 ]]; then
    die "statix reported issues and --strict-statix is enabled"
  fi
  printf 'warning: statix reported issues (continuing; use --strict-statix to fail)\n' >&2
fi

log "nil diagnostics"
while IFS= read -r relpath; do
  run_cmd nil diagnostics "${FLAKE_DIR}/${relpath}"
done < <(cd "${FLAKE_DIR}" && rg --files -g '*.nix')

log "Flake/host evaluation"
run_cmd nix "${NIX_FLAGS[@]}" flake show "${FLAKE_REF}"
run_cmd nix "${NIX_FLAGS[@]}" eval "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath"
run_cmd nix "${NIX_FLAGS[@]}" eval "${FLAKE_REF}#homeConfigurations.${HOST}.activationPackage.drvPath"

if [[ "${DO_DRY_RUN}" -eq 1 ]]; then
  log "Dry-run builds"
  run_cmd nix "${NIX_FLAGS[@]}" build --dry-run "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.toplevel"
  run_cmd nix "${NIX_FLAGS[@]}" build --dry-run "${FLAKE_REF}#homeConfigurations.${HOST}.activationPackage"
fi

log "Done"
printf 'Validation succeeded for host %s\n' "${HOST}"
