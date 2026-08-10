{
  description = "Minimal multi-host NixOS + Home Manager setup with Hyprland, Niri, Plasma, Noctalia, and sops-nix";

  # This literal is the source of truth for both --accept-flake-config and the
  # installed Nix daemon settings. Nix rejects imported/thunked nixConfig
  # values, so modules/nixos/base/binary-caches.nix reads this attribute.
  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://comfyui.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://nix-community.cachix.org"
      "https://install.determinate.systems"
      "https://cache.numtide.com"
      "https://codex-desktop-linux.cachix.org"
      "https://vortex-nix.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://hushmic-nix.cachix.org"
      "https://kevinpita.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
      "vortex-nix.cachix.org-1:7+ZVU0umNp8sz1JqZV/bRcbVgemNuNtzN5KiJxihFRY="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "hushmic-nix.cachix.org-1:29j1XWTAAnb869spxlZ937ITJI9MCU1Wre+z7+1HJUM="
      "kevinpita.cachix.org-1:Cu9UtCDSfDq3/WDnI7N1N/LzAh90SPS+1R+nWao/hz0="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    determinate-nix.follows = "determinate/nix";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Use niri-flake only for its KDL/Home Manager configuration API. The
    # compositor package comes from host nixpkgs to keep Mesa/ABI alignment.
    niri.url = "github:sodiboo/niri-flake";

    # Do not follow nixpkgs: hyprland.cachix.org caches against upstream's pin.
    hyprland = {
      url = "github:hyprwm/Hyprland";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium2nix = {
      url = "github:FKouhai/helium2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
    };

    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cheatengine-flake = {
      url = "github:Hy4ri/cheatengine-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    hushmic-nix = {
      url = "github:crowquillx/hushmic-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    orca-nix.url = "github:kevinpita/orca-nix";

    vortex-nix = {
      url = "github:crowquillx/vortex-nix";
    };

    # Do not follow nixpkgs: nix-gaming.cachix.org caches against upstream's pin.
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
    };

  };

  outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
