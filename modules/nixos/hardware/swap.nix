{ lib, config, ... }:
let
  v = config.nagi.variables;
  zram = v.features.swap.zram;
  disk = v.features.swap.disk;
in
{
  zramSwap = {
    inherit (zram) enable memoryPercent;
  };

  swapDevices = lib.optionals disk.enable [
    {
      device = disk.path;
      size = disk.sizeMiB;
    }
  ];

  boot.kernel.sysctl."vm.swappiness" = v.features.swap.swappiness;

  assertions = [
    {
      assertion = !disk.enable || (disk.path != "/" && !(lib.hasPrefix "/nix/store/" disk.path));
      message = "features.swap.disk.path must name a swap file on writable persistent storage.";
    }
  ];
}
