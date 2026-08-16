{
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
  chatgptPkg = lib.attrByPath [ "llm-agents" "chatgpt" ] null pkgs;
  openaiBundledMarketplace = "${chatgptPkg}/lib/chatgpt/resources/plugins/openai-bundled";
  nodeReplCommand = "${chatgptPkg}/lib/chatgpt/resources/cua_node/bin/node_repl";
  nodeReplNodePath = "${chatgptPkg}/lib/chatgpt/resources/cua_node/bin/node";
  # Version segment from the package name, e.g. chatgpt-26.810.52044
  chatgptAppVersion =
    let
      m = builtins.match ".*-([0-9]+\\.[0-9]+\\.[0-9]+)$" chatgptPkg.name;
    in
    if m != null then builtins.head m else "";
  configureChatgptConfig = ./configure-codex-desktop.py;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(codexEnabled && codexPkg == null);
          message = "features.codingTools.aiCli.codex.enable is true, but pkgs.llm-agents.codex could not be resolved.";
        }
        {
          assertion = !(codexEnabled && chatgptPkg == null);
          message = "features.codingTools.aiCli.codex.enable is true, but the chatgpt desktop package could not be resolved from llm-agents.nix.";
        }
      ];
    }
    (lib.mkIf codexEnabled {
      home.packages = [ codexPkg chatgptPkg ];

      home.activation.configureCodexDesktopPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CODEX_MARKETPLACE_SOURCE=${lib.escapeShellArg openaiBundledMarketplace} \
        CODEX_NODE_REPL_COMMAND=${lib.escapeShellArg nodeReplCommand} \
        CODEX_NODE_REPL_NODE_PATH=${lib.escapeShellArg nodeReplNodePath} \
        CODEX_DESKTOP_APP_VERSION=${lib.escapeShellArg chatgptAppVersion} \
          ${pkgs.python3}/bin/python ${configureChatgptConfig}
      '';
    })
  ];
}
