local scan = require("plenary.scandir")

local M = {}

local function contains(list, text)
  for _, v in pairs(list) do
    if v == text then
      return true
    end
  end
  return false
end

M.create_dependency_string = function(artifact, selected_artifact)
  print(vim.inspect(selected_artifact))
  local project_root = scan.scan_dir(".")
  local is_sbt = contains(project_root, "build.sbt")
  local is_mill = contains(project_root, "build.sc")
  local current_filetype = vim.bo.filetype
  if current_filetype == "sbt" or (current_filetype == "scala" and is_sbt == true) then
    local result = '"' .. artifact["groupId"] .. '" %% "' .. selected_artifact .. '" % "' .. artifact["version"] .. '"'
    return result
  elseif is_mill == true then
    local result = 'ivy"' .. artifact["groupId"] .. "::" .. selected_artifact .. ":" .. artifact["version"] .. '"'
    return result
  else
    local result = "import $ivy.`"
      .. artifact["groupId"]
      .. "::"
      .. selected_artifact
      .. ":"
      .. artifact["version"]
      .. "`"
    return result
  end
end

M.copy_to_clipboard = function(dependency_string)
  local register = vim.o.clipboard == "unnamedplus" and "+" or '"'
  vim.fn.setreg(register, dependency_string)
end

M.open_browser = function(artifact_url)
  local browser_cmd
  if vim.fn.has("unix") == 1 then
    browser_cmd = "xdg-open"
  end
  if vim.fn.has("mac") == 1 then
    browser_cmd = "open"
  end
  if vim.fn.has("win32") == 1 then
    browser_cmd = "start"
  end
  vim.cmd(":silent !" .. browser_cmd .. " " .. vim.fn.fnameescape(artifact_url))
end

return M
