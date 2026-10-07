self: { config, lib, pkgs, ... }:
let cfg = config.programs.nix-lazy-nvim; in
{
  options.programs.nix-lazy-nvim = with lib; {
    enable = mkEnableOption "Neovim whose plugins are fetched by Nix and only loaded by lazy.nvim";
    package = mkOption { type = types.package; default = pkgs.neovim; description = "Neovim to wrap."; };
    plugins = mkOption { type = types.listOf types.raw; default = [ ]; description = "vimPlugins derivations, or { name; plugin; } to override the lazy.nvim name."; };
    extraPlugins = mkOption { type = types.attrsOf types.raw; default = { }; description = "name -> path/derivation for plugins not in nixpkgs."; };
    extraPackages = mkOption { type = types.listOf types.package; default = [ ]; description = "Added to PATH for nvim."; };
    mergeDependencies = mkOption { type = types.listOf types.str; default = [ "nvim-treesitter" ]; description = "Plugins whose `dependencies` (e.g. grammars) are merged into one directory."; };
    configDir = mkOption { type = types.nullOr types.path; default = null; description = "Use this config dir (via NVIM_APPNAME) instead of ~/.config/nvim."; };
    binName = mkOption { type = types.str; default = "nvim"; };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (import ../lib/mkNvim.nix {
        inherit pkgs;
        inherit (cfg) plugins extraPlugins extraPackages mergeDependencies configDir binName;
        neovim = cfg.package;
      })
    ];
  };
}
