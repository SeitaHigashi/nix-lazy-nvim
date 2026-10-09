self: { config, lib, pkgs, ... }:
let cfg = config.programs.nix-lazy-nvim; in
{
  options.programs.nix-lazy-nvim = with lib; {
    enable = mkEnableOption "Neovim whose plugins are fetched by Nix and only loaded by lazy.nvim";
    package = mkOption { type = types.package; default = pkgs.neovim; description = "Neovim to wrap."; };
    plugins = mkOption { type = types.listOf types.raw; default = [ ]; description = "vimPlugins derivations, or { plugin; name?; <lazy fields>; } (see lib/mkLazyNvim.nix)."; };
    extraPlugins = mkOption { type = types.attrsOf types.raw; default = { }; description = "name -> path/derivation for plugins not in nixpkgs."; };
    extraPackages = mkOption { type = types.listOf types.package; default = [ ]; description = "Added to PATH for nvim."; };
    mergeDependencies = mkOption { type = types.listOf types.str; default = [ "nvim-treesitter" ]; description = "Plugins whose `dependencies` (e.g. grammars) are merged into one directory."; };
    configDir = mkOption { type = types.nullOr types.path; default = null; description = "Lua modules (lua/, after/, ...) merged next to the generated init.lua; must not contain init.lua."; };
    importSpecs = mkOption { type = types.listOf types.str; default = [ ]; description = "Lua modules whose plugin specs lazy.nvim imports."; };
    extraInitLuaPre = mkOption { type = types.lines; default = ""; description = "Lua run before lazy.setup."; };
    extraInitLua = mkOption { type = types.lines; default = ""; description = "Lua run after lazy.setup."; };
    lazyOpts = mkOption { type = types.attrsOf types.raw; default = { }; description = "Merged over the default lazy.setup() options."; };
    appName = mkOption { type = types.str; default = "nix-lazy-nvim"; description = "NVIM_APPNAME."; };
    linkConfig = mkOption { type = types.bool; default = false; description = "Symlink the generated config (init.lua + configDir) to ~/.config/nvim and run nvim with the normal config/data dirs, instead of isolating it via NVIM_APPNAME/XDG_CONFIG_HOME. Fails on activation if ~/.config/nvim already exists."; };
    binName = mkOption { type = types.str; default = "nvim"; };
  };

  config = lib.mkIf cfg.enable (
    let
      pkg = import ../lib/mkLazyNvim.nix {
        inherit pkgs;
        inherit (cfg) plugins extraPlugins extraPackages mergeDependencies configDir importSpecs extraInitLuaPre extraInitLua lazyOpts appName binName;
        neovim = cfg.package;
        isolateConfig = !cfg.linkConfig;
      };
    in {
      home.packages = [ pkg ];
      xdg.configFile."nvim" = lib.mkIf cfg.linkConfig { source = pkg.configHome; };
    }
  );
}
