# Repo-owned shared module composition.
# External flake modules and host-conditional upstream modules stay in modules/flake/hosts.nix.
#
# Named feature groups below are composed into nixosModules / homeModules.
# Order of composition matches the former flat lists (ordering can matter).
let
  nixosBase = [
    ../nixos/base/default.nix
    ../nixos/base/determinate.nix
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
    ../nixos/desktop/hyprland.nix
    ../nixos/desktop/kde.nix
    ../nixos/desktop/cursor.nix
    ../nixos/desktop/sddm.nix
    ../nixos/desktop/session-lifecycle.nix
    ../nixos/desktop/session-shell-pam.nix
  ];

  nixosShells = [
    ../nixos/shells/fish-starship.nix
    ../nixos/shells/zsh.nix
  ];

  nixosServices = [
    ../nixos/services/audio.nix
    ../nixos/services/core.nix
    ../nixos/services/bluetooth.nix
    ../nixos/services/networking.nix
    ../nixos/services/ssh.nix
    ../nixos/services/t3code.nix
    ../nixos/services/firewall.nix
    ../nixos/services/portals.nix
    ../nixos/services/computer-use-linux.nix
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
    ../nixos/services/razer.nix
  ];

  nixosSecurity = [
    ../nixos/security/sudo.nix
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
    ../home/dev/computer-use-linux.nix
    ../home/dev/codex-desktop.nix
    ../home/dev/repo-sync.nix
  ];

  homeMedia = [
    ../home/media/video-editing.nix
    ../home/media/blender.nix
  ];

  homeTerminals = [
    ../home/terminals/ghostty.nix
    ../home/terminals/kitty.nix
  ];

  homeTheme = [
    ../home/theme/gtk.nix
    ../home/theme/qt.nix
    ../home/theme/stylix.nix
  ];

  homeShell = [
    ../home/shell/zsh.nix
    ../home/shell/zoxide.nix
    ../home/shell/kotomi.nix
    ../home/shell/ssh-tmux.nix
  ];

  homeDesktop = [
    ../home/desktop/session-runtime.nix
    ../home/desktop/session-shell/default.nix
    ../home/desktop/pointer-cursor.nix
    ../home/desktop/hyprland-user.nix
    ../home/desktop/noctalia-command.nix
    ../home/desktop/noctalia-shell.nix
    ../home/desktop/noctalia-hyprland-workspaces.nix
    ../home/desktop/hushmic-tray.nix
    ../home/desktop/handy.nix
    ../home/desktop/hdr-game.nix
  ];

  homeSecurity = [
    ../home/security/ssh-key.nix
    ../home/security/sops-age-key.nix
    ../home/security/gpg-agent.nix
    ../home/security/keyring.nix
  ];
in
{
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
