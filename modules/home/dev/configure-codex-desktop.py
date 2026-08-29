#!/usr/bin/env python3
"""Safely maintain the repo-owned portions of Codex Desktop config.toml."""

import json
import os
import re
import tempfile
import tomllib
from pathlib import Path

MARKETPLACE_NAME = "openai-bundled"
NODE_REPL_SERVER = "node_repl"
FEATURE_FLAGS = {
    "plugins": "true",
    "code_mode_host": "true",
}


def upsert_feature_flags(text: str, flags: dict[str, str] | None = None) -> str:
    flags = FEATURE_FLAGS if flags is None else flags
    features_re = re.compile(r"(?ms)^\[features\]\n(?P<body>.*?)(?=^\[|\Z)")
    match = features_re.search(text)
    if match is None:
        prefix = "\n" if text and not text.endswith("\n") else ""
        body = "".join(f"{key} = {value}\n" for key, value in flags.items())
        return f"{text}{prefix}[features]\n{body}"

    body = match.group("body")
    for key, value in flags.items():
        if re.search(rf"(?m)^{re.escape(key)}\s*=", body):
            body = re.sub(rf"(?m)^{re.escape(key)}\s*=.*$", f"{key} = {value}", body)
        else:
            body = f"{body.rstrip()}\n{key} = {value}\n"

    return text[: match.start("body")] + body + text[match.end("body") :]


def upsert_marketplace(text: str, source: str) -> str:
    section_re = re.compile(
        rf"(?ms)^\[marketplaces\.{re.escape(MARKETPLACE_NAME)}\]\n.*?(?=^\[|\Z)"
    )
    text = section_re.sub("", text).rstrip()
    section = (
        f"[marketplaces.{MARKETPLACE_NAME}]\n"
        f"source = {source!r}\n"
        'source_type = "local"\n'
    )
    return f"{text}\n\n{section}" if text else section


def _toml_str(value: str) -> str:
    """Return a double-quoted TOML string matching Codex Desktop's writer."""
    return json.dumps(value)


def _replace_assignment(body: str, key: str, value: str) -> str:
    pattern = re.compile(rf"(?m)^({re.escape(key)}\s*=\s*).*$")
    if pattern.search(body):
        return pattern.sub(rf"\g<1>{value}", body)
    if body and not body.endswith("\n"):
        body += "\n"
    return f"{body}{key} = {value}\n"


def rewrite_node_repl_paths(
    text: str,
    command: str,
    node_path: str,
    app_version: str,
    *,
    node_module_dirs: str = "",
    trusted_code_paths: str = "",
    codex_cli_path: str = "",
) -> str:
    """Refresh existing node_repl paths without inventing the server entry."""
    env_re = re.compile(
        rf"(?ms)^(?P<header>\[mcp_servers\.{re.escape(NODE_REPL_SERVER)}\.env\]\n)"
        rf"(?P<body>.*?)(?=^\[|\Z)"
    )
    env_match = env_re.search(text)
    if env_match is not None:
        env_body = env_match.group("body")
        env_body = _replace_assignment(
            env_body, "NODE_REPL_NODE_PATH", _toml_str(node_path)
        )
        if node_module_dirs:
            env_body = _replace_assignment(
                env_body,
                "NODE_REPL_NODE_MODULE_DIRS",
                _toml_str(node_module_dirs),
            )
        if trusted_code_paths:
            env_body = _replace_assignment(
                env_body,
                "NODE_REPL_TRUSTED_CODE_PATHS",
                _toml_str(trusted_code_paths),
            )
        if codex_cli_path:
            env_body = _replace_assignment(
                env_body, "CODEX_CLI_PATH", _toml_str(codex_cli_path)
            )
        if app_version:
            env_body = _replace_assignment(
                env_body,
                "BROWSER_USE_CODEX_APP_VERSION",
                _toml_str(app_version),
            )
        text = (
            text[: env_match.start("body")]
            + env_body
            + text[env_match.end("body") :]
        )

    policy_re = re.compile(
        r"(?ms)^(?P<header>\[shell_environment_policy\.set\]\n)"
        r"(?P<body>.*?)(?=^\[|\Z)"
    )
    policy_match = policy_re.search(text)
    if policy_match is not None and trusted_code_paths:
        policy_body = policy_match.group("body")
        if re.search(r"(?m)^NODE_REPL_TRUSTED_CODE_PATHS\s*=", policy_body):
            policy_body = _replace_assignment(
                policy_body,
                "NODE_REPL_TRUSTED_CODE_PATHS",
                _toml_str(trusted_code_paths),
            )
            text = (
                text[: policy_match.start("body")]
                + policy_body
                + text[policy_match.end("body") :]
            )

    section_re = re.compile(
        rf"(?ms)^(?P<header>\[mcp_servers\.{re.escape(NODE_REPL_SERVER)}\]\n)"
        rf"(?P<body>.*?)(?=^\[|\Z)"
    )
    match = section_re.search(text)
    if match is None:
        return text

    body = _replace_assignment(
        match.group("body"), "command", _toml_str(command)
    )
    return text[: match.start("body")] + body + text[match.end("body") :]


