{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  ydotool,
  wtype,
}:
let
  version = "0.5.0-unstable-2026-09-10";
  rev = "88ecd2fd87b578df26fc78bf1f7ec0819a316855";
  src = fetchFromGitHub {
    owner = "crowquillx";
    repo = "computer-use-linux";
    inherit rev;
    hash = "sha256-SpjZarJAIRJEtJIY/Cu+ohCWz/K54jmqat7st/CxoBk=";
  };
in
rustPlatform.buildRustPackage {
  pname = "computer-use-linux";
  inherit version src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # The test suite spawns a private D-Bus session and probes /tmp ownership, so
  # it cannot run inside the build sandbox. Upstream CI runs it on a live session.
  doCheck = false;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mkdir -p $out/libexec
    mv $out/bin/computer-use-linux $out/libexec/computer-use-linux
    mv $out/bin/computer-use-linux-cosmic $out/libexec/computer-use-linux-cosmic
    makeWrapper $out/libexec/computer-use-linux $out/bin/computer-use-linux \
      --prefix PATH : ${
        lib.makeBinPath [
          ydotool
          wtype
        ]
      } \
      --set COMPUTER_USE_LINUX_COSMIC_HELPER "$out/libexec/computer-use-linux-cosmic"
    ln -s "$out/libexec/computer-use-linux-cosmic" "$out/bin/computer-use-linux-cosmic"
  '';

  meta = {
    description = "Linux desktop control MCP server (AT-SPI, compositor window targeting, portals, ydotool)";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    changelog = "https://github.com/agent-sh/computer-use-linux/releases";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "computer-use-linux";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
}
