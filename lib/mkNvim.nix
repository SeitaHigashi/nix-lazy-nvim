# mkNvim: Nix fetches the plugins, lazy.nvim only loads them.
# Contract with the Lua side: $NVIM_NIX_LAZY points at a Lua file returning
#   { lazypath = <lazy.nvim dir>, opts = <lazy.setup() options> }
{ pkgs
, lib ? pkgs.lib
, neovim ? pkgs.neovim
, plugins ? [ ]           # vimPlugins derivations, or { name = "x.nvim"; plugin = drv; }
, extraPlugins ? { }      # { "name" = path-or-drv; } for plugins nixpkgs lacks
, extraPackages ? [ ]     # put on PATH for nvim (LSP servers, ripgrep, ...)
, mergeDependencies ? [ "nvim-treesitter" ]  # plugins whose `dependencies` (grammars) join one dir
, configDir ? null        # optional: run with this config dir (NVIM_APPNAME) instead of ~/.config/nvim
, appName ? "nix-lazy-nvim"
, binName ? "nvim"
}:
let
  normalize = p: if p ? plugin then p else { name = p.pname; plugin = p; };
  entries = map normalize plugins;

  withDeps = { name, plugin }:
    if builtins.elem name mergeDependencies && plugin ? dependencies
    then { inherit name; plugin = pkgs.symlinkJoin { inherit name; paths = [ plugin ] ++ plugin.dependencies; }; }
    else { inherit name plugin; };

  lazyPlugin = lib.findFirst (e: e.name == "lazy.nvim") { plugin = pkgs.vimPlugins.lazy-nvim; } entries;

  pluginDir = pkgs.linkFarm "nvim-plugins" (
    (map (e: let d = withDeps e; in { inherit (d) name; path = d.plugin; }) (lib.filter (e: e.name != "lazy.nvim") entries))
    ++ [ { name = "lazy.nvim"; path = lazyPlugin.plugin; } ]
    ++ lib.mapAttrsToList (name: path: { inherit name path; }) extraPlugins
  );

  lazyNix = pkgs.writeText "nix-lazy.lua" ''
    return {
      lazypath = "${lazyPlugin.plugin}",
      opts = {
        dev = { path = "${pluginDir}", patterns = { "" }, fallback = false },
        install = { missing = false },
        checker = { enabled = false },
        change_detection = { enabled = false },
        lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
      },
    }
  '';

  configRoot = pkgs.runCommand "nvim-config-root" { } ''
    mkdir -p $out
    ln -s ${configDir} $out/${appName}
  '';
in
pkgs.writeShellScriptBin binName ''
  export NVIM_NIX_LAZY=${lazyNix}
  ${lib.optionalString (configDir != null) ''
    export NVIM_APPNAME=${appName}
    export XDG_CONFIG_HOME=${configRoot}
  ''}
  ${lib.optionalString (extraPackages != [ ]) ''export PATH=${lib.makeBinPath extraPackages}:$PATH''}
  exec ${neovim}/bin/nvim "$@"
''
