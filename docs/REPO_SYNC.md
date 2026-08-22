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
- When a repository is enrolled, its `origin` URL is recorded in the mirror
  (`nagi.origin-url`). Checkouts cloned by `nagi-repo-sync-codebox` get `origin`
  restored from that record, and legacy checkouts whose `origin` pointed at the
  local mirror are migrated to the hosted remote automatically.
- Both scripts refuse to run with `origin` as the sync remote name.

Mirrors created before this scheme do not carry a recorded `nagi.origin-url`;
set it once per mirror so codebox checkouts get their hosted `origin` back:

```bash
ssh codebox git --git-dir=git-mirrors/<name>.git config nagi.origin-url \
  git@github.com:<owner>/<name>.git
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
