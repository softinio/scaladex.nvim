if vim.g.loaded_scaladex then
  return
end
vim.g.loaded_scaladex = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("scaladex.nvim needs Neovim 0.10 or later", vim.log.levels.ERROR, { title = "scaladex" })
  return
end

vim.api.nvim_create_user_command("Scaladex", function(args)
  local opts = require("scaladex.ui").parse_args(args.args)
  opts.action = args.bang and "open" or nil
  require("scaladex").pick(opts)
end, {
  nargs = "*",
  bang = true,
  complete = function(arglead)
    return require("scaladex.ui").complete(arglead)
  end,
  desc = "Search Scala packages on pkg.scalanews.net (! opens the package page)",
})
