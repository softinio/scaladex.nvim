local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This extension requires nvim-telescope/telescope.nvim")
end

local search = require("telescope._extensions.scaladex.search")

-- `:Telescope scaladex` calls the export itself; older mappings call
-- `extensions.scaladex.scaladex.search()`, so it is callable and keeps `search`.
local scaladex = setmetatable({ search = search.search }, {
  __call = function(_, opts)
    search.search(opts)
  end,
})

return telescope.register_extension({
  exports = { scaladex = scaladex, search = search.search },
})
