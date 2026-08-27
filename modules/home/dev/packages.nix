{
  lib,
  pkgs,
  vars ? { },
  inputs,
  config,
  ...
}:
let
  v = vars;
  get = path: default: lib.attrByPath path default v;
  codingToolsEnabled = get [ "features" "codingTools" "enable" ] true;
  paseoEnabled = get [ "features" "codingTools" "paseo" "enable" ] codingToolsEnabled;
  editorsEnabled = get [ "features" "codingTools" "editors" "enable" ] codingToolsEnabled;
  t3codeEnabled = editorsEnabled && get [ "features" "codingTools" "editors" "t3code" "enable" ] true;
  t3ServiceEnabled =
    t3codeEnabled && get [ "features" "codingTools" "editors" "t3code" "service" "enable" ] true;
  t3ServiceExtraArgs = get [ "features" "codingTools" "editors" "t3code" "service" "extraArgs" ] [ ];
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
  # T3 launches `grok agent stdio` from an already-managed process. Pin the
  # official binary's shell to NixOS /bin/sh instead of the stock launcher.
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
  paseoPkg = llmAgent "paseo-desktop";
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
  t3UpstreamPkg = llmAgent "t3code";
  t3NightlyPkg = lib.attrByPath [
    "t3code-nightly-nix"
    "packages"
    system
    "t3code-nightly"
  ] null inputs;
  t3ProviderPackages = lib.filter (pkg: pkg != null) [
    (llmAgent "codex")
    claudeCodePkg
    (llmAgent "cursor-agent")
    (if grokEnabled then grokPkg else null)
    (llmAgent "opencode")
    (lib.attrByPath [ "gh" ] null pkgs)
    (lib.attrByPath [ "git" ] null pkgs)
  ];
  t3codePkg =
    if t3UpstreamPkg == null then
      null
    else
      t3UpstreamPkg.override { providerPackages = t3ProviderPackages; };
  t3DesktopPkg =
    if t3NightlyPkg == null then
      null
    else
      pkgs.stdenvNoCC.mkDerivation {
        pname = "t3code-desktop";
        inherit (t3NightlyPkg) version;
        dontUnpack = true;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin"
          makeWrapper ${lib.getExe t3NightlyPkg} \
            "$out/bin/t3code-desktop" \
            --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath t3ProviderPackages)}
          ln -s t3code-desktop "$out/bin/t3code-nightly"
          ln -s ${t3NightlyPkg}/share "$out/share"
          runHook postInstall
        '';
        meta = t3NightlyPkg.meta // {
          description = "Nightly desktop control surface for coding agents";
          mainProgram = "t3code-desktop";
        };
      };
  t3DesktopProgram =
    if t3DesktopPkg == null then
      "t3code-desktop"
    else
      t3DesktopPkg.meta.mainProgram or "t3code-desktop";
  t3DesktopBin = lib.optionalString (t3DesktopPkg != null) "${t3DesktopPkg}/bin/${t3DesktopProgram}";
  t3UrlHandlerPath = "${config.home.homeDirectory}/.local/share/applications/t3code-url-handler.desktop";
  t3UrlHandlerText = lib.optionalString (t3DesktopBin != "") ''
    [Desktop Entry]
    Type=Application
    Name=T3 Code
    Exec=${t3DesktopBin} %U
    Terminal=false
    NoDisplay=true
    StartupNotify=false
    MimeType=x-scheme-handler/t3code;
  '';
  t3UrlHandlerFile = pkgs.writeText "t3code-url-handler.desktop" t3UrlHandlerText;
  t3UrlHandlerRewrite = pkgs.writeShellScript "nagi-t3code-url-handler" ''
    set -eu
    dest=${lib.escapeShellArg t3UrlHandlerPath}
    src=${t3UrlHandlerFile}
    if [ -f "$dest" ] && ${pkgs.diffutils}/bin/cmp -s "$src" "$dest"; then
      exit 0
    fi
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$dest")"
    ${pkgs.coreutils}/bin/cp "$src" "$dest.tmp"
    ${pkgs.coreutils}/bin/mv "$dest.tmp" "$dest"
  '';
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
      assertion = !(paseoEnabled && paseoPkg == null);
      message = "features.codingTools.paseo.enable is true, but package 'paseo-desktop' could not be resolved from llm-agents.nix.";
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
      assertion = !(t3codeEnabled && t3codePkg == null);
      message = "features.codingTools.editors.t3code.enable is true, but package 't3code' could not be resolved from llm-agents.nix.";
    }
    {
      assertion = !(t3codeEnabled && t3DesktopPkg == null);
      message = "features.codingTools.editors.t3code.enable is true, but package 't3code-nightly' could not be resolved from t3code-nightly-nix.";
    }
    {
      assertion = !(t3ServiceEnabled && t3codePkg == null);
      message = "features.codingTools.editors.t3code.service.enable is true, but package 't3code' could not be resolved from llm-agents.nix.";
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
    ++ lib.optionals (paseoEnabled && paseoPkg != null) [ paseoPkg ]
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
    ++ lib.optionals (t3codeEnabled && t3codePkg != null) [ t3codePkg ]
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
      exec = "${t3DesktopProgram} %U";
      terminal = false;
      type = "Application";
      categories = [ "Development" ];
      icon = "t3code";
      mimeType = [ "x-scheme-handler/t3code" ];
      settings = {
        StartupWMClass = "t3code";
      };
    };
  };

  xdg.mimeApps = lib.mkIf (t3codeEnabled && t3DesktopPkg != null) {
    enable = true;
    defaultApplications."x-scheme-handler/t3code" = [ "t3code.desktop" ];
    associations.added."x-scheme-handler/t3code" = [
      "t3code.desktop"
      "t3code-url-handler.desktop"
    ];
  };

  # T3 may register x-scheme-handler/t3code with process.execPath, which
  # is the unwrapped Electron binary. Rewrite the desktop file whenever T3 does.
  home.file.".local/share/applications/t3code-url-handler.desktop" =
    lib.mkIf (t3codeEnabled && t3DesktopPkg != null)
      {
        text = t3UrlHandlerText;
        force = true;
      };

  systemd.user = {
    paths.nagi-t3code-url-handler = lib.mkIf (t3codeEnabled && t3DesktopPkg != null) {
      Unit.Description = "Watch T3 Code protocol handler desktop file";
      Path = {
        PathChanged = t3UrlHandlerPath;
        PathModified = t3UrlHandlerPath;
        Unit = "nagi-t3code-url-handler.service";
      };
      Install.WantedBy = [ "default.target" ];
    };

    services.nagi-t3code-url-handler = lib.mkIf (t3codeEnabled && t3DesktopPkg != null) {
      Unit.Description = "Rewrite T3 Code protocol handler to the wrapped binary";
      Service = {
        Type = "oneshot";
        ExecStart = t3UrlHandlerRewrite;
      };
    };

    services.nagi-t3code = lib.mkIf (t3ServiceEnabled && t3codePkg != null) {
      Unit = {
        Description = "T3 Code headless server";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe t3codePkg} serve${
          lib.optionalString (t3ServiceExtraArgs != [ ]) " ${lib.escapeShellArgs t3ServiceExtraArgs}"
        }";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
