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
      raw = nix-lazy-nvim.lib.raw;
      plugins = [
        vp.lazy-nvim
        { plugin = vp.nightfox-nvim; lazy = false; priority = 1000; config = ''vim.cmd("colorscheme nordfox")''; }
        { plugin = vp.nvim-treesitter.withAllGrammars; lazy = false; }
        { plugin = vp.gitsigns-nvim; event = "VeryLazy"; dependencies = [ vp.plenary-nvim ]; }
        { plugin = vp.vim-fugitive; cmd = "Git"; }
        { name = "flash.nvim"; plugin = flash-src; cmd = "FlashTest";
          config = "vim.api.nvim_create_user_command('FlashTest', function() end, {})"; }
        { plugin = vp.telescope-nvim; cmd = "Telescope"; dependencies = [ "plenary.nvim" ];
          keys = [ { _1 = "<leader>f"; _2 = "<cmd>Telescope find_files<cr>"; desc = "Find files"; } ]; }
      ];
    in {
      # 1) without home-manager
      packages.${system}.default = nix-lazy-nvim.lib.mkLazyNvim pkgs {
        inherit plugins;
        configDir = ./config;
        extraInitLuaPre = ''require("options")'';
        binName = "nvim-lazy-test";
      };

      # 2) via the home-manager module
      homeConfigurations.test = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-lazy-nvim.homeManagerModules.default
          { home = { username = "test"; homeDirectory = "/home/test"; stateVersion = "25.05"; };
            programs.nix-lazy-nvim = { enable = true; inherit plugins; configDir = ./config; extraInitLuaPre = ''require("options")''; binName = "nvim-lazy-test"; }; }
        ];
      };
    };
}
