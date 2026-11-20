local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Matchmaker = {}
Matchmaker.__index = Matchmaker
local FORMATION = 12
local ARRIVAL_GRACE = 28
local TTL = 180

local function fits(slot, size)
	return slot and slot.closes > os.time() and slot.count + size <= 4
end

function Matchmaker.new(onFailure)
	local self = setmetatable({
		registry = MemoryStoreService:GetHashMap("ThalassophobiaMatches_v1"),
		pending = {}, onFailure = onFailure,
	}, Matchmaker)
	TeleportService.TeleportInitFailed:Connect(function(player, _, message, _, options)
		local request = self.pending[player]
		local data = options and options:GetTeleportData()
		if request and type(data) == "table" and data.ticket == request.ticket then
			self:retry(player, request, message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player) self.pending[player] = nil end)
	return self
end

function Matchmaker:reserve(difficulty, public)
	return { id = HttpService:GenerateGUID(false), difficulty = difficulty,
		closes = os.time() + (public and FORMATION or 0), count = 0, tickets = {} }
end

-- One atomic slot per difficulty admits whole parties. A full slot can be
-- replaced immediately: its private manifest remains available to its arrivals.
function Matchmaker:admit(ticket, size, difficulty, public)
	if not public then return self:reserve(difficulty, false) end
	local key = "open_" .. difficulty
	local candidate = self:reserve(difficulty, true)
	return self.registry:UpdateAsync(key, function(current)
		if current and current.tickets[ticket] then return current end
		if not fits(current, size) then
			current = table.clone(candidate)
			current.tickets = {}
		end
		current.tickets[ticket] = true
		current.count += size
		return current
	end, TTL)
end

function Matchmaker:retry(player, request, reason)
	if self.pending[player] ~= request then return end
	self.pending[player] = nil
	if player.Parent ~= Players then return end
	if request.attempt >= 3 or os.time() >= request.expires then
		warn("Dive transfer failed", player.UserId, reason)
		self.onFailure(player)
		return
	end
	local retry = table.clone(request)
	retry.attempt += 1
	self.pending[player] = retry
	task.delay(2, function()
		if self.pending[player] == retry then self:teleport({player}, retry) end
	end)
end

function Matchmaker:teleport(crew, request)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = request.serverId
	options:SetTeleportData({ ticket = request.ticket })
	for _, player in crew do self.pending[player] = request end
	local ok, message = pcall(function() TeleportService:TeleportAsync(game.PlaceId, crew, options) end)
	for _, player in crew do
		if not ok then
			self:retry(player, request, message)
		else
			task.delay(15, function()
				if self.pending[player] == request then self:retry(player, request, "Timed out") end
			end)
		end
	end
end

function Matchmaker:send(crew, difficulty, public, stillValid)
	local ticket = HttpService:GenerateGUID(false)
	local ok, slot = pcall(function()
		local reserved = self:admit(ticket, #crew, difficulty, public)
		self.registry:UpdateAsync("manifest_" .. reserved.id, function(manifest)
			manifest = manifest or { difficulty = difficulty, closes = reserved.closes, members = {} }
			for _, player in crew do manifest.members[tostring(player.UserId)] = ticket end
			return manifest
		end, TTL)
		return reserved
	end)
	if not ok then warn("Dive matchmaking unavailable", slot) return false end
	if not stillValid() then return false end
	self:teleport(crew, { serverId = slot.id, ticket = ticket, attempt = 1, expires = os.time() + ARRIVAL_GRACE })
	return true
end

function Matchmaker:manifest()
	local ok, value = pcall(function() return self.registry:GetAsync("manifest_" .. game.PrivateServerId) end)
	return ok, value
end

Matchmaker.arrivalGrace = ARRIVAL_GRACE
return Matchmaker
