# Static host registry for the flake.
# Contract:
#   attrset of hostName -> {
#     system :: string;
#     module :: path;          # host NixOS entry module
#     variables :: [ path ];   # folded + schema-validated in hosts.nix
#   }
# Consumed by modules/flake/hosts.nix. Paths are relative to this file.
{
  tandesk = {
    system = "x86_64-linux";
    module = ../hosts/tandesk/default.nix;
    variables = [
      ../hosts/tandesk/variables.nix
      ../hosts/tandesk/advanced.nix
    ];
  };
  default = {
    system = "x86_64-linux";
    module = ../hosts/default/default.nix;
    variables = [
      ../hosts/default/variables.nix
      ../hosts/default/advanced.nix
    ];
  };
  tanlappy = {
    system = "x86_64-linux";
    module = ../hosts/tanlappy/default.nix;
    variables = [
      ../hosts/tanlappy/variables.nix
      ../hosts/tanlappy/advanced.nix
    ];
  };
}
