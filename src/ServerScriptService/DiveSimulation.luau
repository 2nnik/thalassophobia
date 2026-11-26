-- All state transitions and resource costs are evaluated by the server.
local Dive = {}
local TARGET_DEPTH = 10000
local DESCENT_RATE = TARGET_DEPTH / (15 * 60)
local ASCENT_RATE = TARGET_DEPTH / (7 * 60)
local RECOVERY_WINDOW = {Easy = 22, Normal = 19, Hard = 16, Nightmare = 14}
local ANGLER_APPROACH = {Easy = 27, Normal = 24, Hard = 21, Nightmare = 18}
local CRAWLER_APPROACH = {Easy = 13, Normal = 11, Hard = 9.5, Nightmare = 8}
local CRAWLER_ENTRY = .47
Dive.targetDepth = TARGET_DEPTH
local MAX_BREACH = 3
local PRESSURE_START_DEPTH = 500
local SECOND_PRESSURE_LEAK_DEPTH = 6000
local rules = {
	Easy = {pace = 0.80, damage = 0.78, power = 0.85, anglerStrikes = 3, squidSqueezes = 4, squeezeInterval = 7},
	Normal = {pace = 1, damage = 1, power = 1, anglerStrikes = 2, squidSqueezes = 3, squeezeInterval = 6},
	Hard = {pace = 1.28, damage = 1.18, power = 1.12, anglerStrikes = 1, squidSqueezes = 2, squeezeInterval = 5},
	Nightmare = {pace = 1.48, damage = 1.38, power = 1.26, anglerStrikes = 1, squidSqueezes = 1, squeezeInterval = 4},
}
local names = {"shark", "squid", "crawler", "swarm"}
local firstDepth = {shark = 500, squid = 1250, crawler = 2000, swarm = 3000}
local patchChance={Easy=.23,Normal=.33,Hard=.43,Nightmare=.53}
local bearings = {"FORE", "STARBOARD", "AFT", "PORT"}
local squidSections = {1, 3, 3, 2}

