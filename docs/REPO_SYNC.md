# Repository synchronization

`nagi-repo-sync` synchronizes committed branches through private bare Git
repositories on `codebox`. Tandesk and tanlappy also checkpoint `/home/tan/nagi`
every two minutes so unfinished work can move safely between them.

## Remote layout

- The hosted remote (for example GitHub) is always `origin` and the push
  default. Plain `git push` only publishes when you ask it to; repo-sync never
  pushes to `origin`, so committing on a branch with an open PR cannot update
  that PR automatically.
- Machine-to-machine synchronization uses a dedicated `codebox` remote pointing
  at the private bare mirror on codebox. Only branches and `refs/nagi/*`
  checkpoint refs are exchanged there.
- Both scripts refuse to run with `origin` as the sync remote name.

## Repository lifecycle

Repositories move between hosts automatically in both directions:

- A repository created inside the scanned root (`~/REPOS` on laptops,
  `~/Development/projects` on codebox) is enrolled on its next sync run: a bare
  mirror is created on codebox, its branches and tags are pushed, and every
  peer clones it into its own root.
- Mirrors without a local checkout are cloned into the repository root on each
  run (`NAGI_REPO_SYNC_AUTOCLONE=1` by default). Matching is by sync remote
  URL, so a checkout whose directory name differs from its mirror (for example
  `~/REPOS/nakama` tracking `git-mirrors/shoko-companion.git`) owns that mirror
  and no duplicate clone is made; origin propagation resolves through the URL
  match as well.
- The `nagi-repo-sync-codebox` wrapper is a thin shell over
  `nagi-repo-sync` that points it at the local `~/git-mirrors` directory
  instead of using ssh.

## Origin propagation

Each checkout remembers the origin URL it last saw or published (in
`.git/nagi-repo-sync/origin`). On every sync run:

- Adding or changing `origin` locally publishes the new URL to the mirror's
  `nagi.origin-url`, and peers adopt it.
- A peer-published URL is adopted by checkouts whose origin is unchanged.
- If two hosts change the same origin independently, repo-sync warns and leaves
  both alone until resolved manually.
- Checkouts cloned by the sync get their hosted `origin` restored from the
  mirror record; legacy checkouts whose `origin` pointed at the local mirror
  are migrated automatically.

Mirrors created before this scheme do not carry a recorded `nagi.origin-url`;
set it once per mirror so codebox checkouts get their hosted `origin` back:

```bash
ssh codebox git --git-dir=git-mirrors/<name>.git config nagi.origin-url \
  git@github.com:<owner>/<name>.git
```

## Deletion

Deletion is intentional and propagates in both directions:

- Deleting a checkout directory on any host (after it has been synced there
  once) is recognized on the next sync run and published to the mirror as a
  tombstone (`nagi.deleted=<host>`). The mirror itself is kept as the
  tombstone carrier, so deletion also survives hosts that were offline.
- Peers see the tombstone and remove their own checkout of that repository.
  A checkout is only removed when it is clean (nothing uncommitted or
  untracked), fully pushed to the mirror, not mid-operation, and not an
  explicitly configured repository. Anything else is left untouched with a
  warning so work can be recovered manually.
- Tombstoned mirrors are never cloned by new or existing hosts; deleted stays
  deleted.

To purge a tombstoned repository completely once every host has removed its
checkout, delete the bare mirror on codebox:

```bash
ssh codebox rm -rf "git-mirrors/<name>.git"
```

## Checkpoint behavior

- Dirty tracked and untracked, nonignored files are captured with a temporary
  Git index. The active branch, working tree, and real index are not changed.
- Each host publishes its own `refs/nagi/checkpoints/<host>` history.
- A clean peer restores a checkpoint only when it was made from that peer's
  current `HEAD`. The result remains visibly uncommitted.
- A dirty peer is never overwritten. If both hosts edit independently, both
  checkpoint refs remain available for manual reconciliation.
- When one host commits a restored checkpoint, the other host can advance to
  that commit automatically only when its complete working-tree snapshot is
  byte-for-byte identical.
- Obvious private-key material and plaintext `secrets/*.yaml` files block the
  checkpoint. Ignored files are never included.

GitHub remains the deliberate publication remote. Repo-sync pushes branches and
checkpoint refs only to the private `codebox` remote.

The shared host profile also installs codebox's trusted Ed25519 host key
system-wide, so enrollment never needs to disable SSH host-key verification.

## Inspection and recovery

```bash
systemctl --user status nagi-repo-sync.timer
systemctl --user start nagi-repo-sync.service
git show-ref | grep refs/nagi
git log --stat refs/nagi/checkpoints/$(hostname -s)
```

To compare an imported checkpoint before committing:

```bash
git status
git diff
```

Resolve simultaneous edits normally with Git. Repo-sync stops on real
divergence and never force-pushes or overwrites either dirty worktree.
