vim.g.mapleader = ' '

-- Nix hands us lazy's path and options; without it, fall back to a normal clone.
local nix = os.getenv('NVIM_NIX_LAZY') and dofile(os.getenv('NVIM_NIX_LAZY'))
local lazypath = nix and nix.lazypath or (vim.fn.stdpath('data') .. '/lazy/lazy.nvim')
vim.opt.rtp:prepend(lazypath)

local opts = { spec = 'plugins', defaults = { lazy = true } }
require('lazy').setup(vim.tbl_deep_extend('force', opts, nix and nix.opts or {}))

vim.o.number = true
vim.cmd('colorscheme nordfox')
