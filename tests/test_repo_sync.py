#!/usr/bin/env python3

import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(
    os.environ.get(
        "NAGI_REPO_SYNC",
        pathlib.Path(__file__).resolve().parents[1] / "scripts" / "repo-sync",
    )
)


class RepoSyncTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary_directory.name)
        self.remote = self.root / "nagi.git"
        self.tandesk = self.root / "tandesk" / "nagi"
        self.tanlappy = self.root / "tanlappy" / "nagi"

        self.git("init", "--bare", "--initial-branch=main", str(self.remote))
        self.tandesk.mkdir(parents=True)
        self.git("-C", str(self.tandesk), "init", "--initial-branch=main")
        self.configure_identity(self.tandesk)
        (self.tandesk / "flake.nix").write_text("{ }\n", encoding="utf-8")
        self.git("-C", str(self.tandesk), "add", "flake.nix")
        self.git("-C", str(self.tandesk), "commit", "-m", "chore: initial")
        self.git(
            "-C",
            str(self.tandesk),
            "remote",
            "add",
            "codebox",
            str(self.remote),
        )
        self.git(
            "-C",
            str(self.tandesk),
            "push",
            "--set-upstream",
            "codebox",
            "main",
        )

        self.tanlappy.parent.mkdir(parents=True)
        self.git("clone", "--origin=codebox", str(self.remote), str(self.tanlappy))
        self.configure_identity(self.tanlappy)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def git(self, *args, check=True):
        return subprocess.run(
            ["git", *args],
            check=check,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def configure_identity(self, repository):
        self.git("-C", str(repository), "config", "user.name", "Repo Sync Test")
        self.git(
            "-C",
            str(repository),
            "config",
            "user.email",
            "repo-sync@example.invalid",
        )

    def sync(
        self,
        repository,
        hostname,
        *,
        checkpoint_only=False,
        check=True,
        remote_name="codebox",
        mirror_path=None,
        autoclone=None,
    ):
        environment = os.environ.copy()
        environment.update(
            {
                "NAGI_REPO_SYNC_ROOT": str(self.root / "missing-root"),
                "NAGI_REPO_SYNC_REMOTE_NAME": remote_name,
                "NAGI_REPO_SYNC_REPOSITORIES": str(repository),
                "NAGI_REPO_SYNC_CHECKPOINT_REPOSITORIES": str(repository),
                "NAGI_REPO_SYNC_HOST": hostname,
                "NAGI_REPO_SYNC_STATE_DIR": str(self.root / "state"),
            }
        )
        if mirror_path is not None:
            environment["NAGI_REPO_SYNC_MIRROR_PATH"] = str(mirror_path)
        if autoclone is not None:
            environment["NAGI_REPO_SYNC_AUTOCLONE"] = str(autoclone)
        command = [os.environ.get("BASH", "bash"), str(SCRIPT)]
        if checkpoint_only:
            command.append("--checkpoint-only")
        return subprocess.run(
            command,
            check=check,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def rev_parse(self, repository, revision):
        return self.git(
            "-C",
            str(repository),
            "rev-parse",
            revision,
        ).stdout.strip()

    def remote_ref(self, reference):
        return self.git(
            "--git-dir",
            str(self.remote),
            "rev-parse",
            "--verify",
            reference,
            check=False,
        )

    def test_checkpoint_handoff_preserves_worktree_and_converges_after_commit(self):
        initial_head = self.rev_parse(self.tandesk, "HEAD")
        (self.tandesk / "flake.nix").write_text("{ staged = true; }\n", encoding="utf-8")
        self.git("-C", str(self.tandesk), "add", "flake.nix")
        (self.tandesk / "flake.nix").write_text("{ final = true; }\n", encoding="utf-8")
        (self.tandesk / "new-module.nix").write_text("{ ... }: { }\n", encoding="utf-8")
        status_before = self.git(
            "-C",
            str(self.tandesk),
            "status",
            "--porcelain=v1",
        ).stdout

        result = self.sync(self.tandesk, "tandesk", checkpoint_only=True)
        self.assertIn("checkpointed nagi from tandesk", result.stdout)
        self.assertEqual(initial_head, self.rev_parse(self.tandesk, "HEAD"))
        self.assertEqual(
            status_before,
            self.git(
                "-C",
                str(self.tandesk),
                "status",
                "--porcelain=v1",
            ).stdout,
        )

        checkpoint = self.remote_ref("refs/nagi/checkpoints/tandesk")
        self.assertEqual(0, checkpoint.returncode, checkpoint.stderr)
        self.assertEqual(
            "{ final = true; }\n",
            self.git(
                "--git-dir",
                str(self.remote),
                "show",
                f"{checkpoint.stdout.strip()}:flake.nix",
            ).stdout,
        )

        result = self.sync(self.tanlappy, "tanlappy")
        self.assertIn("restored uncommitted nagi checkpoint from tandesk", result.stdout)
        self.assertEqual(initial_head, self.rev_parse(self.tanlappy, "HEAD"))
        self.assertEqual(
            "{ final = true; }\n",
            (self.tanlappy / "flake.nix").read_text(encoding="utf-8"),
        )
        self.assertTrue((self.tanlappy / "new-module.nix").exists())

        self.sync(self.tanlappy, "tanlappy")
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tanlappy").returncode,
        )

        self.git("-C", str(self.tanlappy), "add", "-A")
        self.git(
            "-C",
            str(self.tanlappy),
            "commit",
            "-m",
            "feat: accept checkpoint",
        )
        committed_head = self.rev_parse(self.tanlappy, "HEAD")
        self.sync(self.tanlappy, "tanlappy")

        result = self.sync(self.tandesk, "tandesk")
        self.assertIn("advancing nagi:main to an identical committed checkpoint", result.stdout)
        self.assertEqual(committed_head, self.rev_parse(self.tandesk, "HEAD"))
        self.assertEqual(
            "",
            self.git(
                "-C",
                str(self.tandesk),
                "status",
                "--porcelain=v1",
            ).stdout,
        )

    def test_independent_dirty_worktrees_are_never_overwritten(self):
        (self.tandesk / "flake.nix").write_text("{ host = \"tandesk\"; }\n", encoding="utf-8")
        self.sync(self.tandesk, "tandesk", checkpoint_only=True)

        (self.tanlappy / "flake.nix").write_text("{ host = \"tanlappy\"; }\n", encoding="utf-8")
        self.sync(self.tanlappy, "tanlappy")

        self.assertEqual(
            "{ host = \"tanlappy\"; }\n",
            (self.tanlappy / "flake.nix").read_text(encoding="utf-8"),
        )
        self.assertEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )
        self.assertEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tanlappy").returncode,
        )

    def test_committed_private_key_examples_do_not_block_checkpoint(self):
        (self.tandesk / "key-examples.txt").write_text(
            "-----BEGIN OPENSSH PRIVATE"
            " KEY-----\n"
            "not-a-real-key\n"
            "AGE-SECRET-"
            "KEY-\n",
            encoding="utf-8",
        )
        self.git("-C", str(self.tandesk), "add", "key-examples.txt")
        self.git(
            "-C",
            str(self.tandesk),
            "commit",
            "-m",
            "docs: add key examples",
        )
        (self.tandesk / "flake.nix").write_text("{ updated = true; }\n", encoding="utf-8")

        result = self.sync(self.tandesk, "tandesk", checkpoint_only=True)

        self.assertIn("checkpointed nagi from tandesk", result.stdout)
        self.assertEqual(
            "{ updated = true; }\n",
            self.git(
                "--git-dir",
                str(self.remote),
                "show",
                "refs/nagi/checkpoints/tandesk:flake.nix",
            ).stdout,
        )

    def test_private_key_material_blocks_checkpoint(self):
        (self.tandesk / "accidental-key").write_text(
            "-----BEGIN OPENSSH PRIVATE"
            " KEY-----\nnot-a-real-key\n",
            encoding="utf-8",
        )

        result = self.sync(
            self.tandesk,
            "tandesk",
            checkpoint_only=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("contains private-key material", result.stderr)
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )
        self.assertTrue((self.tandesk / "accidental-key").exists())

    def test_staged_private_key_material_blocks_checkpoint(self):
        (self.tandesk / "accidental-key").write_text(
            "AGE-SECRET-"
            "KEY-1NOTAREALKEY\n",
            encoding="utf-8",
        )
        self.git("-C", str(self.tandesk), "add", "accidental-key")

        result = self.sync(
            self.tandesk,
            "tandesk",
            checkpoint_only=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("contains private-key material", result.stderr)
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )

    def test_tracked_private_key_material_blocks_checkpoint(self):
        (self.tandesk / "config.txt").write_text("safe\n", encoding="utf-8")
        self.git("-C", str(self.tandesk), "add", "config.txt")
        self.git(
            "-C",
            str(self.tandesk),
            "commit",
            "-m",
            "test: add safe config",
        )
        (self.tandesk / "config.txt").write_text(
            "-----BEGIN PRIVATE"
            " KEY-----\nnot-a-real-key\n",
            encoding="utf-8",
        )

        result = self.sync(
            self.tandesk,
            "tandesk",
            checkpoint_only=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("contains private-key material", result.stderr)
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )

    def test_plaintext_sops_yaml_blocks_checkpoint(self):
        secrets = self.tandesk / "secrets"
        secrets.mkdir()
        (secrets / "new-host.yaml").write_text("token: plaintext\n", encoding="utf-8")

        result = self.sync(
            self.tandesk,
            "tandesk",
            checkpoint_only=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("unencrypted SOPS YAML", result.stderr)
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )

    def test_staged_plaintext_sops_yaml_blocks_checkpoint(self):
        secrets = self.tandesk / "secrets"
        secrets.mkdir()
        (secrets / "new-host.yaml").write_text("token: plaintext\n", encoding="utf-8")
        self.git("-C", str(self.tandesk), "add", "secrets/new-host.yaml")

        result = self.sync(
            self.tandesk,
            "tandesk",
            checkpoint_only=True,
            check=False,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("unencrypted SOPS YAML", result.stderr)
        self.assertNotEqual(
            0,
            self.remote_ref("refs/nagi/checkpoints/tandesk").returncode,
        )

    def test_encrypted_sops_yaml_allows_checkpoint(self):
        secrets = self.tandesk / "secrets"
        secrets.mkdir()
        (secrets / "new-host.yaml").write_text(
            "token: ENC[AES256_GCM,data:not-real]\n"
            "sops:\n"
            "  version: 3.10.2\n",
            encoding="utf-8",
        )

        result = self.sync(self.tandesk, "tandesk", checkpoint_only=True)

        self.assertIn("checkpointed nagi from tandesk", result.stdout)
        self.assertEqual(
            "token: ENC[AES256_GCM,data:not-real]\n"
            "sops:\n"
            "  version: 3.10.2\n",
            self.git(
                "--git-dir",
                str(self.remote),
                "show",
                "refs/nagi/checkpoints/tandesk:secrets/new-host.yaml",
            ).stdout,
        )

    def test_sync_never_pushes_to_hosted_origin(self):
        hosted = self.root / "github-hosted.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))
        self.git(
            "-C",
            str(self.tandesk),
            "remote",
            "add",
            "origin",
            str(hosted),
        )
        initial_head = self.rev_parse(self.tandesk, "HEAD")
        self.git("-C", str(self.tandesk), "push", "--quiet", "origin", "main")

        self.git("-C", str(self.tandesk), "commit", "--allow-empty", "-m", "feat: pr work")
        committed_head = self.rev_parse(self.tandesk, "HEAD")
        result = self.sync(self.tandesk, "tandesk")

        self.assertIn("pushing nagi:main", result.stdout)
        self.assertEqual(
            initial_head,
            self.git(
                "--git-dir",
                str(hosted),
                "rev-parse",
                "refs/heads/main",
            ).stdout.strip(),
        )
        self.assertNotEqual(committed_head, initial_head)
        self.assertEqual(
            0,
            self.remote_ref("refs/heads/main").returncode,
        )
        self.assertEqual(
            committed_head,
            self.git(
                "--git-dir",
                str(self.remote),
                "rev-parse",
                "refs/heads/main",
            ).stdout.strip(),
        )

    def test_origin_is_rejected_as_the_sync_remote(self):
        result = self.sync(self.tandesk, "tandesk", check=False, remote_name="origin")

        self.assertEqual(2, result.returncode)
        self.assertIn('refusing "origin"', result.stderr)

    def make_local_repo(self, path, *, hosted=None):
        self.git("init", "--initial-branch=main", str(path))
        self.configure_identity(path)
        (path / "flake.nix").write_text("{ }\n", encoding="utf-8")
        self.git("-C", str(path), "add", "flake.nix")
        self.git("-C", str(path), "commit", "-m", "chore: initial")
        if hosted is not None:
            self.git("-C", str(path), "remote", "add", "origin", str(hosted))

    def mirror_origin_record(self, mirror_name):
        return self.git(
            "--git-dir",
            str(self.root / f"{mirror_name}.git"),
            "config",
            "--get",
            "nagi.origin-url",
            check=False,
        ).stdout.strip()

    def test_created_repos_are_enrolled_into_local_mirrors(self):
        projects = self.root / "projects"
        projects.mkdir()
        demo = projects / "demo"
        self.make_local_repo(demo)

        self.sync(
            demo,
            "tandesk",
            mirror_path=self.root,
            autoclone=0,
        )

        self.assertTrue((self.root / "demo.git").is_dir())
        self.assertEqual("", self.mirror_origin_record("demo"))
        self.assertEqual(
            self.rev_parse(projects / "demo", "HEAD"),
            self.git("--git-dir", str(self.root / "demo.git"), "rev-parse", "refs/heads/main").stdout.strip(),
        )

    def test_missing_mirrors_are_autocloned_with_hosted_origins(self):
        mirrors = self.root / "mirrors"
        mirrors.mkdir()
        hosted = self.root / "github-bar.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))
        seed = self.root / "seed"
        self.make_local_repo(seed, hosted=hosted)
        self.git("init", "--bare", "--initial-branch=main", str(mirrors / "bar.git"))
        self.git("-C", str(seed), "push", "--quiet", str(mirrors / "bar.git"), "main")
        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.origin-url", str(hosted))

        self.sync(
            "",
            "tandesk",
            mirror_path=mirrors,
            autoclone=1,
        )

        target = self.root / "missing-root" / "bar"
        self.assertTrue((target / ".git").is_dir())
        origin_url = self.git("-C", str(target), "remote", "get-url", "origin").stdout.strip()
        sync_url = self.git("-C", str(target), "remote", "get-url", "codebox").stdout.strip()
        self.assertEqual(str(hosted), origin_url)
        self.assertEqual(str(mirrors / "bar.git"), sync_url)
        tracking = self.git("-C", str(target), "config", "--get", "branch.main.remote").stdout.strip()
        self.assertEqual("origin", tracking)

    def test_differently_named_checkout_is_matched_by_sync_remote(self):
        mirrors = self.root / "mirrors"
        mirrors.mkdir()
        hosted = self.root / "github-bar.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))
        seed = self.root / "seed"
        self.make_local_repo(seed, hosted=hosted)
        self.git("init", "--bare", "--initial-branch=main", str(mirrors / "bar.git"))
        self.git("-C", str(seed), "push", "--quiet", str(mirrors / "bar.git"), "main")
        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.origin-url", str(hosted))

        checkout_root = self.root / "missing-root"
        checkout_root.mkdir()
        checkout = checkout_root / "renamed"
        self.git("clone", "--quiet", "--origin", "codebox", str(mirrors / "bar.git"), str(checkout))

        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)

        # The existing differently-named checkout owns the mirror; no duplicate
        # clone appears, and origin propagation still resolves through it.
        self.assertFalse((checkout_root / "bar").exists())
        adopted = self.git("-C", str(checkout), "remote", "get-url", "origin").stdout.strip()
        self.assertEqual(str(hosted), adopted)

    def make_peer_mirror(self, name="bar"):
        mirrors = self.root / "mirrors"
        mirrors.mkdir(exist_ok=True)
        hosted = self.root / f"github-{name}.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))
        seed = self.root / f"seed-{name}"
        self.make_local_repo(seed, hosted=hosted)
        self.git("init", "--bare", "--initial-branch=main", str(mirrors / f"{name}.git"))
        self.git("-C", str(seed), "push", "--quiet", str(mirrors / f"{name}.git"), "main")
        self.git(
            "--git-dir",
            str(mirrors / f"{name}.git"),
            "config",
            "nagi.origin-url",
            str(hosted),
        )
        return mirrors, hosted

    def test_peer_deletion_removes_clean_checkout(self):
        mirrors, _hosted = self.make_peer_mirror()
        target = self.root / "missing-root" / "bar"

        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)
        self.assertTrue((target / ".git").is_dir())

        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.deleted", "tanlappy")
        result = self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)

        self.assertIn("removed bar (deleted on tanlappy)", result.stdout)
        self.assertFalse(target.exists())
        self.assertEqual(0, result.returncode)

    def test_dirty_checkout_survives_peer_deletion(self):
        mirrors, _hosted = self.make_peer_mirror()
        target = self.root / "missing-root" / "bar"

        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)
        (target / "flake.nix").write_text("{ dirty = true; }\n", encoding="utf-8")
        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.deleted", "tanlappy")

        result = self.sync("", "tandesk", check=False, mirror_path=mirrors, autoclone=1)

        self.assertIn("deletion deferred", result.stderr)
        self.assertTrue(target.exists())
        self.assertNotEqual(0, result.returncode)

    def test_unpublished_commits_block_deletion(self):
        mirrors, _hosted = self.make_peer_mirror()
        target = self.root / "missing-root" / "bar"

        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)
        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.deleted", "tanlappy")

        # Commit after the tombstone exists so the normal branch sync never
        # publishes it: the checkout is now clean but ahead of the mirror.
        self.configure_identity(target)
        (target / "extra.nix").write_text("{ }\n", encoding="utf-8")
        self.git("-C", str(target), "add", "extra.nix")
        self.git("-C", str(target), "commit", "-m", "feat: local only")

        result = self.sync("", "tandesk", check=False, mirror_path=mirrors, autoclone=1)

        self.assertIn("not present on codebox", result.stderr)
        self.assertTrue(target.exists())
        self.assertNotEqual(0, result.returncode)

    def test_local_checkout_removal_publishes_tombstone(self):
        mirrors, _hosted = self.make_peer_mirror()
        target = self.root / "missing-root" / "bar"

        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)
        self.assertTrue((target / ".git").is_dir())

        import shutil

        shutil.rmtree(target)
        self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)

        recorded = self.git(
            "--git-dir", str(mirrors / "bar.git"), "config", "--get", "nagi.deleted"
        ).stdout.strip()
        self.assertEqual("tandesk", recorded)
        # The deleted mirror is not resurrected.
        self.assertFalse(target.exists())

    def test_tombstoned_mirror_is_never_cloned_fresh(self):
        mirrors, _hosted = self.make_peer_mirror()
        self.git("--git-dir", str(mirrors / "bar.git"), "config", "nagi.deleted", "tanlappy")

        result = self.sync("", "tandesk", mirror_path=mirrors, autoclone=1)

        self.assertEqual(0, result.returncode)
        self.assertFalse((self.root / "missing-root" / "bar").exists())

    def test_added_origin_is_published_to_the_mirror(self):
        hosted = self.root / "github-nagi.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))

        first = self.sync(self.tandesk, "tandesk", mirror_path=self.root, autoclone=0)
        self.assertEqual("", self.mirror_origin_record("nagi"))

        self.git("-C", str(self.tandesk), "remote", "add", "origin", str(hosted))
        second = self.sync(self.tandesk, "tandesk", mirror_path=self.root, autoclone=0)

        self.assertEqual(str(hosted), self.mirror_origin_record("nagi"))
        self.assertNotIn("warning", second.stderr)

    def test_recorded_origin_is_adopted_by_checkouts_without_one(self):
        hosted = self.root / "github-nagi.git"
        self.git("init", "--bare", "--initial-branch=main", str(hosted))
        self.sync(self.tandesk, "tandesk", mirror_path=self.root, autoclone=0)

        self.git("--git-dir", str(self.remote), "config", "nagi.origin-url", str(hosted))
        result = self.sync(self.tandesk, "tandesk", mirror_path=self.root, autoclone=0)

        self.assertIn("adopted origin for nagi", result.stdout)
        adopted = self.git("-C", str(self.tandesk), "remote", "get-url", "origin").stdout.strip()
        self.assertEqual(str(hosted), adopted)

    def test_conflicting_origin_changes_are_flagged_not_clobbered(self):
        hosted_a = self.root / "github-a.git"
        hosted_b = self.root / "github-b.git"
        for hosted in (hosted_a, hosted_b):
            self.git("init", "--bare", "--initial-branch=main", str(hosted))
        local_url = str(self.root / "github-local.git")
        self.git("init", "--bare", "--initial-branch=main", str(local_url))
        self.git("-C", str(self.tandesk), "remote", "add", "origin", str(local_url))

        # Initialize the announced state with the current local origin.
        self.sync(self.tandesk, "tandesk", mirror_path=self.root, autoclone=0)

        # A peer publishes a different origin while this host changes its own.
        self.git("--git-dir", str(self.remote), "config", "nagi.origin-url", str(hosted_a))
        self.git("-C", str(self.tandesk), "remote", "set-url", "origin", str(hosted_b))

        result = self.sync(
            self.tandesk,
            "tandesk",
            check=False,
            mirror_path=self.root,
            autoclone=0,
        )

        self.assertIn("changed on multiple hosts", result.stderr)
        current = self.git("-C", str(self.tandesk), "remote", "get-url", "origin").stdout.strip()
        self.assertEqual(str(hosted_b), current)
        self.assertEqual(str(hosted_a), self.mirror_origin_record("nagi"))

if __name__ == "__main__":
    unittest.main()
