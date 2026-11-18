-- Leviathan Shark: hunts by sound. Kill the engine while it is near.
local Shark = {}
Shark.__index = Shark

function Shark.new(s)
	local c = s.cfg.Shark
	local self = setmetatable({ session = s, kind = "Shark", done = false, state = "Warning",
		timer = c.Warning * s.diff.reaction, nearTimer = 0, engineOnTimer = 0 }, Shark)
	s:Emit("MonsterWarning", { kind = "Shark" })
	return self
end

function Shark:Update(dt)
	local s, c = self.session, self.session.cfg.Shark
	if self.state == "Warning" then
		self.timer = self.timer - dt
		if self.timer <= 0 then
			self.state, self.nearTimer, self.engineOnTimer = "Near", c.NearTime, 0
			s:Emit("SharkNear", {})
		end
	elseif self.state == "Near" then
		self.nearTimer = self.nearTimer - dt
		if s.engineOn then
			self.engineOnTimer = self.engineOnTimer + dt
			if self.engineOnTimer >= c.Reaction * s.diff.reaction * s.stats.sharkReaction then
				s:DamageHull(c.Damage, "Shark")
				s:AddCracks(c.CracksOnHit)
				s:Emit("SharkAttack", {})
				self.engineOnTimer = -c.AttackCooldown
			end
		else
			self.engineOnTimer = 0
		end
		if self.nearTimer <= 0 then
			self.state, self.timer = "Leaving", 3
			s:Emit("SharkLeft", {})
		end
	else
		self.timer = self.timer - dt
		if self.timer <= 0 then self.done = true end
	end
end

function Shark:OutsideDanger()
	return self.state == "Near"
end

function Shark:Snapshot()
	local c = self.session.cfg.Shark
	local dist = 15
	if self.state == "Warning" then
		dist = 15 + 65 * math.max(self.timer, 0) / (c.Warning * self.session.diff.reaction)
	elseif self.state == "Leaving" then
		dist = 15 + 20 * (3 - math.max(self.timer, 0))
	end
	return { kind = "Shark", state = self.state, dist = dist, bearing = (self.session.time * 30) % 360 }
end

return Shark
