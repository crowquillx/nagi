{
  lib,
  pkgs,
  config,
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
  chatgptBinName = if chatgptPkg == null then "chatgpt" else chatgptPkg.meta.mainProgram or "chatgpt";
  configureChatgptConfig = ./configure-codex-desktop.py;
  computerUseEnabled = get [ "features" "mcp" "computerUseLinux" "enable" ] false;
  computerUseCommand = lib.attrByPath [
    "programs"
    "mcp"
    "servers"
    "computer-use-linux"
    "command"
  ] null config;
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
        {
          assertion = !(codexEnabled && computerUseEnabled) || computerUseCommand != null;
          message = "features.mcp.computerUseLinux.enable is true with Codex, but programs.mcp.servers.computer-use-linux.command is missing.";
        }
      ];
    }
    (lib.mkIf codexEnabled {
      home.packages = [
        codexPkg
        chatgptPkg
      ];

      # llm-agents wraps chatgpt with makeShellWrapper (bin + share only).
      # CUA resources live on the unwrapped output; resolve that at activation
      # so eval does not have to realize the package.
      home.activation.configureCodexDesktopPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        wrapped=${lib.escapeShellArg (toString chatgptPkg)}
        cua_root="$wrapped"
        if [ ! -x "$cua_root/lib/chatgpt/resources/cua_node/bin/node_repl" ]; then
          wrapper="$wrapped/bin/${chatgptBinName}"
          cua_root="$(${pkgs.gnused}/bin/sed -n 's/.*exec "\([^"]*\)\/bin\/chatgpt".*/\1/p' "$wrapper" | ${pkgs.coreutils}/bin/head -n1)"
        fi
        if [ ! -x "$cua_root/lib/chatgpt/resources/cua_node/bin/node_repl" ]; then
          echo "configureCodexDesktopPlugins: node_repl not found under $wrapped or its wrapper target ($cua_root)" >&2
          exit 1
        fi
        resources="$cua_root/lib/chatgpt/resources"
        version="$(${pkgs.coreutils}/bin/basename "$cua_root")"
        version="''${version##*-}"
        mkdir -p "$HOME/.config/environment.d"
        ${pkgs.coreutils}/bin/printf 'CODEX_CODE_MODE_HOST_PATH=%s\n' "$resources/codex-code-mode-host" \
          > "$HOME/.config/environment.d/99-codex-code-mode-host.conf"
        if [ -f "$HOME/.config/systemd/user/codex-remote-control.service.d/code-mode-host.conf" ]; then
          ${pkgs.coreutils}/bin/printf '[Service]\nEnvironment=CODEX_CODE_MODE_HOST_PATH=%s\n' \
            "$resources/codex-code-mode-host" \
            > "$HOME/.config/systemd/user/codex-remote-control.service.d/code-mode-host.conf"
        fi
        CODEX_MARKETPLACE_SOURCE="$resources/plugins/openai-bundled" \
        CODEX_NODE_REPL_COMMAND="$resources/cua_node/bin/node_repl" \
        CODEX_NODE_REPL_NODE_PATH="$resources/cua_node/bin/node" \
        CODEX_NODE_REPL_NODE_MODULE_DIRS="$resources/cua_node/lib/node_modules" \
        CODEX_NODE_REPL_TRUSTED_CODE_PATHS="${config.home.homeDirectory}/.codex:$resources/cua_node/lib/node_modules" \
        CODEX_CLI_PATH="$resources/codex" \
        CODEX_DESKTOP_APP_VERSION="$version" \
        ${
          lib.optionalString (computerUseEnabled && computerUseCommand != null) ''
            CODEX_COMPUTER_USE_LINUX_COMMAND=${lib.escapeShellArg computerUseCommand} \
            CODEX_COMPUTER_USE_LINUX_CWD=${lib.escapeShellArg config.home.homeDirectory} \
          ''
        } \
          ${pkgs.python3}/bin/python ${configureChatgptConfig}
      '';
    })
  ];
}
