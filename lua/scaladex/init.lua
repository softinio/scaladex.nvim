-- scaladex.nvim: search pkg.scalanews.net for Scala libraries and add them to
-- your build.

local M = {}

--- Optional; only needed to change the defaults.
---@param opts? scaladex.UserConfig
M.setup = function(opts)
  require("scaladex.config").setup(opts)
end

--- Searches pkg.scalanews.net. With a callback the request runs in the
--- background; without one it blocks and returns the results.
---@param query string
---@param opts? scaladex.SearchOpts
---@param callback? fun(err: string?, results: scaladex.SearchHit[]?)
---@return scaladex.SearchHit[]? results
---@return string? err
M.search = function(query, opts, callback)
  return require("scaladex.api").search(query, opts, callback)
end

--- Gets one package by groupId and name (without its Scala suffix).
---@param group_id string
---@param name string
---@param callback? fun(err: string?, details: scaladex.PackageDetails?)
---@return scaladex.PackageDetails? details
---@return string? err
M.get_package = function(group_id, name, callback)
  return require("scaladex.api").get_package(group_id, name, callback)
end

--- The pkg.scalanews.net page of a package.
---@param group_id string
---@param name string
---@return string
M.package_url = function(group_id, name)
  return require("scaladex.api").package_url(group_id, name)
end

--- The line that adds a package to the build of a buffer (default: current).
---@param pkg scaladex.Package
---@param buf? integer
---@return string
M.dependency = function(pkg, buf)
  local build = require("scaladex.build")
  return build.dependency(pkg, build.detect(buf))
end

--- Search, pick a project and a module, then copy, insert or open it.
---@param opts? scaladex.PickOpts
M.pick = function(opts)
  require("scaladex.ui").pick(opts)
end

return M
