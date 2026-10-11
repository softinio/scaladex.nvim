local http = require("scaladex.http")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

---@return vim.SystemCompleted
local function curl(body, status, code, stderr)
  return {
    code = code or 0,
    signal = 0,
    stdout = body .. "\n__scaladex_status__:" .. status,
    stderr = stderr or "",
  }
end

T["build_url"] = function()
  eq(
    http.build_url("https://example.com", "/api/v1/search", { { "q", "parse markdown" }, { "scala", "2.13" } }),
    "https://example.com/api/v1/search?q=parse%20markdown&scala=2.13"
  )
  eq(
    http.build_url("https://example.com", "/api/v1/search", { { "q", "a&b=c" } }),
    "https://example.com/api/v1/search?q=a%26b%3Dc"
  )
  eq(http.build_url("https://example.com", "/about"), "https://example.com/about")
end

T["parse"] = MiniTest.new_set()

T["parse"]["decodes JSON, nulls as nil"] = function()
  local body, err = http.parse(curl('{"results":[{"title":"cats","description":null}]}', 200))
  eq(err, nil)
  eq(body, { results = { { title = "cats" } } })
end

T["parse"]["404 is no value and no error"] = function()
  eq({ http.parse(curl('{"error":"no package"}', 404)) }, {})
end

T["parse"]["API errors carry their message"] = function()
  local body, err = http.parse(curl('{"error":"rate limit exceeded"}', 429))
  eq(body, nil)
  eq(err, "rate limit exceeded (HTTP 429)")
  eq(select(2, http.parse(curl("<html>bad gateway</html>", 502))), "HTTP 502")
end

T["parse"]["curl failures"] = function()
  local result = { code = 6, signal = 0, stdout = "", stderr = "curl: (6) Could not resolve host\n" }
  eq(select(2, http.parse(result)), "curl: (6) Could not resolve host")
end

T["parse"]["bad JSON"] = function()
  eq(select(2, http.parse(curl("not json", 200))), "invalid JSON in response")
end

return T
