---@alias scaladex.Action "copy" | "insert" | "open"

--- auto: snacks.nvim's picker when it is enabled, else vim.ui.select
---@alias scaladex.Picker "auto" | "snacks" | "select"

---@class scaladex.Config
---@field base_url string pkg.scalanews.net, or another instance of it
---@field platform? string default platform filter: jvm, js, native, sbt or mill
---@field scala_version? string default Scala version filter, e.g. 3 or 2.13
---@field timeout integer seconds before a request is abandoned
---@field action scaladex.Action what choosing a module does
---@field picker scaladex.Picker the picker :Scaladex uses

---@class scaladex.UserConfig
---@field base_url? string
---@field platform? string
---@field scala_version? string
---@field timeout? integer
---@field action? scaladex.Action
---@field picker? scaladex.Picker

local M = {}

---@type scaladex.Config
M.defaults = {
  base_url = "https://pkg.scalanews.net",
  platform = nil,
  scala_version = nil,
  timeout = 10,
  action = "copy",
  picker = "auto",
}

---@type scaladex.Config
M.options = vim.deepcopy(M.defaults)

M.actions = { "copy", "insert", "open" }

M.pickers = { "auto", "snacks", "select" }

---@param opts? scaladex.UserConfig
M.setup = function(opts)
  opts = opts or {}
  local types = { base_url = "string", platform = "string", scala_version = "string", timeout = "number" }
  for key, expected in pairs(types) do
    if opts[key] ~= nil and type(opts[key]) ~= expected then
      error("scaladex: " .. key .. " must be a " .. expected .. ", got " .. type(opts[key]))
    end
  end
  if opts.action ~= nil and not vim.tbl_contains(M.actions, opts.action) then
    error("scaladex: action must be one of " .. table.concat(M.actions, ", ") .. ", got " .. tostring(opts.action))
  end
  if opts.picker ~= nil and not vim.tbl_contains(M.pickers, opts.picker) then
    error("scaladex: picker must be one of " .. table.concat(M.pickers, ", ") .. ", got " .. tostring(opts.picker))
  end
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
end

return M
