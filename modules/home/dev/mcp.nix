{
  lib,
  pkgs,
  vars ? {},
  inputs,
  ...
}: let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  codingToolsEnabled = get ["features" "codingTools" "enable"] true;
  aiCliEnabled = get ["features" "codingTools" "aiCli" "enable"] codingToolsEnabled;
  codexEnabled = get ["features" "codingTools" "aiCli" "codex" "enable"] aiCliEnabled;
  opencodeEnabled = get ["features" "codingTools" "aiCli" "opencode" "enable"] aiCliEnabled;
  nixosMcpEnabled = get ["features" "mcp" "nixos" "enable"] aiCliEnabled;

  llmAgent = name: lib.attrByPath ["llm-agents" name] null pkgs;

  # Prefer llm-agents.nix for codex because it tracks upstream closely.
  codexPkg = let
    llmPkg = llmAgent "codex";
  in
    if llmPkg != null then llmPkg else lib.attrByPath ["codex"] null pkgs;
  # Prefer llm-agents.nix for opencode: it tracks upstream anomalyco/opencode
  # releases closely (nixpkgs lags far behind). The Home Manager
  # programs.opencode module configures the same project (opencode.ai), so
  # the llm-agents package is a drop-in upgrade, not a different app.
  opencodePkg = let
    llmPkg = llmAgent "opencode";
  in
    if llmPkg != null then llmPkg else lib.attrByPath ["opencode"] null pkgs;

in {
  imports = [
    inputs.mcp-servers-nix.homeManagerModules.default
  ];

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(codexEnabled && codexPkg == null);
          message = "features.codingTools.aiCli.codex.enable is true, but nixpkgs package 'codex' could not be resolved.";
        }
        {
          assertion = !(opencodeEnabled && opencodePkg == null);
          message = "features.codingTools.aiCli.opencode.enable is true, but package 'opencode' could not be resolved from llm-agents.nix or nixpkgs.";
        }
      ];
    }
    (lib.mkIf opencodeEnabled {
      programs.opencode = {
        enable = true;
        package = opencodePkg;
        enableMcpIntegration = nixosMcpEnabled;
      };
    })
    (lib.mkIf nixosMcpEnabled {
      programs.mcp.enable = true;
      mcp-servers.programs.nixos.enable = true;
    })
  ];
}
