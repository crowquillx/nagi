#!/usr/bin/env python3

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(
    os.environ.get(
        "NAGI_REPO_SYNC_CODEBOX",
        pathlib.Path(__file__).resolve().parents[1] / "scripts" / "repo-sync-codebox",
    )
)
SYNC_SCRIPT = pathlib.Path(
    os.environ.get(
        "NAGI_REPO_SYNC",
        SCRIPT.parent / "repo-sync",
    )
)


class RepoSyncCodeboxTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary_directory.name)
        self.mirrors = self.root / "mirrors"
        self.projects = self.root / "projects"
        self.hosted = self.root / "github-hosted.git"
        self.mirror = self.mirrors / "demo.git"
        self.target = self.projects / "demo"
        self.mirrors.mkdir(parents=True)
        self.sync_bin = self.root / "nagi-repo-sync"
        shutil.copyfile(SYNC_SCRIPT, self.sync_bin)
        self.sync_bin.chmod(0o755)

        self.git("init", "--bare", "--initial-branch=main", str(self.hosted))
        seed = self.root / "seed"
        self.git("clone", "--quiet", str(self.hosted), str(seed))
        (seed / "flake.nix").write_text("{ }\n", encoding="utf-8")
        self.configure_identity(seed)
        self.git("-C", str(seed), "add", "flake.nix")
        self.git("-C", str(seed), "commit", "-m", "chore: initial")
        self.git("-C", str(seed), "push", "--quiet", "origin", "main")

        self.git("init", "--bare", "--initial-branch=main", str(self.mirror))
        self.git("--git-dir", str(self.hosted), "push", "--quiet", str(self.mirror), "main")
        self.git(
            "--git-dir",
            str(self.mirror),
            "config",
            "nagi.origin-url",
            str(self.hosted),
        )

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

    def run_wrapper(self, *, check=True):
        environment = os.environ.copy()
        environment.update(
            {
                "NAGI_REPO_SYNC_ROOT": str(self.projects),
                "NAGI_REPO_SYNC_MIRROR_PATH": str(self.mirrors),
                "NAGI_REPO_SYNC_BIN": str(self.sync_bin),
                "NAGI_REPO_SYNC_REMOTE_NAME": "codebox",
                "NAGI_REPO_SYNC_STATE_DIR": str(self.root / "state"),
                "NAGI_REPO_SYNC_HOST": "codebox",
            }
        )
        result = subprocess.run(
            [os.environ.get("BASH", "bash"), str(SCRIPT)],
            check=False,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if check and result.returncode != 0:
            self.fail(
                f"wrapper failed ({result.returncode})\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            )
        return result

    def remote_url(self, repository, name):
        result = self.git(
            "-C",
            str(repository),
            "remote",
            "get-url",
            name,
            check=False,
        )
        return result.stdout.strip() if result.returncode == 0 else ""

    def branch_tracking_remote(self, repository, branch="main"):
        result = self.git(
            "-C",
            str(repository),
            "config",
            "--get",
            f"branch.{branch}.remote",
            check=False,
        )
        return result.stdout.strip() if result.returncode == 0 else ""

    def test_clones_use_hosted_origin_and_private_sync_remote(self):
        result = self.run_wrapper()

        self.assertNotIn("warning", result.stderr)
        self.assertTrue((self.target / ".git").exists())
        self.assertEqual(str(self.hosted), self.remote_url(self.target, "origin"))
        self.assertEqual(str(self.mirror), self.remote_url(self.target, "codebox"))
        self.assertEqual("origin", self.branch_tracking_remote(self.target))

    def test_legacy_mirror_origins_are_migrated(self):
        self.git("clone", "--quiet", str(self.mirror), str(self.target))
        self.configure_identity(self.target)
        self.assertEqual(str(self.mirror), self.remote_url(self.target, "origin"))

        result = self.run_wrapper()

        self.assertIn(str(self.hosted), self.remote_url(self.target, "origin"))
        self.assertEqual(str(self.mirror), self.remote_url(self.target, "codebox"))
        self.assertEqual("origin", self.branch_tracking_remote(self.target))
        self.assertNotIn("warning", result.stderr)

    def test_missing_recorded_origin_warns_instead_of_failing(self):
        self.git("--git-dir", str(self.mirror), "config", "--unset", "nagi.origin-url")

        result = self.run_wrapper()

        self.assertIn("no recorded origin", result.stderr)
        self.assertEqual("", self.remote_url(self.target, "origin"))
        self.assertEqual(str(self.mirror), self.remote_url(self.target, "codebox"))

    def test_origin_is_rejected_as_the_sync_remote(self):
        environment = os.environ.copy()
        environment.update(
            {
                "NAGI_REPO_SYNC_ROOT": str(self.projects),
                "NAGI_REPO_SYNC_MIRROR_PATH": str(self.mirrors),
                "NAGI_REPO_SYNC_BIN": str(self.sync_bin),
                "NAGI_REPO_SYNC_REMOTE_NAME": "origin",
                "NAGI_REPO_SYNC_STATE_DIR": str(self.root / "state"),
                "NAGI_REPO_SYNC_HOST": "codebox",
            }
        )
        result = subprocess.run(
            [os.environ.get("BASH", "bash"), str(SCRIPT)],
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        self.assertEqual(2, result.returncode)
        self.assertIn('refusing "origin"', result.stderr)


if __name__ == "__main__":
    unittest.main()
