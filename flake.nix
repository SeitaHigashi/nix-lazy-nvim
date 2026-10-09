{
  description = "Nix fetches Neovim plugins; lazy.nvim only loads them";

  outputs = { self, ... }: {
    # pkgs: { plugins, extraPackages, configDir, ... } -> wrapped nvim with a generated init.lua
    lib.mkLazyNvim = pkgs: args: import ./lib/mkLazyNvim.nix ({ inherit pkgs; } // args);

    # raw "<lua expr>": emit verbatim into a plugin spec (functions, vim.fn calls, ...)
    lib.raw = expr: { _type = "lua-inline"; inherit expr; };

    homeManagerModules.default = import ./modules/home-manager.nix self;
  };
}
