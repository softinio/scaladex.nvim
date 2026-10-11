.PHONY: test lint format typecheck check deps

deps:
	@mkdir -p deps
	@test -d deps/mini.nvim || git clone --quiet --depth 1 https://github.com/nvim-mini/mini.nvim deps/mini.nvim
	@test -d deps/telescope.nvim || git clone --quiet --depth 1 https://github.com/nvim-telescope/telescope.nvim deps/telescope.nvim
	@test -d deps/plenary.nvim || git clone --quiet --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

lint:
	luacheck lua plugin tests
	stylua --check lua plugin tests

format:
	stylua lua plugin tests

typecheck: deps
	scripts/typecheck

check: lint typecheck test
