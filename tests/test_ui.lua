---@diagnostic disable: duplicate-set-field
local ui = require("scaladex.ui")
local eq = MiniTest.expect.equality

local notified
local real_notify = vim.notify

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      notified = {}
      vim.notify = function(msg)
        table.insert(notified, msg)
      end
      vim.cmd("enew!")
    end,
    post_case = function()
      vim.notify = real_notify
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

T["copy fills the unnamed register and says so"] = function()
  ui.copy('mvn"a::b:1"')
  eq(vim.fn.getreg('"'), 'mvn"a::b:1"')
  eq(notified, { 'Copied mvn"a::b:1"' })
end

T["insert goes below the cursor, indented like it"] = function()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "deps = Seq(", "    first,", ")" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  ui.insert("a\nb", ui.origin())
  eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "deps = Seq(", "    first,", "    a", "    b", ")" })
end

T["insert into a read-only buffer copies instead"] = function()
  vim.bo.modifiable = false
  ui.insert("x", ui.origin())
  eq(vim.fn.getreg('"'), "x")
end

return T
