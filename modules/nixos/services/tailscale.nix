{
  lib,
  config,
  ...
}: let
  v = config.nagi.variables;
  get = path: default: lib.attrByPath path default v;
  enabled = get ["features" "tailscale" "enable"] true;
  acceptDns = get ["features" "tailscale" "acceptDns"] true;
  exitNode = get ["features" "tailscale" "exitNode"] null;
in {
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
        extraUpFlags =
          [
            "--accept-dns=${lib.boolToString acceptDns}"
            "--accept-routes"
          ]
          ++ lib.optional (exitNode != null) "--exit-node=${exitNode}";
      };
    })
  ];
}
