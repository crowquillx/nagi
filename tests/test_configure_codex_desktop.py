import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(os.environ["CODEX_CONFIGURATOR"])
SPEC = importlib.util.spec_from_file_location("codex_configurator", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
configurator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(configurator)

ARGS = {
    "source": "/nix/store/new-app/plugins/openai-bundled",
    "node_repl_command": "/nix/store/new-app/node_repl",
    "node_repl_node_path": "/nix/store/new-app/bin/node",
    "app_version": "26.800.1",
    "node_repl_node_module_dirs": "/nix/store/new-app/node_modules",
    "node_repl_trusted_code_paths": "/home/user/.codex:/nix/store/new-app/node_modules",
    "codex_cli_path": "/nix/store/new-app/codex",
}


class TransformConfigTests(unittest.TestCase):
    def transform(self, text: str) -> str:
        return configurator.transform_config(text, **ARGS)

    def test_empty_config(self) -> None:
        transformed = self.transform("")
        self.assertIn("[features]\nplugins = true\ncode_mode_host = true", transformed)
        self.assertIn("[marketplaces.openai-bundled]", transformed)

    def test_is_idempotent(self) -> None:
        original = '[features]\nplugins = false\n\n[unrelated]\nvalue = "kept"\n'
        transformed = self.transform(original)
        self.assertEqual(self.transform(transformed), transformed)

    def test_preserves_unrelated_config_and_existing_sections(self) -> None:
        original = (
            'model = "gpt-5"\n\n'
            "[features]\n"
            "web_search = true\n"
            "plugins = false\n\n"
            "[marketplaces.openai-bundled]\n"
            'source = "/old"\n'
            'source_type = "local"\n\n'
            "[unrelated]\n"
            'value = "kept"\n'
        )
        transformed = self.transform(original)
        self.assertIn('model = "gpt-5"', transformed)
        self.assertIn("web_search = true", transformed)
        self.assertIn("[unrelated]\nvalue = \"kept\"", transformed)
        self.assertEqual(transformed.count("[marketplaces.openai-bundled]"), 1)
        self.assertIn("plugins = true", transformed)
        self.assertIn("code_mode_host = true", transformed)

    def test_enables_code_mode_host(self) -> None:
        original = "[features]\nplugins = true\ncode_mode_host = false\n"
        transformed = self.transform(original)
        self.assertIn("code_mode_host = true", transformed)
        self.assertNotIn("code_mode_host = false", transformed)

    def test_rewrites_existing_node_repl_paths(self) -> None:
        original = (
            "[mcp_servers.node_repl]\n"
            'command = "/nix/store/old/node_repl"\n'
            'args = ["--stdio"]\n\n'
            "[mcp_servers.node_repl.env]\n"
            'NODE_REPL_NODE_PATH = "/nix/store/old/bin/node"\n'
            'NODE_REPL_NODE_MODULE_DIRS = "/nix/store/old/node_modules"\n'
            'NODE_REPL_TRUSTED_CODE_PATHS = "/home/user/.codex:/nix/store/old/node_modules"\n'
            'CODEX_CLI_PATH = "/nix/store/old/codex"\n'
            'BROWSER_USE_CODEX_APP_VERSION = "old"\n\n'
            "[shell_environment_policy.set]\n"
            'NODE_REPL_TRUSTED_CODE_PATHS = "/home/user/.codex:/nix/store/old/node_modules"\n'
        )
        transformed = self.transform(original)
        self.assertIn(f'command = "{ARGS["node_repl_command"]}"', transformed)
        self.assertIn(
            f'NODE_REPL_NODE_PATH = "{ARGS["node_repl_node_path"]}"',
            transformed,
        )
        self.assertIn(
            f'NODE_REPL_NODE_MODULE_DIRS = "{ARGS["node_repl_node_module_dirs"]}"',
            transformed,
        )
        self.assertIn(
            f'NODE_REPL_TRUSTED_CODE_PATHS = "{ARGS["node_repl_trusted_code_paths"]}"',
            transformed,
        )
        self.assertIn(
            f'CODEX_CLI_PATH = "{ARGS["codex_cli_path"]}"',
            transformed,
        )
        self.assertIn(
            f'BROWSER_USE_CODEX_APP_VERSION = "{ARGS["app_version"]}"',
            transformed,
        )
        self.assertIn('args = ["--stdio"]', transformed)
        self.assertEqual(
            transformed.count(f'NODE_REPL_TRUSTED_CODE_PATHS = "{ARGS["node_repl_trusted_code_paths"]}"'),
            2,
        )

    def test_does_not_create_node_repl_section(self) -> None:
        transformed = self.transform('[unrelated]\nvalue = "kept"\n')
        self.assertNotIn("[mcp_servers.node_repl]", transformed)


class SafeWriteTests(unittest.TestCase):
    def test_invalid_config_is_not_replaced(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            config_path = Path(temp_dir) / "config.toml"
            original = "[invalid\n"
            config_path.write_text(original, encoding="utf-8")

            with self.assertRaises(Exception):
                configurator.configure_config(config_path, **ARGS)

            self.assertEqual(config_path.read_text(encoding="utf-8"), original)

    def test_replace_failure_preserves_original_and_removes_temp_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            config_path = Path(temp_dir) / "config.toml"
            original = '[unrelated]\nvalue = "kept"\n'
            config_path.write_text(original, encoding="utf-8")

            with mock.patch.object(
                configurator.os,
                "replace",
                side_effect=OSError("simulated replace failure"),
            ):
                with self.assertRaises(OSError):
                    configurator.configure_config(config_path, **ARGS)

            self.assertEqual(config_path.read_text(encoding="utf-8"), original)
            self.assertEqual(
                list(Path(temp_dir).glob(".config.toml.*")),
                [],
            )


if __name__ == "__main__":
    unittest.main()