function Dive.new(difficulty, crewCount, traits, rng)
	return {
		phase = "Descent", difficulty = difficulty, rules = rules[difficulty] or rules.Normal,
		crewCount = crewCount, traits = traits, rng = rng or Random.new(), bag = {},
		depth = 0, maxDepth = TARGET_DEPTH, deepest = 0, battery = 100, hull = 100,
		sonarOn = false, nextPing = 0, engine = true, light = false, aim = 1, cracks = {false, false, false},
		breaches = {0, 0, 0}, breachCauses = {}, systemsOffline = false,
		shark = 0, squid = 0, crawler = 0, swarm = 0, pursuer = 0,
		anglerStrikes = 0, squidSqueezes = 0, squidLatched = false, squeezeRemaining = 0,
		squidSide = 1, crawlerSection = 1, boarded = false, artifact = false,
		coast = 0, sharkPass = 0, repelled = 0, catchup = 0, elapsed = 0,
		nextInfestation = math.huge,
		nextThreat = math.huge, pressureExposure = 0, nextCrack = 110, warning = "Descent underway. Listen for contacts.",
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

local function openBreach(s, cause, preferred)
	local section = preferred or 1
	if not preferred or s.breaches[section] >= MAX_BREACH then
		for i, severity in s.breaches do
			if severity < s.breaches[section] then section = i end
		end
	end
	s.breaches[section] = math.min(MAX_BREACH, s.breaches[section] + 1)
	s.breachCauses[section] = cause
	s.systemsOffline, s.sonarOn, s.echoes, s.pingAt, s.nextPing = true, false, nil, nil, 0
	Dive.warn(s, string.format("%s breach in section %02d. Patch it with a plank. Cameras and sonar offline.", cause, section), 8)
end

function Dive.patchBreach(s, section)
	if s.phase == "Results" or not s.breaches[section] or s.breaches[section] == 0 then return false end
	s.breaches[section] -= 1
	if s.breaches[section] == 0 then s.breachCauses[section] = nil end
	s.hull = math.min(100, s.hull + 11)
	s.systemsOffline = s.breaches[1] + s.breaches[2] + s.breaches[3] > 0
	Dive.warn(s, if s.systemsOffline then "Plank secured. Other breaches remain." else "Hull sealed. Cameras and sonar are available.", 5)
	return true
end

function Dive.isUnlocked(s, name)
	if name == "pursuer" then return s.recoveryDeadline ~= nil end
	local threshold = firstDepth[name]
	return threshold ~= nil and s.deepest >= threshold
end

function Dive.spawn(s, name)
	if s.jellyBloom or s.knockbackActive then return false end
	if name == "crawler" and s.crawlerRetreat then return false end
	if name=="swarm" and s.elapsed<(s.nextFoulingAt or 0) then return false end
	if not firstDepth[name] or not Dive.isUnlocked(s, name) or s[name] > 0 then return false end
	s[name] = 0.015
	if name == "shark" then
		s.sharkPass = 0
		Dive.warn(s, "Angler closing on engine noise. Cut propulsion until it passes.", 9)
	elseif name == "squid" then
		s.squidSide = s.patrolSquidSide or s.rng:NextInteger(1, 4)
		s.repelled, s.squidSqueezes, s.squidLatched, s.squeezeRemaining = 0, 0, false, 0
		Dive.warn(s, "Squid silhouette to " .. bearings[s.squidSide] .. ". Train the lamp on it.", 6)
	elseif name == "crawler" then
		s.boarded = false
		s.crawlerStartedAt, s.crawlerBoardAt, s.crawlerEntryWarning = s.elapsed, nil, false
		local open = {}
		for i,value in s.cracks do if value then table.insert(open,i) end end
		s.crawlerSection = #open>0 and open[s.rng:NextInteger(1,#open)] or s.rng:NextInteger(1,3)
		Dive.warn(s, string.format("Worms outside section %02d. Check the window seal.",s.crawlerSection), 7)
	elseif name == "swarm" then
		s.foulingExposure, s.floodWarned = 0, false
		s.cleanSites={-1,-1,-1,-1}
		s.foulingCandidates={1,2,3,4}
		local first=table.remove(s.foulingCandidates,s.rng:NextInteger(1,4))
		s.cleanSites[first]=0
		s.nextFoulingPatch=s.elapsed+s.rng:NextNumber(11,20)
		Dive.warn(s, "Barnacle growth detected. Check sonar for its location.", 6)
	end
	return true
end

local function drawContact(s)
	if #s.bag == 0 then
		for _, name in names do
			if Dive.isUnlocked(s, name) then table.insert(s.bag, name) end
		end
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

function Dive.knockbackRam(s,first)
	if s.jellyBloom or s.knockbackSonar~="Damaged" then return end
	if first then
		crack(s)
	else
		s.hull=math.max(0,s.hull-9*s.rules.damage)
		if s.hull<=0 then Dive.endRun(s,false,"Repeated impacts collapsed the pressure hull.","Flood") end
	end
end

local function nextContact(s, pace)
	return s.elapsed + s.rng:NextNumber(36, 52) / (pace * (1 + s.depth / TARGET_DEPTH * 0.25))
end

local function introduceContacts(s, previousDepth, pace)
	for _, name in names do
		if previousDepth < firstDepth[name] and Dive.isUnlocked(s, name) then
			Dive.spawn(s, name)
			table.clear(s.bag)
			s.nextThreat = nextContact(s, pace)
			if name == "crawler" and s.difficulty == "Nightmare" then
				s.nextInfestation = s.elapsed + 8
			end
		end
	end
end

local function squeeze(s)
	s.squidSqueezes += 1
	s.squidLatched = true
	s.squeezeRemaining = s.rules.squeezeInterval
	local damage = 17 * s.rules.damage
	if s.squidSqueezes >= s.rules.squidSqueezes or (s.squidSqueezes > 1 and s.hull <= damage) then
		Dive.endRun(s, false, "The giant squid split the cage.", "Squid")
		return
	end
	-- Initial contact in the standard modes always leaves a window to repel it.
	s.hull -= math.min(damage, math.max(0, s.hull - 1))
	openBreach(s, "Squid", squidSections[s.squidSide])
end

local function contacts(s, dt, pace)
	if s.shark > 0 then
		local seconds = (ANGLER_APPROACH[s.difficulty] or ANGLER_APPROACH.Normal) + (s.traits.Baffle and 5 or 0)
		s.shark = math.min(1, s.shark + dt * .915 / seconds)
		if s.shark >= 0.93 then
			if s.engine then
				s.anglerStrikes += 1
				s.hull -= 34 * s.rules.damage
				if s.anglerStrikes >= s.rules.anglerStrikes or s.hull <= 0 then
					Dive.endRun(s,false,"The angler swallowed the damaged cage.","Angler")
					return
				end
				s.shark = 0
				openBreach(s, "Angler")
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
				s.squid, s.squidLatched = 0, false
				Dive.warn(s, "Squid retreating. Conserve the lamp.")
			end
		else
			s.repelled = math.max(0, s.repelled - dt / 2)
			if s.squidLatched then
				s.squid = 1
				s.squeezeRemaining -= dt
				if s.squeezeRemaining <= 0 then squeeze(s) end
			else
				s.squid = math.min(1, s.squid + dt * pace / 24)
				if s.squid >= 1 then squeeze(s) end
			end
		end
	end
	if s.phase == "Results" then return end
	if s.crawler > 0 and not s.victim then
		local approach=CRAWLER_APPROACH[s.difficulty] or CRAWLER_APPROACH.Normal
		local approachingFor=s.elapsed-(s.crawlerStartedAt or s.elapsed)
		s.crawler=if s.boarded then s.crawler+dt*pace/26 else .015+(CRAWLER_ENTRY-.015)*math.min(1,approachingFor/approach)
		if not s.boarded and approachingFor>=approach then
			s.crawlerEntryWarning=false
			if not s.cracks[s.crawlerSection] then
				s.crawler = 0
				Dive.warn(s, "Crawler contact fading. The seals held.")
			else
				s.boarded, s.crawlerBoardAt = true, s.elapsed
				Dive.warn(s, "Boarder in section 0" .. s.crawlerSection .. ". Use the extinguisher.", 7)
			end
		elseif not s.boarded and approachingFor>=approach-4
			and not s.crawlerEntryWarning and s.cracks[s.crawlerSection] then
			s.crawlerEntryWarning=true
			Dive.warn(s, string.format("Worms at the open window in section %02d. Seal it now!",s.crawlerSection), 5)
		elseif s.crawler >= 1 then
			s.hull -= 26 * s.rules.damage
			s.battery -= 5
			s.crawler, s.boarded = 0, false
			Dive.warn(s, "The boarder tore through a power conduit.")
		end
	end
	if s.swarm > 0 then
		local candidates=s.foulingCandidates
		if candidates and #candidates>0 and s.elapsed>=s.nextFoulingPatch then
			local index=table.remove(candidates,s.rng:NextInteger(1,#candidates))
			if s.rng:NextNumber(0,1)<(patchChance[s.difficulty] or patchChance.Normal) then
				s.cleanSites[index]=0
			end
			s.nextFoulingPatch=s.elapsed+s.rng:NextNumber(11,20)
		end
		local remaining=0
		for _,cuts in s.cleanSites or {} do
			if cuts>=0 and cuts<3 then remaining+=(3-cuts)/12 end
		end
		if remaining==0 then
			s.swarm,s.foulingCandidates=0,nil
			return
		end
		s.swarm = math.min(1, s.swarm + dt * pace / 18)
		s.battery -= dt * remaining * s.swarm * 0.09 * s.rules.power
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
	if s.phase ~= "Bottom" or s.salvageTaken then return false end
	s.salvageTaken = true
	if not s.recoveryDeadline then
		s.recoveryWindow = RECOVERY_WINDOW[s.difficulty] or RECOVERY_WINDOW.Normal
		s.recoveryDeadline = s.elapsed + s.recoveryWindow
		s.pursuer = 0.035
	end
	Dive.warn(s, "Something woke up. Get the artifact back through the airlock!", 9)
	return true
end

function Dive.reboard(s)
	if s.phase ~= "Bottom" or not s.salvageTaken or s.elapsed >= s.recoveryDeadline then return false end
	s.artifact, s.phase = true, "Ascent"
	s.coast = if s.engine then 2.7 else 0
	s.catchup = math.min(0.52, s.pursuer * 0.55)
	s.nextThreat = math.min(s.nextThreat, s.elapsed + 9)
	Dive.warn(s, "Artifact aboard. Keep the engine running and outrun the Pursuer.", 7)
	return true
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
	if s.phase == "Bottom" and s.recoveryDeadline then
		local progress = 1 - (s.recoveryDeadline - s.elapsed) / s.recoveryWindow
		s.pursuer = 0.035 + 0.965 * math.clamp(progress, 0, 1)
		if s.elapsed >= s.recoveryDeadline then
			Dive.endRun(s, false, "The Pursuer reached the ship before the artifact was brought aboard.")
			return
		end
	end
	local pace = s.rules.pace * (0.72 + 0.095 * (s.crewCount - 1)) * (ascent and 1.27 or 1)
	local depthRatio = s.depth / TARGET_DEPTH
	if s.jellyBloom or s.knockbackActive then
		s.nextThreat+=dt
		s.nextInfestation+=dt
	elseif s.elapsed >= s.nextThreat then
		drawContact(s)
		s.nextThreat = nextContact(s, pace)
	end
	if not s.jellyBloom and not s.knockbackActive and s.elapsed >= s.nextInfestation then
		local first = if s.rng:NextInteger(1, 2) == 1 then "crawler" else "swarm"
		if not Dive.spawn(s, first) then Dive.spawn(s, if first == "crawler" then "swarm" else "crawler") end
		s.nextInfestation = s.elapsed + s.rng:NextNumber(8, 12) / (1 + depthRatio * .25)
	end
	local cracks, breaches, breachCause = 0, 0, nil
	for i, open in s.cracks do
		if open then cracks += 1 end
		breaches += s.breaches[i]
		breachCause = s.breachCauses[i] or breachCause
	end
	local ambientLimit=if s.depth>=SECOND_PRESSURE_LEAK_DEPTH then 2 else 1
	if s.depth>=PRESSURE_START_DEPTH and cracks<ambientLimit and breaches==0 then
		-- Accumulate exposure at the current depth, so ascending immediately eases pressure.
		local pressure=(s.depth-PRESSURE_START_DEPTH)/(TARGET_DEPTH-PRESSURE_START_DEPTH)
		s.pressureExposure+=dt*s.rules.pace*(.82+1.23*pressure)
		if s.pressureExposure>=s.nextCrack then
			crack(s)
			cracks+=1
			s.pressureExposure=0
			s.nextCrack=s.rng:NextNumber(100,124)
		end
	end
	s.hull -= (cracks * .105 + breaches * .32) * dt * s.rules.damage
	if s.hull <= 0 then
		Dive.endRun(s,false,"The pressure hull collapsed.",if breachCause == "Angler" then "Flood" else breachCause)
		return
	end
	-- A continuous round trip uses 52.8% at Normal before lighting, sonar and contacts.
	s.battery -= dt * (0.012 + (s.engine and 0.028 or 0) + (s.light and 0.09 or 0) + (s.sonarOn and 0.008 or 0)) * s.rules.power / (s.traits.Battery and 1.15 or 1)
	if not s.jellyBloom then contacts(s, dt, pace) end
	if s.phase == "Results" then return end
	if s.battery <= 0 then Dive.endRun(s, false, "The cage lost its last reserve of power.") return end
	if s.hull <= 0 then Dive.endRun(s, false, "The pressure hull collapsed.") return end
	local efficiency = math.min(1, 0.62 + s.hull * 0.006) * math.min(1, 0.65 + s.battery * 0.02)
	local speed = (ascent and ASCENT_RATE or DESCENT_RATE) * efficiency * (s.traits.Baffle and 0.95 or 1)
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
		local previousDepth = s.deepest
		s.depth = math.min(TARGET_DEPTH, s.depth + speed * dt)
		s.deepest = math.max(s.deepest, s.depth)
		if s.deepest > previousDepth then introduceContacts(s, previousDepth, pace) end
		if s.depth >= TARGET_DEPTH then
			s.phase = "Bottom"
			Dive.warn(s, "Seabed reached. Take the airlock and follow the beacon down to the artifact.", 12)
		end
	end
end

return Dive
