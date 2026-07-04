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
  configureCodexDesktopPlugins = pkgs.writeText "configure-codex-desktop-plugins.py" ''
    import os
    import re
    from pathlib import Path


    MARKETPLACE_NAME = "openai-bundled"


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


    def main() -> None:
        source = os.environ["CODEX_MARKETPLACE_SOURCE"]
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
