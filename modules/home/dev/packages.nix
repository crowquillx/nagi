{
  lib,
  pkgs,
  vars ? {},
  ...
}: let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  codingToolsEnabled = get ["features" "codingTools" "enable"] true;
  editorsEnabled = get ["features" "codingTools" "editors" "enable"] codingToolsEnabled;
  vscodeEnabled = editorsEnabled && get ["features" "codingTools" "editors" "vscode" "enable"] true;
  antigravityEnabled = editorsEnabled && get ["features" "codingTools" "editors" "antigravity" "enable"] true;
  t3codeEnabled = editorsEnabled && get ["features" "codingTools" "editors" "t3code" "enable"] true;
  cursorEnabled = editorsEnabled && get ["features" "codingTools" "editors" "cursor" "enable"] true;
  zedEnabled = editorsEnabled && get ["features" "codingTools" "editors" "zed" "enable"] true;
  limuxEnabled = editorsEnabled && get ["features" "codingTools" "editors" "limux" "enable"] true;
  aiCliEnabled = get ["features" "codingTools" "aiCli" "enable"] codingToolsEnabled;
  claudeEnabled = get ["features" "codingTools" "aiCli" "claude" "enable"] aiCliEnabled;
  cliProxyApiEnabled = get ["features" "codingTools" "aiCli" "cliProxyApi" "enable"] aiCliEnabled;
  geminiEnabled = get ["features" "codingTools" "aiCli" "gemini" "enable"] aiCliEnabled;
  piEnabled = get ["features" "codingTools" "aiCli" "pi" "enable"] aiCliEnabled;
  ohMyPiEnabled = get ["features" "codingTools" "aiCli" "ohMyPi" "enable"] aiCliEnabled;
  nixToolsEnabled = get ["features" "codingTools" "nixTools" "enable"] codingToolsEnabled;

  llmAgent = name: lib.attrByPath ["llm-agents" name] null pkgs;

  vscodePkg = lib.attrByPath ["vscode"] null pkgs;
  geminiCliPkg = let
    llmPkg = llmAgent "gemini-cli";
    sourcePkg = lib.attrByPath ["gemini-cli"] null pkgs;
    binPkg = lib.attrByPath ["gemini-cli-bin"] null pkgs;
  in
    if llmPkg != null
    then llmPkg
    else if sourcePkg != null
    then sourcePkg
    else binPkg;
  piPkg = llmAgent "pi";
  ohMyPiPkg = llmAgent "omp";
  claudeCodePkg = llmAgent "claude-code";
  cliProxyApiPkg = llmAgent "cli-proxy-api";
  bunPkg = lib.attrByPath ["bun"] null pkgs;
  antigravityPkg = let
    fhsPkg = lib.attrByPath ["antigravity-fhs"] null pkgs;
    nativePkg = lib.attrByPath ["antigravity"] null pkgs;
  in
    if fhsPkg != null
    then fhsPkg
    else nativePkg;
  bubblewrapPkg = lib.attrByPath ["bubblewrap"] null pkgs;
  statixPkg = lib.attrByPath ["statix"] null pkgs;
  uvPkg = lib.attrByPath ["uv"] null pkgs;
  deadnixPkg = lib.attrByPath ["deadnix"] null pkgs;
  alejandraPkg = lib.attrByPath ["alejandra"] null pkgs;
  nixfmtPkg = lib.findFirst (pkg: pkg != null) null [
    (lib.attrByPath ["nixfmt"] null pkgs)
    (lib.attrByPath ["nixfmt-classic"] null pkgs)
    (lib.attrByPath ["nixfmt-rfc-style"] null pkgs)
  ];
  nixLspPkg = lib.findFirst (pkg: pkg != null) null [
    (lib.attrByPath ["nixd"] null pkgs)
    (lib.attrByPath ["nil"] null pkgs)
  ];
  t3DesktopPkg = let
    base = lib.attrByPath ["t3code"] null pkgs;
    llmCodex = llmAgent "codex";
  in
    if base != null && llmCodex != null
    then base.override { codex = llmCodex; }
    else base;
  t3DesktopProgram =
    if t3DesktopPkg == null
    then "t3code-desktop"
    else t3DesktopPkg.meta.mainProgram or "t3code-desktop";
  ghPkg = lib.attrByPath ["gh"] null pkgs;
  skillsPkg = let
    llmPkg = llmAgent "skills";
  in
    if llmPkg != null then llmPkg else lib.attrByPath ["skills"] null pkgs;
  cursorPkg = lib.attrByPath ["code-cursor"] null pkgs;
  cursorCliPkg = lib.attrByPath ["cursor-cli"] null pkgs;
  zedEditorPkg = lib.attrByPath ["zed-editor"] null pkgs;
  limuxPkg = lib.attrByPath ["limux"] null pkgs;
  nilPkg = lib.attrByPath ["nil"] null pkgs;
