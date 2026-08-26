{
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  desktopEnabled = get [ "desktop" "enable" ] true;
  sessionEnabled = get [ "desktop" "session" "enable" ] desktopEnabled;
  keyringEnable = get [ "desktop" "session" "keyring" "enable" ] true;
  compositors = [
    (get [ "desktop" "compositor" ] "hyprland")
  ]
  ++ get [ "desktop" "extraCompositors" ] [ ];
  hasPlasma = builtins.elem "plasma" compositors;
  python = pkgs.python3.withPackages (ps: [ ps.secretstorage ]);
  migratePy = ./migrate-secrets-to-kwallet.py;
  migrator = pkgs.writeShellApplication {
    name = "nagi-migrate-secrets-to-kwallet";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      pkgs.findutils
      pkgs.gawk
      pkgs.gnome-keyring
      pkgs.gnugrep
      pkgs.gnused
      pkgs.kdePackages.kwallet
      pkgs.procps
      pkgs.systemd
      python
    ];
    text = ''
      set -euo pipefail

      usage() {
        cat <<EOF
      Copy gnome-keyring Secret Service items into KWallet/ksecretd.

      Brave, T3 Code, and other --password-store=gnome-libsecret apps talk to
      whoever owns org.freedesktop.secrets. After a Hyprland → Plasma switch
      that is ksecretd, which does not have the old Chromium OSCrypt keys.

      Close Brave and T3 Code before running this, then reopen them after.
      EOF
      }

      if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
        usage
        exit 0
      fi

      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        echo "nagi-migrate-secrets-to-kwallet: no session bus" >&2
        exit 1
      fi

      running_apps=""
      if ${pkgs.procps}/bin/pgrep -u "$(id -u)" -x brave >/dev/null \
        || ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f '[b]rave( |$)' >/dev/null; then
        running_apps="$running_apps brave"
      fi
      if ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f '[t]3code' >/dev/null; then
        running_apps="$running_apps t3code"
      fi
      if [ -n "$running_apps" ] && [ "''${1:-}" != "--force" ]; then
        echo "nagi-migrate-secrets-to-kwallet: close these apps first:$running_apps" >&2
        echo "re-run with --force to continue anyway (they must still be restarted)" >&2
        exit 2
      fi

      workdir="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/nagi-secret-migrate.XXXXXX")"
      chmod 700 "$workdir"
      cleanup() {
        find "$workdir" -type f -exec shred -u {} + 2>/dev/null || true
        rm -rf "$workdir"
      }
      trap cleanup EXIT

      wait_secrets_owner() {
        local needle="$1"
        local comm
        for _ in $(seq 1 100); do
          comm="$(busctl --user status org.freedesktop.secrets 2>/dev/null | sed -n 's/^Comm=//p' || true)"
          if [ -n "$comm" ] && printf '%s' "$comm" | grep -q "$needle"; then
            return 0
          fi
          sleep 0.1
        done
        echo "timed out waiting for org.freedesktop.secrets owner matching $needle" >&2
        busctl --user status org.freedesktop.secrets >&2 || true
        return 1
      }

      echo "backing up the current Secret Service store"
      python ${migratePy} dump --output "$workdir/before.json" --summary

      echo "stopping ksecretd so gnome-keyring can own org.freedesktop.secrets"
      # Match on process comm only. -f would also kill this script.
      ps -u "$(id -u)" -o pid=,comm= | awk '$2 ~ /ksecretd/ {print $1}' | while read -r pid; do
        kill "$pid" || true
      done
      for _ in $(seq 1 100); do
        comm="$(busctl --user status org.freedesktop.secrets 2>/dev/null | sed -n 's/^Comm=//p' || true)"
        if [ -z "$comm" ] || ! printf '%s' "$comm" | grep -q ksecretd; then
          break
        fi
        sleep 0.1
      done

      # The daemon creates its control sockets here; --start refuses without it.
      mkdir -p "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring"
      chmod 700 "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring"
      gnome-keyring-daemon --start --components=secrets >/dev/null
      wait_secrets_owner gnome-keyring

      echo "dumping gnome-keyring"
      python ${migratePy} dump --output "$workdir/gnome.json" --summary
      count="$(python -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["items"]))' "$workdir/gnome.json")"
      if [ "$count" -eq 0 ]; then
        echo "gnome-keyring had 0 items; restoring ksecretd and aborting" >&2
        busctl --user call org.kde.ksecretd / org.freedesktop.DBus.Peer Ping >/dev/null 2>&1 \
          || ksecretd >/dev/null 2>&1 &
        exit 1
      fi

      echo "returning org.freedesktop.secrets to ksecretd"
      gnome-keyring-daemon --replace --components=pkcs11 >/dev/null || true
      sleep 0.3
      ksecretd >/dev/null 2>&1 &
      disown || true
      wait_secrets_owner ksecretd

      echo "importing $count gnome-keyring items into ksecretd"
      python ${migratePy} import --input "$workdir/gnome.json"

      echo "done. restart Brave and T3 Code so they reload OSCrypt keys from KWallet."
    '';
  };

  # Reverse direction of `migrator`: after returning to a Hyprland/Niri
  # session, gnome-keyring reclaims org.freedesktop.secrets but cannot see
  # items written under Plasma by ksecretd. Copy those back.
  migratorToGnome = pkgs.writeShellApplication {
    name = "nagi-migrate-secrets-to-gnome";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gnome-keyring
      pkgs.kdePackages.kwallet
      pkgs.procps
      pkgs.systemd
      python
    ];
    text = ''
      set -euo pipefail

      usage() {
        cat <<EOF
      Copy Secret Service items served by ksecretd/KWallet into gnome-keyring.

      Run this when leaving Plasma: apps using --password-store=gnome-libsecret
      (Brave, T3 Code) read OSCrypt keys from whoever owns
      org.freedesktop.secrets. Under Hyprland that is gnome-keyring again, which
      does not know keys created or changed while Plasma was active.

      Close Brave and T3 Code before running this, then reopen them after.
      EOF
      }

      if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
        usage
        exit 0
      fi

      owner_comm() {
        busctl --user list 2>/dev/null \
          | awk '$1 == "org.freedesktop.secrets" {print $4}'
      }

      wait_secrets_owner() {
        local needle="$1"
        local _ i=0
        while [ "$i" -lt 150 ]; do
          if printf '%s' "$(owner_comm)" | grep -q "$needle"; then
            return 0
          fi
          sleep 0.1
          i=$((i + 1))
        done
        echo "timed out waiting for secrets owner matching $needle" >&2
        return 1
      }

      find_pid() {
        # Match comm strictly; -f would match this script's own args.
        ps -u "$(id -u)" -o pid=,comm= \
          | awk -v n="$1" '$2 == n {print $1}'
      }

      echo "== backing up current Secret Service contents =="
      workdir="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/nagi-secret-migrate-gnome.XXXXXX")"
      chmod 700 "$workdir"
      cleanup() {
        find "$workdir" -type f -exec shred -u {} + 2>/dev/null || true
        rm -rf "$workdir"
      }
      trap cleanup EXIT

      current="$(owner_comm)"
      echo "current owner: ''${current:-none}"
      python ${migratePy} dump --output "$workdir/before.json"

      if ! printf '%s' "$current" | grep -q gnome-keyring; then
        echo "== stopping current Secret Service provider so ksecretd can claim the bus =="
      fi
      find_pid gnome-keyring-daemon | while read -r pid; do
        kill "$pid" || true
      done
      find_pid ksecretd | while read -r pid; do
        kill "$pid" || true
      done
      sleep 0.5

      echo "== starting ksecretd backed by KWallet =="
      kwalletd6 >/dev/null 2>&1 &
      disown || true
      sleep 1
      ksecretd >/dev/null 2>&1 &
      disown || true
      wait_secrets_owner ksecretd

      echo "== dumping KWallet-backed store =="
      python ${migratePy} dump --output "$workdir/kwallet.json" --summary
      count="$(python -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["items"]))' "$workdir/kwallet.json")"
      if [ "$count" -eq 0 ]; then
        echo "kwallet had 0 items; restarting gnome-keyring unchanged" >&2
      else
        echo "== handing org.freedesktop.secrets back to gnome-keyring =="
        find_pid ksecretd | xargs -r kill || true
        sleep 0.5
        # The daemon creates its control sockets here; --start refuses without it.
        mkdir -p "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring"
        chmod 700 "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring"
        gnome-keyring-daemon --start --components=pkcs11,secrets >/dev/null
        wait_secrets_owner gnome-keyring

        echo "== importing $count items into gnome-keyring =="
        python ${migratePy} import --input "$workdir/kwallet.json"
      fi

      echo "== final owner: $(owner_comm) =="
      echo "done. restart Brave and T3 Code so they reload OSCrypt keys from gnome-keyring."
    '';
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (desktopEnabled && hasPlasma) {
      # Keep the wallet open after PAM unlocks it at login. Without this,
      # Plasma prompts on first app access or after idle/screensaver close.
      xdg.configFile."kwalletrc" = {
        force = true;
        text = ''
          [Wallet]
          Close When Idle=false
          Close When Screensaver Starts=false
          Default Wallet=kdewallet
          Enabled=true
          First Use=false
          Idle Timeout=0
          Launch Manager=false
          Leave Manager Open=false
          Leave Open=true
          Prompt on Open=false
          Use One Wallet=true

          [org.freedesktop.secrets]
          apiEnabled=true
        '';
      };
    })
    (lib.mkIf (desktopEnabled && sessionEnabled && keyringEnable) {
      # Install both directions regardless of the active compositor: a
      # compositor switch is exactly when you need these, and gating on
      # hasPlasma removes the tool from the session you are switching away to.
      home.packages = [
        migrator
        migratorToGnome
      ];
    })
  ];
}
