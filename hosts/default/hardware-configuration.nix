{ ... }:
{
  # Placeholder only. Replace with generated hardware config on the target VM:
  # sudo nixos-generate-config --show-hardware-config > hosts/default/hardware-configuration.nix
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
}