in {
  assertions = [
    {
      assertion = !(vscodeEnabled && vscodePkg == null);
      message = "features.codingTools.editors.enable is true, but nixpkgs package 'vscode' could not be resolved.";
    }
    {
      assertion = !(geminiEnabled && geminiCliPkg == null);
      message = "features.codingTools.aiCli.gemini.enable is true, but package 'gemini-cli' could not be resolved from llm-agents.nix, nixpkgs, or gemini-cli-bin fallback.";
    }
    {
      assertion = !(claudeEnabled && claudeCodePkg == null);
      message = "features.codingTools.aiCli.claude.enable is true, but package 'claude-code' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(cliProxyApiEnabled && cliProxyApiPkg == null);
      message = "features.codingTools.aiCli.cliProxyApi.enable is true, but package 'cli-proxy-api' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(piEnabled && piPkg == null);
      message = "features.codingTools.aiCli.pi.enable is true, but package 'pi' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(ohMyPiEnabled && ohMyPiPkg == null);
      message = "features.codingTools.aiCli.ohMyPi.enable is true, but package 'omp' (Oh My Pi) could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(ohMyPiEnabled && bunPkg == null);
      message = "features.codingTools.aiCli.ohMyPi.enable is true, but nixpkgs package 'bun' could not be resolved.";
    }
    {
      assertion = !(antigravityEnabled && antigravityPkg == null);
      message = "features.codingTools.editors.enable is true, but nixpkgs package 'antigravity-fhs' (preferred) or 'antigravity' could not be resolved.";
    }
    {
      assertion = !(aiCliEnabled && bubblewrapPkg == null);
      message = "features.codingTools.aiCli.enable is true, but nixpkgs package 'bubblewrap' could not be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && statixPkg == null);
      message = "features.codingTools.nixTools.enable is true, but nixpkgs package 'statix' could not be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && deadnixPkg == null);
      message = "features.codingTools.nixTools.enable is true, but nixpkgs package 'deadnix' could not be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && alejandraPkg == null);
      message = "features.codingTools.nixTools.enable is true, but nixpkgs package 'alejandra' could not be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && nixfmtPkg == null);
      message = "features.codingTools.nixTools.enable is true, but no nixfmt package could be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && nixLspPkg == null);
      message = "features.codingTools.nixTools.enable is true, but no Nix language server (nixd or nil) could be resolved.";
    }
    {
      assertion = !(t3codeEnabled && t3DesktopPkg == null);
      message = "features.codingTools.editors.enable is true, but nixpkgs package 't3code' could not be resolved.";
    }
    {
      assertion = !(nixToolsEnabled && ghPkg == null);
      message = "features.codingTools.nixTools.enable is true, but nixpkgs package 'gh' could not be resolved.";
    }
    {
      assertion = !(aiCliEnabled && skillsPkg == null);
      message = "features.codingTools.aiCli.enable is true, but package 'skills' could not be resolved from llm-agents.nix or nixpkgs.";
    }
    {
      assertion = !(cursorEnabled && cursorPkg == null);
      message = "features.codingTools.editors.enable is true, but nixpkgs package 'code-cursor' could not be resolved.";
    }
    {
      assertion = !(cursorEnabled && cursorCliPkg == null);
      message = "features.codingTools.editors.enable is true, but nixpkgs package 'cursor-cli' could not be resolved.";
    }
    {
      assertion = !(limuxEnabled && limuxPkg == null);
      message = "features.codingTools.editors.limux.enable is true, but package 'limux' could not be resolved from limux-nix.";
    }
  ];

  home.packages =
    lib.optionals (vscodeEnabled && vscodePkg != null) [vscodePkg]
    ++ lib.optionals (geminiEnabled && geminiCliPkg != null) [geminiCliPkg]
    ++ lib.optionals (claudeEnabled && claudeCodePkg != null) [claudeCodePkg]
    ++ lib.optionals (cliProxyApiEnabled && cliProxyApiPkg != null) [cliProxyApiPkg]
    ++ lib.optionals (piEnabled && piPkg != null) [piPkg]
    ++ lib.optionals (ohMyPiEnabled && ohMyPiPkg != null) [ohMyPiPkg]
    ++ lib.optionals (ohMyPiEnabled && bunPkg != null) [bunPkg]
    ++ lib.optionals (aiCliEnabled && uvPkg != null) [uvPkg]
    ++ lib.optionals (antigravityEnabled && antigravityPkg != null) [antigravityPkg]
    ++ lib.optionals (aiCliEnabled && bubblewrapPkg != null) [bubblewrapPkg]
    ++ lib.optionals (nixToolsEnabled && statixPkg != null) [statixPkg]
    ++ lib.optionals (nixToolsEnabled && deadnixPkg != null) [deadnixPkg]
    ++ lib.optionals (nixToolsEnabled && alejandraPkg != null) [alejandraPkg]
    ++ lib.optionals (nixToolsEnabled && nixfmtPkg != null) [nixfmtPkg]
    ++ lib.optionals (nixToolsEnabled && nixLspPkg != null) [nixLspPkg]
    ++ lib.optionals (t3codeEnabled && t3DesktopPkg != null) [t3DesktopPkg]
    ++ lib.optionals (nixToolsEnabled && ghPkg != null) [ghPkg]
    ++ lib.optionals (aiCliEnabled && skillsPkg != null) [skillsPkg]
    ++ lib.optionals (cursorEnabled && cursorPkg != null) [cursorPkg]
    ++ lib.optionals (cursorEnabled && cursorCliPkg != null) [cursorCliPkg]
    ++ lib.optionals (zedEnabled && zedEditorPkg != null) [zedEditorPkg]
    ++ lib.optionals (nixToolsEnabled && nilPkg != null) [nilPkg]
    ++ lib.optionals (limuxEnabled && limuxPkg != null) [limuxPkg];

  xdg.desktopEntries = lib.optionalAttrs (t3codeEnabled && t3DesktopPkg != null) {
    t3code = {
      name = "T3 Code";
      comment = "T3 Code desktop build";
      exec = "${t3DesktopProgram} --no-sandbox %U";
      terminal = false;
      type = "Application";
      categories = ["Development"];
      icon = "t3code";
      settings = {
        StartupWMClass = "t3-code-desktop";
      };
    };
  };
}
