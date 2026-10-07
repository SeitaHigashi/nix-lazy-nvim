return {
  { 'folke/lazy.nvim', version = false },
  { 'EdenEast/nightfox.nvim', lazy = false, priority = 1000 },
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
  },
  { 'lewis6991/gitsigns.nvim', event = 'VeryLazy', dependencies = { 'nvim-lua/plenary.nvim' } },
  { 'tpope/vim-fugitive', cmd = 'Git' },
  { 'folke/flash.nvim', cmd = 'FlashTest', config = function() vim.api.nvim_create_user_command('FlashTest', function() end, {}) end },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
}
