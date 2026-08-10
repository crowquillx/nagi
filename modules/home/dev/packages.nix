{
  lib,
  pkgs,
  vars ? { },
  inputs,
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  codingToolsEnabled = get [ "features" "codingTools" "enable" ] true;
  orcaEnabled = get [ "features" "codingTools" "orca" "enable" ] codingToolsEnabled;
  editorsEnabled = get [ "features" "codingTools" "editors" "enable" ] codingToolsEnabled;
  t3codeEnabled = editorsEnabled && get [ "features" "codingTools" "editors" "t3code" "enable" ] true;
  cursorEnabled = editorsEnabled && get [ "features" "codingTools" "editors" "cursor" "enable" ] true;
  zedEnabled = editorsEnabled && get [ "features" "codingTools" "editors" "zed" "enable" ] true;
  aiCliEnabled = get [ "features" "codingTools" "aiCli" "enable" ] codingToolsEnabled;
  claudeEnabled = get [ "features" "codingTools" "aiCli" "claude" "enable" ] aiCliEnabled;
  cliProxyApiEnabled = get [ "features" "codingTools" "aiCli" "cliProxyApi" "enable" ] aiCliEnabled;
  opencode2Enabled = get [ "features" "codingTools" "aiCli" "opencode2" "enable" ] false;
  geminiEnabled = get [ "features" "codingTools" "aiCli" "gemini" "enable" ] aiCliEnabled;
  grokEnabled = get [ "features" "codingTools" "aiCli" "grok" "enable" ] aiCliEnabled;
  piEnabled = get [ "features" "codingTools" "aiCli" "pi" "enable" ] aiCliEnabled;
  ohMyPiEnabled = get [ "features" "codingTools" "aiCli" "ohMyPi" "enable" ] aiCliEnabled;
  herdrEnabled = get [ "features" "codingTools" "aiCli" "herdr" "enable" ] aiCliEnabled;
  primeAgentEnabled = get [ "features" "codingTools" "aiCli" "primeAgent" "enable" ] aiCliEnabled;
  nixToolsEnabled = get [ "features" "codingTools" "nixTools" "enable" ] codingToolsEnabled;
  system = pkgs.stdenv.hostPlatform.system;

  orcaPkg = lib.attrByPath [ "orca-nix" "packages" system "default" ] null inputs;

  llmAgent = name: lib.attrByPath [ "llm-agents" name ] null pkgs;

  geminiCliPkg =
    let
      llmPkg = llmAgent "antigravity-cli";
      sourcePkg = lib.attrByPath [ "antigravity-cli" ] null pkgs;
      binPkg = lib.attrByPath [ "antigravity-cli-bin" ] null pkgs;
    in
    if llmPkg != null then
      llmPkg
    else if sourcePkg != null then
      sourcePkg
    else
      binPkg;
  piPkg = llmAgent "pi";
  ohMyPiPkg = llmAgent "omp";
  herdrPkg = llmAgent "herdr";
  primeAgentPkg = llmAgent "prime-agent";
  grokUpstreamPkg = llmAgent "grok";
  # The upstream Linux package uses bubblewrap to synthesize /bin/bash and
  # /bin/zsh. That is useful for the standalone CLI, but T3 Code launches
  # `grok agent stdio` from an already-managed desktop process, where the
  # nested mount namespace can fail before ACP initialization. The official
  # binary itself works when its shell is pinned to NixOS's /bin/sh.
  grokPkg =
    if grokUpstreamPkg == null then
      null
    else
      pkgs.symlinkJoin {
        name = "${grokUpstreamPkg.name}-direct";
        paths = [ grokUpstreamPkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f "$out/bin/grok" "$out/bin/agent"
          makeShellWrapper "${grokUpstreamPkg}/libexec/grok/grok" "$out/bin/grok" \
            --argv0 grok \
            --set SHELL /bin/sh \
            --add-flags "--no-auto-update"
          makeShellWrapper "${grokUpstreamPkg}/libexec/grok/grok" "$out/bin/agent" \
            --argv0 agent \
            --set SHELL /bin/sh \
            --add-flags "--no-auto-update"
        '';
        meta = grokUpstreamPkg.meta // {
          description = "Grok Build official binary with a T3 Code-compatible launcher";
        };
      };
  claudeCodePkg = llmAgent "claude-code";
  cliProxyApiPkg = llmAgent "cli-proxy-api";
  # OpenCode 2 is intentionally packaged as the separate `opencode2` binary,
  # so it can coexist with the v1 `programs.opencode` package.
  opencode2Pkg = llmAgent "opencode2";
  bunPkg = lib.attrByPath [ "bun" ] null pkgs;
  bubblewrapPkg = lib.attrByPath [ "bubblewrap" ] null pkgs;
  statixPkg = lib.attrByPath [ "statix" ] null pkgs;
  uvPkg = lib.attrByPath [ "uv" ] null pkgs;
  deadnixPkg = lib.attrByPath [ "deadnix" ] null pkgs;
  alejandraPkg = lib.attrByPath [ "alejandra" ] null pkgs;
  nixfmtPkg = lib.findFirst (pkg: pkg != null) null [
    (lib.attrByPath [ "nixfmt" ] null pkgs)
    (lib.attrByPath [ "nixfmt-classic" ] null pkgs)
    (lib.attrByPath [ "nixfmt-rfc-style" ] null pkgs)
  ];
  nixLspPkg = lib.findFirst (pkg: pkg != null) null [
    (lib.attrByPath [ "nixd" ] null pkgs)
    (lib.attrByPath [ "nil" ] null pkgs)
  ];
  t3DesktopPkg =
    let
      base = lib.attrByPath [ "t3code" ] null pkgs;
      llmCodex = llmAgent "codex";
    in
    if base != null && llmCodex != null then
      base.override {
        codex = llmCodex;
        grok = if grokEnabled then grokPkg else null;
      }
    else
      base;
  t3DesktopProgram =
    if t3DesktopPkg == null then
      "t3code-desktop"
    else
      t3DesktopPkg.meta.mainProgram or "t3code-desktop";
  ghPkg = lib.attrByPath [ "gh" ] null pkgs;
  graphiteCliPkg = lib.attrByPath [ "graphite-cli" ] null pkgs;
  skillsPkg =
    let
      llmPkg = llmAgent "skills";
    in
    if llmPkg != null then llmPkg else lib.attrByPath [ "skills" ] null pkgs;
  cursorPkg = lib.attrByPath [ "code-cursor" ] null pkgs;
  cursorCliPkg = lib.attrByPath [ "cursor-cli" ] null pkgs;
  zedEditorPkg = lib.attrByPath [ "zed-editor" ] null pkgs;
  nilPkg = lib.attrByPath [ "nil" ] null pkgs;
in
{
  assertions = [
    {
      assertion = !(orcaEnabled && orcaPkg == null);
      message = "features.codingTools.orca.enable is true, but the orca-nix package could not be resolved from the flake input.";
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
      assertion = !(opencode2Enabled && opencode2Pkg == null);
      message = "features.codingTools.aiCli.opencode2.enable is true, but package 'opencode2' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(grokEnabled && grokPkg == null);
      message = "features.codingTools.aiCli.grok.enable is true, but package 'grok' could not be resolved from llm-agents.nix.";
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
      assertion = !(herdrEnabled && herdrPkg == null);
      message = "features.codingTools.aiCli.herdr.enable is true, but package 'herdr' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(primeAgentEnabled && primeAgentPkg == null);
      message = "features.codingTools.aiCli.primeAgent.enable is true, but package 'prime-agent' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(ohMyPiEnabled && bunPkg == null);
      message = "features.codingTools.aiCli.ohMyPi.enable is true, but nixpkgs package 'bun' could not be resolved.";
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
      assertion = !(nixToolsEnabled && graphiteCliPkg == null);
      message = "features.codingTools.nixTools.enable is true, but nixpkgs package 'graphite-cli' could not be resolved.";
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
  ];

  home.packages =
    lib.optionals codingToolsEnabled [ pkgs.nodejs ]
    ++ lib.optionals (orcaEnabled && orcaPkg != null) [ orcaPkg ]
    ++ lib.optionals (geminiEnabled && geminiCliPkg != null) [ geminiCliPkg ]
    ++ lib.optionals (claudeEnabled && claudeCodePkg != null) [ claudeCodePkg ]
    ++ lib.optionals (cliProxyApiEnabled && cliProxyApiPkg != null) [ cliProxyApiPkg ]
    ++ lib.optionals (opencode2Enabled && opencode2Pkg != null) [ opencode2Pkg ]
    ++ lib.optionals (grokEnabled && grokPkg != null) [ grokPkg ]
    ++ lib.optionals (piEnabled && piPkg != null) [ piPkg ]
    ++ lib.optionals (ohMyPiEnabled && ohMyPiPkg != null) [ ohMyPiPkg ]
    ++ lib.optionals (ohMyPiEnabled && bunPkg != null) [ bunPkg ]
    ++ lib.optionals (herdrEnabled && herdrPkg != null) [ herdrPkg ]
    ++ lib.optionals (primeAgentEnabled && primeAgentPkg != null) [ primeAgentPkg ]
    ++ lib.optionals (aiCliEnabled && uvPkg != null) [ uvPkg ]
    ++ lib.optionals (aiCliEnabled && bubblewrapPkg != null) [ bubblewrapPkg ]
    ++ lib.optionals (nixToolsEnabled && statixPkg != null) [ statixPkg ]
    ++ lib.optionals (nixToolsEnabled && deadnixPkg != null) [ deadnixPkg ]
    ++ lib.optionals (nixToolsEnabled && alejandraPkg != null) [ alejandraPkg ]
    ++ lib.optionals (nixToolsEnabled && nixfmtPkg != null) [ nixfmtPkg ]
    ++ lib.optionals (nixToolsEnabled && nixLspPkg != null) [ nixLspPkg ]
    ++ lib.optionals (t3codeEnabled && t3DesktopPkg != null) [ t3DesktopPkg ]
    # `gh` is provided by programs.gh in modules/home/base (git HTTPS→SSH fixes).
    ++ lib.optionals (nixToolsEnabled && graphiteCliPkg != null) [ graphiteCliPkg ]
    ++ lib.optionals (aiCliEnabled && skillsPkg != null) [ skillsPkg ]
    ++ lib.optionals (cursorEnabled && cursorPkg != null) [ cursorPkg ]
    ++ lib.optionals (cursorEnabled && cursorCliPkg != null) [ cursorCliPkg ]
    ++ lib.optionals (zedEnabled && zedEditorPkg != null) [ zedEditorPkg ]
    ++ lib.optionals (nixToolsEnabled && nilPkg != null) [ nilPkg ];

  xdg.desktopEntries = lib.optionalAttrs (t3codeEnabled && t3DesktopPkg != null) {
    t3code = {
      name = "T3 Code";
      comment = "T3 Code desktop build";
      exec = "${t3DesktopProgram} --no-sandbox --password-store=gnome-libsecret %U";
      terminal = false;
      type = "Application";
      categories = [ "Development" ];
      icon = "t3code";
      mimeType = [ "x-scheme-handler/t3code" ];
      settings = {
        StartupWMClass = "t3-code-desktop";
      };
    };
  };

  xdg.mimeApps = lib.mkIf (t3codeEnabled && t3DesktopPkg != null) {
    enable = true;
    defaultApplications."x-scheme-handler/t3code" = [ "t3code.desktop" ];
    associations.added."x-scheme-handler/t3code" = [ "t3code.desktop" ];
  };
}
