std = "luajit"
globals = { "vim" }
read_globals = { "MiniTest" }
exclude_files = { "deps/" }
max_line_length = 120

-- 212: unused argument (callbacks keep their full signatures)
ignore = { "212" }
