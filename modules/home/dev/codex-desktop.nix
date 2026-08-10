{
  inputs,
  lib,
  pkgs,
  vars ? { },
  ...
}:
let
  get = path: default: lib.attrByPath path default vars;
  codingToolsEnabled = get [ "features" "codingTools" "enable" ] true;
  aiCliEnabled = get [ "features" "codingTools" "aiCli" "enable" ] codingToolsEnabled;
  codexEnabled = get [ "features" "codingTools" "aiCli" "codex" "enable" ] aiCliEnabled;
  codexPkg = lib.attrByPath [ "llm-agents" "codex" ] null pkgs;
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
  configureCodexDesktopPlugins = ./configure-codex-desktop.py;
in
{
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
      home.packages = [ codexPkg ];

      home.activation.configureCodexDesktopPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
