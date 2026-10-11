local format = require("scaladex.format")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

---@type scaladex.Package
local cats = {
  groupId = "org.typelevel",
  name = "cats-core",
  latestVersion = "2.13.0",
  latestReleaseAt = "2025-01-02T03:04:05Z",
  targets = { "jvm:3", "jvm:2.13", "sjs1:3", "native0.5:3" },
  licenses = { "MIT" },
  deprecated = false,
  dependents = 12,
  project = {
    id = "github.com/typelevel/cats",
    description = "Lightweight, modular, and extensible library for functional programming.",
    summary = "Type classes for functional programming.",
    stars = 5000,
    topics = { "fp" },
  },
}

T["targets grouped by platform"] = function()
  eq(format.targets(cats.targets), { "JVM: 3, 2.13", "Scala.js 1: 3", "Scala Native 0.5: 3" })
  eq(format.targets({ "sbt1.0:2.12", "mill1:3" }), { "sbt plugin 1.0: 2.12", "Mill plugin 1: 3" })
end

T["hit line prefers the summary"] = function()
  local hit =
    { key = "github.com/typelevel/cats", title = "cats", packages = { cats }, moduleCount = 1, dependents = 0 }
  eq(format.hit(hit), "cats (org.typelevel) - Type classes for functional programming.")
  local bare = vim.deepcopy(cats)
  bare.project = nil
  eq(
    format.hit({
      key = "github.com/typelevel/cats",
      title = "cats",
      packages = { bare },
      moduleCount = 1,
      dependents = 0,
    }),
    "cats (org.typelevel)"
  )
end

T["filters"] = function()
  eq(format.filters({}), "any platform, any Scala version")
  eq(format.filters({ platform = "js", scala_version = "3" }), "Scala.js, Scala 3")
  eq(format.filters({ platform = "", scala_version = "2.13" }), "any platform, Scala 2.13")
end

T["package line"] = function()
  eq(format.package(cats), "cats-core 2.13.0")
  eq(format.package(vim.tbl_extend("force", cats, { deprecated = true })), "cats-core 2.13.0 (deprecated)")
end

T["hit preview counts hidden modules"] = function()
  local lines = format.hit_preview({
    key = "github.com/typelevel/cats",
    title = "cats",
    packages = { cats },
    moduleCount = 7,
    dependents = 3,
  })
  eq(vim.tbl_contains(lines, "## Modules (1 of 7)"), true)
  eq(vim.tbl_contains(lines, "Source: https://github.com/typelevel/cats"), true)
  eq(vim.tbl_contains(lines, "Used by: 3 indexed projects"), true)
end

T["package preview ends with the dependency"] = function()
  local lines = format.package_preview(cats, "//| mvnDeps:\n//| - a::b::1")
  eq(vim.list_slice(lines, #lines - 3), { "```", "//| mvnDeps:", "//| - a::b::1", "```" })
  eq(vim.tbl_contains(lines, "Released: 2025-01-02"), true)
end

return T
