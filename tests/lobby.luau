-- lune run tests/lobby.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local now, scheduled = 100, {}
local function later(delay, f)
	table.insert(scheduled, { at = now + delay, thread = if type(f) == "thread" then f else coroutine.create(f) })
end
local function advance(seconds)
	local target = now + seconds
	while #scheduled > 0 do
		table.sort(scheduled, function(a, b) return a.at < b.at end)
		local job = scheduled[1]
		if job.at > target then break end
		table.remove(scheduled, 1)
		now = job.at
		local success, delay = coroutine.resume(job.thread)
		assert(success, tostring(delay))
		if coroutine.status(job.thread) ~= "dead" then later(delay, job.thread) end
	end
	now = target
end
local function signal()
	local signal = { callbacks = {} }
	function signal:Connect(f) table.insert(self.callbacks, f) end
	function signal:fire(...) for _, callback in self.callbacks do callback(...) end end
	return signal
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), list = {} }
function players:GetPlayers() return self.list end
function players:GetPlayerByUserId(id)
	for _, player in self.list do if player.UserId == id then return player end end
end
local function add(id)
	local p = { UserId = id, Parent = players }
	table.insert(players.list, p)
	players.PlayerAdded:fire(p)
	return p
end
local function remove(player)
	players.PlayerRemoving:fire(player)
	table.remove(players.list, table.find(players.list, player))
	player.Parent = nil
