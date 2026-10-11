-- The search flow and what choosing a module does. Pickers go through
-- vim.ui.select, so whichever picker the user has set up (Telescope, fzf-lua,
-- snacks, …) is used.

local api = require("scaladex.api")
local build = require("scaladex.build")
local config = require("scaladex.config")
local format = require("scaladex.format")

local M = {}

---@param message string
---@param level? integer
M.notify = function(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "scaladex" })
end

--- Where the search started, so the result goes back to that buffer once the
--- pickers have closed.
---@class scaladex.Origin
---@field buf integer
---@field win integer

---@return scaladex.Origin
M.origin = function()
  return { buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win() }
end

--- Puts text in the unnamed register and, when Neovim has a clipboard, the
--- system clipboard too.
---@param text string
M.copy = function(text)
  local regtype = text:find("\n", 1, true) and "l" or "v"
  vim.fn.setreg('"', text, regtype)
  if vim.fn.has("clipboard") == 1 then
    pcall(vim.fn.setreg, "+", text, regtype)
    if vim.tbl_contains(vim.opt.clipboard:get(), "unnamed") then
      pcall(vim.fn.setreg, "*", text, regtype)
    end
  end
  M.notify("Copied " .. (text:gsub("\n", " ")))
end

--- Inserts text below the cursor line of the origin window, indented like
--- that line. Copies it instead when that is not possible.
---@param text string
---@param origin scaladex.Origin
M.insert = function(text, origin)
  if
    not vim.api.nvim_win_is_valid(origin.win)
    or vim.api.nvim_win_get_buf(origin.win) ~= origin.buf
    or not vim.bo[origin.buf].modifiable
  then
    M.copy(text)
    return
  end
  vim.api.nvim_win_call(origin.win, function()
    local indent = vim.api.nvim_get_current_line():match("^%s*")
    local lines = vim.tbl_map(function(line)
      return indent .. line
    end, vim.split(text, "\n"))
    vim.api.nvim_put(lines, "l", true, true)
  end)
end

---@param pkg scaladex.Package
M.open = function(pkg)
  local _, err = vim.ui.open(api.package_url(pkg.groupId, pkg.name))
  if err ~= nil then
    M.notify("Could not open the browser: " .. err, vim.log.levels.ERROR)
  end
end

--- The line that adds a package to the build the origin buffer belongs to.
---@param pkg scaladex.Package
---@param origin scaladex.Origin
---@return string
M.dependency = function(pkg, origin)
  local buf = vim.api.nvim_buf_is_valid(origin.buf) and origin.buf or vim.api.nvim_get_current_buf()
  return build.dependency(pkg, build.detect(buf))
end

--- Copies, inserts or opens a module.
---@param action scaladex.Action
---@param pkg scaladex.Package
---@param origin scaladex.Origin
M.apply = function(action, pkg, origin)
  if action == "open" then
    M.open(pkg)
  elseif action == "insert" then
    M.insert(M.dependency(pkg, origin), origin)
  else
    M.copy(M.dependency(pkg, origin))
  end
end

---@class scaladex.PickOpts: scaladex.SearchOpts
---@field query? string asked for when left out
---@field action? scaladex.Action defaults to the configured action

---@class scaladex.Filters: scaladex.SearchOpts
---@field platform string "" for any
---@field scala_version string "" for any

--- The filters a search uses: those in `opts`, else the configured ones.
---@param opts scaladex.SearchOpts
---@return scaladex.Filters
M.filters = function(opts)
  local function pick(value, default)
    if value ~= nil then
      return vim.trim(value)
    end
    return default and vim.trim(default) or ""
  end
  return {
    platform = pick(opts.platform, config.options.platform):lower(),
    scala_version = pick(api.scala_version(opts.scala_version), config.options.scala_version),
  }
end

-- `:Scaladex` arguments that set a filter instead of being part of the query
local filter_args = { platform = "platform", scala = "scala_version", scala_version = "scala_version" }

--- Splits `:Scaladex` arguments into the query and filters, e.g.
--- `platform=js scala=3 json parser`. `platform=` or `scala=` alone means any.
---@param args string
---@return scaladex.PickOpts
M.parse_args = function(args)
  local opts, words = {}, {}
  for _, word in ipairs(vim.split(vim.trim(args), "%s+", { trimempty = true })) do
    local key, value = word:match("^([%w_]+)=(.*)$")
    if key ~= nil and filter_args[key] ~= nil then
      opts[filter_args[key]] = value
    else
      table.insert(words, word)
    end
  end
  if #words > 0 then
    opts.query = table.concat(words, " ")
  end
  return opts
end

--- Completion for `:Scaladex`: the filter arguments and their values.
---@param arglead string
---@return string[]
M.complete = function(arglead)
  local candidates = {}
  for _, platform in ipairs(api.platforms) do
    table.insert(candidates, "platform=" .. platform)
  end
  for _, version in ipairs(api.scala_versions) do
    table.insert(candidates, "scala=" .. version)
  end
  return vim.tbl_filter(function(c)
    return vim.startswith(c, arglead)
  end, candidates)
