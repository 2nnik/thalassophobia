-- Decides when monsters spawn. Tension builds over time (faster when deeper, on the ascent, with more players
-- and on harder difficulties); spawns may stack so several monsters attack at once.
local Monsters = script.Parent.Monsters
local KINDS = {
	Shark = require(Monsters.Shark),
	Squid = require(Monsters.Squid),
	Crawler = require(Monsters.CrackCrawler),
	Swarm = require(Monsters.Swarm),
}
local Pursuer = require(Monsters.Pursuer)

local Director = {}
Director.__index = Director
Director.Kinds = KINDS

function Director.new(session)
	return setmetatable({ session = session, tension = 0, sinceLast = 0, pursuerSpawned = false }, Director)
end

function Director:Rate()
	local s = self.session
	local depthFrac = math.min(s.depth / s.cfg.Cage.MaxDepth, 1)
	local rate = s.cfg.Director.BaseRate * (0.5 + depthFrac) * s.diff.monsterRate * s:PlayerScale()
	if s.phase == "Ascent" then rate = rate * s.diff.ascent end
	return rate
end

function Director:Active(kind)
	for _, m in ipairs(self.session.monsters) do
		if m.kind == kind then return true end
	end
	return false
end

function Director:CountActive()
	local n = 0
	for _, m in ipairs(self.session.monsters) do
		if m.kind ~= "Pursuer" then n = n + 1 end
	end
	return n
end

function Director:Pick()
	local s = self.session
	local cfg = s.cfg.Director
	local options, total = {}, 0
	for kind, module in pairs(KINDS) do
		local allowed = s.maxDepth >= cfg.Unlock[kind] and not self:Active(kind)
		if allowed and module.canSpawn and not module.canSpawn(s) then allowed = false end
		if allowed then
			options[#options + 1] = { kind = kind, w = cfg.Weights[kind] }
			total = total + cfg.Weights[kind]
		end
	end
	if total == 0 then return nil end
	local roll = s.rng() * total
	for _, o in ipairs(options) do
		roll = roll - o.w
		if roll <= 0 then return o.kind end
	end
	return options[#options].kind
end

function Director:Spawn(kind)
	local s = self.session
	s.monsters[#s.monsters + 1] = KINDS[kind].new(s)
end

function Director:Update(dt)
	local s = self.session
	local cfg = s.cfg.Director
	if s.phase == "Ascent" and not self.pursuerSpawned then
		self.pursuerSpawned = true
		s.monsters[#s.monsters + 1] = Pursuer.new(s)
	end
	self.sinceLast = self.sinceLast + dt
	self.tension = self.tension + self:Rate() * dt
	local cap = (s.phase == "Ascent") and cfg.MaxConcurrentAscent or cfg.MaxConcurrent
	if self.tension >= 1 and self.sinceLast >= cfg.MinGap and self:CountActive() < cap then
		local kind = self:Pick()
		if kind then
			self:Spawn(kind)
			self.tension, self.sinceLast = 0, 0
			if s.rng() < cfg.OverlapChance and self:CountActive() < cap then
				local second = self:Pick()
				if second then self:Spawn(second) end
			end
		end
	end
end

return Director
