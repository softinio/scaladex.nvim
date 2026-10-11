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

--- Asks for the query when it is not given, then calls back with the results.
--- Errors and empty results are reported and do not call back.
---@param opts scaladex.PickOpts
---@param callback fun(hits: scaladex.SearchHit[], query: string)
M.search = function(opts, callback)
  local function run(query)
    if query == nil or vim.trim(query) == "" then
      return
    end
    vim.api.nvim_echo({ { "Searching for " .. query .. "…" } }, false, {})
    api.search(query, { platform = opts.platform, scala_version = opts.scala_version }, function(err, hits)
      vim.api.nvim_echo({ { "" } }, false, {})
      if err ~= nil then
        M.notify("Search failed: " .. err, vim.log.levels.ERROR)
      elseif hits == nil or #hits == 0 then
        M.notify("No results for " .. query, vim.log.levels.WARN)
      else
        callback(hits, query)
      end
    end)
  end

  if opts.query ~= nil and vim.trim(opts.query) ~= "" then
    run(opts.query)
  else
    vim.ui.input({ prompt = "Search Scala packages: " }, run)
  end
end

--- Search, pick a project, pick one of its modules, then copy, insert or open
--- it.
---@param opts? scaladex.PickOpts
M.pick = function(opts)
  opts = opts or {}
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

  M.search(opts, function(hits)
    vim.ui.select(hits, {
      prompt = "Project",
      kind = "scaladex.project",
      format_item = format.hit,
    }, function(hit)
      if hit ~= nil then
        choose_module(hit.packages)
      end
    end)
  end)
end

return M
