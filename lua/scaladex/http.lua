-- GET requests with curl, run through vim.system so they do not block the editor.

local M = {}

-- curl writes the status code on a line of its own after the body.
local status_marker = "\n__scaladex_status__:"

--- Percent-encodes everything but RFC 3986 unreserved characters, so `&`, `=`
--- and `/` in a value cannot break the URL.
---@param s string
---@return string
M.encode = function(s)
  return (s:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

---@param base_url string
---@param path string
---@param params? [string, string][] query-string pairs, in order
---@return string
M.build_url = function(base_url, path, params)
  local query = {}
  for _, p in ipairs(params or {}) do
    table.insert(query, p[1] .. "=" .. M.encode(p[2]))
  end
  local url = base_url .. path
  if #query > 0 then
    url = url .. "?" .. table.concat(query, "&")
  end
  return url
end

---@param url string
---@param timeout integer seconds
---@return string[]
M.command = function(url, timeout)
  return {
    "curl",
    "--silent",
    "--show-error",
    "--location",
    "--max-time",
    tostring(timeout),
    "--header",
    "Accept: application/json",
    "--user-agent",
    "scaladex.nvim",
    "--write-out",
    status_marker .. "%{http_code}",
    url,
  }
end

--- Turns a finished curl run into the decoded JSON body, nil for a 404, or an
--- error message.
---@param result vim.SystemCompleted
---@return any? body
---@return string? err
M.parse = function(result)
  if result.code ~= 0 then
    local reason = vim.trim(result.stderr or "")
    return nil, reason ~= "" and reason or ("curl exited with " .. result.code)
  end
  local stdout = result.stdout or ""
  local at = stdout:find(status_marker, 1, true)
  if at == nil then
    return nil, "unexpected response from curl"
  end
  local body = stdout:sub(1, at - 1)
  local status = tonumber(stdout:sub(at + #status_marker))
  if status == 404 then
    return nil, nil
  end
  local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true, array = true } })
  if status ~= 200 then
    if ok and type(decoded) == "table" and type(decoded.error) == "string" then
      return nil, decoded.error .. " (HTTP " .. status .. ")"
    end
    return nil, "HTTP " .. tostring(status)
  end
  if not ok then
    return nil, "invalid JSON in response"
  end
  return decoded, nil
end

--- GETs `url`. With a callback the request runs in the background and the
--- callback is called on the main loop; without one it blocks and returns.
---@param url string
---@param timeout integer seconds
---@param callback? fun(err: string?, body: any?)
---@return any? body
---@return string? err
M.get = function(url, timeout, callback)
  local cmd = M.command(url, timeout)
  local ok, process = pcall(vim.system, cmd, { text = true }, callback and function(result)
    local body, err = M.parse(result)
    vim.schedule(function()
      callback(err, body)
    end)
  end)
  if not ok then
    -- curl is missing
    local err = tostring(process)
    if callback then
      vim.schedule(function()
        callback(err, nil)
      end)
      return nil, nil
    end
    return nil, err
  end
  if callback then
    return nil, nil
  end
  return M.parse(process:wait())
end

return M
