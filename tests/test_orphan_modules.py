import importlib.util
import os
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(os.environ["ORPHAN_SCANNER"])
SPEC = importlib.util.spec_from_file_location("orphan_scanner", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
scanner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scanner)


class OrphanScannerTests(unittest.TestCase):
    def write(self, root: Path, relative: str, content: str = "{...}: { }") -> None:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def test_path_aware_reachability_comments_and_default_imports(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self.write(
                repo,
                "modules/combined/stacks.nix",
                """
                [
                  ../home/used/shared.nix
                  ../home/directory
                ]
                # ../home/commented/shared.nix
                """,
            )
            self.write(repo, "modules/home/used/shared.nix")
            self.write(repo, "modules/home/directory/default.nix")
            self.write(repo, "modules/home/commented/shared.nix")
            self.write(repo, "modules/home/duplicate/shared.nix")

            orphans, _ = scanner.scan(repo)
            relative = {path.relative_to(repo).as_posix() for path in orphans}

            self.assertNotIn("modules/home/used/shared.nix", relative)
            self.assertNotIn("modules/home/directory/default.nix", relative)
            self.assertIn("modules/home/commented/shared.nix", relative)
            self.assertIn("modules/home/duplicate/shared.nix", relative)

    def test_dormant_niri_roots_keep_their_dependencies_reachable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self.write(repo, "modules/combined/stacks.nix", "[ ]")
            self.write(
                repo,
                "modules/home/desktop/niri-user.nix",
                "{...}: { imports = [ ./niri ]; }",
            )
            self.write(repo, "modules/home/desktop/niri/default.nix")
            self.write(repo, "modules/nixos/desktop/niri.nix")

            orphans, dormant = scanner.scan(repo)

            self.assertEqual(orphans, [])
            self.assertEqual(len(dormant), 2)


if __name__ == "__main__":
    unittest.main()
