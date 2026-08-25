# hdr-game: switches the designated HDR display to HDR+WCG while a wrapped
# game runs, then restores the original display state. Intended for Steam
# Launch Options: `hdr-game %command%`.
{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  cfgEnable = get [
    "desktop"
    "hdrGame"
    "enable"
  ] false;
  monitorUuid = get [
    "desktop"
    "hdrGame"
    "monitor"
    "uuid"
  ] "";
  monitorModel = get [
    "desktop"
    "hdrGame"
    "monitor"
    "model"
  ] "";
  monitorSerial = get [
    "desktop"
    "hdrGame"
    "monitor"
    "serial"
  ] "";
  monitorFallback = get [
    "desktop"
    "hdrGame"
    "monitor"
    "fallbackConnector"
  ] "";
  notifyEnable = get [
    "desktop"
    "hdrGame"
    "notifications"
    "enable"
  ] false;

  hasIdentityHint = monitorUuid != "" || (monitorModel != "" && monitorSerial != "");
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfgEnable && !hasIdentityHint) {
      assertions = [
        {
          assertion = false;
          message = "desktop.hdrGame requires desktop.hdrGame.monitor.uuid or both monitor.model and monitor.serial.";
        }
      ];
    })
    (lib.mkIf cfgEnable {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "hdr-game";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jq
            pkgs.kdePackages.libkscreen
            pkgs.libnotify
            pkgs.util-linux
          ];
          text = ''
            set -euo pipefail

            MONITOR_UUID=${lib.escapeShellArg monitorUuid}
            MONITOR_MODEL=${lib.escapeShellArg monitorModel}
            MONITOR_SERIAL=${lib.escapeShellArg monitorSerial}
            FALLBACK_CONNECTOR=${lib.escapeShellArg monitorFallback}
            if ${lib.boolToString notifyEnable}; then NOTIFY_ENABLED=1; else NOTIFY_ENABLED=0; fi

            KSCREEN_TIMEOUT_S=8
            POLL_STEP_MS=150
            POLL_TIMEOUT_MS=12000
            STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/hdr-game"
            LOCK_FILE="$STATE_DIR/lock"
            COUNT_FILE="$STATE_DIR/count"
            SNAPSHOT_FILE="$STATE_DIR/state"

            DEBUG=0
            USE_ATOMIC=""
            TARGET=""
            OUTPUTS_JSON=""
            CHILD_PID=0
            SIG_COUNT=0
            DID_START=0

            log() { printf 'hdr-game: %s\n' "$*" >&2; }
            debug() { [ "$DEBUG" -eq 1 ] && log "debug: $*"; return 0; }
            notify_user() {
              if [ "$NOTIFY_ENABLED" -eq 1 ]; then
                timeout 5 notify-send -u low -a hdr-game "$1" "$2" >/dev/null 2>&1 || true
              fi
            }
            notify_error() {
              if [ "$NOTIFY_ENABLED" -eq 1 ]; then
                timeout 5 notify-send -u critical -a hdr-game "$1" "$2" >/dev/null 2>&1 || true
              fi
            }
            die() {
              log "ERROR: $*"
              notify_error "hdr-game failed" "$*"
              exit 1
            }
            usage() {
              cat <<'EOF'
            hdr-game - run a command with the HDR display switched to HDR+WCG

            Usage:
              hdr-game [--debug] COMMAND [ARGS...]   run COMMAND with HDR enabled, restore afterwards
              hdr-game --status                      show resolved output, live state, holders
              hdr-game --on                          manually enable HDR+WCG on the target
              hdr-game --off                         manually disable HDR+WCG on the target
              hdr-game --restore                     recover saved state after a crashed wrapper
              hdr-game --help                        this help

            Environment:
              Game-side variables (PROTON_ENABLE_HDR etc.) pass through untouched.
              Set HDR_GAME_DEBUG=1 or pass --debug for verbose logging.
            EOF
            }

            # ---------- kscreen helpers ----------

            kscreen() {
              timeout "$KSCREEN_TIMEOUT_S" kscreen-doctor "$@"
            }

            refresh_json() {
              OUTPUTS_JSON=$(timeout "$KSCREEN_TIMEOUT_S" kscreen-doctor -j 2>/dev/null || true)
              [ -n "$OUTPUTS_JSON" ]
            }

            # Field values are stringified so that JSON false survives.
            get_field() {
              jq -r --arg n "$TARGET" --arg f "$1" \
                'first(.outputs[] | select(.name == $n) | .[$f]) | if . == null then "" else tostring end' \
                <<<"$OUTPUTS_JSON"
            }

            output_map() {
              kscreen -o 2>/dev/null \
                | sed -e 's/\x1b\[[0-9;]*m//g' \
                | grep '^Output:' || true
            }

            # connector_matches_edid NAME
            # 0: sysfs EDID matches configured model/serial
            # 1: sysfs EDID readable but does not match
            # 2: cannot verify (no sysfs EDID)
            connector_matches_edid() {
              local p found=""
              for p in /sys/class/drm/card*-"$1"/edid; do
                if [ -e "$p" ]; then found="$p"; break; fi
              done
              if [ -z "$found" ] || [ ! -r "$found" ]; then return 2; fi
              # sysfs EDID files report stat size 0; read to check emptiness.
              if [ "$(wc -c <"$found" 2>/dev/null || true)" = "0" ]; then return 2; fi
              local tokens
              tokens=$(tr -c '[:print:]' '\n' <"$found")
              if [ -n "$MONITOR_SERIAL" ] && ! grep -qxF "$MONITOR_SERIAL" <<<"$tokens"; then return 1; fi
              if [ -n "$MONITOR_MODEL" ] && ! grep -qxF "$MONITOR_MODEL" <<<"$tokens"; then return 1; fi
              return 0
            }

            resolve_target() {
              local map name uuid_name candidate match_count
              map=$(output_map)
              debug "outputs: $(printf '%s' "$map" | tr '\n' ';')"
              refresh_json || die "cannot query KScreen (is Plasma Wayland running?)"

              # 1. Known stable KScreen UUID.
              if [ -n "$MONITOR_UUID" ]; then
                uuid_name=$(printf '%s\n' "$map" | awk -v u="$MONITOR_UUID" '$4 == u { print $3 }')
                if [ -n "$uuid_name" ]; then
                  connector_matches_edid "$uuid_name"
                  case $? in
                    0)
                      TARGET=$uuid_name
                      debug "resolved via UUID $MONITOR_UUID -> $TARGET (EDID verified)"
                      return 0
                      ;;
                    2)
                      TARGET=$uuid_name
                      debug "resolved via UUID $MONITOR_UUID -> $TARGET (EDID unavailable, trusting UUID)"
                      return 0
                      ;;
                    1) debug "UUID $MONITOR_UUID resolves to $uuid_name but its EDID does not match; falling back" ;;
                  esac
                else
                  debug "UUID $MONITOR_UUID not present right now"
                fi
              fi

              # 2. Live EDID scan over all connected KScreen outputs.
              candidate=""
              match_count=0
              while IFS= read -r name; do
                [ -n "$name" ] || continue
                if connector_matches_edid "$name"; then
                  candidate=$name
                  match_count=$((match_count + 1))
                fi
              done < <(jq -r '.outputs[] | select(.connected == true) | .name' <<<"$OUTPUTS_JSON")
              if [ "$match_count" -gt 1 ]; then
                die "monitor identity is ambiguous: $match_count outputs match model/serial"
              fi
              if [ -n "$candidate" ]; then
                TARGET=$candidate
                debug "resolved via live EDID scan -> $TARGET"
                return 0
              fi

              # 3. Explicit fallback connector; accepted only with matching EDID.
              if [ -n "$FALLBACK_CONNECTOR" ] \
                && printf '%s\n' "$map" | awk '{ print $3 }' | grep -qxF "$FALLBACK_CONNECTOR" \
                && [ "$(connector_matches_edid "$FALLBACK_CONNECTOR"; printf '%s' $?)" = "0" ]; then
                TARGET=$FALLBACK_CONNECTOR
                debug "resolved via fallback connector -> $TARGET (EDID verified)"
                return 0
              fi

              die "expected display not found (model=''${MONITOR_MODEL:-any} serial=''${MONITOR_SERIAL:-any}); refusing to touch any output"
            }

            ensure_capable() {
              refresh_json || die "cannot query KScreen state"
              if [ "$(get_field hdr)" = "" ] && [ "$(get_field wcg)" = "" ]; then
                die "output $TARGET does not support HDR/WCG"
              fi
              if [ "$(get_field enabled)" != "true" ]; then
                die "output $TARGET is disabled; refusing to modify a disabled output"
              fi
            }

            # Try an operation, then confirm KWin actually applied it.
            # USE_ATOMIC is detected behaviorally: the atomic hdrAndWcg op is
            # attempted first and kept if it verifies; otherwise separate
            # hdr/wcg ops are used instead.
            apply_state() {
              local want_h="$1" want_w="$2" op
              debug "requesting hdr=$want_h wcg=$want_w on $TARGET"
              if [ "$USE_ATOMIC" != "0" ]; then
                op=disable
                if [ "$want_h" = "true" ]; then op=enable; fi
                kscreen "output.$TARGET.hdrAndWcg.$op" >/dev/null 2>&1 \
                  || log "warning: kscreen-doctor returned nonzero for hdrAndWcg.$op"
                if poll_state "$want_h" "$want_w"; then
                  USE_ATOMIC=1
                  debug "atomic hdrAndWcg op verified"
                  return 0
                fi
                USE_ATOMIC=0
                log "atomic hdrAndWcg op did not take effect; retrying with separate hdr/wcg ops"
              fi
              if [ "$want_h" = "true" ]; then op=enable; else op=disable; fi
              kscreen "output.$TARGET.hdr.$op" >/dev/null 2>&1 || true
              if [ "$want_w" = "true" ]; then op=enable; else op=disable; fi
              kscreen "output.$TARGET.wcg.$op" >/dev/null 2>&1 || true
              poll_state "$want_h" "$want_w"
            }

            poll_state() {
              local want_h="$1" want_w="$2" waited_ms=0 h w
              while :; do
                refresh_json || true
                h=$(get_field hdr)
                w=$(get_field wcg)
                if [ "$h" = "$want_h" ] && [ "$w" = "$want_w" ]; then
                  debug "confirmed hdr=$h wcg=$w after ''${waited_ms}ms"
                  return 0
                fi
                if [ "$waited_ms" -ge "$POLL_TIMEOUT_MS" ]; then
                  log "timed out waiting for hdr=$want_h wcg=$want_w (last seen hdr=$h wcg=$w)"
                  return 1
                fi
                sleep 0.15
                waited_ms=$((waited_ms + POLL_STEP_MS))
              done
            }

            # ---------- shared-state bookkeeping (flock refcount) ----------

            acquire_lock() {
              mkdir -p "$STATE_DIR"
              chmod 700 "$STATE_DIR" 2>/dev/null || true
              exec 9>"$LOCK_FILE"
              flock -w 10 9 || return 1
            }

            read_snapshot() {
              SNAP_H=$(sed -n 's/^hdr=\([a-z]*\) .*/\1/p' "$SNAPSHOT_FILE")
              SNAP_W=$(sed -n 's/^hdr=[a-z]* wcg=\([a-z]*\)$/\1/p' "$SNAPSHOT_FILE")
              [ -n "$SNAP_H" ] && [ -n "$SNAP_W" ]
            }

            begin_shared() {
              local count
              count=$(cat "$COUNT_FILE" 2>/dev/null || true)
              if [ -z "$count" ] || [ "$count" -le 0 ]; then
                ensure_capable
                SNAP_H=$(get_field hdr)
                SNAP_W=$(get_field wcg)
                printf 'hdr=%s wcg=%s\n' "$SNAP_H" "$SNAP_W" >"$SNAPSHOT_FILE"
                printf '1\n' >"$COUNT_FILE"
                DID_START=1
                debug "first holder; snapshot hdr=$SNAP_H wcg=$SNAP_W"
                if [ "$SNAP_H" = "true" ] && [ "$SNAP_W" = "true" ]; then
                  debug "HDR+WCG already active; nothing to enable"
                else
                  if ! apply_state true true; then
                    apply_state "$SNAP_H" "$SNAP_W" || true
                    die "failed to enable HDR+WCG on $TARGET; restored previous state"
                  fi
                  notify_user "hdr-game" "HDR enabled on $TARGET"
                fi
              else
                printf '%s\n' "$((count + 1))" >"$COUNT_FILE"
                DID_START=1
                debug "another wrapper holds the display (holders now $((count + 1)))"
              fi
            }

            # shellcheck disable=SC2329
            end_shared() {
              local count
              count=$(cat "$COUNT_FILE" 2>/dev/null || true)
              if [ -z "$count" ] || [ "$count" -le 0 ]; then
                debug "no holder count left; nothing to do"
                rm -f "$COUNT_FILE"
                return 0
              fi
              if [ "$count" -gt 1 ]; then
                printf '%s\n' "$((count - 1))" >"$COUNT_FILE"
                debug "other wrappers still hold the display (holders now $((count - 1))); keeping HDR"
                return 0
              fi
              rm -f "$COUNT_FILE"
              if [ -f "$SNAPSHOT_FILE" ] && read_snapshot; then
                debug "restoring snapshot hdr=$SNAP_H wcg=$SNAP_W"
                apply_state "$SNAP_H" "$SNAP_W" \
                  || log "warning: could not confirm restored state (hdr=$SNAP_H wcg=$SNAP_W)"
                rm -f "$SNAPSHOT_FILE"
                notify_user "hdr-game" "Display state restored"
              else
                debug "no readable snapshot to restore"
                rm -f "$SNAPSHOT_FILE"
              fi
            }

            # shellcheck disable=SC2329
            cleanup() {
              local rc=$?
              trap - EXIT INT TERM HUP
              if [ "$CHILD_PID" -gt 0 ] && kill -0 "$CHILD_PID" 2>/dev/null; then
                kill -TERM "$CHILD_PID" 2>/dev/null || true
                wait "$CHILD_PID" 2>/dev/null || true
              fi
              if [ "$DID_START" -eq 1 ]; then
                if acquire_lock; then
                  end_shared
                else
                  log "ERROR: could not take cleanup lock; run: hdr-game --restore"
                fi
              fi
              exit "$rc"
            }

            # shellcheck disable=SC2329
            forward_signal() {
              SIG_COUNT=$((SIG_COUNT + 1))
              debug "received signal; forwarding to child"
              if [ "$CHILD_PID" -gt 0 ] && kill -0 "$CHILD_PID" 2>/dev/null; then
                kill -s "$1" "$CHILD_PID" 2>/dev/null || true
              fi
              if [ "$SIG_COUNT" -ge 3 ] && [ "$CHILD_PID" -gt 0 ]; then
                kill -KILL "$CHILD_PID" 2>/dev/null || true
              fi
            }

            # ---------- subcommands ----------

            show_status() {
              resolve_target
              ensure_capable
              refresh_json || true
              local holders saved mode_id mode_name
              holders=$(cat "$COUNT_FILE" 2>/dev/null || true)
              [ -n "$holders" ] || holders=0
              saved="none"
              [ -f "$SNAPSHOT_FILE" ] && saved=$(cat "$SNAPSHOT_FILE")
              mode_id=$(get_field currentModeId)
              mode_name=$(jq -r --arg n "$TARGET" --arg id "$mode_id" \
                'first(.outputs[] | select(.name == $n) | .modes[] | select(.id == $id) | .name)' \
                <<<"$OUTPUTS_JSON")
              printf 'output:         %s\n' "$TARGET"
              printf 'mode:           %s\n' "$mode_name"
              printf 'hdr:            %s\n' "$(get_field hdr)"
              printf 'wcg:            %s\n' "$(get_field wcg)"
              printf 'active holders: %s\n' "$holders"
              printf 'saved snapshot: %s\n' "$saved"
            }

            force_restore() {
              acquire_lock || die "could not acquire state lock"
              if [ -f "$SNAPSHOT_FILE" ] && read_snapshot; then
                resolve_target
                ensure_capable
                log "restoring saved state hdr=$SNAP_H wcg=$SNAP_W on $TARGET"
                apply_state "$SNAP_H" "$SNAP_W" || die "could not confirm restored state"
                rm -f "$SNAPSHOT_FILE" "$COUNT_FILE"
                log "done"
              elif [ -f "$COUNT_FILE" ]; then
                rm -f "$COUNT_FILE"
                log "cleared stale holder count without snapshot; nothing to restore"
              else
                log "nothing to restore (no stale state found)"
              fi
            }

            manual_toggle() {
              local holders
              resolve_target
              ensure_capable
              holders=$(cat "$COUNT_FILE" 2>/dev/null || true)
              if [ -n "$holders" ] && [ "$holders" -gt 0 ]; then
                log "warning: $holders wrapped game(s) are holding this display"
              fi
              case "$1" in
                on)
                  apply_state true true || die "failed to enable HDR+WCG"
                  log "HDR+WCG enabled on $TARGET"
                  ;;
                off)
                  apply_state false false || die "failed to disable HDR+WCG"
                  log "HDR+WCG disabled on $TARGET"
                  ;;
              esac
            }

            # ---------- argument handling ----------

            if [ "''${HDR_GAME_DEBUG:-}" = "1" ]; then DEBUG=1; fi

            ACTION=""
            while [ $# -gt 0 ]; do
              case "$1" in
                --debug) DEBUG=1 ;;
                --help | -h)
                  usage
                  exit 0
                  ;;
                --status | --on | --off | --restore)
                  if [ -n "$ACTION" ]; then
                    usage >&2
                    exit 64
                  fi
                  ACTION=$1
                  ;;
                *)
                  break
                  ;;
              esac
              shift
            done

            case "$ACTION" in
              --status)
                show_status
                exit 0
                ;;
              --restore)
                force_restore
                exit 0
                ;;
              --on)
                manual_toggle on
                exit 0
                ;;
              --off)
                manual_toggle off
                exit 0
                ;;
            esac

            if [ $# -lt 1 ]; then
              usage >&2
              exit 64
            fi

            if ! command -v kscreen-doctor >/dev/null 2>&1; then
              die "kscreen-doctor not available"
            fi
            if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -z "''${DISPLAY:-}" ]; then
              die "neither WAYLAND_DISPLAY nor DISPLAY set; refusing to guess compositor state"
            fi

            resolve_target
            ensure_capable

            trap cleanup EXIT
            trap 'forward_signal INT' INT
            trap 'forward_signal TERM' TERM
            trap 'forward_signal HUP' HUP

            acquire_lock
            begin_shared

            "$@" &
            CHILD_PID=$!
            debug "child pid $CHILD_PID: $*"

            GAME_RC=0
            INTERRUPTS=0
            while :; do
              wait "$CHILD_PID" && GAME_RC=0 || GAME_RC=$?
              if [ "$GAME_RC" -ge 128 ] && kill -0 "$CHILD_PID" 2>/dev/null; then
                INTERRUPTS=$((INTERRUPTS + 1))
                debug "wait interrupted (rc=$GAME_RC); child still alive"
                if [ "$INTERRUPTS" -ge 20 ]; then
                  kill -KILL "$CHILD_PID" 2>/dev/null || true
                fi
                continue
              fi
              break
            done
            debug "child exited rc=$GAME_RC"

            exit "$GAME_RC"
          '';
        })
      ];
    })
  ];
}
