-- Used by `make test`: the plugin and mini.test, nothing from the user's config.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.getcwd() .. "/deps/mini.nvim")
vim.opt.swapfile = false

require("mini.test").setup()
