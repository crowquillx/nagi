{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  ydotool,
  wtype,
}:
let
  inherit (stdenv.hostPlatform) system;
  hashes = {
    x86_64-linux = {
      main = "sha256-0h55gzb1xrae98hTKIZjmVD+JIVeLbsgXMPzRSiUAg4=";
      cosmic = "sha256-wet2Dul9UNwVfWcRlWzYT5dwHJmIVbI8HvG9d2GaFFg=";
    };
    aarch64-linux = {
      main = "sha256-UScY62T5HNjvyWEHJ/ZfQOyTIYv+dRprtg/jYmaOIqY=";
      cosmic = "sha256-IlALWHrGUKw8yMTd2MdcD9ov0B9Or/0cpIKA3btiCvo=";
    };
  };
  rustTarget =
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
    }
    .${system} or (throw "computer-use-linux: unsupported system ${system}");
  srcHashes = hashes.${system} or (throw "computer-use-linux: unsupported system ${system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "computer-use-linux";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-${rustTarget}";
    hash = srcHashes.main;
  };

  cosmic = fetchurl {
    url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-cosmic-${rustTarget}";
    hash = srcHashes.cosmic;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec" "$out/bin"
    install -Dm755 "$src" "$out/libexec/computer-use-linux"
    install -Dm755 ${finalAttrs.cosmic} "$out/libexec/computer-use-linux-cosmic"
    makeWrapper "$out/libexec/computer-use-linux" "$out/bin/computer-use-linux" \
      --prefix PATH : ${
        lib.makeBinPath [
          ydotool
          wtype
        ]
      } \
      --set COMPUTER_USE_LINUX_COSMIC_HELPER "$out/libexec/computer-use-linux-cosmic"
    ln -s "$out/libexec/computer-use-linux-cosmic" "$out/bin/computer-use-linux-cosmic"
    runHook postInstall
  '';

  meta = {
    description = "Linux desktop control MCP server (AT-SPI, compositor window targeting, portals, ydotool)";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    changelog = "https://github.com/agent-sh/computer-use-linux/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "computer-use-linux";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
