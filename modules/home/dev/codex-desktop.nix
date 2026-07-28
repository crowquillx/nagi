{
  inputs,
  lib,
  pkgs,
  vars ? {},
  ...
}: let
  get = path: default: lib.attrByPath path default vars;
  codingToolsEnabled = get ["features" "codingTools" "enable"] true;
  aiCliEnabled = get ["features" "codingTools" "aiCli" "enable"] codingToolsEnabled;
  codexEnabled = get ["features" "codingTools" "aiCli" "codex" "enable"] aiCliEnabled;
  codexPkg = lib.attrByPath ["llm-agents" "codex"] null pkgs;
  codexDesktopPkg =
    inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.codex-desktop-computer-use-ui-remote-mobile-control;
  openaiBundledMarketplace = "${codexDesktopPkg}/opt/codex-desktop/resources/plugins/openai-bundled";
  nodeReplCommand = "${codexDesktopPkg}/opt/codex-desktop/resources/node_repl";
  nodeReplNodePath = "${codexDesktopPkg}/opt/codex-desktop/resources/node-runtime/bin/node";
  # Version segment from the package name, e.g. ...-26.721.41059
  codexDesktopAppVersion =
    let
      m = builtins.match ".*-([0-9]+\\.[0-9]+\\.[0-9]+)$" codexDesktopPkg.name;
    in
      if m != null then builtins.head m else "";
  configureCodexDesktopPlugins = pkgs.writeText "configure-codex-desktop-plugins.py" ''
    import json
    import os
    import re
    from pathlib import Path

    MARKETPLACE_NAME = "openai-bundled"
    NODE_REPL_SERVER = "node_repl"

    def upsert_features_plugins(text: str) -> str:
        features_re = re.compile(r"(?ms)^\[features\]\n(?P<body>.*?)(?=^\[|\Z)")
        match = features_re.search(text)
        if match is None:
            prefix = "\n" if text and not text.endswith("\n") else ""
            return f"{text}{prefix}[features]\nplugins = true\n"

        body = match.group("body")
        if re.search(r"(?m)^plugins\s*=", body):
            body = re.sub(r"(?m)^plugins\s*=.*$", "plugins = true", body)
        else:
            body = f"{body.rstrip()}\nplugins = true\n"

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
        """Double-quoted TOML string matching Codex Desktop's writer."""
        return json.dumps(value)


    def _replace_assignment(body: str, key: str, value: str) -> str:
        """Set key = value in a TOML section body; add the key if missing."""
        pattern = re.compile(rf"(?m)^({re.escape(key)}\s*=\s*).*$")
        if pattern.search(body):
            return pattern.sub(rf"\g<1>{value}", body)
        # Preserve trailing newline conventions used by surrounding sections.
        if body and not body.endswith("\n"):
            body += "\n"
        return f"{body}{key} = {value}\n"


    def rewrite_node_repl_paths(
        text: str,
        command: str,
        node_path: str,
        app_version: str,
    ) -> str:
        """Keep mcp_servers.node_repl on the current Codex Desktop store paths.

        Codex Desktop writes absolute /nix/store paths into config.toml. After a
        package upgrade + GC those paths vanish and omp (which imports
        [mcp_servers.*] from ~/.codex/config.toml) fails with posix_spawn ENOENT.
        Only rewrite when the section already exists — we do not invent the
        server entry; Desktop owns creating it.
        """
        # Rewrite nested .env first so later top-level section edits see final text.
        env_re = re.compile(
            rf"(?ms)^(?P<header>\[mcp_servers\.{re.escape(NODE_REPL_SERVER)}\.env\]\n)"
            rf"(?P<body>.*?)(?=^\[|\Z)"
        )
        env_match = env_re.search(text)
        if env_match is not None:
            env_body = env_match.group("body")
            env_body = _replace_assignment(env_body, "NODE_REPL_NODE_PATH", _toml_str(node_path))
            if app_version:
                env_body = _replace_assignment(
                    env_body, "BROWSER_USE_CODEX_APP_VERSION", _toml_str(app_version)
                )
            text = (
                text[: env_match.start("body")]
                + env_body
                + text[env_match.end("body") :]
            )

        section_re = re.compile(
            rf"(?ms)^(?P<header>\[mcp_servers\.{re.escape(NODE_REPL_SERVER)}\]\n)"
            rf"(?P<body>.*?)(?=^\[|\Z)"
        )
        match = section_re.search(text)
        if match is None:
            return text

        body = _replace_assignment(match.group("body"), "command", _toml_str(command))
        return text[: match.start("body")] + body + text[match.end("body") :]


    def main() -> None:
        source = os.environ["CODEX_MARKETPLACE_SOURCE"]
        node_repl_command = os.environ["CODEX_NODE_REPL_COMMAND"]
        node_repl_node_path = os.environ["CODEX_NODE_REPL_NODE_PATH"]
        app_version = os.environ.get("CODEX_DESKTOP_APP_VERSION", "")
        config_dir = Path(os.environ["HOME"]) / ".codex"
        config_path = config_dir / "config.toml"
        config_dir.mkdir(mode=0o700, exist_ok=True)

        if config_path.is_symlink():
            try:
                text = config_path.read_text()
            except FileNotFoundError:
                text = ""
            config_path.unlink()
        elif config_path.exists():
            text = config_path.read_text()
        else:
            text = ""

        text = upsert_features_plugins(text)
        text = upsert_marketplace(text, source)
        text = rewrite_node_repl_paths(
            text,
            command=node_repl_command,
            node_path=node_repl_node_path,
            app_version=app_version,
        )
        config_path.write_text(text)


    if __name__ == "__main__":
        main()
  '';
in {
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(codexEnabled && codexPkg == null);
          message = "features.codingTools.aiCli.codex.enable is true, but pkgs.llm-agents.codex could not be resolved for Codex Desktop.";
        }
      ];
    }
    (lib.mkIf codexEnabled {
      home.packages = [codexPkg];

      home.activation.configureCodexDesktopPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
        CODEX_MARKETPLACE_SOURCE=${lib.escapeShellArg openaiBundledMarketplace} \
        CODEX_NODE_REPL_COMMAND=${lib.escapeShellArg nodeReplCommand} \
        CODEX_NODE_REPL_NODE_PATH=${lib.escapeShellArg nodeReplNodePath} \
        CODEX_DESKTOP_APP_VERSION=${lib.escapeShellArg codexDesktopAppVersion} \
          ${pkgs.python3}/bin/python ${configureCodexDesktopPlugins}
      '';

      programs.codexDesktopLinux = {
        enable = true;
        package = codexDesktopPkg;
        cliPackage = codexPkg;
        computerUseUi.enable = true;
        remoteControl = {
          enable = true;
          package = codexPkg;
        };
        remoteMobileControl.enable = true;
      };
    })
  ];
}
