local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local scaladex = require("scaladex")
local helpers = require("telescope._extensions.scaladex.helpers")

local M = {}

M.search = function(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "scaladex search",
    finder = finders.new_table({
      results = {},
    }),
    layout_strategy = "bottom_pane",
    layout_config = {
      height = 1,
    },
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selected = action_state.get_current_line()
        local results = scaladex.search(selected)
        if next(results) == nil then
          vim.notify("No results for " .. selected)
        else
          M.package_search(opts, results)
        end
      end)
      return true
    end,
  }):find()
end

M.package_search = function(opts, results)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "scaladex package selection",
    sorter = conf.generic_sorter(opts),
    layout_strategy = "vertical",
    layout_config = {
      height = 10,
      width = 0.3,
      prompt_position = "bottom",
    },
    finder = finders.new_table({
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry["repository"] .. " by " .. entry["organization"],
          ordinal = entry["repository"],
        }
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selected = action_state.get_selected_entry()
        if next(selected) ~= nil then
          local value = selected["value"]
          local selection = scaladex.get_project(value["organization"], value["repository"])
          M.artifacts(opts, selection)
        end
      end)
      return true
    end,
  }):find()
end

M.artifacts = function(opts, results)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "scaladex artifact selection",
    sorter = conf.generic_sorter(opts),
    layout_strategy = "vertical",
    layout_config = {
      height = 10,
      width = 0.3,
      prompt_position = "bottom",
    },
    finder = finders.new_table({
      results = results["artifacts"],
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selected = action_state.get_selected_entry()
        if next(selected) ~= nil then
          local value = selected["value"]
          local dep = helpers.create_dependency_string(results, value)
          helpers.copy_to_clipboard(dep)
        end
      end)
      map("n", "<c-s>", function()
        actions.close(prompt_bufnr)
        local selected = action_state.get_selected_entry()
        if next(selected) ~= nil then
          local value = selected["value"]
          local url = "https://index.scala-lang.org/" .. value["organization"] .. "/" .. value["repository"]
          helpers.open_browser(url)
        end
      end)
      return true
    end,
  }):find()
end

return M