end

--- Asks for a platform, then a Scala version, each with how many results it
--- gives when the counts are known. Calls back only when both are chosen.
---@param current scaladex.Filters
---@param facets? scaladex.Facets
---@param callback fun(filters: scaladex.Filters)
M.choose_filters = function(current, facets, callback)
  ---@param values string[]
  ---@param counts? table<string, integer>
  ---@param any string
  ---@param label fun(value: string): string
  ---@param selected string
  ---@param prompt string
  ---@param next fun(value: string)
  local function choose(values, counts, any, label, selected, prompt, next)
    local items = vim.list_extend({ "" }, values)
    vim.ui.select(items, {
      prompt = prompt,
      kind = "scaladex.filter",
      format_item = function(value)
        local line = value == "" and any or label(value)
        if counts ~= nil and value ~= "" then
          line = line .. " (" .. (counts[value] or 0) .. ")"
        end
        return (value == selected and "* " or "  ") .. line
      end,
    }, function(value)
      if value ~= nil then
        next(value)
      end
    end)
  end

  choose(
    api.platforms,
    facets and facets.platforms,
    "Any platform",
    format.platform,
    current.platform,
    "Platform",
    function(platform)
      choose(
        api.scala_versions,
        facets and facets.scalaVersions,
        "Any Scala version",
        function(v)
          return "Scala " .. v
        end,
        current.scala_version,
        "Scala version",
        function(scala)
          callback({ platform = platform, scala_version = scala })
        end
      )
    end
  )
end

--- Asks for the query when it is not given, then calls back with the results.
--- Errors and empty results are reported and do not call back.
---@param opts scaladex.PickOpts
---@param callback fun(hits: scaladex.SearchHit[], query: string, response: scaladex.SearchResponse)
M.search = function(opts, callback)
  local filters = M.filters(opts)

  local function run(query)
    if query == nil or vim.trim(query) == "" then
      return
    end
    vim.api.nvim_echo({ { "Searching for " .. query .. "…" } }, false, {})
    api.search(query, filters, function(err, hits, response)
      vim.api.nvim_echo({ { "" } }, false, {})
      if err ~= nil then
        M.notify("Search failed: " .. err, vim.log.levels.ERROR)
      elseif hits == nil or #hits == 0 or response == nil then
        M.notify("No results for " .. query .. " (" .. format.filters(filters) .. ")", vim.log.levels.WARN)
      else
        callback(hits, query, response)
      end
    end)
  end

  local query = opts.query ~= nil and tostring(opts.query) or ""
  if vim.trim(query) ~= "" then
    run(query)
  else
    vim.ui.input({ prompt = "Search Scala packages: " }, run)
  end
end

--- Whether to use snacks.nvim's picker: always with `picker = "snacks"`, and
--- with "auto" when snacks.nvim has its picker enabled.
---@return boolean
M.use_snacks = function()
  local picker = config.options.picker
  if picker == "select" then
    return false
  end
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    if picker == "snacks" then
      M.notify('picker is "snacks" but snacks.nvim is not installed; using vim.ui.select', vim.log.levels.WARN)
    end
    return false
  end
  -- set by Snacks.setup({ picker = { enabled = true } })
  local snacks_picker = snacks.config.picker --[[@as { enabled?: boolean }?]]
  return picker == "snacks" or (snacks_picker ~= nil and snacks_picker.enabled == true)
end

--- Search, pick a project, pick one of its modules, then copy, insert or open
--- it, with snacks.nvim's picker when it is in use (see `use_snacks`) or else
--- vim.ui.select. The vim.ui.select project list starts with an entry for changing the filters, which
--- searches again.
---@param opts? scaladex.PickOpts
M.pick = function(opts)
  opts = opts or {}
  if M.use_snacks() then
    require("scaladex.snacks").pick(opts)
    return
  end
  local origin = M.origin()
  local action = opts.action or config.options.action

  local function choose_module(packages)
    if #packages == 1 then
      M.apply(action, packages[1], origin)
      return
    end
    vim.ui.select(packages, {
      prompt = "Module",
      kind = "scaladex.package",
      format_item = format.package,
    }, function(pkg)
      if pkg ~= nil then
        M.apply(action, pkg, origin)
      end
    end)
  end

  M.search(opts, function(hits, query, response)
    local filters = M.filters(opts)
    local change = { filters = true }
    local items = vim.list_extend({ change }, hits)
    vim.ui.select(items, {
      prompt = "Project",
      kind = "scaladex.project",
      format_item = function(item)
        if item == change then
          return "Change filters (" .. format.filters(filters) .. ")…"
        end
        return format.hit(item)
      end,
    }, function(item)
      if item == change then
        M.choose_filters(filters, response.facets, function(chosen)
          M.pick(vim.tbl_extend("force", opts, chosen, { query = query }))
        end)
      elseif item ~= nil then
        choose_module(item.packages)
      end
    end)
  end)
end

return M
