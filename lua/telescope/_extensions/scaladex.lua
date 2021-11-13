local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires nvim-telescope/telescope.nvim")
end

local scaladex = require("telescope._extensions.scaladex.search")

return telescope.register_extension({
  exports = { scaladex = scaladex },
})
