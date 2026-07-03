# Add A New Host

## 1) Copy an existing host profile

Use `default` as a starting point unless you need laptop defaults.

```bash
cp -r hosts/default hosts/<newhost>
```

## 2) Update host variables

Edit `hosts/<newhost>/variables.nix` and at minimum set:

- `host.name = "<newhost>"`
- `host.isVm = true|false`
- `users.primary = "<username>"`
- `users.flakeDirectory = "/home/<username>/<flake-dir>"` or `null` to use `/home/<username>/nagi`
- core desktop, graphics, and maintenance toggles for that machine
- `security.sops.defaultSopsFile = ../../secrets/<newhost>.yaml` (if using sops)

Put niche or optional feature toggles in `hosts/<newhost>/advanced.nix`.

Detailed variable reference: `docs/VARIABLES.md`.

If adding/removing globally shared modules, update `modules/combined/stacks.nix` so both NixOS and Home Manager stacks stay aligned.

## 3) Provide hardware configuration

Option A (recommended): let bootstrap generate it.

```bash
sudo ./install/bootstrap.sh <newhost> --user <username> --hostname <hostname> --flake-dir /home/<username>/nagi --update-hardware
```

Option B: manually generate and place `hosts/<newhost>/hardware-configuration.nix`.

## 4) Register host in the flake host registry

Add `<newhost>` in the `hosts` attrset in `modules/flake/hosts.nix` with its system, host module path, and ordered variable fragment list so both outputs are generated:

```nix
<newhost> = {
  system = "x86_64-linux";
  module = ../../hosts/<newhost>/default.nix;
  variables = [
    ../../hosts/<newhost>/variables.nix
    ../../hosts/<newhost>/advanced.nix
  ];
};
```

- `nixosConfigurations.<newhost>`
- `homeConfigurations.<newhost>`

## 5) Build and switch

```bash
sudo ./install/bootstrap.sh <newhost> --user <username> --hostname <hostname> --flake-dir /home/<username>/nagi
```

or after initial bootstrap:

```bash
tcli rebuild switch <newhost>
```

## 6) Verify

- system build completes without eval errors
- user session comes up as expected
- Home Manager activation applies for the primary user
