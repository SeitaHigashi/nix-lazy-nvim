{
  description = "Test: plugins fetched by Nix, lazy.nvim only loads them";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      vp = pkgs.vimPlugins;
      withDeps = p: pkgs.symlinkJoin { name = p.pname; paths = [ p ] ++ p.dependencies; };

      # name = the repo name lazy.nvim derives from the spec's 'owner/<name>'.
      plugins = {
        "lazy.nvim" = vp.lazy-nvim;
        "plenary.nvim" = vp.plenary-nvim;
        "telescope.nvim" = vp.telescope-nvim;
        # grammars/queries are separate plugins in nixpkgs ("dependencies"); merge them into one dir
        "nvim-treesitter" = withDeps vp.nvim-treesitter.withAllGrammars;
        "gitsigns.nvim" = vp.gitsigns-nvim;
        "vim-fugitive" = vp.vim-fugitive;
        "nightfox.nvim" = vp.nightfox-nvim;
      };

      pluginDir = pkgs.linkFarm "nvim-plugins"
        (pkgs.lib.mapAttrsToList (name: path: { inherit name path; }) plugins);

      # Generated lazy.nvim options: lazy only loads, never clones/updates.
      lazyNix = pkgs.writeText "nix-lazy.lua" ''
        return {
          lazypath = "${plugins."lazy.nvim"}",
          opts = {
            dev = { path = "${pluginDir}", patterns = { "" }, fallback = false },
            install = { missing = false },
            checker = { enabled = false },
            change_detection = { enabled = false },
            lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
          },
        }
      '';

      # The config dir lives in the store; NVIM_APPNAME is just a name under XDG_CONFIG_HOME.
      configRoot = pkgs.runCommand "nvim-config-root" { } ''
        mkdir -p $out
        ln -s ${./config} $out/nvim-lazy-test
      '';

      nvim = pkgs.writeShellScriptBin "nvim-lazy-test" ''
        export NVIM_APPNAME=nvim-lazy-test
        export XDG_CONFIG_HOME=${configRoot}
        export NVIM_NIX_LAZY=${lazyNix}
        exec ${pkgs.neovim}/bin/nvim "$@"
      '';
    in
    {
      packages.${system}.default = nvim;
      apps.${system}.default = { type = "app"; program = "${nvim}/bin/nvim-lazy-test"; };
    };
}
