local build = require("scaladex.build")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

---@return scaladex.Package
local function pkg(targets, name)
  return {
    groupId = "org.typelevel",
    name = name or "cats-core",
    latestVersion = "2.13.0",
    targets = targets,
    licenses = {},
    deprecated = false,
    dependents = 0,
  }
end

local jvm = pkg({ "jvm:3", "jvm:2.13", "sjs1:3" })
local js_only = pkg({ "sjs1:3", "native0.5:3" })

T["dependency"] = MiniTest.new_set()

T["dependency"]["sbt"] = function()
  eq(build.dependency(jvm, { tool = "sbt" }), '"org.typelevel" %% "cats-core" % "2.13.0"')
  eq(build.dependency(js_only, { tool = "sbt" }), '"org.typelevel" %%% "cats-core" % "2.13.0"')
end

T["dependency"]["mill"] = function()
  eq(build.dependency(jvm, { tool = "mill" }), 'mvn"org.typelevel::cats-core:2.13.0"')
  eq(build.dependency(js_only, { tool = "mill" }), 'mvn"org.typelevel::cats-core::2.13.0"')
  eq(build.dependency(jvm, { tool = "mill", legacy_mill = true }), 'ivy"org.typelevel::cats-core:2.13.0"')
end

T["dependency"]["scala-cli"] = function()
  eq(build.dependency(jvm, { tool = "scala-cli" }), "//> using dep org.typelevel::cats-core:2.13.0")
  eq(build.dependency(js_only, { tool = "scala-cli" }), "//> using dep org.typelevel::cats-core::2.13.0")
end

T["dependency"]["sbt plugin, whatever the build"] = function()
  local plugin = pkg({ "sbt1.0:2.12" }, "sbt-ci-release")
  for _, tool in ipairs({ "sbt", "mill", "scala-cli" }) do
    eq(build.dependency(plugin, { tool = tool }), 'addSbtPlugin("org.typelevel" % "sbt-ci-release" % "2.13.0")')
  end
end

T["dependency"]["mill plugin"] = function()
  local plugin = pkg({ "mill1:3" }, "mill-plugin")
  eq(build.dependency(plugin, { tool = "mill" }), "//| mvnDeps:\n//| - org.typelevel::mill-plugin::2.13.0")
  eq(
    build.dependency(plugin, { tool = "mill", legacy_mill = true }),
    "import $ivy.`org.typelevel::mill-plugin::2.13.0`"
  )
end

T["detect"] = MiniTest.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

--- A temporary project with the given files, and a buffer editing a source
--- file inside it.
---@param files table<string, string[]>
---@return string root
---@return integer buf
local function project(files)
  local root = vim.fs.normalize(vim.fn.resolve(vim.fn.tempname()))
  vim.fn.mkdir(root .. "/src", "p")
  for path, lines in pairs(files) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. path), "p")
    vim.fn.writefile(lines, root .. "/" .. path)
  end
  vim.cmd.edit(root .. "/src/Main.scala")
  return root, vim.api.nvim_get_current_buf()
end

T["detect"]["sbt"] = function()
  local root, buf = project({ ["build.sbt"] = {} })
  eq(build.detect(buf), { tool = "sbt", root = root })
end

T["detect"]["Mill 1 by default"] = function()
  local root, buf = project({ ["build.mill"] = {} })
  eq(build.detect(buf), { tool = "mill", root = root, legacy_mill = false })
end

T["detect"]["Mill 0.x from .mill-version"] = function()
  local _, buf = project({ ["build.mill"] = {}, [".mill-version"] = { "0.12.10" } })
  eq(build.detect(buf).legacy_mill, true)
end

T["detect"]["Mill version from the build.mill header"] = function()
  local _, buf = project({ ["build.mill"] = { "//| mill-version: 1.0.6", "package build" } })
  eq(build.detect(buf).legacy_mill, false)
  local _, old = project({ ["build.mill"] = { "//| mill-version: 0.12.14" } })
  eq(build.detect(old).legacy_mill, true)
end

T["detect"]["build.sc is legacy Mill"] = function()
  local root, buf = project({ ["build.sc"] = {} })
  eq(build.detect(buf), { tool = "mill", root = root, legacy_mill = true })
end

T["detect"]["scala-cli project"] = function()
  local root, buf = project({ ["project.scala"] = {} })
  eq(build.detect(buf), { tool = "scala-cli", root = root })
end

T["detect"]["using directives win over the build"] = function()
  local _, buf = project({ ["build.sbt"] = {} })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "//> using scala 3", "@main def run = ()" })
  eq(build.detect(buf).tool, "scala-cli")
end

T["detect"]["nearest build wins"] = function()
  local root, buf = project({ ["build.sbt"] = {}, ["src/project.scala"] = {} })
  eq(build.detect(buf), { tool = "scala-cli", root = root .. "/src" })
end

T["detect"]["no build is scala-cli"] = function()
  local _, buf = project({})
  eq(build.detect(buf), { tool = "scala-cli" })
end

T["detect"]["sbt filetype"] = function()
  local _, buf = project({})
  vim.bo[buf].filetype = "sbt"
  eq(build.detect(buf).tool, "sbt")
end

T["has_target"] = function()
  eq(build.has_target(jvm, "jvm"), true)
  eq(build.has_target(js_only, "jvm"), false)
  eq(build.has_target(js_only, "native"), true)
end

return T
