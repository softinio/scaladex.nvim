-- How projects and modules are shown in pickers and previews.

local M = {}

local platform_labels = {
  jvm = "JVM",
  sjs = "Scala.js",
  native = "Scala Native",
  sbt = "sbt plugin",
  mill = "Mill plugin",
}

-- the API's platform filter values
local facet_labels = {
  jvm = "JVM",
  js = "Scala.js",
  native = "Scala Native",
  sbt = "sbt plugins",
  mill = "Mill plugins",
}

---@param platform string a platform filter value, e.g. js
---@return string
M.platform = function(platform)
  return facet_labels[platform] or platform
end

--- The filters a search uses, e.g. `Scala.js, Scala 3` or `any platform, any
--- Scala version`. "" or nil means any.
---@param filters { platform?: string, scala_version?: string }
---@return string
M.filters = function(filters)
  local platform = filters.platform or ""
  local scala = filters.scala_version or ""
  return (platform ~= "" and M.platform(platform) or "any platform")
    .. ", "
    .. (scala ~= "" and ("Scala " .. scala) or "any Scala version")
end

--- Groups target keys (jvm:3, sjs1:2.13, …) by platform, e.g.
--- `JVM: 3, 2.13` and `Scala.js 1: 3, 2.13`, in the order they first appear.
---@param targets string[]
---@return string[]
M.targets = function(targets)
  local order, versions = {}, {}
  for _, target in ipairs(targets or {}) do
    local platform, scala = target:match("^([^:]+):(.+)$")
    if platform ~= nil then
      local kind, version = platform:match("^(%a+)(.*)$")
      local label = (platform_labels[kind] or kind) .. (version ~= "" and " " .. version or "")
      if versions[label] == nil then
        versions[label] = {}
        table.insert(order, label)
      end
      table.insert(versions[label], scala)
    end
  end
  return vim.tbl_map(function(label)
    return label .. ": " .. table.concat(versions[label], ", ")
  end, order)
end

--- The one line about a project: its generated summary, else its description.
---@param project? scaladex.ProjectInfo
---@return string?
M.blurb = function(project)
  if project == nil then
    return nil
  end
  return project.summary or project.description
end

---@param hit scaladex.SearchHit
---@return string
M.hit = function(hit)
  local line = hit.title .. " (" .. hit.packages[1].groupId .. ")"
  local blurb = M.blurb(hit.packages[1].project)
  if blurb ~= nil then
    line = line .. " - " .. blurb
  end
  return line
end

---@param pkg scaladex.Package
---@return string
M.package = function(pkg)
  local line = pkg.name .. " " .. pkg.latestVersion
  if pkg.deprecated then
    line = line .. " (deprecated)"
  end
  return line
end

---@param iso? string
---@return string?
local function date(iso)
  return iso and iso:sub(1, 10) or nil
end

---@param lines string[]
---@param label string
---@param value any
local function field(lines, label, value)
  if value ~= nil and value ~= "" then
    table.insert(lines, label .. ": " .. tostring(value))
  end
end

---@param lines string[]
---@param project? scaladex.ProjectInfo
local function project_lines(lines, project)
  if project == nil then
    return
  end
  if project.description ~= nil then
    table.insert(lines, project.description)
  end
  if project.summary ~= nil and project.summary ~= project.description then
    table.insert(lines, project.summary)
  end
  table.insert(lines, "")
  field(lines, "Source", "https://" .. project.id)
  field(lines, "Homepage", project.homepage)
  field(lines, "Stars", project.stars)
  field(lines, "License", project.license)
  if project.topics ~= nil and #project.topics > 0 then
    field(lines, "Topics", table.concat(project.topics, ", "))
  end
end

--- Preview of a search result: the project and the modules it lists.
---@param hit scaladex.SearchHit
---@return string[]
M.hit_preview = function(hit)
  local primary = hit.packages[1]
  local lines = { "# " .. hit.title, "" }
  project_lines(lines, primary.project)
  field(lines, "Group", primary.groupId)
  field(lines, "Latest release", date(hit.latestReleaseAt))
  field(lines, "Used by", hit.dependents > 0 and (hit.dependents .. " indexed projects") or nil)
  table.insert(lines, "")
  local shown = #hit.packages
  table.insert(
    lines,
    "## Modules" .. (hit.moduleCount > shown and (" (" .. shown .. " of " .. hit.moduleCount .. ")") or "")
  )
  for _, pkg in ipairs(hit.packages) do
    table.insert(lines, "- " .. M.package(pkg))
  end
  return lines
end

--- Preview of a module, ending with the line that adds it to the build.
---@param pkg scaladex.Package
---@param dependency string
---@return string[]
M.package_preview = function(pkg, dependency)
  local lines = { "# " .. pkg.groupId .. ":" .. pkg.name .. " " .. pkg.latestVersion, "" }
  if pkg.deprecated then
    table.insert(lines, "Deprecated")
    table.insert(lines, "")
  end
  field(lines, "Released", date(pkg.latestReleaseAt))
  field(lines, "Licenses", #pkg.licenses > 0 and table.concat(pkg.licenses, ", ") or nil)
  field(lines, "Used by", pkg.dependents > 0 and (pkg.dependents .. " indexed projects") or nil)
  table.insert(lines, "")
  table.insert(lines, "## Targets")
  for _, line in ipairs(M.targets(pkg.targets)) do
    table.insert(lines, "- " .. line)
  end
  table.insert(lines, "")
  table.insert(lines, "## Add to your build")
  table.insert(lines, "```")
  vim.list_extend(lines, vim.split(dependency, "\n"))
  table.insert(lines, "```")
  return lines
end

return M
