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

    def sync(self, repository, hostname, *, checkpoint_only=False, check=True):
        environment = os.environ.copy()
        environment.update(
            {
                "NAGI_REPO_SYNC_ROOT": str(self.root / "missing-root"),
                "NAGI_REPO_SYNC_REMOTE_NAME": "codebox",
                "NAGI_REPO_SYNC_REPOSITORIES": str(repository),
                "NAGI_REPO_SYNC_CHECKPOINT_REPOSITORIES": str(repository),
                "NAGI_REPO_SYNC_HOST": hostname,
            }
        )
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


if __name__ == "__main__":
    unittest.main()
