-- Client for the pkg.scalanews.net JSON API (/api/v1).

local config = require("scaladex.config")
local http = require("scaladex.http")

---@class scaladex.ProjectInfo
---@field id string deps.dev project key, e.g. github.com/typelevel/cats
---@field description? string
---@field summary? string one-line generated summary
---@field stars? integer
---@field forks? integer
---@field openIssues? integer
---@field license? string
---@field homepage? string
---@field scorecard? number OpenSSF Scorecard score, 0 to 10
---@field topics string[]

---@class scaladex.Package
---@field groupId string
---@field name string artifact name without its Scala suffix, e.g. cats-core
---@field latestVersion string
---@field latestReleaseAt? string ISO-8601
---@field targets string[] e.g. jvm:3, sjs1:2.13, native0.5:3, sbt1.0:2.12
---@field licenses string[]
---@field deprecated boolean
---@field project? scaladex.ProjectInfo
---@field dependents integer other indexed projects that depend on it

---@class scaladex.SearchHit
---@field key string project id, or maven:<groupId>
---@field title string
---@field latestReleaseAt? string
---@field packages scaladex.Package[] the modules worth showing for the query
---@field moduleCount integer every module that passes the filters
---@field dependents integer

---@class scaladex.Snippet
---@field tool string sbt, Mill or scala-cli
---@field code string

---@class scaladex.PackageDetails
---@field summary scaladex.Package
---@field install scaladex.Snippet[]

---@class scaladex.SearchOpts
---@field platform? string jvm, js, native, sbt or mill
---@field scala_version? string e.g. 3 or 2.13
---@field page? integer 1-based

local M = {}

M.platforms = { "jvm", "js", "native", "sbt", "mill" }

--- Query-string pairs for a search, or an error message for a bad filter.
---@param query string
---@param opts scaladex.SearchOpts
---@return [string, string][]? params
---@return string? err
M.search_params = function(query, opts)
  local params = { { "q", vim.trim(query) } }
  local platform = opts.platform and vim.trim(opts.platform):lower() or ""
  if platform ~= "" then
    if not vim.tbl_contains(M.platforms, platform) then
      return nil, "unknown platform " .. opts.platform .. ", expected one of " .. table.concat(M.platforms, ", ")
    end
    table.insert(params, { "platform", platform })
  end
  local scala = opts.scala_version and vim.trim(opts.scala_version) or ""
  if scala ~= "" then
    table.insert(params, { "scala", scala })
  end
  if opts.page ~= nil and opts.page > 1 then
    table.insert(params, { "page", tostring(opts.page) })
  end
  return params, nil
end

--- Calls back with `err` or `value`, or returns them when there is no callback.
---@generic T
---@param callback? fun(err: string?, value: T?)
---@param err string?
---@param value T?
---@return T? value
---@return string? err
local function finish(callback, err, value)
  if callback then
    vim.schedule(function()
      callback(err, value)
    end)
    return nil, nil
  end
  return value, err
end

--- Searches pkg.scalanews.net. Filters left out of `opts` fall back to the
--- configured defaults, and leaving both out does not filter on them. Results are
--- projects, each with the modules worth showing for the query.
---
--- With a callback the request runs in the background; without one it blocks
--- and returns the results.
---@param query string
---@param opts? scaladex.SearchOpts
---@param callback? fun(err: string?, results: scaladex.SearchHit[]?)
---@return scaladex.SearchHit[]? results
---@return string? err
M.search = function(query, opts, callback)
  if query == nil or vim.trim(query) == "" then
    return finish(callback, nil, {})
  end
  local options = config.options
  opts = vim.tbl_extend("keep", opts or {}, { platform = options.platform, scala_version = options.scala_version })
  local params, perr = M.search_params(query, opts)
  if params == nil then
    return finish(callback, perr, nil)
  end
  local url = http.build_url(options.base_url, "/api/v1/search", params)

  ---@param err string?
  ---@param body table?
  ---@return scaladex.SearchHit[]
  local function results(err, body)
    return err == nil and body and body.results or {}
  end

  if callback then
    http.get(url, options.timeout, function(err, body)
      callback(err, results(err, body))
    end)
    return nil, nil
  end
  local body, err = http.get(url, options.timeout)
  return results(err, body), err
end

--- Gets one package: a groupId plus the artifact name without its Scala suffix,
--- e.g. org.typelevel / cats-core. Nil when there is no such package.
---@param group_id string
---@param name string
---@param callback? fun(err: string?, details: scaladex.PackageDetails?)
---@return scaladex.PackageDetails? details
---@return string? err
M.get_package = function(group_id, name, callback)
  if group_id == nil or name == nil then
    return finish(callback, "a groupId and a name are required", nil)
  end
  local path = "/api/v1/packages/" .. http.encode(vim.trim(group_id)) .. "/" .. http.encode(vim.trim(name))
  local url = http.build_url(config.options.base_url, path)
  if callback then
    http.get(url, config.options.timeout, callback)
    return nil, nil
  end
  return http.get(url, config.options.timeout)
end

--- The pkg.scalanews.net page of a package.
---@param group_id string
---@param name string
---@return string
M.package_url = function(group_id, name)
  return config.options.base_url .. "/p/" .. group_id .. "/" .. name
end

return M
