-- All state transitions and resource costs are evaluated by the server.
local Dive = {}
local TARGET_DEPTH = 600
local rules = {
	Easy = {pace = 0.80, damage = 0.78, power = 0.85},
	Normal = {pace = 1, damage = 1, power = 1},
	Hard = {pace = 1.28, damage = 1.18, power = 1.12},
}
local names = {"shark", "squid", "crawler", "swarm"}
local bearings = {"FORE", "STARBOARD", "AFT", "PORT"}

function Dive.new(difficulty, crewCount, traits, rng)
	return {
		phase = "Descent", difficulty = difficulty, rules = rules[difficulty] or rules.Normal,
		crewCount = crewCount, traits = traits, rng = rng or Random.new(), bag = {},
		depth = 0, maxDepth = TARGET_DEPTH, deepest = 0, battery = 100, hull = 100,
		sonarOn = false, nextPing = 0, engine = true, light = false, aim = 1, cracks = {false, false, false},
		shark = 0, squid = 0, crawler = 0, swarm = 0, pursuer = 0,
		squidSide = 1, crawlerSection = 1, boarded = false, artifact = false,
		coast = 0, sharkPass = 0, repelled = 0, catchup = 0, elapsed = 0,
		nextThreat = 13, nextCrack = 23, warning = "Descent underway. Listen for contacts.",
		warningUntil = 7, 
	}
end

function Dive.warn(s, message, duration)
	s.warning, s.warningUntil = message, s.elapsed + (duration or 4)
end

