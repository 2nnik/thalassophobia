-- Giant Squid: creeps closer in the dark. Keep the light on it to push it back; too close and the cage is crushed.
local Squid = {}
Squid.__index = Squid

function Squid.new(s)
	local c = s.cfg.Squid
	local self = setmetatable({ session = s, kind = "Squid", done = false, dist = c.StartDist,
		bearing = s.rng() * 360, stage = "Far" }, Squid)
	s:Emit("MonsterWarning", { kind = "Squid" })
	return self
end

function Squid:_stageFor(d)
	local c = self.session.cfg.Squid
	if d > c.Far then return "Far" elseif d > c.Near then return "Near" elseif d > c.VeryNear then return "VeryNear" end
	return "Lethal"
end

function Squid:Update(dt)
	local s, c = self.session, self.session.cfg.Squid
	if s:IsLit(self.bearing) then
		self.dist = self.dist + c.PushSpeed * dt
	else
		self.dist = self.dist - c.CloseSpeed * s.diff.monsterSpeed * s:SpeedScale() * dt
	end
	self.bearing = (self.bearing + (s.rng() - 0.5) * 2 * c.Drift * dt) % 360
	local stage = self:_stageFor(self.dist)
	if stage ~= self.stage then
		self.stage = stage
		s:Emit("SquidStage", { stage = stage })
	end
	if self.dist <= 0 then
		s:Kill("Squid")
	elseif self.dist >= c.RetreatDist then
		s:Emit("SquidLeft", {})
		self.done = true
	end
end

function Squid:OutsideDanger()
	return self.dist < self.session.cfg.Squid.Near + 5
end

function Squid:Snapshot()
	return { kind = "Squid", state = self.stage, dist = self.dist, bearing = self.bearing }
end

return Squid
