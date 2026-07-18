# Repo-owned shared module composition.
# External flake modules and host-conditional upstream modules stay in modules/flake/hosts.nix.
#
# Named feature groups below are composed into nixosModules / homeModules.
# Order of composition matches the former flat lists (ordering can matter).
let
  nixosBase = [
    ../nixos/base/default.nix
    ../nixos/base/lix.nix
  ];

  # Mounts stay early: before theme/hardware/desktop, as in the prior flat list.
  nixosMounts = [
    ../nixos/services/mounts.nix
  ];

  nixosTheme = [
    ../nixos/theme/stylix.nix
  ];

  nixosHardware = [
    ../nixos/hardware/graphics.nix
    ../nixos/hardware/swap.nix
  ];

  nixosDesktop = [
    ../nixos/desktop/niri.nix
    ../nixos/desktop/kde.nix
    ../nixos/desktop/sddm.nix
    ../nixos/desktop/session-lifecycle.nix
  ];

  nixosShells = [
    ../nixos/shells/fish-starship.nix
  ];

  nixosServices = [
    ../nixos/services/audio.nix
    ../nixos/services/core.nix
    ../nixos/services/bluetooth.nix
    ../nixos/services/networking.nix
    ../nixos/services/ssh.nix
    ../nixos/services/firewall.nix
    ../nixos/services/portals.nix
    ../nixos/services/filemanager.nix
    ../nixos/services/printing.nix
    ../nixos/services/flatpak.nix
    ../nixos/services/nh.nix
    ../nixos/services/steam.nix
    ../nixos/services/virtualisation.nix
    ../nixos/services/mullvad-vpn.nix
    ../nixos/services/ai.nix
    ../nixos/services/keyring.nix
    ../nixos/services/tailscale.nix
    ../nixos/services/localsend.nix
  ];

  nixosSecurity = [
    ../nixos/security/noctalia-secrets.nix
    ../nixos/security/sops.nix
    ../nixos/security/kotomi.nix
    ../nixos/security/sops-gnupg.nix
    ../nixos/security/yubikey.nix
    ../nixos/security/secure-boot.nix
  ];

  nixosProfiles = [
    ../nixos/profiles/vm-guest.nix
    ../nixos/profiles/laptop.nix
  ];

  homeBase = [
    ../home/base/default.nix
    ../home/base/extra-packages.nix
    ../home/base/tcli.nix
  ];

  homeDev = [
    ../home/dev/packages.nix
    ../home/dev/mcp.nix
    ../home/dev/codex-desktop.nix
  ];

  homeMedia = [
    ../home/media/video-editing.nix
  ];

  homeTerminals = [
    ../home/terminals/ghostty.nix
    ../home/terminals/kitty.nix
  ];

  homeTheme = [
    ../home/theme/gtk.nix
    ../home/theme/qt.nix
  ];

  homeShell = [
    ../home/shell/zoxide.nix
    ../home/shell/kotomi.nix
  ];

  homeDesktop = [
    ../home/desktop/session-runtime.nix
    ../home/desktop/niri-user.nix
    ../home/desktop/noctalia-command.nix
    ../home/desktop/noctalia-shell.nix
    ../home/desktop/hushmic-tray.nix
  ];

  homeSecurity = [
    ../home/security/ssh-key.nix
    ../home/security/sops-age-key.nix
    ../home/security/gpg-agent.nix
  ];
in {
  inherit
    nixosBase
    nixosMounts
    nixosTheme
    nixosHardware
    nixosDesktop
    nixosShells
    nixosServices
    nixosSecurity
    nixosProfiles
    homeBase
    homeDev
    homeMedia
    homeTerminals
    homeTheme
    homeShell
    homeDesktop
    homeSecurity
    ;

  nixosModules =
    nixosBase
    ++ nixosMounts
    ++ nixosTheme
    ++ nixosHardware
    ++ nixosDesktop
    ++ nixosShells
    ++ nixosServices
    ++ nixosSecurity
    ++ nixosProfiles;

  homeModules =
    homeBase
    ++ homeDev
    ++ homeMedia
    ++ homeTerminals
    ++ homeTheme
    ++ homeShell
    ++ homeDesktop
    ++ homeSecurity;
}
