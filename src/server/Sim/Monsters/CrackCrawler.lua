-- Crack Crawler: squeezes in through an unrepaired crack. Spray it with an extinguisher in whichever
-- section it is in. If it is not driven out it kills someone.
local Crawler = {}
Crawler.__index = Crawler

local function oldestUnclaimed(s)
	local best
	for _, crack in pairs(s.cracks) do
		if not crack.claimed and crack.age >= s.cfg.Crawler.MinCrackAge and (not best or crack.age > best.age) then
			best = crack
		end
	end
	return best
end

function Crawler.canSpawn(s)
	return oldestUnclaimed(s) ~= nil
end

function Crawler.new(s)
	local c = s.cfg.Crawler
	local crack = oldestUnclaimed(s)
	crack.claimed = true
	local self = setmetatable({ session = s, kind = "Crawler", done = false, state = "Scratching", crackId = crack.id,
		section = crack.section, timer = c.Warning * s.diff.reaction, killTimer = 0, moveTimer = 0, spray = 0 }, Crawler)
	s:Emit("MonsterWarning", { kind = "Crawler", section = crack.section })
	return self
end

function Crawler:_release()
	local crack = self.session.cracks[self.crackId]
	if crack then crack.claimed, crack.age = false, 0 end
end

function Crawler:Update(dt)
	local s, c = self.session, self.session.cfg.Crawler
	if self.state == "Scratching" then
		if not s.cracks[self.crackId] then
			s:Emit("CrawlerGaveUp", {})
			self.done = true
			return
		end
		self.timer = self.timer - dt
		if self.timer <= 0 then
			self.state = "Inside"
			self.killTimer = c.KillTime * s.diff.reaction
			self.moveTimer = c.MoveTime
			s:Emit("CrawlerEntered", { section = self.section })
		end
	elseif self.state == "Inside" then
		self.killTimer = self.killTimer - dt
		self.moveTimer = self.moveTimer - dt
		if not self.sprayedNow then self.spray = math.max(0, self.spray - c.SprayDecay * dt) end
		self.sprayedNow = false
		if self.moveTimer <= 0 then
			local adj = s.cfg.Adjacent[self.section]
			self.section = adj[math.floor(s.rng() * #adj) + 1]
			self.moveTimer = c.MoveTime
			s:Emit("CrawlerMoved", { section = self.section })
		end
		if self.killTimer <= 0 then
			local here, any = {}, {}
			for id, p in pairs(s.players) do
				if p.alive and not p.outside then
					any[#any + 1] = id
					if p.section == self.section then here[#here + 1] = id end
				end
			end
			local pool = #here > 0 and here or any
			if #pool > 0 then s:KillPlayer(pool[math.floor(s.rng() * #pool) + 1], "Crawler") end
			self.killTimer = c.KillTime * s.diff.reaction
		end
	else
		self.timer = self.timer - dt
		if self.timer <= 0 then
			self:_release()
			self.done = true
		end
	end
end

function Crawler:OnSpray(section, dt)
	if self.state ~= "Inside" or section ~= self.section then return end
	self.spray = self.spray + dt
	self.sprayedNow = true
	if self.spray >= self.session.cfg.Crawler.SprayNeeded then
		self.state, self.timer = "Leaving", 2
		self.session:Emit("CrawlerLeft", {})
	end
end

function Crawler:Snapshot()
	return { kind = "Crawler", state = self.state, section = self.section,
		progress = self.spray / self.session.cfg.Crawler.SprayNeeded }
end

return Crawler
