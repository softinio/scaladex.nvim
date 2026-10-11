-- Pickers built on snacks.nvim, with previews and the same keys as the
-- Telescope extension, except <C-o> for the filters (snacks uses <C-f> to
-- scroll the preview).

local build = require("scaladex.build")
local config = require("scaladex.config")
local format = require("scaladex.format")
local ui = require("scaladex.ui")

local M = {}

--- Keys for both the input and the list window.
---@param keys table<string, { [1]: string, desc: string }>
---@return snacks.picker.win.Config
local function windows(keys)
  local mapped = {}
  for key, spec in pairs(keys) do
    mapped[key] = { spec[1], mode = { "n", "i" }, desc = spec.desc }
  end
  return {
    input = { keys = mapped },
    list = { keys = mapped },
    preview = { wo = { wrap = true } },
  }
end

--- Closes the picker, then runs `fn` with the item's value once it has gone,
--- so a picker opened by `fn` does not race the closing one.
---@param fn fun(value: any)
---@return fun(picker: snacks.Picker, item?: snacks.picker.Item)
local function after_close(fn)
  return function(picker, item)
    picker:close()
    if item ~= nil then
      vim.schedule(function()
        fn(item.value)
      end)
    end
  end
end

---@param lines string[]
---@return snacks.picker.Item.preview
local function preview(lines)
  return { text = table.concat(lines, "\n"), ft = "markdown", loc = false }
end

---@param opts scaladex.PickOpts
---@param packages scaladex.Package[]
---@param origin scaladex.Origin
M.modules = function(opts, packages, origin)
  local action = opts.action or config.options.action
  local origin_build = build.detect(vim.api.nvim_buf_is_valid(origin.buf) and origin.buf or nil)
  local items = {}
  for i, pkg in ipairs(packages) do
    table.insert(items, {
      idx = i,
      text = format.package(pkg),
      value = pkg,
      preview = preview(format.package_preview(pkg, build.dependency(pkg, origin_build))),
    })
  end
  require("snacks").picker.pick({
    title = "Module",
    items = items,
    format = "text",
    preview = "preview",
    sort = { fields = { "score:desc", "idx" } },
    confirm = after_close(function(pkg)
      ui.apply(action, pkg, origin)
    end),
    actions = {
      scaladex_open = after_close(ui.open),
      scaladex_copy = after_close(function(pkg)
        ui.apply("copy", pkg, origin)
      end),
    },
    win = windows({
      ["<c-s>"] = { "scaladex_open", desc = "Open the package page" },
      ["<c-y>"] = { "scaladex_copy", desc = "Copy the dependency" },
    }),
  })
end

---@param opts scaladex.PickOpts
---@param hits scaladex.SearchHit[]
---@param query string
---@param origin scaladex.Origin
---@param response scaladex.SearchResponse
M.projects = function(opts, hits, query, origin, response)
  local action = opts.action or config.options.action
  local filters = ui.filters(opts)
  local items = {}
  for i, hit in ipairs(hits) do
    table.insert(items, {
      idx = i,
      text = format.hit(hit),
      value = hit,
      preview = preview(format.hit_preview(hit)),
    })
  end
  require("snacks").picker.pick({
    title = "Projects for " .. query .. " (" .. format.filters(filters) .. ")",
    items = items,
    format = "text",
    preview = "preview",
    sort = { fields = { "score:desc", "idx" } },
    ---@param hit scaladex.SearchHit
    confirm = after_close(function(hit)
      if #hit.packages == 1 then
        ui.apply(action, hit.packages[1], origin)
      else
        M.modules(opts, hit.packages, origin)
      end
    end),
    actions = {
      ---@param hit scaladex.SearchHit
      scaladex_open = after_close(function(hit)
        ui.open(hit.packages[1])
      end),
      scaladex_filters = function(picker)
        picker:close()
        vim.schedule(function()
          ui.choose_filters(filters, response.facets, function(chosen)
            M.run(vim.tbl_extend("force", opts, chosen, { query = query }), origin)
          end)
        end)
      end,
    },
    win = windows({
      ["<c-s>"] = { "scaladex_open", desc = "Open the project's main package page" },
      ["<c-o>"] = { "scaladex_filters", desc = "Change the platform and Scala version filters" },
    }),
  })
end

---@param opts scaladex.PickOpts
---@param origin scaladex.Origin
M.run = function(opts, origin)
  ui.search(opts, function(hits, query, response)
    M.projects(opts, hits, query, origin, response)
  end)
end

--- Search, then pick a project and a module with snacks.nvim's picker. Takes
--- the same options as `require("scaladex").pick()`.
---@param opts? scaladex.PickOpts
M.pick = function(opts)
  M.run(opts or {}, ui.origin())
end

return M
