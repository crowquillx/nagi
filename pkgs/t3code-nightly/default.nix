{
  appimageTools,
  fetchurl,
  gh,
  git,
  lib,
  makeBinaryWrapper,
  symlinkJoin,
  codex,
  enableCodex ? true,
  enableGitHub ? true,
  enableGit ? true,
}:
let
  pname = "t3code-desktop";
  version = "0.0.31-nightly.20260729.948";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-CnGRYsfQhQ4QGun+b1CH21EGHnnWcK+a5A7owMy3Zbs=";
  };
  appImageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
  appImage = appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -m 444 -D \
        ${appImageContents}/t3code.desktop \
        "$out/share/applications/t3code.desktop"
      substituteInPlace "$out/share/applications/t3code.desktop" \
        --replace-fail "Exec=AppRun" "Exec=t3code-desktop"
      cp -r ${appImageContents}/usr/share/icons "$out/share/"
    '';

    meta = {
      description = "Minimal web GUI for coding agents (nightly AppImage)";
      homepage = "https://t3.codes";
      downloadPage = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      license = lib.licenses.mit;
      mainProgram = pname;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
  runtimePackages =
    lib.optionals enableCodex [ codex ]
    ++ lib.optionals enableGitHub [ gh ]
    ++ lib.optionals enableGit [ git ];
in
symlinkJoin {
  inherit pname version;
  paths = [ appImage ];
  nativeBuildInputs = [ makeBinaryWrapper ];

  postBuild = lib.optionalString (runtimePackages != [ ]) ''
    wrapProgram "$out/bin/t3code-desktop" \
      --prefix PATH : "${lib.makeBinPath runtimePackages}"
  '';

  passthru = {
    inherit appImage appImageContents src;
  };

  inherit (appImage) meta;
}