def transform_config(
    text: str,
    *,
    source: str,
    node_repl_command: str,
    node_repl_node_path: str,
    app_version: str,
    node_repl_node_module_dirs: str = "",
    node_repl_trusted_code_paths: str = "",
    codex_cli_path: str = "",
) -> str:
    transformed = upsert_feature_flags(text)
    transformed = upsert_marketplace(transformed, source)
    transformed = rewrite_node_repl_paths(
        transformed,
        command=node_repl_command,
        node_path=node_repl_node_path,
        app_version=app_version,
        node_module_dirs=node_repl_node_module_dirs,
        trusted_code_paths=node_repl_trusted_code_paths,
        codex_cli_path=codex_cli_path,
    )
    # Refuse to replace a user's config if either existing content or a
    # transformation produced invalid TOML.
    tomllib.loads(transformed)
    return transformed


def atomic_write(path: Path, text: str) -> None:
    """Replace path atomically, leaving the original untouched on failure."""
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            os.fchmod(temporary.fileno(), 0o600)
            temporary.write(text)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_path, path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def configure_config(
    config_path: Path,
    *,
    source: str,
    node_repl_command: str,
    node_repl_node_path: str,
    app_version: str,
    node_repl_node_module_dirs: str = "",
    node_repl_trusted_code_paths: str = "",
    codex_cli_path: str = "",
) -> None:
    try:
        text = config_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        text = ""

    transformed = transform_config(
        text,
        source=source,
        node_repl_command=node_repl_command,
        node_repl_node_path=node_repl_node_path,
        app_version=app_version,
        node_repl_node_module_dirs=node_repl_node_module_dirs,
        node_repl_trusted_code_paths=node_repl_trusted_code_paths,
        codex_cli_path=codex_cli_path,
    )
    atomic_write(config_path, transformed)


def main() -> None:
    config_dir = Path(os.environ["HOME"]) / ".codex"
    config_path = config_dir / "config.toml"
    config_dir.mkdir(mode=0o700, exist_ok=True)
    configure_config(
        config_path,
        source=os.environ["CODEX_MARKETPLACE_SOURCE"],
        node_repl_command=os.environ["CODEX_NODE_REPL_COMMAND"],
        node_repl_node_path=os.environ["CODEX_NODE_REPL_NODE_PATH"],
        app_version=os.environ.get("CODEX_DESKTOP_APP_VERSION", ""),
        node_repl_node_module_dirs=os.environ.get(
            "CODEX_NODE_REPL_NODE_MODULE_DIRS", ""
        ),
        node_repl_trusted_code_paths=os.environ.get(
            "CODEX_NODE_REPL_TRUSTED_CODE_PATHS", ""
        ),
        codex_cli_path=os.environ.get("CODEX_CLI_PATH", ""),
    )


if __name__ == "__main__":
    main()
