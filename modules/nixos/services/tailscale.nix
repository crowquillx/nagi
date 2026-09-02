{
  lib,
  config,
  ...
}:
let
  v = config.nagi.variables;
  inherit (v.features.tailscale) acceptDns disableUpstreamLogging exitNode;
  enabled = v.features.tailscale.enable;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          # Schema allows nullOr str; reject empty strings that would yield --exit-node=.
          assertion = exitNode == null || exitNode != "";
          message = "features.tailscale.exitNode must be null or a non-empty string.";
        }
      ];
    }
    (lib.mkIf enabled {
      services.tailscale = {
        enable = true;
        openFirewall = true;
        inherit disableUpstreamLogging;
        extraUpFlags = [
          "--accept-dns=${lib.boolToString acceptDns}"
          "--accept-routes"
        ]
        ++ lib.optional (exitNode != null) "--exit-node=${exitNode}";
      };
    })
  ];
}
