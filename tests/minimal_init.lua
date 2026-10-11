-- Used by `make test`: Neovim's runtime, the plugin and mini.test, and nothing
-- from the user's config or installed packages.
local cwd = vim.fn.getcwd()
vim.opt.packpath = {}
vim.opt.rtp = { cwd, vim.env.VIMRUNTIME, cwd .. "/deps/mini.nvim" }
vim.opt.swapfile = false

require("mini.test").setup()
