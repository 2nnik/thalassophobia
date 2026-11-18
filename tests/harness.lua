-- Emulates Roblox's require(script.Parent.X) so the pure simulation modules can run outside Studio.
local root = ROOT
local cache = {}
local mk
local function req(node)
	local p = rawget(node, "__path")
	if cache[p] then return cache[p] end
	local env = setmetatable({ script = mk(p), require = req }, { __index = _G })
	local f = assert(loadfile(root .. "/" .. p .. ".lua", "t", env))
	local m = f()
	cache[p] = m
	return m
end
mk = function(path)
	return setmetatable({ __path = path }, { __index = function(_, k)
		if k == "Parent" then return mk(path:match("^(.*)/[^/]*$") or "") end
		return mk(path == "" and k or (path .. "/" .. k))
	end })
end
return { require = req, node = mk }
