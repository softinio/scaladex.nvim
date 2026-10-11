local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local preview_utils = require("telescope.previewers.utils")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local build = require("scaladex.build")
local config = require("scaladex.config")
local format = require("scaladex.format")
local ui = require("scaladex.ui")

local M = {}

---@param lines fun(entry: table): string[]
local function previewer(lines)
  return previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines(entry.value))
      vim.wo[self.state.winid].wrap = true
      preview_utils.highlighter(self.state.bufnr, "markdown")
    end,
  })
end

--- Runs `fn` on the selected entry's value after closing the picker.
---@param prompt_bufnr integer
---@param fn fun(value: any)
local function with_selection(prompt_bufnr, fn)
  local selected = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  if selected ~= nil then
    fn(selected.value)
  end
end

---@param opts table
---@param packages scaladex.Package[]
---@param origin scaladex.Origin
M.modules = function(opts, packages, origin)
  local action = opts.action or config.options.action
  local origin_build = build.detect(vim.api.nvim_buf_is_valid(origin.buf) and origin.buf or nil)
  pickers
    .new(opts, {
      prompt_title = "Module",
      sorter = conf.generic_sorter(opts),
      previewer = previewer(function(pkg)
        return format.package_preview(pkg, build.dependency(pkg, origin_build))
      end),
      finder = finders.new_table({
        results = packages,
        ---@param pkg scaladex.Package
        entry_maker = function(pkg)
          return { value = pkg, display = format.package(pkg), ordinal = pkg.name }
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          with_selection(prompt_bufnr, function(pkg)
            ui.apply(action, pkg, origin)
          end)
        end)
        for _, mode in ipairs({ "i", "n" }) do
          map(mode, "<C-s>", function()
            with_selection(prompt_bufnr, ui.open)
          end, { desc = "open the package page" })
          map(mode, "<C-y>", function()
            with_selection(prompt_bufnr, function(pkg)
              ui.apply("copy", pkg, origin)
            end)
          end, { desc = "copy the dependency" })
        end
        return true
      end,
    })
    :find()
end

---@param opts table
---@param hits scaladex.SearchHit[]
---@param query string
---@param origin scaladex.Origin
---@param response scaladex.SearchResponse
M.projects = function(opts, hits, query, origin, response)
  local filters = ui.filters(opts)
  pickers
    .new(opts, {
      prompt_title = "Projects for " .. query .. " (" .. format.filters(filters) .. ")",
      sorter = conf.generic_sorter(opts),
      previewer = previewer(format.hit_preview),
      finder = finders.new_table({
        results = hits,
        ---@param hit scaladex.SearchHit
        entry_maker = function(hit)
          local display = format.hit(hit)
          return { value = hit, display = display, ordinal = display }
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          with_selection(prompt_bufnr, function(hit)
            if #hit.packages == 1 then
              ui.apply(opts.action or config.options.action, hit.packages[1], origin)
            else
              M.modules(opts, hit.packages, origin)
            end
          end)
        end)
        for _, mode in ipairs({ "i", "n" }) do
          map(mode, "<C-s>", function()
            with_selection(prompt_bufnr, function(hit)
              ui.open(hit.packages[1])
            end)
          end, { desc = "open the project's main package page" })
          map(mode, "<C-f>", function()
            actions.close(prompt_bufnr)
            ui.choose_filters(filters, response.facets, function(chosen)
              M.run(vim.tbl_extend("force", opts, chosen, { query = query }), origin)
            end)
          end, { desc = "change the platform and Scala version filters" })
        end
        return true
      end,
    })
    :find()
end

--- Search pkg.scalanews.net, then pick a project and a module. Takes the usual
--- Telescope options plus `query`, `platform`, `scala_version` and `action`.
---@param opts? table
M.search = function(opts)
  M.run(opts or {}, ui.origin())
end

---@param opts table
---@param origin scaladex.Origin
M.run = function(opts, origin)
  ui.search(opts, function(hits, query, response)
    M.projects(opts, hits, query, origin, response)
  end)
end

return M
