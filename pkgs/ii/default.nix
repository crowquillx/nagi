{ pkgs, src }:
let
  inherit (pkgs) lib;

  optionalTop = name: lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);

  optionalKde =
    name:
    lib.optional (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages) (
      builtins.getAttr name pkgs.kdePackages
    );

  optionalQt6 =
    name:
    lib.optional (builtins.hasAttr "qt6" pkgs && builtins.hasAttr name pkgs.qt6) (
      builtins.getAttr name pkgs.qt6
    );

  runtimeDeps = [
    pkgs.bash
    pkgs.bc
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.procps
    pkgs.python3
    pkgs.ripgrep
    pkgs.quickshell
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.grim
    pkgs.slurp
    pkgs.playerctl
    pkgs.libnotify
    pkgs.glib
    pkgs.pipewire
    pkgs.pulseaudio
    pkgs.wireplumber
  ]
  ++ optionalTop "brightnessctl"
  ++ optionalTop "cava"
  ++ optionalTop "ddcutil"
  ++ optionalTop "ffmpeg"
  ++ optionalTop "fuzzel"
  ++ optionalTop "geoclue2"
  ++ optionalTop "hyprpicker"
  ++ optionalTop "hyprsunset"
  ++ optionalTop "imagemagick"
  ++ optionalTop "libqalculate"
  ++ optionalTop "socat"
  ++ optionalTop "swappy"
  ++ optionalTop "tesseract"
  ++ optionalTop "translate-shell"
  ++ optionalTop "upower"
  ++ optionalTop "wf-recorder"
  ++ optionalTop "wtype"
  ++ optionalTop "ydotool"
  ++ optionalKde "breeze-icons"
  ++ optionalKde "kdialog"
  ++ optionalKde "kirigami"
  ++ optionalKde "kconfig"
  ++ optionalKde "plasma-integration"
  ++ optionalKde "syntax-highlighting"
  ++ optionalQt6 "qt5compat"
  ++ optionalQt6 "qtbase"
  ++ optionalQt6 "qtdeclarative"
  ++ optionalQt6 "qtimageformats"
  ++ optionalQt6 "qtmultimedia"
  ++ optionalQt6 "qtpositioning"
  ++ optionalQt6 "qtquicktimeline"
  ++ optionalQt6 "qtsensors"
  ++ optionalQt6 "qtsvg"
  ++ optionalQt6 "qttools"
  ++ optionalQt6 "qttranslations"
  ++ optionalQt6 "qtvirtualkeyboard"
  ++ optionalQt6 "qtwayland";

  qmlDeps =
    (lib.optional (
      builtins.hasAttr "kdePackages" pkgs
      && builtins.hasAttr "kirigami" pkgs.kdePackages
      && pkgs.kdePackages.kirigami.passthru ? unwrapped
    ) pkgs.kdePackages.kirigami.passthru.unwrapped)
    ++ optionalKde "syntax-highlighting"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtpositioning"
    ++ optionalQt6 "qtquicktimeline"
    ++ optionalQt6 "qtsensors"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qtvirtualkeyboard"
    ++ optionalQt6 "qtwayland";

  materialSymbolsFont =
    if builtins.hasAttr "material-symbols" pkgs then
      pkgs.makeFontsConf { fontDirectories = [ pkgs.material-symbols ]; }
    else
      null;
  materialSymbolsWrapperArg = lib.optionalString (
    materialSymbolsFont != null
  ) "--set FONTCONFIG_FILE ${lib.escapeShellArg materialSymbolsFont}";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "nagi-ii";
  version = src.shortRev or src.rev or "unstable";
  inherit src;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # Non-standard env shebangs in the color scripts break patchShebangs.
  preFixup = ''
    find "$out/share/ii" -type f -name '*.py' -exec chmod -x {} +
  '';

  postFixup = ''
    find "$out/share/ii" -type f -name '*.py' -exec chmod +x {} +
  '';

  installPhase = ''
    runHook preInstall

    qsTree="$out/share/ii"
    mkdir -p "$qsTree" "$out/bin"

    if [ ! -d dots/.config/quickshell/ii ]; then
      echo "illogical-impulse source is missing dots/.config/quickshell/ii" >&2
      exit 1
    fi

    cp -R dots/.config/quickshell/ii/. "$qsTree/"

    find "$qsTree" -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) \
      -exec sed -i '1!s#/usr/bin/##g' {} +

    find "$qsTree" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} \;

    makeWrapper ${lib.getExe pkgs.quickshell} "$out/bin/ii" \
      --add-flags "-c ii" \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      --prefix QML2_IMPORT_PATH : ${lib.makeSearchPath "lib/qt-6/qml" qmlDeps} \
      --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps} \
      ${materialSymbolsWrapperArg}

    makeWrapper ${lib.getExe pkgs.quickshell} "$out/bin/ii-settings" \
      --add-flags "-p $qsTree/settings.qml" \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      --prefix QML2_IMPORT_PATH : ${lib.makeSearchPath "lib/qt-6/qml" qmlDeps} \
      --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps} \
      ${materialSymbolsWrapperArg}

    runHook postInstall
  '';

  meta = {
    description = "illogical-impulse Quickshell tree wrapped for nagi";
    homepage = "https://github.com/end-4/dots-hyprland";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "ii";
  };
}
