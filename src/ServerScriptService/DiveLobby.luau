local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Profiles = require(script.Parent.DiveProfiles)
local Matchmaker = require(script.Parent.DiveMatchmaker)

local Lobby = {}
Lobby.__index = Lobby
local DIFFICULTIES = { Easy = true, Normal = true, Hard = true }
local LOCAL_WAIT = 8

local function roster(party)
	local ids = {}
	for _, member in party.members do table.insert(ids, member.UserId) end
	return ids
end

function Lobby:single(player)
	local party = { members = {player}, host = player, state = "Ready", difficulty = "Normal" }
	self.parties[player] = party
	return party
end

function Lobby:detach(player)
	local party = self.parties[player]
	if not party then return end
	self.parties[player] = nil
	local at = table.find(party.members, player)
	if at then table.remove(party.members, at) end
	party.host = party.members[1]
	if party.state == "Queued" then party.state = "Ready" end
end

function Lobby:added(player)
	if self.parties[player] then return end
	local party = self:single(player)
	party.state = "Loading"
	self.invites[player] = {}
	task.spawn(function()
		local delaySeconds = 1
		while player.Parent == Players and not self.profiles:load(player.UserId) do
			self.notices[player] = "Loading your credits. Retrying."
			task.wait(delaySeconds)
			delaySeconds = math.min(10, delaySeconds * 2)
		end
		if player.Parent ~= Players then return end
		if self.arriving then party.state = "Arriving" else party.state = "Ready" end
		self.notices[player] = nil
	end)
end

function Lobby.new(onLaunch)
	local self = setmetatable({
		parties = {}, invites = {}, notices = {}, lastAction = {}, shops = {},
		onLaunch = onLaunch, profiles = Profiles.new(), active = nil, paidRuns = {},
	}, Lobby)
	if not RunService:IsStudio() then
		self.matchmaker = Matchmaker.new(function(player)
			local party = self.parties[player]
			if party and party.state == "Transferring" then
				self:detach(player)
				self:single(player)
				self.notices[player] = "Transfer failed. Your lobby is ready again."
			end
		end)
	end
	self.arriving = self.matchmaker ~= nil and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	Players.PlayerAdded:Connect(function(player) self:added(player) end)
	Players.PlayerRemoving:Connect(function(player)
		self:detach(player)
		self.invites[player], self.lastAction[player], self.shops[player], self.notices[player] = nil, nil, nil, nil
		for _, invitations in self.invites do invitations[player.UserId] = nil end
	end)
	for _, player in Players:GetPlayers() do self:added(player) end
	if self.arriving then task.spawn(function() self:acceptArrivals() end) end
	return self
end

function Lobby:snapshot(player)
	local party = self.parties[player]
	local data = self.profiles.cache[player.UserId]
	local invitations = {}
	for id, invite in self.invites[player] or {} do
		if invite.expires >= os.clock() and invite.party.host and invite.party.host.UserId == id
			and invite.party.state == "Ready" then table.insert(invitations, id) end
	end
	table.sort(invitations)
	return {
		state = party and party.state or "Loading",
		hostId = party and party.host.UserId or player.UserId, members = party and roster(party) or {},
		invites = invitations, difficulty = party and party.difficulty or "Normal",
		credits = data and data.credits or 0, equipped = data and data.equipped or "",
		owned = data and table.clone(data.owned) or {}, traits = Profiles.costs, notice = self.notices[player],
	}
end

function Lobby:launch(crew, difficulty)
	if self.active or #crew == 0 or #crew > 4 then return false end
	local traits, active = {}, {}
	for _, player in crew do
		if not self.parties[player] or not self.profiles.cache[player.UserId] or self.shops[player] then return false end
		traits[player.UserId] = self.profiles.cache[player.UserId].equipped
		active[player.UserId] = true
	end
	self.active = active
	local ok, launched = pcall(self.onLaunch, table.clone(crew), difficulty, traits)
	if not ok or not launched then
		if not ok then warn("Dive launch failed", launched) end
		self.active = nil
		return false
	end
	for _, player in crew do
		local party = self.parties[player]
		if party then party.state = "Diving" end
	end
	return true
end

function Lobby:acceptArrivals()
	local deadline = os.time() + 55
	while os.time() < deadline do
		local ok, manifest = self.matchmaker:manifest()
		if ok and manifest then
			local crew, expected = {}, 0
			for id, ticket in manifest.members do
				expected += 1
				local player = Players:GetPlayerByUserId(tonumber(id))
				local party = player and self.parties[player]
				if party and party.state == "Arriving" then
					local join = player:GetJoinData()
					local data = join.TeleportData
					if join.SourcePlaceId == game.PlaceId and type(data) == "table" and data.ticket == ticket then
						table.insert(crew, player)
					end
				end
			end
			local now = os.time()
			if #crew > 0 and ((#crew == expected and (expected == 4 or now >= manifest.closes + 2))
				or now >= manifest.closes + self.matchmaker.arrivalGrace) then
				if self:launch(crew, manifest.difficulty) then break end
			end
		end
		task.wait(2)
	end
	self.arriving = false
	for _, party in self.parties do
		if party.state == "Arriving" then party.state = "Ready" end
	end
