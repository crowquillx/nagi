# Agent Notes

## Purpose
This repository is a multi-host NixOS flake with Home Manager integration. It is organized around a small `flake.nix`, `flake-parts`, `import-tree`, and a dendritic or parts-wrapped layout where flake logic, shared stacks, host wiring, and user wiring stay separated.

Agents should preserve that structure. Do not collapse this repo back into a monolithic `flake.nix` or ad hoc host imports unless explicitly asked. As much as possible should be done with nix, do not look for lazy workarounds! 

## Architecture

### Flake-parts and dendritic layout
- `flake.nix` should stay thin.
- `flake.nix` is expected to do three things only:
  1. declare inputs
  2. bootstrap `flake-parts`
  3. import `modules/flake` via `import-tree`
- Flake output logic belongs in `modules/flake/`, not in `flake.nix`.
- Shared module composition belongs in `modules/combined/stacks.nix`.
- Host-specific wiring belongs in `hosts/<host>/`.
- User-specific Home Manager wiring belongs in `users/<user>/`.

Read [docs/DENDRITIC.md](/home/tan/tanos/docs/DENDRITIC.md) before changing flake structure, module loading, or host composition.

### Key paths
- [flake.nix](/home/tan/tanos/flake.nix): flake inputs and `flake-parts` bootstrap only.
- [modules/flake/hosts.nix](/home/tan/tanos/modules/flake/hosts.nix): host map, `nixosConfigurations`, `homeConfigurations`, special args, and shared module injection.
- [modules/flake/packages.nix](/home/tan/tanos/modules/flake/packages.nix): custom and wrapped package outputs.
- [modules/combined/stacks.nix](/home/tan/tanos/modules/combined/stacks.nix): authoritative shared module stack for NixOS and Home Manager.
- [hosts/common/default.nix](/home/tan/tanos/hosts/common/default.nix): shared host wiring and Home Manager integration.
- [hosts/common/variables-schema.nix](/home/tan/tanos/hosts/common/variables-schema.nix): variable schema and defaults.
- [hosts/<host>/variables.nix](/home/tan/tanos/hosts/tandesk/variables.nix): host toggles and values.
- [users/default/home.nix](/home/tan/tanos/users/default/home.nix): primary user Home Manager entrypoint.

## Working Rules

### Preserve the composition model
- Prefer adding a focused module under `modules/nixos/` or `modules/home/` over putting unrelated logic into host files.
- If a new shared feature is introduced, wire it through [modules/combined/stacks.nix](/home/tan/tanos/modules/combined/stacks.nix).
- If a change is host-specific, keep it in that host’s `variables.nix` or host module rather than baking it into shared defaults.
- Keep NixOS and Home Manager responsibilities separated. System services belong in `modules/nixos`; user session behavior belongs in `modules/home`.

### Prefer declarative modules over shell-heavy activation
- Do not reinvent the wheel when a working upstream implementation already exists.
- Prefer established NixOS modules, Home Manager modules, and maintained external flakes over custom reimplementations.
- Before writing custom glue, check whether the behavior already exists in `nixpkgs`, Home Manager, or a well-maintained flake used by the community.
- Good example: use a maintained declarative Flatpak module such as `nix-flatpak` rather than custom activation scripts for package lifecycle management.
- Avoid custom boot-time shell in `system.activationScripts` when an existing NixOS or Home Manager module can model the state directly.
- Prefer upstream module options and well-maintained flake inputs over hand-rolled lifecycle scripts.
- Be especially conservative with anything that runs during activation or boot. A broken activation snippet can prevent the machine from booting cleanly.

### Host variable model
- This repo uses `config.nagi.variables` as the shared host data model.
- Prefer adding a clear variable and consuming it from a module instead of hardcoding host-specific behavior in shared modules.
- When adding a new variable, update the schema and docs.

### Desktop/session specifics
- `tandesk`, `default`, and `tanlappy` may differ in graphics, session, and hardware assumptions.
- Niri support is intentional and should be preserved.
- SDDM, portals, keyring, session services, and compositor-specific behavior should be treated as runtime-sensitive changes and validated carefully.
- Do not assume KDE- or GNOME-style defaults fit a Niri session; check the existing module design first.

### Security and secrets
- Never commit plaintext secrets.
- Use `sops-nix` and host-specific files under `secrets/`.
- Keep hardware configuration host-specific.

## Change Workflow

### Before editing
- Read the relevant module and the related host variables first.
- Check whether the repo already has a module or option for the behavior you need.
- For structural changes, read [docs/DENDRITIC.md](/home/tan/tanos/docs/DENDRITIC.md).
- For host variable changes, read [docs/VARIABLES.md](/home/tan/tanos/docs/VARIABLES.md).

### Preferred commands
- `tcli rebuild build <host>`: build only.
- `tcli rebuild switch <host>`: apply system and Home Manager changes.
- `tcli update <host>`: update inputs then rebuild.
- `statix check .`: lint.

Agent restriction:
- Do not run `switch`, `boot`, `test`, or `home-manager switch` as part of normal validation.
- Do not apply live system or Home Manager changes on this machine unless the user explicitly asks for that exact command in the current turn.
- Default to eval/build-only validation, even for the local host.

Fallback commands:
- `sudo nixos-rebuild build --flake .#<host>`
- `sudo nixos-rebuild switch --flake .#<host>`
- `home-manager switch --flake .#<host>`

### Validation expectations
- Validation is build- and eval-based; there is no dedicated unit-test suite.
- At minimum, build affected hosts.
- For runtime-sensitive changes, note that runtime verification may be needed, but do not perform `switch` or other live activation steps unless the user explicitly requests it in the current turn.
- For portal, compositor, display manager, audio, boot, and graphics changes, prefer host-specific validation over assuming a successful eval is sufficient.

## Style
- Use 2-space indentation in Nix files.
- Keep assignments semicolon-terminated.
- Keep modules focused by domain.
- Use lowercase kebab-case filenames for new modules.
- Keep comments brief and high-signal.

## Docs Map
- [README.md](/home/tan/tanos/README.md): repo overview and common workflows.
- [docs/DENDRITIC.md](/home/tan/tanos/docs/DENDRITIC.md): flake-parts and parts-wrapped structure.
- [docs/VARIABLES.md](/home/tan/tanos/docs/VARIABLES.md): host variable reference and examples.
- [docs/TCLI.md](/home/tan/tanos/docs/TCLI.md): `tcli` behavior and command mapping.
- [docs/NEW_HOST.md](/home/tan/tanos/docs/NEW_HOST.md): adding a host.
- [docs/SOPS.md](/home/tan/tanos/docs/SOPS.md): secrets workflow.
- [docs/SECURE_BOOT.md](/home/tan/tanos/docs/SECURE_BOOT.md): secure boot setup.

## Useful reminders for agents
- This repo may have unrelated local changes; do not revert them unless asked.
- Prefer `rg` for searches.
- Prefer targeted module edits over broad rewrites.
- If adding a new flake input, keep the change minimal and justify why an upstream module or package is needed.
- If changing host composition, verify [modules/flake/hosts.nix](/home/tan/tanos/modules/flake/hosts.nix) and [modules/combined/stacks.nix](/home/tan/tanos/modules/combined/stacks.nix) still reflect the intended composition.
- If you touch docs, keep them consistent with the actual wiring in code.
