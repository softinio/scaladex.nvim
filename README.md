[![CI](https://github.com/softinio/scaladex.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/softinio/scaladex.nvim/actions/workflows/ci.yml)

# scaladex.nvim

Search [Scala Packages](https://pkg.scalanews.net), the search index of every Scala library on Maven Central, from [Neovim](https://neovim.io/) and add the library you pick to your build, or open its page on pkg.scalanews.net. It also provides a Lua library you can `require` to query the index yourself.

Data comes from the [pkg.scalanews.net JSON API](https://pkg.scalanews.net/about) (`/api/v1`). Search finds libraries by what they do, not just by name, so a search like `parse markdown` works too.

## Features

- Search by what a library does, not just its name, e.g. `json parsing` or `http4s server`
- Copies the dependency line for your build, inserts it below the cursor, or opens the package page
- Works out the build from the file you are editing: sbt, Mill 1.x and 0.x, and scala-cli
- Requests run in the background and never block the editor
- Uses `vim.ui.select`, so it works with whichever picker you have set up (Telescope, fzf-lua, snacks.nvim, …), plus a Telescope extension with previews

## Requirements

- Neovim 0.10+
- `curl`
- [Telescope](https://github.com/nvim-telescope/telescope.nvim) (optional)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "softinio/scaladex.nvim",
  cmd = "Scaladex",
  keys = {
    { "<leader>si", "<cmd>Scaladex<cr>", desc = "Search Scala packages" },
  },
  -- optional, only to change the defaults
  opts = {},
}
```

Using Neovim's built-in package manager (0.12+):

```lua
vim.pack.add({ "https://github.com/softinio/scaladex.nvim" })
vim.keymap.set("n", "<leader>si", "<cmd>Scaladex<cr>", { desc = "Search Scala packages" })
```

## Usage

1. Run `:Scaladex` (or `:Scaladex cats` to skip the prompt)
2. Enter what you are looking for, e.g. `cats` or `json parsing`
3. Pick a project
4. Pick a module (skipped when the project has only one)

The dependency line is then copied to your clipboard. `:Scaladex!` opens the package page on pkg.scalanews.net instead.

The line matches the build of the file you are editing:

| Build | Line |
| ----- | ---- |
| sbt (`build.sbt`) | `"org.typelevel" %% "cats-core" % "2.13.0"` |
| Mill 1.x (`build.mill`) | `mvn"org.typelevel::cats-core:2.13.0"` |
| Mill 0.x (`build.sc`, or `build.mill` pinned to 0.x) | `ivy"org.typelevel::cats-core:2.13.0"` |
| scala-cli (`//> using` directives, `project.scala`, or no build) | `//> using dep org.typelevel::cats-core:2.13.0` |

Libraries published only for Scala.js or Scala Native get `%%%` (sbt) or `::` before the version (Mill, scala-cli). sbt plugins get `addSbtPlugin(...)`.

### Configuration

`setup` is optional. These are the defaults:

```lua
require("scaladex").setup({
  base_url = "https://pkg.scalanews.net",
  -- default search filters; nil does not filter
  platform = nil,      -- "jvm", "js", "native", "sbt" or "mill"
  scala_version = nil, -- e.g. "3" or "2.13"
  -- seconds before a request is abandoned
  timeout = 10,
  -- what choosing a module does: "copy", "insert" (below the cursor) or "open"
  action = "copy",
})
```

### Telescope

For pickers with previews of each project and module (including the exact line that will be added):

```lua
require("telescope").load_extension("scaladex")
```

Then run `:Telescope scaladex`, optionally with `query=http4s scala_version=3`.

| Keyboard | What it does |
| -------- | ------------ |
| `<CR>` | Projects: show its modules. Modules: copy (or insert/open, per `action`) |
| `<C-s>` | Open the package page on pkg.scalanews.net |
| `<C-y>` | Copy the dependency line |

### Health

`:checkhealth scaladex` checks for curl, that pkg.scalanews.net is reachable, and whether Telescope is available.

### Use as a Library

```lua
local scaladex = require("scaladex")
```

Functions that make a request run in the background when given a callback, called as `callback(err, value)` on the main loop. Without one they block and return `value, err`.

- `search(query, opts, callback)`: searches pkg.scalanews.net.
  - `opts.platform` is one of `jvm`, `js`, `native`, `sbt` or `mill`, `opts.scala_version` a Scala binary version such as `3` or `2.13`, and `opts.page` a 1-based page. All optional.
  - Returns a list of matching projects, each with `title`, `key` and `packages`, the project's modules (`groupId`, `name`, `latestVersion`, `targets`, `project`, ...)
- `get_package(group_id, name, callback)`: the details of one package: its `summary` and `install` snippets for sbt, Mill and scala-cli
  - `group_id` is the Maven groupId, e.g. `org.typelevel`
  - `name` is the artifact name without its Scala suffix, e.g. `cats-core`
- `package_url(group_id, name)`: the pkg.scalanews.net page of a package
- `dependency(package, buf)`: the line that adds one of a search result's `packages` to the build of a buffer

```lua
-- blocking
local results, err = scaladex.search("cats")

-- in the background, Scala 3 libraries for Scala.js
scaladex.search("json", { platform = "js", scala_version = "3" }, function(err, results)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  vim.print(vim.tbl_map(function(r) return r.title end, results))
end)

scaladex.get_package("org.typelevel", "cats-core")
```

See `:help scaladex` for the full documentation.

## Demo and Video Tutorial on using `scaladex.nvim`

[Using scaladex.nvim](https://watch.softinio.com/w/44bD8ASpSkzmKifDBNMBkr)

## Support and Help

Have a question or want to discuss anything related to this project? [Start a Discussion](https://github.com/softinio/scaladex.nvim/discussions)

Have a problem, a bug or a feature request? Make [an issue](https://github.com/softinio/scaladex.nvim/issues) or [PR welcome](https://github.com/softinio/scaladex.nvim/pulls)

## Development

```
git clone git@github.com:softinio/scaladex.nvim.git
cd scaladex.nvim
nvim --cmd "set rtp+=$(pwd)"
```

| Command | What it does |
| ------- | ------------ |
| `make test` | Runs the tests with [mini.test](https://github.com/nvim-mini/mini.nvim) (cloned into `deps/`) |
| `make lint` | luacheck and StyLua |
| `make format` | Formats with StyLua |
| `make typecheck` | Type-checks with lua-language-server |
| `make check` | All of the above |

## To Do

- [ ] add support for `maven` and `gradle`
- [ ] cache search history and add telescope option to browse history
- [ ] add ability to choose platform and Scala version from the pickers
- [ ] add ability to choose older versions of a library

