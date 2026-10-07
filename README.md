# nix-lazy-nvim

Nix fetches Neovim plugins; [lazy.nvim](https://github.com/folke/lazy.nvim) only loads them.
Your Lua config stays plain Lua (lazy specs, `event`/`cmd`/`ft`/`keys` lazy-loading all work),
and it still runs without Nix.

How it works: Nix builds one directory containing every plugin and wraps `nvim` so that
lazy.nvim is configured with

```lua
dev = { path = "<that dir>", patterns = { "" }, fallback = false }
install = { missing = false }
checker = { enabled = false }
change_detection = { enabled = false }
```

With `patterns = { "" }` every plugin spec resolves to a directory in the Nix-built dir
instead of being cloned.

## Quickstart

```sh
cd examples/basic && nix run .
```

The root flake exports only `lib` and `homeManagerModules`, no `packages`/`apps`, so
`nix run .` at the repository root errors. The example (`examples/basic/flake.nix`) builds the
wrapper as `nvim-lazy-test`.

## The contract

The wrapper sets `NVIM_NIX_LAZY` to a Lua file returning `{ lazypath, opts }`
(`lazypath` = Nix store path of lazy.nvim, `opts` = options for `require("lazy").setup`).
Your `init.lua` consumes it, and falls back to a normal clone when the variable is unset
(from `examples/basic/config/init.lua`):

```lua
local nix = os.getenv('NVIM_NIX_LAZY') and dofile(os.getenv('NVIM_NIX_LAZY'))
local lazypath = nix and nix.lazypath or (vim.fn.stdpath('data') .. '/lazy/lazy.nvim')
vim.opt.rtp:prepend(lazypath)

local opts = { spec = 'plugins', defaults = { lazy = true } }
require('lazy').setup(vim.tbl_deep_extend('force', opts, nix and nix.opts or {}))
```

Note: that example does not bootstrap-clone lazy.nvim in the non-Nix branch; add your usual
clone step if you want the fallback to work on a fresh machine (the fallback path is not
exercised by this repo).

## API

### `lib.mkNvim pkgs { ... }` -> derivation (a wrapper script)

| argument | default | meaning |
|---|---|---|
| `plugins` | `[ ]` | `vimPlugins` derivations, or `{ name = "x.nvim"; plugin = drv; }` |
| `extraPlugins` | `{ }` | `{ "name" = path-or-drv; }` for plugins nixpkgs lacks |
| `extraPackages` | `[ ]` | put on `PATH` for nvim (LSP servers, ripgrep, ...) |
| `mergeDependencies` | `[ "nvim-treesitter" ]` | plugins whose `dependencies` are merged into one dir |
| `configDir` | `null` | run with this config dir (via `NVIM_APPNAME` + `XDG_CONFIG_HOME`) instead of `~/.config/nvim` |
| `appName` | `"nix-lazy-nvim"` | `NVIM_APPNAME` used with `configDir` |
| `binName` | `"nvim"` | name of the executable |
| `neovim` | `pkgs.neovim` | Neovim package to wrap |

```nix
nix-lazy-nvim.lib.mkNvim pkgs {
  plugins = [ pkgs.vimPlugins.lazy-nvim pkgs.vimPlugins.telescope-nvim ];
  extraPlugins."flash.nvim" = flash-src;
  configDir = ./config;
  binName = "nvim-lazy";
}
```

### `homeManagerModules.default` -> `programs.nix-lazy-nvim.*`

Installs the wrapper into `home.packages`.

| option | default |
|---|---|
| `enable` | `false` |
| `package` | `pkgs.neovim` (passed as `neovim`) |
| `plugins`, `extraPlugins`, `extraPackages`, `mergeDependencies`, `configDir`, `binName` | same as above |

`appName` is **not** exposed by the module (always the default `"nix-lazy-nvim"`).

## Usage examples

Add the input (use `inputs.nixpkgs.follows` as usual):

```nix
inputs.nix-lazy-nvim.url = "github:SeitaHigashi/nix-lazy-nvim";
```

### Standalone package (no module)

```nix
packages.x86_64-linux.default = nix-lazy-nvim.lib.mkNvim pkgs {
  plugins = [ pkgs.vimPlugins.lazy-nvim pkgs.vimPlugins.telescope-nvim ];
  configDir = ./config;       # your init.lua + lua/plugins
  binName = "nvim-lazy";
};
```

### NixOS module (system-wide)

`lib.mkNvim` returns a package, so put it in `environment.systemPackages`:

```nix
{ pkgs, nix-lazy-nvim, ... }: {
  environment.systemPackages = [
    (nix-lazy-nvim.lib.mkNvim pkgs {
      plugins = [ pkgs.vimPlugins.lazy-nvim pkgs.vimPlugins.telescope-nvim ];
      extraPackages = [ pkgs.ripgrep ];
      configDir = ./config;
      binName = "nvim-lazy";
    })
  ];
}
```

### home-manager (standalone)

```nix
homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    nix-lazy-nvim.homeManagerModules.default
    {
      programs.nix-lazy-nvim = {
        enable = true;
        plugins = [ pkgs.vimPlugins.lazy-nvim pkgs.vimPlugins.telescope-nvim ];
        configDir = ./config;
        binName = "nvim-lazy";
      };
    }
  ];
};
```

### home-manager as a NixOS module

```nix
home-manager.users.alice = { ... }: {
  imports = [ nix-lazy-nvim.homeManagerModules.default ];
  programs.nix-lazy-nvim = {
    enable = true;
    plugins = [ pkgs.vimPlugins.lazy-nvim ];
    binName = "nvim-lazy";
  };
};
```

Apply with your usual command (`nixos-rebuild switch --flake .#host` or `home-manager switch --flake .#me`).

Checked: `examples/basic`'s `homeConfigurations.test` and a throwaway NixOS configuration containing
both the `environment.systemPackages` form and the home-manager-as-NixOS-module form build
(`nix build`; evaluated and built only, not activated or run).

## Usage notes

- **Plugin names** come from `pname` and must match the last path segment lazy.nvim derives
  from the spec (`'nvim-telescope/telescope.nvim'` -> `telescope.nvim`). If they differ,
  override with `{ name = "telescope.nvim"; plugin = pkgs.vimPlugins.telescope-nvim; }`.
  A missing/misnamed plugin fails at startup, because the plugin list lives in both Nix and Lua.
- **Git-only plugins**: add a flake input with `flake = false` and pass it via
  `extraPlugins."name" = input;` (see `flash-src` in `examples/basic/flake.nix`).
- **Treesitter**: in nixpkgs the grammars are `dependencies` of `nvim-treesitter`
  (e.g. `vimPlugins.nvim-treesitter.withAllGrammars`). `mergeDependencies` symlink-joins them
  into one directory so they sit on the runtimepath with the plugin.
- **Wrapper vs `programs.neovim`**: the wrapper only writes a shell script, no files. So it does
  not clash with a symlinked `~/.config/nvim`, and `binName` lets it live next to another `nvim`
  without a command clash.

## Known limits

- `build = ...` steps (`make`, `install.sh`, `:TSUpdate`) are not run with `dev`; the plugin must
  already be built by Nix (use the nixpkgs derivation).
- LuaRocks dependencies are not handled.
- Plugins with unfree or missing licenses need `nixpkgs.config.allowUnfreePredicate` (or equivalent).
- Mason downloads prebuilt binaries at runtime, which commonly does not work on NixOS;
  provide LSP servers etc. via `extraPackages`. (Not tested here.)
- The plugin list is duplicated between Nix and Lua.

## Verified

On x86_64-linux, `examples/basic` builds (`nix build .#default`) and
`nvim-lazy-test --headless` starts, loads the `nordfox` colorscheme and registers 8 plugins.
The non-Nix fallback was not run for this README.

## License

MIT, see `LICENSE`.
