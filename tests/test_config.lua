local config = require("scaladex.config")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({ hooks = { post_case = config.setup } })

T["defaults"] = function()
  config.setup()
  eq(config.options, config.defaults)
end

T["merges with defaults"] = function()
  config.setup({ action = "insert", scala_version = "3" })
  eq(config.options.action, "insert")
  eq(config.options.scala_version, "3")
  eq(config.options.base_url, "https://pkg.scalanews.net")
end

T["rejects bad options"] = function()
  MiniTest.expect.error(function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ action = "paste" })
  end, "action must be one of")
  MiniTest.expect.error(function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ timeout = "10" })
  end, "timeout must be a number")
  MiniTest.expect.error(function()
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ picker = "fzf" })
  end, "picker must be one of")
end

return T
