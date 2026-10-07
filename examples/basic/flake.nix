{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lazy-nix.url = "path:../..";
    flash-src = { url = "github:folke/flash.nvim"; flake = false; };  # git-only plugin
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, lazy-nix, home-manager, flash-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      vp = pkgs.vimPlugins;
      plugins = [ vp.lazy-nvim vp.plenary-nvim vp.telescope-nvim vp.nvim-treesitter.withAllGrammars
                  vp.gitsigns-nvim vp.vim-fugitive vp.nightfox-nvim ];
    in {
      # 1) without home-manager
      packages.${system}.default = lazy-nix.lib.mkNvim pkgs {
        inherit plugins;
        extraPlugins."flash.nvim" = flash-src;
        configDir = ./config;
        binName = "nvim-lazy-test";
      };

      # 2) via the home-manager module
      homeConfigurations.test = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          lazy-nix.homeManagerModules.default
          { home = { username = "test"; homeDirectory = "/home/test"; stateVersion = "25.05"; };
            programs.lazy-nix = { enable = true; inherit plugins; configDir = ./config; binName = "nvim-lazy-test"; }; }
        ];
      };
    };
}
