# tcli

`tcli` is a Home Manager-installed helper command for this repository.

It provides one place to run common flake lifecycle tasks while handling both layers through one NixOS rebuild path (Home Manager via NixOS integration).

The default rebuild path now runs through `nh`, so you get the tree view, diffs, and related `nh` UX without changing the repo's host/home composition model.

## Commands

### `tcli`

- Equivalent to: `tcli switch`
- Defaults to current machine hostname
- Runs:
  - `nh os switch <repo> -H <host> --accept-flake-config`

### `tcli [switch|build|test|boot] [host] [-- <nh-args...>]`

- Default host: current machine hostname
- Runs a single `nh` command:
  - `nh os <action> <repo> -H <host> --accept-flake-config [nh args...]`

Home Manager is applied through the NixOS `home-manager` module (`home-manager.users`), so this remains a full system+home workflow without a second standalone `home-manager` invocation.

### `tcli rebuild [switch|build|test|boot] [host]`

- Backward-compatible alias for `tcli [switch|build|test|boot] [host]`

### `tcli update [host]` / `tcli upgrade [host] [-- <nh-args...>]`

- Defaults to current machine hostname
- Runs:
  - `nix flake update --accept-flake-config --flake <repo>`
  - `nh os switch <repo> -H <host> --accept-flake-config [nh args...]`

This keeps Home Manager on the NixOS-integrated path. `tcli` performs the flake update itself instead of using `nh --update` because `nh 4.4.0` does not pass `--accept-flake-config` through to its internal `nix flake update` command.

### `tcli check`

Runs three pre-build validation checks:

1. **statix check** — Nix lint on the flake directory.
2. **Orphan module scan** — finds `.nix` files under `modules/nixos` and `modules/home` that are not referenced by any other `.nix` file (not in `stacks.nix`, not imported by a parent). Catches modules that exist but were never wired into the module stack.
3. **nix flake check --no-build** — eval-only flake validation.

Exits non-zero if any check fails. Safe to run before any build or switch.

### `tcli doctor [host]`

Comprehensive diagnostic that checks:

1. **Git status** — HEAD sha, branch, and uncommitted-file count.
2. **Orphan module scan** — same as `tcli check`.
3. **statix check** — Nix lint.
4. **nix flake check --no-build** — eval-only flake validation.
5. **Stale result link** — checks if `./result` exists, is not dangling, and matches the running system.
6. **Host check** — compares the target host with the current hostname.
7. **Running system sync** — evaluates the flake's expected toplevel path and compares it with `/run/current-system`. If they differ, the running system may have been built from uncommitted state that has since been lost.

Exits non-zero if any check fails.

### `tcli rollback`

Rolls back to the previous system generation and activates it. This is the standard NixOS recovery path — no rebuild, just switches to a previously-built and previously-tested system closure.

Runs:
- `sudo nix-env -p /nix/var/nix/profiles/system --rollback`
- `sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch`

Shows a closure diff after activation.

### `tcli gens`

Lists all system generations with dates, kernel versions, and nixpkgs revisions. Pairs with `tcli rollback` for visibility into what has been activated.

### `tcli why <pkg> [host]`

Traces why a package is (or is not) in the system closure. Checks three sources:

1. **`/run/current-system`** — why the running system depends on the package.
2. **`./result` link** — why the last build depends on the package (if a result link exists).
3. **Flake target** — why `.#nixosConfigurations.<host>` depends on the package.

The package name is normalized to `nixpkgs#<name>` if no flake ref is present. Example: `tcli why mullvad-vpn`.

### `tcli hosts`

Lists all available hosts, marking the current one with `*`. A host is defined as a directory under `hosts/` that contains both `default.nix` and `variables.nix`. Optional host-local variable fragments such as `advanced.nix` are registered in `modules/flake/hosts.nix`.

### `tcli gc [-- <nh-args...>]`

Runs:

- `nh clean all [nh args...]`

### `tcli nh os [switch|build|test|boot] [host] [-- <nh-args...>]`

- Default action: `switch`
- Default host: current machine hostname
- Runs:
  - `nh os <action> <repo> -H <host> --accept-flake-config [nh args...]`

### `tcli nh home [switch|build] [host] [-- <nh-args...>]`

- Default action: `switch`
- Default host: current machine hostname
- Runs:
  - `nh home <action> <repo> -c <host> --accept-flake-config [nh args...]`

### `tcli nh clean [-- <nh-args...>]`

- Runs:
  - `nh clean all [nh args...]`

## Hardening features

### `--force` / `-f` flag

Skips the uncommitted-state confirmation prompt. Can be passed anywhere in the args before `--`. Example: `tcli --force switch` or `tcli rebuild build --force`.

### Uncommitted-state guard (`switch`, `boot`, `test`, `update`)

Before activating a system, `tcli` checks `git status --porcelain`. If the working tree has uncommitted changes, it prints a warning listing the dirty files and prompts for confirmation. This prevents activating a system built from state that could be lost, leaving future rebuilds with a different closure. Skip with `--force`.

### Auto-statix before activation (`switch`, `boot`, `test`, `update`)

Before activation, `tcli` runs `statix check` silently. If it fails, a warning is printed. This catches lint errors before a long build. Use `tcli check` for full details.

### Closure-diff service summarizer (`build`, `switch`, `test`, `rollback`)

After a successful build, activation, or rollback, `tcli` runs `nix store diff-closures` between the old and new system and prints a focused summary of:
- Closure size change
- Added/removed systemd units (`unit-*.service`, `unit-*.socket`, `unit-*.timer`, `unit-*.target`)

This makes unexpected service removals immediately visible instead of buried in the full `nh` diff table.

### Non-current host note

When building for a host that does not match the current hostname, `tcli` prints a note so cross-host builds are intentional and visible.

### Git build context

Before every `nh os` invocation, `tcli` prints the current git HEAD sha and uncommitted-file count, so you can see exactly what state the system is being built from.

## Resolution rules

### Host resolution

- If host is passed, use it
- Otherwise use `/etc/hostname` (or `hostname` fallback)
- Host must exist under `hosts/<host>`

### Flake path resolution

`tcli` finds the repo in this order:

1. `NAGI_FLAKE_DIR` environment variable
2. current git root (if it has `flake.nix`)
3. current directory (if it has `flake.nix`)
4. `$HOME/nagi`

## Aliases

Shell aliases are set by Home Manager (bash + fish):

- `fu` -> `tcli update`
- `fr` -> `tcli`
- `ncg` -> `tcli gc`

## Bootstrap integration

`install/bootstrap.sh` still explicitly runs both:

1. `nixos-rebuild`
2. Home Manager activation package (`homeConfigurations.<host>.activationPackage`)

So bootstrap and `tcli` both enforce full system + HM activation, but via different command paths.
Both paths consume the same published user module entrypoint from `flake.homeModules`.
