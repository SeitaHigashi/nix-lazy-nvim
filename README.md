# nix-lazy-nvim

Nix fetches Neovim plugins; lazy.nvim only loads them. Config stays plain Lua.

Contract: `$NVIM_NIX_LAZY` points at a Lua file returning `{ lazypath, opts }`.
See `examples/basic/config/init.lua` for the Lua side (falls back to a normal clone without Nix).

- `lib.mkNvim pkgs { plugins; extraPlugins; extraPackages; configDir; ... }` -> wrapped nvim
- `homeManagerModules.default` -> `programs.nix-lazy-nvim.*` (same options)

Try: `cd examples/basic && nix run .`
