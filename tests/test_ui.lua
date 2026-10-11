---@diagnostic disable: duplicate-set-field
local api = require("scaladex.api")
local config = require("scaladex.config")
local ui = require("scaladex.ui")
local eq = MiniTest.expect.equality

local notified
local real_notify = vim.notify
local real_select = vim.ui.select
local real_search = api.search

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
      vim.ui.select = real_select
      api.search = real_search
      package.loaded.snacks = nil
      package.loaded["scaladex.snacks"] = nil
      config.setup()
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

T["parse_args"] = function()
  eq(ui.parse_args(""), {})
  eq(ui.parse_args("json parser"), { query = "json parser" })
  eq(ui.parse_args("platform=js json scala=3 parser"), { query = "json parser", platform = "js", scala_version = "3" })
  eq(ui.parse_args("scala_version=2.12 cats"), { query = "cats", scala_version = "2.12" })
  -- an empty value means any, overriding the configured filter
  eq(ui.parse_args("platform= cats"), { query = "cats", platform = "" })
  -- other key=value words are part of the query
  eq(ui.parse_args("a=b"), { query = "a=b" })
end

T["complete"] = function()
  eq(ui.complete("platform=n"), { "platform=native" })
  eq(ui.complete("scala=2.1"), { "scala=2.13", "scala=2.12", "scala=2.11", "scala=2.10" })
  eq(#ui.complete(""), 10)
end

T["filters fall back to the configured ones"] = function()
  eq(ui.filters({}), { platform = "", scala_version = "" })
  config.setup({ platform = "JVM", scala_version = "3" })
  eq(ui.filters({}), { platform = "jvm", scala_version = "3" })
  eq(ui.filters({ platform = "", scala_version = "2.13" }), { platform = "", scala_version = "2.13" })
end

T["filters from Telescope numbers"] = function()
  eq(ui.filters({ scala_version = 2.1 }).scala_version, "2.10")
  eq(ui.filters({ scala_version = 3 }).scala_version, "3")
  eq(ui.filters({ scala_version = 2.13 }).scala_version, "2.13")
end

--- Stubs vim.ui.select to answer with the item whose formatted line matches
--- each pattern in turn, recording the lines shown.
---@param answers string[]
---@return string[][] shown
local function answer(answers)
  local shown = {}
  vim.ui.select = function(items, opts, on_choice)
    local lines = vim.tbl_map(opts.format_item, items)
    table.insert(shown, lines)
    local want = table.remove(answers, 1)
    for i, line in ipairs(lines) do
      if want ~= nil and line:find(want) then
        return on_choice(items[i], i)
      end
    end
    on_choice(nil, nil)
  end
  return shown
end

local facets = { platforms = { jvm = 10, js = 4 }, scalaVersions = { ["3"] = 7, ["2.13"] = 9 } }

T["choose_filters shows counts and the current choice"] = function()
  local shown = answer({ "Scala.js", "Any Scala" })
  local chosen
  ui.choose_filters({ platform = "jvm", scala_version = "3" }, facets, function(f)
    chosen = f
  end)
  eq(chosen, { platform = "js", scala_version = "" })
  eq(shown[1], {
    "  Any platform",
    "* JVM (10)",
    "  Scala.js (4)",
    "  Scala Native (0)",
    "  sbt plugins (0)",
    "  Mill plugins (0)",
  })
  eq(shown[2][2], "* Scala 3 (7)")
end

T["choose_filters cancelled does not call back"] = function()
  answer({ "Scala.js" })
  local called = false
  ui.choose_filters({ platform = "", scala_version = "" }, facets, function()
    called = true
  end)
  eq(called, false)
end

T["pick can change filters and search again"] = function()
  local searches = {}
  api.search = function(query, opts, callback)
    table.insert(searches, { query = query, platform = opts.platform, scala_version = opts.scala_version })
    local circe = {
      groupId = "io.circe",
      name = "circe-core",
      latestVersion = "0.14.0",
      targets = { "jvm:3" },
      licenses = {},
      deprecated = false,
      dependents = 0,
    }
    callback(nil, { { title = "circe", key = "k", packages = { circe }, moduleCount = 1, dependents = 0 } }, {
      results = {},
      total = 1,
      facets = facets,
      related = false,
    })
  end
  local shown = answer({ "Change filters", "Scala Native", "Scala 2.13" })
  ui.pick({ query = "json" })
  eq(searches, {
    { query = "json", platform = "", scala_version = "" },
    { query = "json", platform = "native", scala_version = "2.13" },
  })
  eq(shown[1][1], "Change filters (any platform, any Scala version)…")
  eq(shown[4][1], "Change filters (Scala Native, Scala 2.13)…")
end

T["use_snacks"] = MiniTest.new_set()

T["use_snacks"]["auto: only when the snacks picker is enabled"] = function()
  eq(ui.use_snacks(), false)
  package.loaded.snacks = { config = { picker = { enabled = false } } }
  eq(ui.use_snacks(), false)
  package.loaded.snacks = { config = { picker = { enabled = true } } }
  eq(ui.use_snacks(), true)
end

T["use_snacks"]["select never uses snacks"] = function()
  package.loaded.snacks = { config = { picker = { enabled = true } } }
  config.setup({ picker = "select" })
  eq(ui.use_snacks(), false)
end

T["use_snacks"]["snacks without snacks.nvim falls back and says so"] = function()
  config.setup({ picker = "snacks" })
  eq(ui.use_snacks(), false)
  eq(notified, { 'picker is "snacks" but snacks.nvim is not installed; using vim.ui.select' })
  package.loaded.snacks = { config = {} }
  eq(ui.use_snacks(), true)
end

T["pick hands over to snacks"] = function()
  local got
  package.loaded.snacks = { config = { picker = { enabled = true } } }
  package.loaded["scaladex.snacks"] = {
    pick = function(opts)
      got = opts
    end,
  }
  ui.pick({ query = "cats" })
  eq(got, { query = "cats" })
end

return T
