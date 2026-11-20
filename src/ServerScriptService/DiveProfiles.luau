local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Profiles = {}
Profiles.__index = Profiles
Profiles.costs = { Battery = 100, Optics = 70, Repair = 80, QuietEngine = 90, Extinguisher = 60, Oxygen = 75 }
local rewardScale = { Easy = 0.8, Normal = 1, Hard = 1.4 }

local function normalize(data)
	data = data or {}
	data.credits = data.credits or 0
	data.owned = data.owned or {}
	data.equipped = data.equipped or ""
	data.receipts = data.receipts or {}
	return data
end

function Profiles.new()
	local self = setmetatable({ cache = {}, locks = {}, pending = 0 }, Profiles)
	if not RunService:IsStudio() then
		self.store = DataStoreService:GetDataStore("ThalassophobiaProfiles_v1")
		game:BindToClose(function()
			local untilTime = os.clock() + 26
			-- The run owner may finish a final dive in a sibling close callback.
			task.wait()
			while self.pending > 0 and os.clock() < untilTime do task.wait(0.2) end
		end)
	end
	return self
end

-- Every write transforms the latest persistent value. The local lock also keeps
-- asynchronous completions from rolling a player's displayed balance backwards.
function Profiles:update(id, transform)
	while self.locks[id] do task.wait(0.05) end
	self.locks[id] = true
	local function apply(old)
		local data = normalize(old)
		transform(data)
		return data
	end
	local ok, data = pcall(function()
		if self.store then return self.store:UpdateAsync("player_" .. id, apply) end
		return apply(self.cache[id])
	end)
	if ok then self.cache[id] = data end
	self.locks[id] = nil
	if not ok then warn("Dive profile unavailable", id, data) end
	return ok
end

function Profiles:load(id)
	return self:update(id, function() end)
end

function Profiles:shop(id, action, trait)
	if not self.costs[trait] and not (action == "Equip" and trait == "") then return false, "Unknown trait." end
	local notice
	local ok = self:update(id, function(data)
		notice = nil
		if action == "Buy" then
			if data.owned[trait] then notice = "Already owned."
			elseif data.credits < self.costs[trait] then notice = "Insufficient credits."
			else
				data.credits -= self.costs[trait]
				data.owned[trait] = true
			end
		elseif trait == "" or data.owned[trait] then
			data.equipped = trait
		else
			notice = "Purchase this trait first."
		end
	end)
	return ok and not notice, notice or (not ok and "Store unavailable. Try again." or nil)
end

function Profiles.reward(id, result)
	local survived = result.survived
	if result.survivors then survived = result.survivors[id] == true end
	local depth = math.clamp(result.deepest or 0, 0, 600)
	local base = math.floor(depth / 10) + (result.artifact and 35 or 0) + (survived and 65 or 0)
	return math.floor(base * (rewardScale[result.difficulty] or 1))
end

function Profiles:award(id, runId, amount, onAward)
	self.pending += 1
	task.spawn(function()
		local delaySeconds = 1
		while true do
			local ok = self:update(id, function(data)
				if data.receipts[runId] == nil then
					data.credits += amount
					data.receipts[runId] = amount
				end
			end)
			if ok then break end
			task.wait(delaySeconds)
			delaySeconds = math.min(8, delaySeconds * 2)
		end
		self.pending -= 1
		if onAward then onAward() end
	end)
end

return Profiles
