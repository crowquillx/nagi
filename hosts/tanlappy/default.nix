{ ... }: {
  imports = [
    ../common/default.nix
    ../profiles/pango.nix
    ./hardware-configuration.nix
  ];

  programs.ssh.knownHosts.tandesk.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtYFilNXxwllsrzNufMzcK6DJdqowu+xsZ4zMucF6NW";
}
