if vim.g.loaded_scaladex then
  return
end
vim.g.loaded_scaladex = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("scaladex.nvim needs Neovim 0.10 or later", vim.log.levels.ERROR, { title = "scaladex" })
  return
end

vim.api.nvim_create_user_command("Scaladex", function(args)
  require("scaladex").pick({
    query = args.args ~= "" and args.args or nil,
    action = args.bang and "open" or nil,
  })
end, {
  nargs = "*",
  bang = true,
  desc = "Search Scala packages on pkg.scalanews.net (! opens the package page)",
})
