-- Works out the build tool a buffer belongs to and the line that adds a package
-- to it.

---@alias scaladex.BuildTool "sbt" | "mill" | "scala-cli"

---@class scaladex.Build
---@field tool scaladex.BuildTool
---@field root? string the directory holding the build definition
---@field legacy_mill? boolean Mill 0.x (build.sc or a 0.x version), which uses ivy"..."

local M = {}

-- Mill 1 builds are build.mill or build.mill.scala
local mill_builds = { "build.mill", "build.mill.scala" }

M.markers = { "build.sbt", "build.mill", "build.mill.scala", "build.sc", "project.scala", ".scala-build" }

-- scala-cli directives are only read from the top of a file
local directive_lines = 50

---@param path string
---@return string?
local function first_line(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 1)
  if ok and lines[1] ~= nil then
    return vim.trim(lines[1])
  end
  return nil
end

--- The Mill version a build pins, from .mill-version, .config/mill-version or
--- the `//| mill-version:` header of build.mill or build.mill.scala.
---@param root string
---@return string?
M.mill_version = function(root)
  for _, file in ipairs({ ".mill-version", ".config/mill-version" }) do
    local version = first_line(vim.fs.joinpath(root, file))
    if version ~= nil and version ~= "" then
      return version
    end
  end
  for _, build in ipairs(mill_builds) do
    local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(root, build), "", directive_lines)
    if ok then
      for _, line in ipairs(lines) do
        local version = line:match("^//|%s*mill%-version:%s*(%S+)")
        if version ~= nil then
          return version
        end
      end
    end
  end
  return nil
end

---@param buf integer
---@return boolean
local function has_using_directives(buf)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, directive_lines, false)) do
    if line:match("^%s*//>%s*using%s") then
      return true
    end
  end
  return false
end

---@param path string
---@return boolean
local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

--- The build tool for a buffer: scala-cli if the buffer has `//> using`
--- directives, else whichever build definition is nearest above it, else
--- scala-cli.
---@param source? integer buffer, defaults to the current one
---@return scaladex.Build
M.detect = function(source)
  local buf = (source == nil or source == 0) and vim.api.nvim_get_current_buf() or source --[[@as integer]]
  if vim.bo[buf].filetype == "sbt" then
    local name = vim.api.nvim_buf_get_name(buf)
    return { tool = "sbt", root = name ~= "" and vim.fs.dirname(name) or nil }
  end
  if has_using_directives(buf) then
    return { tool = "scala-cli" }
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local start = (name ~= "" and vim.bo[buf].buftype == "") and vim.fs.dirname(name) or vim.uv.cwd()
  -- vim.fs.root treats a list of markers as an order of preference; find checks
  -- each directory for all of them, so the nearest build wins
  local found = vim.fs.find(M.markers, { upward = true, path = start, limit = 1 })[1]
  if found == nil then
    return { tool = "scala-cli" }
  end
  local root = vim.fs.dirname(found)
  if exists(vim.fs.joinpath(root, "build.sbt")) then
    return { tool = "sbt", root = root }
  elseif vim.iter(mill_builds):any(function(build)
    return exists(vim.fs.joinpath(root, build))
  end) then
    local version = M.mill_version(root)
    return { tool = "mill", root = root, legacy_mill = version ~= nil and vim.startswith(version, "0.") }
  elseif exists(vim.fs.joinpath(root, "build.sc")) then
    return { tool = "mill", root = root, legacy_mill = true }
  end
  return { tool = "scala-cli", root = root }
end

--- Whether any of a package's targets is on a platform, by key prefix: jvm,
--- sjs, native, sbt or mill.
---@param pkg scaladex.Package
---@param prefix string
---@return boolean
M.has_target = function(pkg, prefix)
  for _, target in ipairs(pkg.targets or {}) do
    if vim.startswith(target, prefix) then
      return true
    end
  end
  return false
end

--- The line(s) that add a package to a build. A library published only for
--- Scala.js or Scala Native gets the cross-platform form (%%% or ::).
---@param pkg scaladex.Package
---@param build scaladex.Build
---@return string
M.dependency = function(pkg, build)
  local g, n, v = pkg.groupId, pkg.name, pkg.latestVersion

  if M.has_target(pkg, "sbt") then
    return 'addSbtPlugin("' .. g .. '" % "' .. n .. '" % "' .. v .. '")'
  end
  if M.has_target(pkg, "mill") then
    local coordinates = g .. "::" .. n .. "::" .. v
    if build.legacy_mill then
      return "import $ivy.`" .. coordinates .. "`"
    end
    return "//| mvnDeps:\n//| - " .. coordinates
  end

  local cross = not M.has_target(pkg, "jvm")
  local coordinates = g .. "::" .. n .. (cross and "::" or ":") .. v
  if build.tool == "sbt" then
    return '"' .. g .. '" ' .. (cross and "%%%" or "%%") .. ' "' .. n .. '" % "' .. v .. '"'
  elseif build.tool == "mill" then
    return (build.legacy_mill and "ivy" or "mvn") .. '"' .. coordinates .. '"'
  end
  return "//> using dep " .. coordinates
end

return M
