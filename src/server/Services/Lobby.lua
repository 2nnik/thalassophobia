-- Lobby place: shop, solo start and cross-server matchmaking (max 4 per run).
-- UNTESTED in Studio: MemoryStore/MessagingService/Teleport only work in a published experience.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Economy = require(script.Parent.Economy)

local Lobby = {}

local function validDifficulty(d)
	return type(d) == "string" and Config.Difficulties[d] ~= nil
end

local function sendState(player, message)
	local profile = Economy.Load(player)
	Remotes.LobbyState:FireClient(player, {
		money = profile.money, owned = profile.owned, equipped = profile.equipped, message = message,
	})
end

local function teleportGroup(players, code, difficulty, expected)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ difficulty = difficulty, expected = expected })
	pcall(function() TeleportService:TeleportAsync(Config.Places.Run, players, options) end)
end

function Lobby.start()
	-- every lobby server listens for finished matches and teleports its own players
	pcall(function()
		MessagingService:SubscribeAsync("ThalassoMatch", function(message)
			local data = HttpService:JSONDecode(message.Data)
			local mine = {}
			for _, userId in ipairs(data.users) do
				local player = Players:GetPlayerByUserId(userId)
				if player then mine[#mine + 1] = player end
			end
			if #mine > 0 then teleportGroup(mine, data.code, data.difficulty, #data.users) end
		end)
	end)

	Remotes.LobbyAction.OnServerEvent:Connect(function(player, action, arg1, arg2)
		if action == "Sync" then
			sendState(player)
		elseif action == "Buy" then
			local ok, msg = Economy.Buy(player, arg1)
			sendState(player, ok and "Purchased" or msg)
		elseif action == "Equip" then
			local ok, msg = Economy.Equip(player, arg1, arg2 == true)
			sendState(player, ok and "Updated loadout" or msg)
		elseif action == "Solo" and validDifficulty(arg1) then
			Economy.Save(player)
			teleportGroup({ player }, TeleportService:ReserveServer(Config.Places.Run), arg1, 1)
		elseif action == "Queue" and validDifficulty(arg1) then
			local queue = MemoryStoreService:GetQueue("Match_" .. arg1, 60)
			local ok = pcall(function()
				queue:AddAsync({ userId = player.UserId, t = os.time() }, 120)
			end)
			sendState(player, ok and "Searching for a crew..." or "Matchmaking unavailable")
		end
	end)

	-- Matcher loop: collect waiting players per difficulty, launch at 4 or after the wait time.
	local pending = {}
	for _, difficulty in ipairs(Config.DifficultyOrder) do
		pending[difficulty] = { items = {}, first = nil, queue = MemoryStoreService:GetQueue("Match_" .. difficulty, 60) }
	end
	task.spawn(function()
		while true do
			task.wait(3)
			for difficulty, group in pairs(pending) do
				local ok, items, readId = pcall(function()
					return group.queue:ReadAsync(Config.MaxPlayers - #group.items, false, 0)
				end)
				if ok and items and #items > 0 then
					for _, item in ipairs(items) do group.items[#group.items + 1] = item end
					group.first = group.first or os.clock()
					group.readIds = group.readIds or {}
					table.insert(group.readIds, readId)
				end
				local ready = #group.items >= Config.MaxPlayers
					or (#group.items > 0 and group.first and os.clock() - group.first >= Config.Match.WaitSeconds)
				if ready then
					local users = {}
					for _, item in ipairs(group.items) do users[#users + 1] = item.userId end
					for _, id in ipairs(group.readIds or {}) do pcall(function() group.queue:RemoveAsync(id) end) end
					local okReserve, code = pcall(function() return TeleportService:ReserveServer(Config.Places.Run) end)
					if okReserve then
						pcall(function()
							MessagingService:PublishAsync("ThalassoMatch", HttpService:JSONEncode(
								{ users = users, code = code, difficulty = difficulty }))
						end)
					end
					pending[difficulty] = { items = {}, first = nil, queue = group.queue }
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player) task.defer(sendState, player) end)
end

return Lobby
