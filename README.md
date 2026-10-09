# nix-lazy-nvim

Declare plugins in Nix; Nix fetches them **and generates `init.lua`**, in which every plugin spec
carries its `/nix/store` path (`dir = "/nix/store/..."`). [lazy.nvim](https://github.com/folke/lazy.nvim)
only loads them, so `event`/`cmd`/`ft`/`keys` lazy-loading all work and nothing is ever cloned.

```nix
plugins = [
  vp.lazy-nvim
  { plugin = vp.nightfox-nvim; lazy = false; priority = 1000; config = ''vim.cmd("colorscheme nordfox")''; }
  { plugin = vp.telescope-nvim; cmd = "Telescope"; dependencies = [ vp.plenary-nvim ]; }
];
```

generates (abridged)

```lua
vim.opt.rtp:prepend("/nix/store/...-lazy.nvim-...")
require("lazy").setup({
  { name = "nightfox.nvim", dir = "/nix/store/...", lazy = false, priority = 1000,
    config = function(plugin, opts) vim.cmd("colorscheme nordfox") end },
  { name = "telescope.nvim", dir = "/nix/store/...", cmd = "Telescope", dependencies = { "plenary.nvim" } },
  { name = "plenary.nvim", dir = "/nix/store/..." },
}, { install = { missing = false }, checker = { enabled = false }, change_detection = { enabled = false }, ... })
```

## Quickstart

```sh
cd examples/basic && nix run .
```

The root flake exports only `lib` and `homeManagerModules`, no `packages`/`apps`, so
`nix run .` at the repository root errors. The example (`examples/basic/flake.nix`) builds the
wrapper as `nvim-lazy-test`.

## Plugin entries

A plugin is a derivation, or an attrset `{ plugin = drv; ... }`:

| field | meaning |
|---|---|
| `plugin` | derivation or path (flake input with `flake = false` for git-only plugins) |
| `name` | lazy.nvim name; defaults to `pname` |
| `dependencies` | list of names (strings) or plugins; plugins are added to the spec automatically |
| `config`, `init` | **string** = Lua function body (`function(plugin, opts) <body> end`) |
| `opts` | attrset = Lua table, string = function body |
| anything else | passed through as Lua data (`event`, `cmd`, `ft`, `keys`, `lazy`, `priority`, `version`, ...) |

- Non-data values (functions, `vim.fn` calls): `nix-lazy-nvim.lib.raw "<lua expr>"`.
- Positional table entries (e.g. `keys`): attr names `_1`, `_2`, ... (`{ _1 = "<leader>f"; _2 = "<cmd>Telescope<cr>"; desc = "Find"; }`).
- Both inline Lua and hand-written modules work: `config = ''require("plugins.telescope")''`.

## Adding your own Lua

`init.lua` is generated, so extend it through:

- `configDir`: a directory with `lua/`, `after/`, `ftplugin/` ... merged next to the generated
  `init.lua` (it must not contain its own `init.lua`). `require("mod")` works from anywhere.
- `extraInitLuaPre` / `extraInitLua`: Lua text before / after `lazy.setup` (e.g. `require("options")`).
- `importSpecs = [ "plugins" ]`: lazy.nvim imports `lua/plugins/*.lua` from `configDir` as extra specs
  (specs merge by name with the Nix entries).
- `lazyOpts`: merged over the default `lazy.setup()` options.

### `lib.mkLazyNvim pkgs { ... }` -> derivation (a wrapper script)

| argument | default | meaning |
|---|---|---|
| `plugins` | `[ ]` | plugin entries, see above |
| `extraPlugins` | `{ }` | `{ "name" = path-or-drv; }` sugar for plugins nixpkgs lacks (use a plugin entry if you need lazy fields) |
| `extraPackages` | `[ ]` | put on `PATH` for nvim (LSP servers, ripgrep, ...) |
| `mergeDependencies` | `[ "nvim-treesitter" ]` | plugins whose `dependencies` are merged into one dir |
| `configDir` | `null` | Lua modules merged next to the generated `init.lua` |
| `importSpecs` | `[ ]` | modules whose specs lazy.nvim imports |
| `extraInitLuaPre`, `extraInitLua` | `""` | Lua before / after `lazy.setup` |
| `lazyOpts` | `{ }` | merged over the default `lazy.setup()` options |
| `appName` | `"nix-lazy-nvim"` | `NVIM_APPNAME`; the wrapper always runs nvim with its own config root (`XDG_CONFIG_HOME`), never `~/.config/nvim` |
| `binName` | `"nvim"` | name of the executable |
| `neovim` | `pkgs.neovim` | Neovim package to wrap |

```nix
nix-lazy-nvim.lib.mkLazyNvim pkgs {
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
| `plugins`, `extraPlugins`, `extraPackages`, `mergeDependencies`, `configDir`, `importSpecs`, `extraInitLuaPre`, `extraInitLua`, `lazyOpts`, `appName`, `binName` | same as above |


## Usage examples

Add the input (use `inputs.nixpkgs.follows` as usual):

```nix
inputs.nix-lazy-nvim.url = "github:SeitaHigashi/nix-lazy-nvim";
```

### Standalone package (no module)

```nix
packages.x86_64-linux.default = nix-lazy-nvim.lib.mkLazyNvim pkgs {
  plugins = [ pkgs.vimPlugins.lazy-nvim pkgs.vimPlugins.telescope-nvim ];
  configDir = ./config;       # lua modules; init.lua is generated
  binName = "nvim-lazy";
};
```

### NixOS module (system-wide)

`lib.mkLazyNvim` returns a package, so put it in `environment.systemPackages`:

```nix
{ pkgs, nix-lazy-nvim, ... }: {
  environment.systemPackages = [
    (nix-lazy-nvim.lib.mkLazyNvim pkgs {
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

- **Plugin names** come from `pname`; override with `name = "telescope.nvim"`. Hand-written specs
  (`importSpecs`) merge with Nix entries by lazy.nvim's derived name (`'nvim-telescope/telescope.nvim'`
  -> `telescope.nvim`).
- **Git-only plugins**: add a flake input with `flake = false` and use
  `{ name = "flash.nvim"; plugin = flash-src; ... }` (see `examples/basic/flake.nix`).
- **Treesitter**: in nixpkgs the grammars are `dependencies` of `nvim-treesitter`
  (e.g. `vimPlugins.nvim-treesitter.withAllGrammars`). `mergeDependencies` symlink-joins them
  into one directory so they sit on the runtimepath with the plugin.
- **Wrapper vs `programs.neovim`**: the wrapper only writes a shell script and uses its own config
  root, so it does not clash with a symlinked `~/.config/nvim`, and `binName` lets it live next to another `nvim`
  without a command clash.

## Known limits

- `build = ...` steps (`make`, `install.sh`, `:TSUpdate`) are not run for local `dir` plugins; the plugin must
  already be built by Nix (use the nixpkgs derivation).
- LuaRocks dependencies are not handled.
- Plugins with unfree or missing licenses need `nixpkgs.config.allowUnfreePredicate` (or equivalent).
- Mason downloads prebuilt binaries at runtime, which commonly does not work on NixOS;
  provide LSP servers etc. via `extraPackages`. (Not tested here.)

## Verified

On x86_64-linux, `examples/basic` builds (`nix build .#default`) and
`nvim-lazy-test --headless` starts, loads the `nordfox` colorscheme and registers 8 plugins.
Lazy-loading was checked headless: `:Telescope`/`:FlashTest` and a `keys` mapping exist before load,
`:Telescope` loads telescope. The generated `init.lua` has no non-Nix fallback.

## License

MIT, see `LICENSE`.
