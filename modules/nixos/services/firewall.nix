{
  lib,
  ...
}:
{
  # Explicit firewall enablement.
  #
  # networking.firewall.enable defaults to true in NixOS, but relying on the
  # implicit default means a future nixpkgs change could silently expose
  # hosts. Pinning it here makes the security posture declarative.
  config = {
    networking.firewall.enable = lib.mkDefault true;
  };

  # Port ownership reference (kept here as the single source of truth for
  # why each exposed TCP/UDP port exists). No port is opened or closed by
  # this module; each feature module remains the owner of its own ports.
  #
  # ┌────────┬──────┬──────────────────────────┬──────────────────────────────────────────────────────────────────┐
  # │ Host   │ Port │ Proto                    │ Owner (variable)                                                 │
  # ├────────┼──────┼──────────────────────────┼──────────────────────────────────────────────────────────────────┤
  # │ all    │ 22   │ tcp                      │ features.ssh.openFirewall (services.openssh.openFirewall)        │
  # │ all    │ 41641│ udp                      │ features.tailscale.enable (services.tailscale.openFirewall)      │
  # │ tandesk│ 27015│ tcp + udp                │ features.gaming.steam.dedicatedServer.openFirewall               │
  # │ tandesk│ 27036│ tcp + udp                │ features.gaming.steam.remotePlay.openFirewall + transfers        │
  # │ tandesk│ 27037│ tcp                      │ features.gaming.steam.remotePlay.openFirewall                    │
  # │ tandesk│ 27040│ tcp                      │ features.gaming.steam.localNetworkGameTransfers.openFirewall     │
  # │ tandesk│ 10400│ udp                      │ features.gaming.steam.remotePlay.openFirewall                    │
  # │ tandesk│ 10401│ udp                      │ features.gaming.steam.remotePlay.openFirewall                    │
  # │ tandesk│ 27031-27035│ udp range           │ features.gaming.steam.remotePlay.openFirewall                    │
  # │ tandesk│ 53317│ tcp + udp                │ features.localsend.openFirewall (modules/nixos/services/localsend) │
  # └────────┴──────┴──────────────────────────┴──────────────────────────────────────────────────────────────────┘
  #
  # Notes:
  # - Steam port openings only take effect on hosts where features.gaming.enable = true
  #   (currently tandesk only). On default/tanlappy, gaming is disabled, so the
  #   features.gaming.steam.*.openFirewall toggles are inert regardless of value.
  # - mullvad-vpn, ollama, open-webui, and comfyui bind to 127.0.0.1 and open
  #   no firewall ports.
  # - ICMP echo (allowPing) is left at the NixOS default (true) for diagnostics;
  #   it is not a TCP/UDP port and can be tightened separately if desired.
  # - No interface-scoped restrictions are used: NetworkManager connection
  #   names, Wi-Fi/Ethernet/VPN interfaces, and Tailscale interfaces vary, so
  #   narrowing to a guessed interface name would break LAN features
  #   non-deterministically.
}
