{
  lib,
  pkgs,
  inputs,
  self,
  vars ? { },
  ...
}:
let
  fishEnabled = lib.attrByPath [ "features" "shell" "fish" "enable" ] true vars;
  zshEnabled = lib.attrByPath [ "features" "shell" "zsh" "enable" ] false vars;
  sharedAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
    codebox = "ssh tan@codebox";
    tandesk = "ssh tan@tandesk";
    tanlappy = "ssh tan@tanlappy";
    tanime = "ssh root@192.168.0.85";
    tanmedia = "ssh tan@192.168.0.116";
  };
  homeManagerPkg =
    let
      pkgsBySystem = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system};
    in
    pkgsBySystem.home-manager or pkgsBySystem.default;
  tcli = self.packages.${pkgs.stdenv.hostPlatform.system}.tcli;
in
{
  home.packages = [
    tcli
    homeManagerPkg
  ];

  programs = {
    bash.shellAliases = {
      fu = "tcli update";
      fr = "tcli rebuild";
      ncg = "tcli gc";
      winblows = "systemctl reboot --boot-loader-entry=auto-windows";
      enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
    };

    fish.shellAliases = lib.mkIf fishEnabled sharedAliases;
    zsh.shellAliases = lib.mkIf zshEnabled sharedAliases;
  };
}
