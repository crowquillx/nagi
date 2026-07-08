{ pkgs, inputs, ... }:
let
  homeManagerPkg =
    let
      pkgsBySystem = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system};
    in
    pkgsBySystem.home-manager or pkgsBySystem.default;
  tcli = pkgs.writeShellScriptBin "tcli" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Global: set by --force/-f to skip dirty-tree confirmation.
    FORCE=0
    # Global: trust repo-declared cache settings by default.
    ACCEPT_FLAKE_CONFIG=1
    FILTERED_ARGS=()

    usage() {
      cat <<'EOF'
    tcli - nagi helper for flake updates, rebuilds, and garbage collection

    Usage:
      tcli
      tcli [switch|build|test|boot] [host] [-- <nh-args...>]
      tcli rebuild [switch|build|test|boot] [host]
      tcli update [host] [-- <nh-args...>]
      tcli upgrade [host] [-- <nh-args...>]
      tcli rollback
      tcli gens
      tcli why <pkg> [host]
      tcli doctor [host]
      tcli hosts
      tcli check
      tcli gc [-- <nh-args...>]
      tcli nh os [switch|build|test|boot] [host] [-- <nh-args...>]
      tcli nh home [switch|build] [host] [-- <nh-args...>]
      tcli nh clean [-- <nh-args...>]

    Flags:
      --force, -f              Skip the uncommitted-state confirmation prompt.
      --accept-flake-config    Trust flake-configured substituters and public keys (default).

    Hardening:
      - check:             statix lint + orphan module scan + nix flake check --no-build
      - doctor:            full diagnostic: git sync, orphans, statix, flake eval, stale result
      - switch/boot/test:  warn if working tree has uncommitted changes
      - build/switch/test: show closure diff with added/removed service units
      - switch/boot/test:  auto-run statix check before activation
      - why:               trace why a package is (or is not) in the system closure

    Notes:
      - Host defaults to current hostname.
      - Flake path defaults to current repo root; override with NAGI_FLAKE_DIR.
      - Bare `tcli` defaults to `switch` on the current host.
      - Rebuilds run through `nh os`, so Home Manager is still applied via NixOS module integration.
    EOF
    }

    die() {
      printf 'tcli: %s\n' "$1" >&2
      exit 1
    }

    resolve_flake_dir() {
      if [[ -n "''${NAGI_FLAKE_DIR-}" ]]; then
        [[ -f "''${NAGI_FLAKE_DIR}/flake.nix" ]] || die "NAGI_FLAKE_DIR does not contain flake.nix: ''${NAGI_FLAKE_DIR}"
        printf '%s\n' "''${NAGI_FLAKE_DIR}"
        return
      fi

      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -f "''${git_root}/flake.nix" ]]; then
        printf '%s\n' "''${git_root}"
        return
      fi

      if [[ -f "./flake.nix" ]]; then
        pwd
        return
      fi

      if [[ -f "$HOME/nagi/flake.nix" ]]; then
        printf '%s\n' "$HOME/nagi"
        return
      fi

      die "could not find nagi flake. Run inside the repo, or set NAGI_FLAKE_DIR."
    }

    resolve_host() {
      if [[ -n "''${1-}" ]]; then
        printf '%s\n' "$1"
        return
      fi

      if [[ -f /etc/hostname ]]; then
        tr -d '\n' </etc/hostname
        return
      fi

      hostname
    }

    # Print the git HEAD sha and dirty-file count for build context.
    print_git_context() {
      local flake_dir="$1"
      if (cd "$flake_dir" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        local sha dirty_count
        sha=$(cd "$flake_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        dirty_count=$(cd "$flake_dir" && git status --porcelain 2>/dev/null | wc -l || echo 0)
        if [[ "$dirty_count" -eq 0 ]]; then
          printf '==> Building from git %s (clean)\n' "$sha"
        else
          printf '==> Building from git %s (%s uncommitted change(s))\n' "$sha" "$dirty_count"
        fi
      fi
    }

    # Print a note if building for a host that does not match the running machine.
    print_host_note() {
      local host="$1"
      local current_host
      current_host=$(resolve_host "")
      if [[ "$host" != "$current_host" ]]; then
        printf '==> NOTE: building for %s, but running on %s\n' "$host" "$current_host"
      fi
    }

    # After build/switch, show added/removed systemd units prominently.
    # This makes "one-line edit nuked 1 GiB of services" immediately obvious.
    summarize_closure_diff() {
      local old="$1"
      local new="$2"

      [[ -n "$old" && -n "$new" && "$old" != "$new" ]] || return 0

      local diff_output
      diff_output="$(nix store diff-closures "$old" "$new" 2>/dev/null)" || {
        printf '  (could not compute closure diff)\n'
        return 0
      }

      printf '\n==> Closure diff (service units)\n'

      echo "$diff_output" | grep -iE '^SIZE[[:space:]]*:|Size:' | head -1 | sed 's/^[[:space:]]*/  /' || true

      local units
      units=$(echo "$diff_output" | grep -E 'unit-.*\.(service|socket|timer|target)' || true)
      if [[ -n "$units" ]]; then
        echo "$units" | sed 's/^[[:space:]]*/  /'
      else
        printf '  (no service unit changes)\n'
      fi
    }

    # Warn before activating a system built from uncommitted state.
    # Catches the "lost working-tree edits" class of incident.
    check_dirty_tree() {
      local flake_dir="$1"

      [[ "$FORCE" -eq 1 ]] && return 0

      (cd "$flake_dir" && git rev-parse --is-inside-work-tree >/dev/null 2>&1) || return 0

      local dirty
      dirty=$(cd "$flake_dir" && git status --porcelain 2>/dev/null || true)
      [[ -n "$dirty" ]] || return 0

      printf '\n'
      printf '  ! WARNING: working tree has uncommitted changes.\n'
      printf '    The system you are about to activate is built from\n'
      printf '    UNCOMMITTED state. If these changes are lost, future\n'
      printf '    rebuilds will produce a different system.\n'
      printf '\n'
      printf '    Uncommitted files:\n'
      echo "$dirty" | head -10 | sed 's/^/      /'
      local count
      count=$(echo "$dirty" | wc -l)
      if [[ "$count" -gt 10 ]]; then
        printf '      ... and %d more\n' "$((count - 10))"
      fi
      printf '\n  Continue? [y/N] '
      local response
      read -r response || die "aborted by user"
      case "$response" in
        y|Y|yes|YES) ;;
        *) die "aborted by user" ;;
      esac
    }

    # Quick statix check before activation. Warns on failure, does not block.
    auto_statix() {
      local flake_dir="$1"
      if command -v statix >/dev/null 2>&1; then
        local output=""
        output="$(statix check "$flake_dir" 2>&1)" || {
          printf '  ! WARNING: statix check failed. Run `tcli check` for details.\n'
          # Show the first few lines of statix output to make debugging easier.
          printf '%s\n' "$output" | head -5 | sed 's/^/      /'
        }
      fi
    }

    # Find .nix files under modules/ not referenced by any other .nix file.
    # Catches modules that exist but were never added to stacks.nix or
    # imported by a parent module.
    scan_orphan_modules() {
      local flake_dir="$1"
      local orphans=0

      while IFS= read -r f; do
        local base
        base="$(basename "$f")"
        # default.nix is auto-loaded by directory imports.
        [[ "$base" == "default.nix" ]] && continue
        # stacks.nix is the manifest itself.
        [[ "$base" == "stacks.nix" ]] && continue

        local found
        found=$(grep -rl --include='*.nix' -- "$base" \
          "$flake_dir/modules" "$flake_dir/hosts" "$flake_dir/users" \
          "$flake_dir/flake.nix" 2>/dev/null \
          | grep -v "^''${f}$" || true)
        if [[ -z "$found" ]]; then
          printf '    ORPHAN: %s\n' "''${f#$flake_dir/}"
          orphans=$((orphans + 1))
        fi
      done < <(find "$flake_dir/modules/nixos" "$flake_dir/modules/home" \
                  -name '*.nix' -type f 2>/dev/null | sort)

      if [[ "$orphans" -eq 0 ]]; then
        printf '    no orphan modules detected\n'
      else
        printf '    %d orphan module(s) found - add to modules/combined/stacks.nix or import from a parent.\n' "$orphans"
      fi
      return "$orphans"
    }

    run_check() {
      local flake_dir="$1"
      local rc=0

      printf '==> statix check\n'
      if command -v statix >/dev/null 2>&1; then
        statix check "$flake_dir" || rc=1
      else
        printf '  (statix not found, skipping)\n'
      fi

      printf '==> orphan module scan\n'
      scan_orphan_modules "$flake_dir" || rc=1

      printf '==> nix flake check --no-build\n'
      local nix_args=()
      mapfile -t nix_args < <(nix_extra_args)
      nix flake check "$flake_dir" --no-build "''${nix_args[@]}" || rc=1

      return "$rc"
    }

    run_nh_os() {
      local action="$1"
      local host="$2"
      local flake_ref="$3"
      shift 3

      case "$action" in
        switch|build|test|boot) ;;
        *) die "invalid nh os action: $action (expected switch|build|test|boot)" ;;
      esac

      local old_system=""
      if [[ -e /run/current-system ]]; then
        old_system="$(readlink -f /run/current-system)"
      fi

      case "$action" in
        switch|boot|test)
          auto_statix "$flake_ref"
          check_dirty_tree "$flake_ref"
          ;;
      esac

      print_git_context "$flake_ref"
      print_host_note "$host"
      printf '==> nh os %s for host %s\n' "$action" "$host"
      printf '==> Home Manager is applied via NixOS module integration (single build path)\n'
      local extra_args=()
      mapfile -t extra_args < <(build_nh_extra_args "$@")
      nh os "$action" "$flake_ref" -H "$host" "''${extra_args[@]}"
      local nh_rc=$?

      if [[ $nh_rc -eq 0 ]]; then
        local new_system=""
        case "$action" in
          build)
            [[ -L ./result ]] && new_system="$(readlink -f ./result)"
            ;;
          switch|test)
            new_system="$(readlink -f /run/current-system)"
            ;;
        esac
        summarize_closure_diff "$old_system" "$new_system"
      fi

      return $nh_rc
    }

    run_rebuild() {
      local action="$1"
      local host="$2"
      local flake_ref="$3"
      shift 3

      case "$action" in
        switch|build|test|boot) ;;
        *) die "invalid rebuild action: $action (expected switch|build|test|boot)" ;;
      esac

      run_nh_os "$action" "$host" "$flake_ref" "$@"
    }

    run_update() {
      local host="$1"
      local flake_ref="$2"
      shift 2

      local old_system=""
      if [[ -e /run/current-system ]]; then
        old_system="$(readlink -f /run/current-system)"
      fi

      auto_statix "$flake_ref"
      check_dirty_tree "$flake_ref"

      print_git_context "$flake_ref"
      print_host_note "$host"
      printf '==> Updating flake inputs\n'
      local nix_args=()
      mapfile -t nix_args < <(nix_extra_args)
      nix flake update "''${nix_args[@]}" --flake "$flake_ref"

      printf '==> nh os switch for host %s\n' "$host"
      printf '==> Home Manager is applied via NixOS module integration (single build path)\n'
      local extra_args=()
      mapfile -t extra_args < <(build_nh_extra_args "$@")
      nh os switch "$flake_ref" -H "$host" "''${extra_args[@]}"
      local nh_rc=$?

      if [[ $nh_rc -eq 0 ]]; then
        local new_system
        new_system="$(readlink -f /run/current-system)"
        summarize_closure_diff "$old_system" "$new_system"
      fi

      return $nh_rc
    }

    run_gc() {
      printf '==> nh clean all\n'
      nh clean all "$@"
    }

    run_nh_home() {
      local action="$1"
      local host="$2"
      local flake_ref="$3"
      shift 3

      case "$action" in
        switch|build) ;;
        *) die "invalid nh home action: $action (expected switch|build)" ;;
      esac

      printf '==> nh home %s for host %s\n' "$action" "$host"
      local extra_args=()
      mapfile -t extra_args < <(build_nh_extra_args "$@")
      nh home "$action" "$flake_ref" -c "$host" "''${extra_args[@]}"
    }

    # Roll back to the previous system generation and activate it.
    # This is the standard NixOS recovery path: no rebuild, just switches
    # to a previously-built and previously-tested system closure.
    run_rollback() {
      local old_system=""
      if [[ -e /run/current-system ]]; then
        old_system="$(readlink -f /run/current-system)"
      fi

      printf '==> Rolling back to previous system generation\n'

      # Roll the system profile to the previous generation.
      if ! sudo nix-env -p /nix/var/nix/profiles/system --rollback; then
        die "rollback failed: could not roll system profile"
      fi

      # Activate the rolled-back generation.
      local new_system
      new_system="$(readlink -f /nix/var/nix/profiles/system)"
      printf '==> Activating %s\n' "$new_system"
      sudo "$new_system/bin/switch-to-configuration" switch

      summarize_closure_diff "$old_system" "$new_system"
    }

    # List all system generations with dates and nixpkgs revisions.
    run_gens() {
      printf '==> System generations\n\n'
      nixos-rebuild list-generations 2>/dev/null || \
        nix-env -p /nix/var/nix/profiles/system --list-generations
    }

    # Trace why a package is (or is not) in the system closure.
    # Checks both the running system and the flake's target build.
    run_why() {
      local pkg="$1"
      local host="$2"
      local flake_ref="$3"

      [[ -n "$pkg" ]] || die "why: package name required (e.g., tcli why mullvad-vpn)"

      # Normalize to nixpkgs#<name> if no flake ref is present.
      case "$pkg" in
        *#*) ;;
        *) pkg="nixpkgs#$pkg" ;;
      esac

      printf '==> Why does /run/current-system depend on %s?\n' "$pkg"
      if [[ -e /run/current-system ]]; then
        nix why-depends /run/current-system "$pkg" 2>&1 || \
          printf '  (not found in running system)\n'
      else
        printf '  (no running system)\n'
      fi

      if [[ -L "$flake_ref/result" ]]; then
        local built
        built="$(readlink -f "$flake_ref/result" 2>/dev/null || true)"
        if [[ -n "$built" && -e "$built" ]]; then
          printf '\n==> Why does the last build (result link) depend on %s?\n' "$pkg"
          nix why-depends "$built" "$pkg" 2>&1 || \
            printf '  (not found in last build)\n'
        fi
      fi

      printf '\n==> Why does .#nixosConfigurations.%s depend on %s?\n' "$host" "$pkg"
      local nix_args=()
      mapfile -t nix_args < <(nix_extra_args)
      nix why-depends "''${nix_args[@]}" \
        ".#nixosConfigurations.''${host}.config.system.build.toplevel" \
        "$pkg" 2>&1 || \
        printf '  (not found in flake target)\n'
    }

    # Comprehensive diagnostic: git sync, orphans, statix, flake eval,
    # stale result link, host check, running system vs flake output.
    run_doctor() {
      local flake_dir="$1"
      local host="$2"
      local rc=0

      printf '==> tcli doctor\n\n'

      # 1. Git status
      printf -- '--- git ---\n'
      if (cd "$flake_dir" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        local sha branch dirty_count
        sha=$(cd "$flake_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        branch=$(cd "$flake_dir" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
        dirty_count=$(cd "$flake_dir" && git status --porcelain 2>/dev/null | wc -l || echo 0)
        printf '  HEAD: %s (%s)\n' "$sha" "$branch"
        if [[ "$dirty_count" -eq 0 ]]; then
          printf '  working tree: clean\n'
        else
          printf '  working tree: %d uncommitted change(s)\n' "$dirty_count"
        fi
      else
        printf '  not a git repository\n'
      fi
      printf '\n'

      # 2. Orphan scan
      printf -- '--- orphan modules ---\n'
      scan_orphan_modules "$flake_dir" || rc=1
      printf '\n'

      # 3. Statix
      printf -- '--- statix ---\n'
      if command -v statix >/dev/null 2>&1; then
        statix check "$flake_dir" && printf '  ok\n' || { printf '  issues found\n'; rc=1; }
      else
        printf '  statix not installed\n'
      fi
      printf '\n'

      # 4. Flake check (eval only)
      printf -- '--- nix flake check --no-build ---\n'
      local nix_args=()
      mapfile -t nix_args < <(nix_extra_args)
      nix flake check "$flake_dir" --no-build "''${nix_args[@]}" && printf '  ok\n' || { printf '  eval failed\n'; rc=1; }
      printf '\n'

      # 5. Stale result link
      printf -- '--- result link ---\n'
      if [[ -L "$flake_dir/result" ]]; then
        local result_target
        result_target="$(readlink -f "$flake_dir/result" 2>/dev/null || true)"
        if [[ -n "$result_target" && -e "$result_target" ]]; then
          local current_system
          current_system="$(readlink -f /run/current-system 2>/dev/null || true)"
          if [[ "$result_target" == "$current_system" ]]; then
            printf '  result -> %s (matches running system)\n' "$result_target"
          else
            printf '  result -> %s (stale: does not match running system)\n' "$result_target"
          fi
        else
          printf '  result -> %s (dangling: target missing)\n' "''${result_target:-?}"
        fi
      else
        printf '  no result link\n'
      fi
      printf '\n'

      # 6. Host check
      printf -- '--- host ---\n'
      local current_host
      current_host=$(resolve_host "")
      printf '  current hostname: %s\n' "$current_host"
      printf '  target host: %s\n' "$host"
      if [[ "$current_host" != "$host" ]]; then
        printf '  note: building for a different host than this machine\n'
      fi
      printf '\n'

      # 7. Running system vs current flake output
      printf -- '--- running system sync ---\n'
      if [[ -e /run/current-system ]]; then
        local expected_path
        local nix_args=()
        mapfile -t nix_args < <(nix_extra_args)
        expected_path=$(nix eval --raw "''${nix_args[@]}" \
          ".#nixosConfigurations.''${host}.config.system.build.toplevel.outPath" \
          2>/dev/null || echo "")
        if [[ -n "$expected_path" ]]; then
          local running_path
          running_path="$(readlink -f /run/current-system)"
          if [[ "$expected_path" == "$running_path" ]]; then
            printf '  running system matches current flake output\n'
          else
            printf '  WARNING: running system differs from current flake\n'
            printf '    running:  %s\n' "$running_path"
            printf '    flake:    %s\n' "$expected_path"
            printf '    this may indicate the running system was built from\n'
            printf '    uncommitted state that has since been lost\n'
          fi
        else
          printf '  could not evaluate expected toplevel path\n'
        fi
      else
        printf '  no running system found\n'
      fi

      printf '\n==> doctor %s\n' "$([[ $rc -eq 0 ]] && echo 'passed' || echo 'found issues')"
      return "$rc"
    }

    # List available hosts, marking the current one.
    run_hosts() {
      local flake_dir="$1"
      local current_host
      current_host=$(resolve_host "")
      printf 'Available hosts:\n'
      local found=0
      for d in "$flake_dir"/hosts/*/; do
        [[ -d "$d" ]] || continue
        local name
        name=$(basename "$d")
        # Skip hosts/common — it has no variables.nix.
        [[ -f "$d/variables.nix" ]] || continue
        if [[ "$name" == "$current_host" ]]; then
          printf '  * %s (current)\n' "$name"
        else
          printf '    %s\n' "$name"
        fi
        found=$((found + 1))
      done
      [[ "$found" -eq 0 ]] && printf '  (none found)\n'
    }

    # Parse global flags from args before dispatching.
    extract_global_flags() {
      FILTERED_ARGS=()
      local filtered=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --force|-f) FORCE=1 ;;
          --accept-flake-config) ACCEPT_FLAKE_CONFIG=1 ;;
          *) filtered+=("$1") ;;
        esac
        shift
      done
      FILTERED_ARGS=("''${filtered[@]}")
    }

    # Build an array of args for `nh` commands, inserting trust flags as
    # first-class nh options before any caller-provided separator.
    build_nh_extra_args() {
      if [[ "$ACCEPT_FLAKE_CONFIG" -eq 1 ]]; then
        printf '%s\n' "--accept-flake-config"
      fi
      if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@"
      fi
    }

    # Extra args for plain `nix` commands (flake check, eval, why-depends).
    nix_extra_args() {
      if [[ "$ACCEPT_FLAKE_CONFIG" -eq 1 ]]; then
        printf '%s\n' "--accept-flake-config"
      fi
    }

    main() {
      extract_global_flags "$@"
      set -- "''${FILTERED_ARGS[@]}"
      local cmd="''${1-switch}"
      if [[ $# -gt 0 ]]; then
        shift || true
      fi

      local flake_dir flake_ref host action nh_scope pkg
      flake_dir="$(resolve_flake_dir)"
      flake_ref="''${flake_dir}"

      case "$cmd" in
        switch|build|test|boot)
          action="$cmd"
          if [[ -n "''${1-}" && "$1" != "--" ]]; then
            host="$(resolve_host "$1")"
            shift || true
          else
            host="$(resolve_host "")"
          fi
          [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
          if [[ "''${1-}" == "--" ]]; then
            shift || true
          fi
          run_rebuild "$action" "$host" "$flake_ref" "$@"
          ;;
        rebuild)
          action="switch"
          if [[ "''${1-}" =~ ^(switch|build|test|boot)$ ]]; then
            action="$1"
            shift
          fi
          if [[ -n "''${1-}" && "$1" != "--" ]]; then
            host="$(resolve_host "$1")"
            shift || true
          else
            host="$(resolve_host "")"
          fi
          [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
          if [[ "''${1-}" == "--" ]]; then
            shift || true
          fi
          run_rebuild "$action" "$host" "$flake_ref" "$@"
          ;;
        check)
          run_check "$flake_dir"
          ;;
        doctor)
          if [[ -n "''${1-}" && "$1" != "--" ]]; then
            host="$(resolve_host "$1")"
            shift || true
          else
            host="$(resolve_host "")"
          fi
          run_doctor "$flake_dir" "$host"
          ;;
        rollback)
          run_rollback
          ;;
        gens)
          run_gens
          ;;
        why)
          pkg="''${1-}"
          [[ -n "$pkg" ]] || die "why: package name required (e.g., tcli why mullvad-vpn)"
          shift || true
          if [[ -n "''${1-}" && "$1" != "--" ]]; then
            host="$(resolve_host "$1")"
            shift || true
          else
            host="$(resolve_host "")"
          fi
          [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
          run_why "$pkg" "$host" "$flake_ref"
          ;;
        hosts)
          run_hosts "$flake_dir"
          ;;
        update|upgrade)
          if [[ -n "''${1-}" && "$1" != "--" ]]; then
            host="$(resolve_host "$1")"
            shift || true
          else
            host="$(resolve_host "")"
          fi
          [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
          if [[ "''${1-}" == "--" ]]; then
            shift || true
          fi
          run_update "$host" "$flake_ref" "$@"
          ;;
        gc)
          if [[ "''${1-}" == "--" ]]; then
            shift || true
          fi
          run_gc "$@"
          ;;
        nh)
          nh_scope="''${1-}"
          [[ -n "$nh_scope" ]] || die "missing nh scope (expected os|home|clean)"
          shift || true
          case "$nh_scope" in
            os)
              action="switch"
              if [[ "''${1-}" =~ ^(switch|build|test|boot)$ ]]; then
                action="$1"
                shift
              fi
              if [[ -n "''${1-}" && "$1" != "--" ]]; then
                host="$(resolve_host "$1")"
                shift || true
              else
                host="$(resolve_host "")"
              fi
              [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
              if [[ "''${1-}" == "--" ]]; then
                shift || true
              fi
              run_nh_os "$action" "$host" "$flake_ref" "$@"
              ;;
            home)
              action="switch"
              if [[ "''${1-}" =~ ^(switch|build)$ ]]; then
                action="$1"
                shift
              fi
              if [[ -n "''${1-}" && "$1" != "--" ]]; then
                host="$(resolve_host "$1")"
                shift || true
              else
                host="$(resolve_host "")"
              fi
              [[ -d "''${flake_dir}/hosts/''${host}" ]] || die "unknown host ''${host} in ''${flake_dir}/hosts"
              if [[ "''${1-}" == "--" ]]; then
                shift || true
              fi
              run_nh_home "$action" "$host" "$flake_ref" "$@"
              ;;
            clean)
              if [[ "''${1-}" == "--" ]]; then
                shift || true
              fi
              run_gc "$@"
              ;;
            *)
              die "invalid nh scope: $nh_scope (expected os|home|clean)"
              ;;
          esac
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          die "unknown command: $cmd"
          ;;
      esac
    }

    main "$@"
  '';
in
{
  home.packages = [
    tcli
    homeManagerPkg
  ];

  programs.bash.shellAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
  };

  programs.fish.shellAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
    tanime = "ssh root@192.168.0.85";
    tanmedia = "ssh tan@192.168.0.116";
  };
}
