{
  description = "Nix fetches Neovim plugins; lazy.nvim only loads them";

  outputs = { self, ... }: {
    # pkgs: { plugins, extraPlugins, extraPackages, configDir, ... } -> wrapped nvim
    lib.mkNvim = pkgs: args: import ./lib/mkNvim.nix ({ inherit pkgs; } // args);

    homeManagerModules.default = import ./modules/home-manager.nix self;
  };
}
