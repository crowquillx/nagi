# Reuse the flake-level cache policy so CLI and installed Nix settings cannot drift.
(import ../../../flake.nix).nixConfig
