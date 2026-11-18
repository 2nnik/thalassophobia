-- The Pursuer (ascent only): closes in whenever the cage is not rising fast enough. Keep moving.
local Pursuer = {}
Pursuer.__index = Pursuer

function Pursuer.new(s)
	local self = setmetatable({ session = s, kind = "Pursuer", done = false, meter = 0, stage = 0 }, Pursuer)
	s:Emit("MonsterWarning", { kind = "Pursuer" })
	return self
end

function Pursuer:Update(dt)
	local s, c = self.session, self.session.cfg.Pursuer
	local minSpeed = c.MinSpeedFrac * s.cfg.Cage.AscentSpeed
	local v = s.verticalSpeed
	if v < minSpeed then
		local deficit = (minSpeed - math.max(v, 0)) / minSpeed
		self.meter = self.meter + c.FillRate * deficit * s.diff.monsterSpeed * s:SpeedScale(true) * dt
	else
		self.meter = math.max(0, self.meter - c.DrainRate * dt)
	end
	local stage = self.meter >= 66 and 2 or (self.meter >= 33 and 1 or 0)
	if stage ~= self.stage then
		self.stage = stage
		s:Emit("PursuerStage", { stage = stage })
	end
	if self.meter >= 100 then s:Kill("Pursuer") end
end

function Pursuer:OutsideDanger()
	return self.meter > 60
end

function Pursuer:Snapshot()
	return { kind = "Pursuer", state = tostring(self.stage), dist = 100 - self.meter, bearing = 180,
		progress = self.meter / 100 }
end

return Pursuer
