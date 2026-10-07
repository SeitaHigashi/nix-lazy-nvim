{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-lazy-nvim.url = "path:../..";
    flash-src = { url = "github:folke/flash.nvim"; flake = false; };  # git-only plugin
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, nix-lazy-nvim, home-manager, flash-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      vp = pkgs.vimPlugins;
      plugins = [ vp.lazy-nvim vp.plenary-nvim vp.telescope-nvim vp.nvim-treesitter.withAllGrammars
                  vp.gitsigns-nvim vp.vim-fugitive vp.nightfox-nvim ];
    in {
      # 1) without home-manager
      packages.${system}.default = nix-lazy-nvim.lib.mkNvim pkgs {
        inherit plugins;
        extraPlugins."flash.nvim" = flash-src;
        configDir = ./config;
        binName = "nvim-lazy-test";
      };

      # 2) via the home-manager module
      homeConfigurations.test = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-lazy-nvim.homeManagerModules.default
          { home = { username = "test"; homeDirectory = "/home/test"; stateVersion = "25.05"; };
            programs.nix-lazy-nvim = { enable = true; inherit plugins; configDir = ./config; binName = "nvim-lazy-test"; }; }
        ];
      };
    };
}
