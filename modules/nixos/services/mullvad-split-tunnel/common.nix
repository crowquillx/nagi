# Shared Whonix split-tunnel parameters. Plain Nix attrset (not a NixOS module).
# Concern modules import this so routing identifiers and hardening stay aligned
# without inventing a custom module option surface.
{
  config,
  lib,
}:
let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
in
{
  inherit get;

  whonixEnabled = get [ "features" "mullvad" "splitTunnel" "whonix" "enable" ] false;
  browserEnabled = get [ "features" "mullvad" "splitTunnel" "browser" "enable" ] false;
  mullvadServiceEnabled = get [ "features" "mullvad" "service" "enable" ] false;
  sopsEnabled = get [ "security" "sops" "enable" ] true;
  externalInterface = get [
    "features"
    "mullvad"
    "splitTunnel"
    "whonix"
    "externalInterface"
  ] "virbr1";
  ipv4Subnet = get [ "features" "mullvad" "splitTunnel" "whonix" "ipv4Subnet" ] "10.0.2.0/24";
  ipv6Subnet = get [ "features" "mullvad" "splitTunnel" "whonix" "ipv6Subnet" ] "fd19:c33d:98bc::/64";
  vmUuid = get [ "features" "mullvad" "splitTunnel" "whonix" "vmUuid" ] null;

  interface = "mullvad-whonix";
  routingTable = "51820";
  routingMark = "0x6d76";
  secretName = "mullvad_whonix_config";
  relayCatalog = ../data/mullvad-relays.tsv;
  secretPath = config.sops.secrets.mullvad_whonix_config.path;

  # Handshake older than this (seconds) means the peer is dead despite keepalive.
  handshakeStaleSecs = 180;
  # Allow this long after bring-up before requiring a successful handshake.
  handshakeGraceSecs = 60;

  commonHardening = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    PrivateTmp = true;
    PrivateDevices = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
    CapabilityBoundingSet = [
      "CAP_NET_ADMIN"
      "CAP_NET_RAW"
    ];
    AmbientCapabilities = [
      "CAP_NET_ADMIN"
      "CAP_NET_RAW"
    ];
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
      "AF_UNIX"
    ];
    UMask = "0077";
  };

  # Shared override for units that need netlink / nft / wireguard ioctls.
  networkSyscallFilter = [
    "@system-service"
    "@network-io"
    "~@resources"
  ];
}
