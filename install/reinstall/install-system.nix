# First-install variant of nixosConfigurations.<host>: identical except that
# Lanzaboote measured boot is off. systemd-pcrlock needs firmware measurements
# from a real boot of the installed system, so post-install.sh turns it on
# with a normal rebuild after the first boot.
#
#   nix build --impure -f install-system.nix --argstr flakePath path:/home/tan/nagi
{
  flakePath,
  host ? "tandesk",
}:
let
  flake = builtins.getFlake flakePath;
  base = flake.nixosConfigurations.${host};
in
(base.extendModules {
  modules = [
    (
      { lib, ... }:
      {
        boot.lanzaboote.measuredBoot.enable = lib.mkForce false;
      }
    )
  ];
}).config.system.build.toplevel