local function crack(s)
	local slots = {}
	for index, open in s.cracks do
		if not open then table.insert(slots, index) end
	end
	if #slots == 0 then return end
	local index = slots[s.rng:NextInteger(1, #slots)]
	s.cracks[index] = true
	Dive.warn(s, "Hull fracture in section 0" .. index .. ". Seal the leak.")
end

function Dive.endRun(s, survived, reason, sequence)
	if s.phase == "Results" then return end
	s.phase, s.survived, s.reason = "Results", survived, reason
	s.sequence = sequence
end

function Dive.spawn(s, name)
	if s[name] > 0 then return false end
	s[name] = 0.015
	if name == "shark" then
		s.sharkPass = 0
		Dive.warn(s, "Angler closing on engine noise. Cut propulsion until it passes.", 6)
	elseif name == "squid" then
		s.squidSide = s.patrolSquidSide or s.rng:NextInteger(1, 4)
		s.repelled = 0
		Dive.warn(s, "Squid silhouette to " .. bearings[s.squidSide] .. ". Train the lamp on it.", 6)
	elseif name == "crawler" then
		s.boarded = false
		local open = {}
		for i,value in s.cracks do if value then table.insert(open,i) end end
		s.crawlerSection = #open>0 and open[s.rng:NextInteger(1,#open)] or s.rng:NextInteger(1,3)
		Dive.warn(s, "Scraping on the hull. Seal open fractures.", 5)
	elseif name == "swarm" then
		s.foulingExposure, s.floodWarned = 0, false
		Dive.warn(s, "Barnacles spreading across four hull faces. Check sonar before exiting.", 6)
	end
	return true
end

local function drawContact(s)
	if #s.bag == 0 then
		s.bag = table.clone(names)
		for i = #s.bag, 2, -1 do
			local j = s.rng:NextInteger(1, i)
			s.bag[i], s.bag[j] = s.bag[j], s.bag[i]
		end
	end
	for i = #s.bag, 1, -1 do
		if s[s.bag[i]] == 0 then
			Dive.spawn(s, table.remove(s.bag, i))
			return
		end
	end
end

local function contacts(s, dt, pace)
	if s.shark > 0 then
		s.shark = math.min(1, s.shark + dt * pace / (s.traits.Baffle and 14 or 11) * (s.artifact and 1.12 or 1))
		if s.shark >= 0.93 then
			if s.engine then
				s.hull -= 34 * s.rules.damage
				if s.hull <= 0 then
					Dive.endRun(s,false,"The angler swallowed the damaged cage.","Angler")
					return
				end
				crack(s)
				s.shark = 0
				Dive.warn(s, "Angler impact. Inspect the hull.", 5)
			else
				s.sharkPass += dt
				if s.sharkPass >= 2.6 then
					s.shark = 0
					Dive.warn(s, "Angler passed. Restart propulsion.")
				end
			end
		end
	end
	if s.squid > 0 then
		if s.light and s.aim == s.squidSide then
			s.repelled += dt
			s.squid = math.max(0.015, s.squid - dt * 0.14)
			if s.repelled >= (s.traits.Optics and 1.9 or 2.8) then
				s.squid = 0
				Dive.warn(s, "Squid retreating. Conserve the lamp.")
			end
		else
			s.squid += dt * pace / 24
			s.repelled = math.max(0, s.repelled - dt / 2)
			if s.squid >= 1 then
				Dive.endRun(s,false,"The giant squid split the cage.","Squid")
				return
			end
		end
	end
	if s.crawler > 0 and not s.victim then
		s.crawler += dt * pace / (s.boarded and 26 or 17)
		if not s.boarded and s.crawler >= 0.47 then
			if not s.cracks[s.crawlerSection] then
				s.crawler = 0
				Dive.warn(s, "Crawler contact fading. The seals held.")
			else
				s.boarded = true
				Dive.warn(s, "Boarder in section 0" .. s.crawlerSection .. ". Use the extinguisher.", 7)
			end
		elseif s.crawler >= 1 then
			s.hull -= 26 * s.rules.damage
			s.battery -= 5
			s.crawler, s.boarded = 0, false
			Dive.warn(s, "The boarder tore through a power conduit.")
		end
	end
	if s.swarm > 0 then
		s.swarm = math.min(1, s.swarm + dt * pace / 18)
		local remaining = 1
		for _,cuts in s.cleanSites or {} do remaining -= cuts/12 end
		s.battery -= dt * remaining * s.swarm * 0.22 * s.rules.power
		s.hull -= dt * remaining * s.swarm * 0.17 * s.rules.damage
		s.foulingExposure = (s.foulingExposure or 0) + dt * remaining * s.swarm * pace
		if s.foulingExposure >= 36 then
			Dive.endRun(s,false,"Barnacle growth tore open the hull. The angler followed the wreck.","Flood")
			return
		elseif s.foulingExposure >= 24 and not s.floodWarned then
			s.floodWarned = true
			Dive.warn(s,"Hull buckling under growth. Clear the colonies before it ruptures.",8)
		elseif s.hull <= 0 then
			Dive.endRun(s,false,"The fouled hull ruptured. The angler followed the wreck.","Flood")
			return
		end
	end
end

function Dive.pickup(s)
	if s.phase ~= "Bottom" then return end
	s.artifact, s.phase, s.coast = true, "Ascent", 2.7
	s.pursuer = 0.035
	s.nextThreat = math.min(s.nextThreat, s.elapsed + 9)
	Dive.warn(s, "Artifact secured. Keep climbing. Something is following below.", 7)
end

function Dive.scan(s)
	local hits = {}
	if s.shark > 0 then table.insert(hits, s.shark > 0.65 and "ANGLER CLOSE / SILENCE" or "ANGLER INBOUND") end
	if s.squid > 0 then table.insert(hits, "SQUID / " .. bearings[s.squidSide]) end
	if s.crawler > 0 then table.insert(hits, s.boarded and "BOARDER / 0"..s.crawlerSection or "CRAWLER / OUTER HULL") end
	if s.swarm > 0 then table.insert(hits, "FOULING / OUTER HULL") end
	if s.pursuer > 0 then table.insert(hits, "DEEP CONTACT / " .. (s.pursuer > 0.45 and "CLOSING" or "TRAILING")) end
	return #hits > 0 and table.concat(hits, "   •   ") or "Clear water. No contacts in range."
end

function Dive.step(s, dt)
	if s.phase == "Results" then return end
	s.elapsed += dt
	if s.elapsed > s.warningUntil then s.warning = "" end
	local ascent = s.phase == "Ascent"
	local pace = s.rules.pace * (0.72 + 0.095 * (s.crewCount - 1)) * (ascent and 1.27 or 1)
	local depthRatio = s.depth / TARGET_DEPTH
	if s.elapsed >= s.nextCrack then
		crack(s)
		s.nextCrack = s.elapsed + s.rng:NextNumber(23, 31) / (pace * (1 + depthRatio * 0.25))
	end
	if s.elapsed >= s.nextThreat then
		drawContact(s)
		s.nextThreat = s.elapsed + s.rng:NextNumber(17, 24) / (pace * (1 + depthRatio * 0.25))
	end
	local leaks = 0
	for _, open in s.cracks do if open then leaks += 1 end end
	s.hull -= leaks * dt * 0.105 * s.rules.damage
	s.battery -= dt * (0.077 + (s.engine and 0.196 or 0) + (s.light and 0.46 or 0) + (s.sonarOn and 0.046 or 0)) * s.rules.power / (s.traits.Battery and 1.15 or 1)
	contacts(s, dt, pace)
	if s.phase == "Results" then return end
	if s.battery <= 0 then Dive.endRun(s, false, "The cage lost its last reserve of power.") return end
	if s.hull <= 0 then Dive.endRun(s, false, "The pressure hull collapsed.") return end
	local efficiency = math.min(1, 0.62 + s.hull * 0.006) * math.min(1, 0.65 + s.battery * 0.02)
	local speed = (ascent and 4.9 or 6) * efficiency * (s.traits.Baffle and 0.95 or 1)
	if ascent then
		if s.engine then s.coast = 2.7 else s.coast = math.max(0, s.coast - dt) end
		local thrust = s.engine and 1 or 0.62 * s.coast / 2.7
		s.depth = math.max(0, s.depth - speed * thrust * dt)
		if s.engine and efficiency > 0.72 then
			s.catchup = math.max(0, s.catchup - dt * 0.095)
		elseif s.coast <= 0 or s.engine then
			s.catchup += dt * pace * (s.engine and 0.018 or 0.064)
		end
		s.pursuer = 0.035 + 0.965 * math.min(1, s.catchup)
		if s.catchup >= 1 then Dive.endRun(s, false, "The Pursuer caught the stalled cage.") 
		elseif s.depth <= 0 then Dive.endRun(s, true, "The cage surfaced with the artifact.") end
	elseif s.phase == "Descent" and s.engine then
		s.depth = math.min(TARGET_DEPTH, s.depth + speed * dt)
		s.deepest = math.max(s.deepest, s.depth)
		if s.depth >= TARGET_DEPTH then
			s.phase = "Bottom"
			Dive.warn(s, "Seabed reached. Recover the artifact at the salvage hatch.", 12)
		end
	end
end

return Dive
