local curl = require("plenary.curl")

local M = {}


M.search = function(query, target, scalaVersion)
	local q = nil
	local t = nil
	local v = nil
	if query == nil then
		return {}
	else
		q = string.gsub(query, "%s+", "")
	end

	if target == nil then
		t = "JVM"
	else
		t = string.gsub(target, "%s+", "")
	end

	if scalaVersion == nil then
		v = "2.13"
	else
		v = string.gsub(scalaVersion, "%s+", "")
	end

	local parameters = {
		q = q,
		t = t,
		v = v
	}

	local url = string.gsub("https://index.scala-lang.org/api/search?q=$q&target=$t&scalaVersion=$v", "$(%w+)",parameters)

	local response = curl.request {
		url = url,
		method = "get",
		accept = "application/json"
	}

	if response.status ~= 200 then
		error("Failed to search scaladex, got a status: " .. response.status)
		return {}
	end
	local decoded = vim.fn.json_decode(response.body)
	-- print(response.body)
	return decoded
end

M.get_project = function(org, repo)
	if org == nil or repo == nil then return {} end
	local organization = string.gsub(org, "%s+", "")
	local repository = string.gsub(repo, "%s+", "")
	local parameters = {
		organization = organization,
		repository = repository
	}

	local url = string.gsub("https://index.scala-lang.org/api/project?organization=$organization&repository=$repository", "$(%w+)",parameters)

	local response = curl.request {
		url = url,
		method = "get",
		accept = "application/json"
	}

	if response.status ~= 200 then
		error("Failed to get project from scaladex, got a status: " .. response.status)
		return {}
	end
	local decoded = vim.fn.json_decode(response.body)
	-- print(response.body)
	return decoded
end

return M

