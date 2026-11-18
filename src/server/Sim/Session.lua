-- Pure game simulation for one run. No Roblox APIs: the server drives it with Tick(dt) and player actions,
-- and reads Snapshot()/TakeEvents(). Everything here is server-authoritative.
local Session = {}
Session.__index = Session

local function clamp(x, a, b)
	if x < a then return a elseif x > b then return b end
	return x
end

local function pick(rng, list)
	return list[math.floor(rng() * #list) + 1]
end

function Session.computeStats(cfg, players)
	local stats = { battery = 1, lightCone = 1, lightDrain = 1, repair = 1, sharkReaction = 1, thrust = 1,
		extCapacity = 1, oxygen = 1, flicker = 0 }
	local seen = {}
	for _, p in ipairs(players or {}) do
		for _, id in ipairs(p.traits or {}) do
			local trait = cfg.Traits[id]
			if trait and not seen[id] then
				seen[id] = true
				for key, value in pairs(trait.effects) do
					if key == "flicker" then
						stats.flicker = stats.flicker + value
					else
						stats[key] = (stats[key] or 1) * value
					end
				end
			end
		end
	end
	return stats
end

-- opts: difficulty, players = { {id=, traits={...}} }, rng, noDirector
function Session.new(cfg, opts)
	opts = opts or {}
	local self = setmetatable({}, Session)
	self.cfg = cfg
	self.rng = opts.rng or math.random
	self.diffName = cfg.Difficulties[opts.difficulty or ""] and opts.difficulty or "Normal"
	self.diff = cfg.Difficulties[self.diffName]
	self.stats = Session.computeStats(cfg, opts.players)

	self.phase = "Descent" -- Descent | Bottom | Ascent | Won | Dead
	self.time = 0
	self.depth, self.maxDepth, self.verticalSpeed = 0, 0, 0
	self.engineOn, self.lightOn, self.lightYaw = true, false, 0
	self.coast = cfg.Cage.CoastTime
	self.batteryMax = cfg.Battery.Max * self.stats.battery
	self.battery = self.batteryMax
	self.hull = cfg.Cage.Hull
	self.hasArtifact = false
	self.swarmCoverage = 0
	self.flickerOut = 0
	self.deathReason = nil

	self.cracks, self.nextCrackId = {}, 1
	self.crackTimer = cfg.Cracks.FirstDelay
	self.monsters = {}
	self.events = {}

	self.players = {}
	for _, p in ipairs(opts.players or {}) do
		self.players[p.id] = { id = p.id, section = "Midship", alive = true, left = false, outside = false,
			oxygen = 0, dangerTime = 0, heldExt = nil }
	end

	self.extinguishers = {}
	local ec = cfg.Extinguisher
	for i, section in ipairs(ec.Sections) do
		self.extinguishers[i] = { id = i, section = section, holder = nil, charge = ec.Capacity * self.stats.extCapacity }
	end

	if not opts.noDirector then
		self.director = require(script.Parent.Director).new(self)
	end
	return self
end

-- ---------------------------------------------------------------- helpers

function Session:Emit(name, data)
	self.events[#self.events + 1] = { name = name, data = data or {}, t = self.time }
end

function Session:TakeEvents()
	local out = self.events
	self.events = {}
	return out
end

function Session:AliveCount()
	local n = 0
	for _, p in pairs(self.players) do
		if p.alive then n = n + 1 end
	end
	return n
end

function Session:_scaleIndex()
	return clamp(self:AliveCount(), 1, 4)
end

function Session:PlayerScale()
	return self.cfg.PlayerScale.rate[self:_scaleIndex()]
end

-- How fast monsters move. Includes the ascent boost unless noAscent is set.
function Session:SpeedScale(noAscent)
	local s = self.cfg.PlayerScale.speed[self:_scaleIndex()]
	if self.phase == "Ascent" and not noAscent then
		s = s * self.cfg.Director.AscentSpeedMult
	end
	return s
end

function Session:LightEffective()
	return self.lightOn and self.battery > 0 and self.flickerOut <= 0 and self.swarmCoverage < 0.99
end

function Session:LightCone()
	return self.cfg.Light.Cone * self.stats.lightCone * (1 - 0.5 * self.swarmCoverage)
end

function Session:IsLit(bearing)
	if not self:LightEffective() then return false end
	local diff = math.abs((self.lightYaw - bearing + 180) % 360 - 180)
	return diff <= self:LightCone()
end

function Session:CountCracks()
	local n = 0
	for _ in pairs(self.cracks) do n = n + 1 end
	return n
end

function Session:AddCrack(section)
	section = section or pick(self.rng, self.cfg.CrackSections)
	local id = self.nextCrackId
	self.nextCrackId = id + 1
	self.cracks[id] = { id = id, section = section, age = 0, progress = 0, claimed = false }
	self:Emit("CrackAppeared", { id = id, section = section })
	return id
end

function Session:AddCracks(n)
	for _ = 1, n do
		if self:CountCracks() < self.cfg.Cracks.Max + 3 then self:AddCrack() end
	end
end

function Session:DamageHull(amount, reason)
	self.hull = self.hull - amount
	self:Emit("HullHit", { amount = amount, hull = math.max(self.hull, 0) })
	if self.hull <= 0 then
		self.hull = 0
		self:Kill(reason or "Hull")
	end
end

function Session:Kill(reason)
	if self.phase == "Dead" or self.phase == "Won" then return end
	self.phase = "Dead"
	self.deathReason = reason
	self:Emit("RunDied", { reason = reason })
end

function Session:KillPlayer(id, reason)
	local p = self.players[id]
	if not p or not p.alive then return end
	p.alive, p.outside = false, false
	if p.heldExt then
		self.extinguishers[p.heldExt].holder = nil
		p.heldExt = nil
	end
	self:Emit("PlayerDied", { id = id, reason = reason })
	if self:AliveCount() == 0 then self:Kill("Crew") end
end

-- A disconnect is not a death: the rest of the crew carries on.
function Session:RemovePlayer(id)
	local p = self.players[id]
	if not p or p.left then return end
	p.left, p.alive, p.outside = true, false, false
	if p.heldExt then
		self.extinguishers[p.heldExt].holder = nil
		p.heldExt = nil
	end
	self:Emit("PlayerLeft", { id = id })
	if self:AliveCount() == 0 then self:Kill("Crew") end
end

function Session:OutsideDanger()
	for _, m in ipairs(self.monsters) do
		if m.OutsideDanger and m:OutsideDanger() then return true end
	end
	return false
end

-- ---------------------------------------------------------------- tick

function Session:Tick(dt)
	if self.phase == "Dead" or self.phase == "Won" then return end
	self.time = self.time + dt
	self:_updateMovement(dt)
	self:_updateBattery(dt)
	self:_updateLight(dt)
	self:_updateCracks(dt)

	local list = {}
	for i, m in ipairs(self.monsters) do list[i] = m end
	for _, m in ipairs(list) do m:Update(dt) end
	local kept = {}
	for _, m in ipairs(self.monsters) do
		if not m.done then kept[#kept + 1] = m end
	end
	self.monsters = kept

	self:_updatePlayers(dt)
	if self.director then self.director:Update(dt) end

	if self.phase == "Ascent" and self.depth <= 0 then
		self.depth = 0
		self.phase = "Won"
		self:Emit("RunWon", {})
	end
end

function Session:_updateMovement(dt)
	local c = self.cfg.Cage
	if self.phase == "Descent" then
		local rate = self.engineOn and (c.DescentSpeed * self.stats.thrust) or c.DriftDescent
		self.verticalSpeed = -rate
		self.depth = self.depth + rate * dt
		if self.depth >= c.MaxDepth then
			self.depth = c.MaxDepth
			self.phase = "Bottom"
			self.verticalSpeed = 0
			self:Emit("ReachedBottom", {})
		end
	elseif self.phase == "Bottom" then
		self.verticalSpeed = 0
	elseif self.phase == "Ascent" then
		local full = c.AscentSpeed * self.stats.thrust * (self.hasArtifact and c.ArtifactSpeedMult or 1)
		if self.engineOn then
			self.coast = c.CoastTime
			self.verticalSpeed = full
		else
			self.coast = math.max(self.coast - dt, 0)
			if self.coast > 0 then
				self.verticalSpeed = full * (self.coast / c.CoastTime)
			else
				self.verticalSpeed = -c.SinkSpeed
			end
		end
		self.depth = math.min(self.depth - self.verticalSpeed * dt, c.MaxDepth)
	end
	if self.depth > self.maxDepth then self.maxDepth = self.depth end
end

function Session:_updateBattery(dt)
	local b = self.cfg.Battery
	local drain = b.Base
	if self.engineOn then drain = drain + b.Engine end
	if self:LightEffective() then drain = drain + b.Light * self.stats.lightDrain end
	drain = (drain + self.swarmCoverage * b.SwarmDrain) * self.diff.battery
	if self.hasArtifact then drain = drain * b.ArtifactMult end
	self.battery = self.battery - drain * dt
	if self.battery <= 0 then
		self.battery = 0
		self.engineOn = false
		self:Kill("Battery")
	end
end

function Session:_updateLight(dt)
	if self.flickerOut > 0 then
		self.flickerOut = self.flickerOut - dt
	elseif self.lightOn and self.stats.flicker > 0 and self.rng() < 0.1 * self.stats.flicker * dt then
		self.flickerOut = 0.7
	end
end

function Session:_updateCracks(dt)
	local c = self.cfg.Cracks
	for _, crack in pairs(self.cracks) do crack.age = crack.age + dt end
	self.crackTimer = self.crackTimer - dt
	if self.crackTimer <= 0 then
		if self:CountCracks() < c.Max then self:AddCrack() end
		local depthFrac = clamp(self.depth / self.cfg.Cage.MaxDepth, 0, 1)
		self.crackTimer = c.Interval / (self.diff.crack * (1 + depthFrac)) * (0.7 + 0.6 * self.rng())
	end
end

function Session:_updatePlayers(dt)
	local oc = self.cfg.Outside
	local danger = self:OutsideDanger()
	for id, p in pairs(self.players) do
		if p.alive and p.outside then
			p.oxygen = p.oxygen - dt
			if p.oxygen <= 0 then
				self:KillPlayer(id, "Drowned")
			elseif danger then
				if p.dangerTime == 0 then self:Emit("OutsideDanger", { id = id }) end
				p.dangerTime = p.dangerTime + dt
				if p.dangerTime >= oc.DangerGrace * self.diff.reaction then
					self:KillPlayer(id, "Eaten")
				end
			else
				p.dangerTime = math.max(0, p.dangerTime - dt * 2)
			end
		end
	end
end

-- ---------------------------------------------------------------- player actions (all validated)

function Session:_player(id)
	local p = self.players[id]
	if p and p.alive then return p end
	return nil
end

function Session:SetPlayerSection(id, section)
	local p = self:_player(id)
	if p and not p.outside and (section == "Bow" or section == "Midship" or section == "Stern" or section == "Airlock") then
		p.section = section
	end
end

function Session:SetEngine(on)
	if self.phase == "Dead" or self.phase == "Won" then return false end
	self.engineOn = on and self.battery > 0
	return true
end

function Session:SetLight(on, yaw)
	self.lightOn = on and true or false
	if yaw then self.lightYaw = yaw % 360 end
	return true
end

function Session:Repair(id, crackId, dt)
	local p, crack = self:_player(id), self.cracks[crackId]
	if not p or not crack or p.outside or p.section ~= crack.section then return false end
	crack.progress = crack.progress + dt * self.stats.repair
	if crack.progress >= self.cfg.Cracks.RepairTime then
		self.cracks[crackId] = nil
		self:Emit("CrackRepaired", { id = crackId })
	end
	return true
end

function Session:GrabExtinguisher(id, extId)
	local p, ext = self:_player(id), self.extinguishers[extId]
	if not p or not ext or ext.holder or p.outside or p.section ~= ext.section then return false end
	self:DropExtinguisher(id)
	ext.holder, p.heldExt = id, extId
	return true
end

function Session:DropExtinguisher(id)
	local p = self.players[id]
	if not p or not p.heldExt then return false end
	local ext = self.extinguishers[p.heldExt]
	ext.holder = nil -- it returns to its wall mount
	p.heldExt = nil
	return true
end

function Session:Spray(id, dt)
	local p = self:_player(id)
	if not p or p.outside or not p.heldExt then return false end
	local ext = self.extinguishers[p.heldExt]
	if ext.charge <= 0 then return false end
	ext.charge = math.max(0, ext.charge - self.cfg.Extinguisher.SprayDrain * dt)
	for _, m in ipairs(self.monsters) do
		if m.OnSpray then m:OnSpray(p.section, dt) end
	end
	return true
end

function Session:Refill(id, dt)
	local p = self:_player(id)
	if not p or p.outside or p.section ~= "Stern" or not p.heldExt then return false end
	local ext = self.extinguishers[p.heldExt]
	local cap = self.cfg.Extinguisher.Capacity * self.stats.extCapacity
	ext.charge = math.min(cap, ext.charge + self.cfg.Extinguisher.RefillRate * dt)
	return true
end

function Session:ExitAirlock(id)
	local p = self:_player(id)
	if not p or p.outside or p.section ~= "Airlock" then return false end
	for _, other in pairs(self.players) do
		if other.outside then return false end -- the hatch only fits one diver
	end
	p.outside = true
	p.oxygen = self.cfg.Outside.Oxygen * self.stats.oxygen
	p.dangerTime = 0
	self:DropExtinguisher(id)
	self:Emit("DiverOut", { id = id })
	return true
end

function Session:EnterAirlock(id)
	local p = self:_player(id)
	if not p or not p.outside then return false end
	p.outside, p.section, p.dangerTime = false, "Airlock", 0
	self:Emit("DiverIn", { id = id })
	return true
end

function Session:Scrub(id, dt)
	local p = self:_player(id)
	if not p or not p.outside then return false end
	for _, m in ipairs(self.monsters) do
		if m.OnScrub then m:OnScrub(dt) end
	end
	return true
end

function Session:PickUpArtifact(id)
	local p = self:_player(id)
	if not p or p.outside or self.phase ~= "Bottom" then return false end
	self.hasArtifact = true
	self.phase = "Ascent"
	self.coast = 0
	self:Emit("ArtifactTaken", {})
	return true
end

-- ---------------------------------------------------------------- output

function Session:Result()
	local m = self.cfg.Money
	local won = self.phase == "Won"
	local money = math.floor(self.maxDepth * m.PerMeter * self.diff.money)
	if won then
		money = money + math.floor((m.SurviveBonus + m.ArtifactBonus) * self.diff.money)
	end
	return { survived = won, depth = math.floor(self.maxDepth), artifact = self.hasArtifact, money = money,
		reason = self.deathReason, time = math.floor(self.time), difficulty = self.diffName }
end

function Session:Snapshot()
	local monsters, cracks, players, exts = {}, {}, {}, {}
	for _, m in ipairs(self.monsters) do monsters[#monsters + 1] = m:Snapshot() end
	for _, c in pairs(self.cracks) do cracks[#cracks + 1] = { id = c.id, section = c.section } end
	for _, p in pairs(self.players) do
		players[#players + 1] = { id = p.id, section = p.section, alive = p.alive, outside = p.outside,
			oxygen = p.oxygen, held = p.heldExt }
	end
	for _, e in ipairs(self.extinguishers) do
		exts[#exts + 1] = { id = e.id, section = e.section, charge = e.charge, holder = e.holder }
	end
	return {
		phase = self.phase, time = self.time, depth = self.depth, speed = self.verticalSpeed,
		battery = self.battery / self.batteryMax, hull = self.hull / self.cfg.Cage.Hull,
		engineOn = self.engineOn, lightOn = self:LightEffective(), lightYaw = self.lightYaw,
		artifact = self.hasArtifact, monsters = monsters, cracks = cracks, players = players, extinguishers = exts,
	}
end

return Session
