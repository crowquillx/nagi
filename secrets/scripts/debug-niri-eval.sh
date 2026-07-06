#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-tanlappy}"
USER_NAME="${2:-tan}"
FLAKE_REF="${3:-.}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/nagi-niri-debug-${HOST}-${USER_NAME}-${STAMP}.log"

run_eval() {
  local title="$1"
  shift
  echo "=== ${title} ==="
  nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --show-trace "$@"
  echo
}

run_eval_raw() {
  local title="$1"
  shift
  echo "=== ${title} ==="
  nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --show-trace --raw "$@"
  echo
}

run_eval_optional() {
  local title="$1"
  shift
  echo "=== ${title} (optional) ==="
  if nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --show-trace "$@"; then
    :
  else
    echo "optional check failed; continuing"
  fi
  echo
}

run_eval_optional_raw() {
  local title="$1"
  shift
  echo "=== ${title} (optional) ==="
  if nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --show-trace --raw "$@"; then
    :
  else
    echo "optional check failed; continuing"
  fi
  echo
}

{
  echo "Debug started: $(date --iso-8601=seconds)"
  echo "Host: ${HOST}"
  echo "User: ${USER_NAME}"
  echo "Flake: ${FLAKE_REF}"
  echo

  run_eval \
    "1) HM programs.niri.package option (nixosConfigurations path)" \
    "${FLAKE_REF}#nixosConfigurations.${HOST}.config.home-manager.users.${USER_NAME}.programs.niri.package"

  run_eval_optional \
    "2) HM programs.niri.settings.outputs (homeConfigurations path)" \
    "${FLAKE_REF}#homeConfigurations.${HOST}.config.programs.niri.settings.outputs"

  run_eval_optional \
    "3) HM programs.noctalia-shell.systemd.enable (homeConfigurations path)" \
    "${FLAKE_REF}#homeConfigurations.${HOST}.config.programs.noctalia-shell.systemd.enable"

  run_eval_optional \
    "4) HM programs.noctalia-shell.settings (homeConfigurations path)" \
    "${FLAKE_REF}#homeConfigurations.${HOST}.config.programs.noctalia-shell.settings"

  run_eval_raw \
    "5) NixOS programs.niri.package drvPath" \
    "${FLAKE_REF}#nixosConfigurations.${HOST}.config.programs.niri.package.drvPath"

  run_eval_optional \
    "6) NixOS displayManager defaultSession" \
    "${FLAKE_REF}#nixosConfigurations.${HOST}.config.services.displayManager.defaultSession"

  run_eval_optional_raw \
    "7) Home session XDG_CURRENT_DESKTOP" \
    "${FLAKE_REF}#homeConfigurations.${HOST}.config.home.sessionVariables.XDG_CURRENT_DESKTOP"
} 2>&1 | tee "${LOG_FILE}"

echo
echo "Saved log: ${LOG_FILE}"