end

function Lobby:matchLocal(difficulty)
	if self.active then return end
	local parties = {}
	for player, party in self.parties do
		if party.host == player and party.state == "Queued" and party.difficulty == difficulty then
			table.insert(parties, party)
		end
	end
	table.sort(parties, function(a, b) return a.queuedAt < b.queuedAt end)
	local crew = {}
	for _, party in parties do
		if #crew + #party.members <= 4 then
			for _, member in party.members do table.insert(crew, member) end
		end
	end
	if #crew == 4 or (#crew > 0 and os.clock() - parties[1].queuedAt >= LOCAL_WAIT) then
		self:launch(crew, difficulty)
	end
end

function Lobby:transfer(party, public)
	local crew = table.clone(party.members)
	party.state = "Transferring"
	task.spawn(function()
		local sent = self.matchmaker:send(crew, party.difficulty, public, function()
			if party.state ~= "Transferring" or #party.members ~= #crew then return false end
			for _, player in crew do if self.parties[player] ~= party then return false end end
			return true
		end)
		if not sent and party.state == "Transferring" then
			party.state = "Ready"
			for _, player in party.members do self.notices[player] = "Match unavailable. Try again." end
		end
	end)
end

function Lobby:enqueue(party)
	party.state = "Queued"
	party.queuedAt = os.clock()
	local started = party.queuedAt
	task.spawn(function()
		if self.matchmaker then
			task.wait(3)
			if party.state == "Queued" and started == party.queuedAt then self:transfer(party, true) end
		else
			while party.state == "Queued" and started == party.queuedAt do
				self:matchLocal(party.difficulty)
				task.wait(0.5)
			end
		end
	end)
end

function Lobby:action(player, action, payload)
	local party = self.parties[player]
	if not party then return false end
	if os.clock() - (self.lastAction[player] or -1) < 0.15 then return false end
	self.lastAction[player] = os.clock()
	payload = if type(payload) == "table" then payload else {}
	local function reject(message) self.notices[player] = message return false end
	self.notices[player] = nil
	if action == "Leave" and (party.state == "Queued" or party.state == "Ready") then
		if party.state == "Queued" and party.host == player then party.state = "Ready"
		else self:detach(player) self:single(player) end
		return true
	end
	if party.state ~= "Ready" or self.shops[player] then return reject("Crew is busy.") end
	if action == "Buy" or action == "Equip" then
		if type(payload.trait) ~= "string" then return reject("Choose a trait.") end
		self.shops[player] = true
		local ok, notice = self.profiles:shop(player.UserId, action, payload.trait)
		self.shops[player] = nil
		if not ok then return reject(notice) end
		return true
	end
	if action == "Join" then
		if type(payload.hostId) ~= "number" or #party.members > 1 then return reject("Leave your crew first.") end
		local invite = self.invites[player][payload.hostId]
		local target = invite and invite.party
		if not target or invite.expires < os.clock() or not target.host or target.host.UserId ~= payload.hostId
			or target.state ~= "Ready" or #target.members >= 4 then return reject("Invite expired or crew full.") end
		self:detach(player)
		table.insert(target.members, player)
		self.parties[player] = target
		self.invites[player] = {}
		return true
	end
	if party.host ~= player then return reject("Only the crew host can do that.") end
	if action == "Invite" then
		if type(payload.userId) ~= "number" then return reject("Choose a player.") end
		local other = Players:GetPlayerByUserId(payload.userId)
		if not other or not self.invites[other] or self.parties[other] == party or #party.members >= 4 then
			return reject("Player unavailable or crew full.")
		end
		self.invites[other][player.UserId] = { party = party, expires = os.clock() + 90 }
		return true
	elseif action == "Difficulty" and DIFFICULTIES[payload.difficulty] then
		party.difficulty = payload.difficulty
		return true
	elseif action == "Public" or action == "Private" or action == "Solo" then
		for _, member in party.members do if self.shops[member] then return reject("Crew member is shopping.") end end
		if action == "Solo" and #party.members > 1 then return reject("Leave your party to launch solo.") end
		if action == "Public" then self:enqueue(party) return true end
		if not self.active and not self.arriving then
			if self:launch(table.clone(party.members), party.difficulty) then return true end
		elseif self.matchmaker then self:transfer(party, false) return true end
		return reject("A dive is underway. Choose Public to wait for a berth.")
	end
	return false
end

function Lobby:finish(crew, runId, result)
	local active = self.active
	if not active or self.paidRuns[runId] then return end
	self.paidRuns[runId] = true
	self.active = nil
	for id in active do
		local player = Players:GetPlayerByUserId(id)
		local party = player and self.parties[player]
		if party and party.state == "Diving" then party.state = "Ready" end
		local amount = Profiles.reward(id, result)
		self.profiles:award(id, runId, amount, function()
			if player and self.parties[player] then self.notices[player] = ("Dive complete. +%d credits."):format(amount) end
		end)
	end
end

return Lobby
