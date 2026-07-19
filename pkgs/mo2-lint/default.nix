{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  coreutils,
  procps,
  p7zip,
  curl,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mo2-lint";
  version = "7.0.0-rc6";

  src = fetchurl {
    url = "https://github.com/Furglitch/modorganizer2-linux-installer/releases/download/${finalAttrs.version}/mo2-lint";
    hash = "sha256-+F2M02+tJeAaUONJNUIOuKeVCnDsheFOBmWOy+M0Lq4=";
  };

  dontUnpack = true;
  # PyInstaller onefile payloads break when stripped.
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    zlib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/libexec/mo2-lint/mo2-lint"
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/libexec/mo2-lint/mo2-lint" "$out/bin/mo2-lint" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          procps
          p7zip
          curl
          xdg-utils
        ]
      }
  '';

  meta = {
    description = "Mod Organizer 2 Linux Installer (MO2-LINT)";
    homepage = "https://github.com/Furglitch/modorganizer2-linux-installer";
    changelog = "https://github.com/Furglitch/modorganizer2-linux-installer/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mo2-lint";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
