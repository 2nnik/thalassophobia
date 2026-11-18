-- Hull Swarm: clings to the outside, blinding the light and draining power. A diver must go out and scrub it off.
local Swarm = {}
Swarm.__index = Swarm

function Swarm.new(s)
	local self = setmetatable({ session = s, kind = "Swarm", done = false, coverage = 0.05 }, Swarm)
	s.swarmCoverage = self.coverage
	s:Emit("MonsterWarning", { kind = "Swarm" })
	return self
end

function Swarm:Update(dt)
	local s, c = self.session, self.session.cfg.Swarm
	if not self.scrubbedNow then -- it stops spreading while a diver is scrubbing
		self.coverage = math.min(1, self.coverage + dt / (c.GrowTime / (s.diff.monsterSpeed * s:SpeedScale())))
	end
	self.scrubbedNow = false
	s.swarmCoverage = self.coverage
	self:_checkDone()
end

function Swarm:OnScrub(dt)
	self.scrubbedNow = true
	self.coverage = self.coverage - dt / self.session.cfg.Swarm.ClearTime
	self.session.swarmCoverage = math.max(self.coverage, 0)
	self:_checkDone()
end

function Swarm:_checkDone()
	if self.coverage <= 0 and not self.done then
		self.coverage = 0
		self.session.swarmCoverage = 0
		self.session:Emit("SwarmCleared", {})
		self.done = true
	end
end

function Swarm:Snapshot()
	return { kind = "Swarm", state = "Attached", coverage = self.coverage, dist = 0, bearing = 0 }
end

return Swarm
