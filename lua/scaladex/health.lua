-- :checkhealth scaladex

local M = {}

M.check = function()
  local health = vim.health
  local config = require("scaladex.config").options

  health.start("scaladex.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.10 or later is required")
  end

  if vim.fn.executable("curl") == 1 then
    health.ok("curl found")
  else
    health.error("curl not found", { "Install curl; every request to " .. config.base_url .. " goes through it" })
    return
  end

  local results, err = require("scaladex.api").search("cats")
  if err ~= nil then
    health.error("Could not search " .. config.base_url .. ": " .. err)
  else
    health.ok(config.base_url .. " reachable (" .. #(results or {}) .. " results for cats)")
  end

  health.info("Choosing a module does: " .. config.action)

  local ui = require("scaladex.ui")
  if ui.use_snacks() then
    health.ok("`:Scaladex` uses the snacks.nvim picker (picker = " .. config.picker .. ")")
  elseif config.picker == "snacks" then
    health.warn('picker = "snacks" but snacks.nvim is not installed; `:Scaladex` uses vim.ui.select')
  else
    health.info("`:Scaladex` uses vim.ui.select (picker = " .. config.picker .. ")")
  end

  if pcall(require, "telescope") then
    health.ok("Telescope found: `:Telescope scaladex` is available")
  end
end

return M
