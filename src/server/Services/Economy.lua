-- Persistent money and traits. All writes go through here so the rules (cost, equip slots) live in one place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local Economy = {}
local store = DataStoreService:GetDataStore("Thalassophobia_v1")
local profiles = {}

local function default()
	return { money = 0, owned = {}, equipped = {} }
end

local function retry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then return true, result end
		task.wait(attempt)
	end
	return false, nil
end

function Economy.Load(player)
	if profiles[player] then return profiles[player] end
	local ok, data = retry(function() return store:GetAsync("u_" .. player.UserId) end)
	local profile = default()
	if ok and type(data) == "table" then
		profile.money = tonumber(data.money) or 0
		profile.owned = type(data.owned) == "table" and data.owned or {}
		profile.equipped = type(data.equipped) == "table" and data.equipped or {}
	end
	profile.loaded = ok -- never overwrite saved data if the load failed
	profiles[player] = profile
	return profile
end

function Economy.Get(player)
	return profiles[player]
end

function Economy.Save(player)
	local profile = profiles[player]
	if not profile or not profile.loaded then return false end
	local payload = { money = profile.money, owned = profile.owned, equipped = profile.equipped }
	return (retry(function()
		store:UpdateAsync("u_" .. player.UserId, function() return payload end)
	end))
end

function Economy.Award(player, amount)
	local profile = Economy.Load(player)
	profile.money = profile.money + math.max(0, math.floor(amount))
	Economy.Save(player)
end

local function has(list, id)
	for _, v in ipairs(list) do if v == id then return true end end
	return false
end

function Economy.Buy(player, id)
	local profile, trait = Economy.Load(player), Config.Traits[id]
	if not trait then return false, "Unknown trait" end
	if has(profile.owned, id) then return false, "Already owned" end
	if profile.money < trait.cost then return false, "Not enough money" end
	profile.money = profile.money - trait.cost
	table.insert(profile.owned, id)
	Economy.Save(player)
	return true
end

function Economy.Equip(player, id, on)
	local profile = Economy.Load(player)
	if not Config.Traits[id] or not has(profile.owned, id) then return false, "Not owned" end
	for i, v in ipairs(profile.equipped) do
		if v == id then table.remove(profile.equipped, i) break end
	end
	if on then
		if #profile.equipped >= Config.Shop.EquipSlots then return false, "No free slots" end
		table.insert(profile.equipped, id)
	end
	Economy.Save(player)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	Economy.Save(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	for player in pairs(profiles) do Economy.Save(player) end
end)

return Economy
