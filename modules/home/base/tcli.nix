{ pkgs, inputs, self, ... }:
let
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

  programs.bash.shellAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
  };

  programs.fish.shellAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
    tanime = "ssh root@192.168.0.85";
    tanmedia = "ssh tan@192.168.0.116";
  };
}
