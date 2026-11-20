local fs = require("@lune/fs")
local luau = require("@lune/luau")

local receipt = 0
local entropyCalls = 0
local persisted = {}
local store = {}
function store:GetAsync(key) return persisted[key] end
function store:UpdateAsync(key, write)
	-- Simulate an optimistic write retried against the same uncommitted profile.
	local function copy(record)
		if type(record) ~= "table" then return record end
		local result = {}
		for k, v in pairs(record) do result[k] = copy(v) end
		return result
	end
	write(copy(persisted[key]))
	persisted[key] = write(copy(persisted[key]))
	return persisted[key]
end

local services = {
	Players = {},
	RunService = {IsStudio = function() return false end},
	DataStoreService = {GetDataStore = function() return store end},
	HttpService = {GenerateGUID = function()
		receipt += 1
		return tostring(receipt)
	end},
}
local Profiles = luau.load(fs.readFile("src/ServerScriptService/DiveLobbyProfiles.luau"), {
	environment = {
		game = {GameId = 1, GetService = function(_, name) return services[name] end},
		typeof = type,
		Random = {new = function() return {NextInteger = function(_, low, high)
			assert(low == 1 and high == 100)
			entropyCalls += 1
			return 1
		end} end},
	},
	injectGlobals = true,
})()

local player = {UserId = 71, Parent = true}
persisted.u71 = {money = 130, owned = {Optics = true}, equipped = "Optics"}
Profiles.load(player)
assert(Profiles.choose(player, "Battery") == "Unlock this trait at the spin station.")
assert(Profiles.view(player) == 130 and Profiles.trait(player) == "Optics")
assert(Profiles.spin(player) == "Reserve cells unlocked.")
local credits, equipped, traits, spin = Profiles.view(player)
assert(credits == 80 and equipped == "Optics" and spin.trait == "Battery" and not spin.duplicate)
assert(traits[1].owned and traits[1].weight == 10 and traits[1].price == nil)
assert(Profiles.choose(player, "Battery") == "Reserve cells equipped.")
assert(Profiles.spin(player) == "Reserve cells duplicate. +20 credits returned.")
local balance, chosen, _, second = Profiles.view(player)
assert(balance == 50 and chosen == "Battery" and second.id ~= spin.id and second.duplicate and second.refund == 20)
assert(Profiles.spin(player) == "Reserve cells duplicate. +20 credits returned.")
assert(Profiles.spin(player) == "A spin costs 50 earned credits.")
assert(Profiles.view(player) == 20 and entropyCalls == 4)
print("PASS: legacy unlocks, deterministic retries, weighted reveal, equip, duplicate refund and insufficient credits")