end
local function deep(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in value do copy[k] = deep(v) end
	return copy
end
local map = { data = {} }
function map:GetAsync(key) return deep(self.data[key]) end
function map:UpdateAsync(key, apply)
	local v = apply(self:GetAsync(key))
	if v then self.data[key] = v end
	return deep(v)
end
local serial = 0
local function uid() serial += 1 return "T" .. serial end
local tp = { TeleportInitFailed = signal(), calls = {} }
function tp:TeleportAsync(_, group, opts)
	table.insert(self.calls, { group = group, options = opts })
end
local services = {
	Players = players, RunService = { IsStudio = function() return true end },
	HttpService = { GenerateGUID = uid }, TeleportService = tp,
	DataStoreService = {}, MemoryStoreService = { GetHashMap = function() return map end },
}
local gameMock = { PlaceId = 123, GetService = function(_, name) return assert(services[name]) end }
local modules = {}
local env = {
	game = gameMock, script = { Parent = { DiveProfiles = "DiveProfiles", DiveMatchmaker = "DiveMatchmaker" } },
	require = function(name) return assert(modules[name]) end,
	os = { clock = function() return now end, time = function() return math.floor(now) end },
	task = { spawn = function(f) later(0, f) end, delay = later, wait = coroutine.yield },
	Instance = { new = function() return {
		SetTeleportData = function(self, data) self.data = data end,
		GetTeleportData = function(self) return self.data end,
	} end },
}
for _, name in {"DiveProfiles", "DiveMatchmaker", "DiveLobby"} do
	local source = fs.readFile("src/ServerScriptService/" .. name .. ".luau")
	modules[name] = luau.load(source, { environment = env, injectGlobals = true })()
end
local launches = {}
local lobby = modules.DiveLobby.new(function(group, difficulty, traits)
	table.insert(launches, { group = group, difficulty = difficulty, traits = traits })
	return true
end)
local p1, p2, p3, p4, p5 = add(1), add(2), add(3), add(4), add(5)
advance(0)
local function act(p, name, payload)
	advance(0.2)
	return lobby:action(p, name, payload)
end
assert(not act(p2, "Join", {hostId = 1}))
assert(act(p1, "Difficulty", {difficulty = "Hard"}))
for _, friend in {p2, p3, p4} do
	assert(act(p1, "Invite", {userId = friend.UserId}))
	assert(lobby:snapshot(friend).invites[1] == 1)
	assert(act(friend, "Join", {hostId = 1}))
end
assert(not act(p1, "Invite", {userId = 5}))
assert(not act(p2, "Private") and not act(p1, "Solo"))
assert(act(p1, "Private"))
assert(#launches[1].group == 4 and launches[1].difficulty == "Hard")
assert(lobby:snapshot(p2).state == "Diving")
assert(act(p5, "Public"))
remove(p1)
assert(lobby:snapshot(p2).hostId == 2)
advance(9)
assert(#launches == 1)
local result = { deepest = 600, artifact = true, difficulty = "Hard", survived = true,
	survivors = {[2] = true, [3] = true, [4] = true} }
lobby:finish({p2,p3,p4}, "A", result)
advance(1)
assert(#launches == 2 and launches[2].group[1] == p5)
assert(lobby:snapshot(p2).credits == 224 and lobby.profiles.cache[1].credits == 133)
lobby:finish({p2,p3,p4}, "A", result)
assert(lobby.active and lobby.active[5])
lobby:finish({p5}, "B", { deepest = 230, difficulty = "Normal" })
advance(0)
assert(lobby:snapshot(p5).credits == 23)
assert(act(p2, "Buy", {trait = "Battery"}))
assert(not act(p2, "Buy", {trait = "Battery"}) and lobby:snapshot(p2).credits == 124)
assert(act(p2, "Equip", {trait = "Battery"}))
assert(act(p2, "Private") and launches[3].traits[2] == "Battery")
lobby.profiles:award(2, "A", 224)
advance(0)
assert(lobby:snapshot(p2).credits == 124)
assert(act(p5, "Public") and act(p5, "Leave"))
advance(10)
assert(lobby:snapshot(p5).state == "Ready")
print("PASS private 4-player cap, host migration, local queue, traits, departed/death/survival payout and duplicate receipt")

local failed = {}
local matchmaker = modules.DiveMatchmaker.new(function(p) failed[p] = true end)
for _, group in {{p2,p3}, {p4,p5}, {p2}} do
	assert(matchmaker:send(group, "Normal", true, function() return true end))
end
local first, second, third = tp.calls[1], tp.calls[2], tp.calls[3]
assert(first.options.ReservedServerId == second.options.ReservedServerId)
assert(first.options.ReservedServerId ~= third.options.ReservedServerId)
gameMock.PrivateServerId = first.options.ReservedServerId
local ok, manifest = matchmaker:manifest()
assert(ok and manifest.members["3"] == first.options.data.ticket and manifest.members["4"] == second.options.data.ticket)
assert(modules.DiveProfiles.reward(2, {deepest = 600, artifact = true, survived = true, difficulty = "Easy"}) == 128)
local before = #tp.calls
tp.TeleportInitFailed:fire(p2, {}, "fixture failure", gameMock.PlaceId, third.options)
advance(2)
tp.TeleportInitFailed:fire(p2, {}, "fixture failure", gameMock.PlaceId, tp.calls[#tp.calls].options)
advance(2)
tp.TeleportInitFailed:fire(p2, {}, "fixture failure", gameMock.PlaceId, tp.calls[#tp.calls].options)
assert(#tp.calls == before + 2 and failed[p2])
print("PASS shared reserved destination, indivisible party overflow, private admission manifest and bounded transfer retries")

-- One crew member misses the arrival window. Another player's unrelated
-- teleport ticket cannot take their berth. Waiting players remain playable.
local arrived
local dest = setmetatable({
	matchmaker = matchmaker, arriving = true, parties = {}, shops = {}, profiles = lobby.profiles,
	onLaunch = function(group) arrived = group return true end,
}, modules.DiveLobby)
for _, p in {p2,p3,p4,p5} do
	dest:single(p).state = "Arriving"
	function p:GetJoinData()
		return { SourcePlaceId = gameMock.PlaceId,
			TeleportData = { ticket = if self == p5 then "other" else manifest.members[tostring(self.UserId)] } }
	end
end
later(0, function() dest:acceptArrivals() end)
advance(3)
assert(not arrived)
advance(40)
assert(#arrived == 3 and not table.find(arrived, p5) and dest.parties[p5].state == "Ready")
assert(dest.arriving == false)

-- Two server caches use the same backing key. Replaying a settled receipt
-- against a newer purchase must preserve that purchase and the current balance.
local a, b = modules.DiveProfiles.new(), modules.DiveProfiles.new()
a.store, b.store = map, map
a:award(99, "r1", 100)
advance(0)
assert(b:load(99) and b:shop(99, "Buy", "Battery"))
a:award(99, "r1", 100)
advance(0)
assert(a.cache[99].credits == 0 and a.cache[99].owned.Battery)
print("PASS partial arrivals recover, rejected ticket remains in lobby, cross-server receipt replay preserves purchase")
