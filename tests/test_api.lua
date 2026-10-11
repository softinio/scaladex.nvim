---@diagnostic disable: duplicate-set-field
local api = require("scaladex.api")
local config = require("scaladex.config")
local http = require("scaladex.http")
local eq = MiniTest.expect.equality

local requested
local real_get = http.get

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      requested = {}
      http.get = function(url, _, callback)
        table.insert(requested, url)
        local body = { results = { { title = "cats" } } }
        if callback then
          vim.schedule(function()
            callback(nil, body)
          end)
          return nil, nil
        end
        return body, nil
      end
    end,
    post_case = function()
      http.get = real_get
      config.setup()
    end,
  },
})

T["search_params"] = function()
  eq(api.search_params(" cats ", { platform = "JS", scala_version = "3", page = 2 }), {
    { "q", "cats" },
    { "platform", "js" },
    { "scala", "3" },
    { "page", "2" },
  })
  eq(api.search_params("cats", {}), { { "q", "cats" } })
  local params, err = api.search_params("cats", { platform = "android" })
  eq(params, nil)
  eq(err, "unknown platform android, expected one of jvm, js, native, sbt, mill")
end

T["search blocks without a callback"] = function()
  eq(api.search("cats"), { { title = "cats" } })
  eq(requested, { "https://pkg.scalanews.net/api/v1/search?q=cats" })
end

T["search uses configured filters"] = function()
  config.setup({ platform = "jvm", scala_version = "3" })
  api.search("cats")
  api.search("cats", { scala_version = "2.13" })
  eq(requested, {
    "https://pkg.scalanews.net/api/v1/search?q=cats&platform=jvm&scala=3",
    "https://pkg.scalanews.net/api/v1/search?q=cats&platform=jvm&scala=2.13",
  })
end

T["search calls back"] = function()
  local got
  api.search("cats", nil, function(err, results)
    got = { err = err, results = results }
  end)
  vim.wait(1000, function()
    return got ~= nil
  end)
  eq(got, { results = { { title = "cats" } } })
end

T["empty search makes no request"] = function()
  eq(api.search("   "), {})
  eq(requested, {})
end

T["bad filter is an error, not a request"] = function()
  local results, err = api.search("cats", { platform = "android" })
  eq(results, nil)
  eq(err ~= nil, true)
  eq(requested, {})
end

T["get_package"] = function()
  api.get_package("org.typelevel", "cats-core")
  eq(requested, { "https://pkg.scalanews.net/api/v1/packages/org.typelevel/cats-core" })
end

T["package_url follows base_url"] = function()
  config.setup({ base_url = "http://localhost:8080" })
  eq(api.package_url("org.typelevel", "cats-core"), "http://localhost:8080/p/org.typelevel/cats-core")
end

return T
