# scaladex.nvim

This [neovim](https://neovim.io/) plugin serves two purposes:

- It provides a library that you can `require` and query the [scaladex index](https://index.scala-lang.org)
- A [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension that allows you to search the [scaladex index](https://index.scala-lang.org) and add a dependency to your project or look at the dependencies page on scaladex.

## Requirements

- Neovim 0.5+ 
- [Plenary](https://github.com/nvim-lua/plenary.nvim)
- [Telescope](https://github.com/nvim-telescope) (optional if you want to use as a Telescope extension)

## Supports

- [SBT](https://www.scala-sbt.org/)
- [Mill](https://github.com/com-lihaoyi/mill)
- [Ammonite](https://ammonite.io/)

## Installation

Using [packer](https://github.com/wbthomason/packer.nvim):

Add the following to your `init.lua`:

```
use { 'nvim-telescope/telescope.nvim', requires = { { 'nvim-lua/popup.nvim' }, { 'nvim-lua/plenary.nvim' } } }
use { 'softinio/telescope-scaladex.nvim' }
```

Require the extension:

```
require'telescope'.load_extension'scaladex`
```

Add a mapping to open search box:

```
vim.api.nvim_set_keymap('n', '<leader>si', [[<cmd>lua require('scaladex').search()<cr>]], { noremap = true, silent = true })
```

## Usage

### Telescope

1. Open search (if above mapping set that would be your `<leader>` key and `si`)
2. Enter package you are searching for and press enter, e.g. `cats`
3. From the results panel select the one you are interested in, then:

| Keyboard | What it does |
| <C-s> | Opens the browser, scaladex page for the package you selected |
| <C-R> (enter) | Copies to your clipboard what you need to add to your build file to add dependency to your project |

### Use as a Library

#### To import library

```
local scaladex = require'scaladex'
```

#### Functions available

- `search(search_term, targeted_platform, scala_version)` : searches scaladex for the term you want to search for. 
  - `targeted_platform` defaults to "JVM" and `scala_version` defaults to `2.13` when not provided with function call. 
	- Returns a list of possible projects matching your `search_term`
- `get_project(organization, repository)` - returns all details of a specific project from scaladex 
  - `organization` is the github organization
	- `repository` is the project/repository name within the organization

#### Examples

##### Search

```
-- search for 'cats' 
scaladex.search('cats')
```

##### Get Project

```
-- get details of 'cats' library
scaladex.get_project('typelevel', 'cats')
```

## Demo and screenshots

TBA

## Support and Help

Have a question or want to discuss anything related to this project? [Start a Discussion](https://github.com/softinio/scaladex.nvim/discussions)

Have a problem, a bug or a feature request? Make [an issue](https://github.com/softinio/scaladex.nvim/issues) or [PR welcome](https://github.com/softinio/scaladex.nvim/pulls)

## Development

```
git clone git@github.com:softinio/scaladex.nvim.git
cd scaladex.nvim
nvim --cmd "set rtp+=$(pwd)"
```

## To Do

- [ ] make rest calls async using plenary
- [ ] add support for `scala-cli`
- [ ] add support for `maven` and `gradle`
- [ ] cache search history and add telescope option to browse history
- [ ] add ability to choose platform
- [ ] add ability to choose older versions of a library

