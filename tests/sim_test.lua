local H = ...
local Config = H.require(H.node("src/shared/Config"))
local Session = H.require(H.node("src/server/Sim/Session"))
local Shark = H.require(H.node("src/server/Sim/Monsters/Shark"))
local Squid = H.require(H.node("src/server/Sim/Monsters/Squid"))
local Crawler = H.require(H.node("src/server/Sim/Monsters/CrackCrawler"))
local Swarm = H.require(H.node("src/server/Sim/Monsters/Swarm"))

local function copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copy(v) end
	return out
end

local failed, passed = 0, 0
local function test(name, fn)
	math.randomseed(12345)
	local ok, err = pcall(fn)
	if ok then passed = passed + 1; print("ok   " .. name)
	else failed = failed + 1; print("FAIL " .. name .. "\n     " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end

local function run(s, seconds, step)
	step = step or 0.1
	for _ = 1, math.floor(seconds / step) do s:Tick(step) end
end
local function crew(n, traits)
	local list = {}
	for i = 1, n do list[i] = { id = i, traits = traits or {} } end
	return list
end
-- A session with random monsters/cracks switched off, so a scenario is isolated.
local function quiet(n, difficulty)
	local s = Session.new(Config, { difficulty = difficulty or "Normal", players = crew(n or 4), noDirector = true })
	s.crackTimer = 1e9
	return s
end
local function addMonster(s, m) s.monsters[#s.monsters + 1] = m; return m end

test("descent reaches the bottom and waits for the artifact", function()
	local s = quiet()
	run(s, 305)
	eq(s.phase, "Bottom")
	eq(s.depth, Config.Cage.MaxDepth)
end)

test("artifact pickup starts the ascent and spawns the Pursuer", function()
	local s = Session.new(Config, { players = crew(4) })
	s.crackTimer = 1e9
	s.depth, s.phase = Config.Cage.MaxDepth, "Bottom"
	truthy(s:PickUpArtifact(1))
	eq(s.phase, "Ascent")
	s:Tick(0.1)
	local found = false
	for _, m in ipairs(s.monsters) do if m.kind == "Pursuer" then found = true end end
	truthy(found, "Pursuer should exist on the ascent")
end)

test("artifact can only be taken at the bottom", function()
	local s = quiet()
	eq(s:PickUpArtifact(1), false)
end)

test("a clean run with no monsters is survivable and pays out", function()
	local s = quiet()
	run(s, 305)
	s:PickUpArtifact(1)
	run(s, 420)
	eq(s.phase, "Won", "phase after the ascent (battery " .. math.floor(s.battery) .. ")")
	local r = s:Result()
	truthy(r.survived and r.artifact)
	eq(r.money, math.floor(1500 * 0.5) + 500)
end)

test("dying pays money per depth reached only", function()
	local s = quiet()
	run(s, 100)
	s:Kill("Test")
	local r = s:Result()
	eq(r.survived, false)
	eq(r.money, math.floor(s.maxDepth * 0.5))
end)

test("battery at zero kills the crew", function()
	local s = quiet()
	s.battery = 0.01
	run(s, 1)
	eq(s.phase, "Dead"); eq(s.deathReason, "Battery")
end)

test("light drains battery faster", function()
	local a, b = quiet(), quiet()
	b:SetLight(true, 0)
	run(a, 10); run(b, 10)
	truthy(b.battery < a.battery - 4, "light should cost ~5 units over 10s")
end)

test("Pursuer kills a cage that stops on the ascent", function()
	local s = Session.new(Config, { players = crew(4), noDirector = true })
	s.crackTimer = 1e9
	s.depth, s.phase = 1000, "Bottom"
	s:PickUpArtifact(1)
	local Pursuer = H.require(H.node("src/server/Sim/Monsters/Pursuer"))
	addMonster(s, Pursuer.new(s))
	s:SetEngine(false)
	run(s, 40)
	eq(s.phase, "Dead"); eq(s.deathReason, "Pursuer")
end)

test("a short coast with the engine off is survivable, long stops are not", function()
	local s = Session.new(Config, { players = crew(4), noDirector = true })
	s.crackTimer = 1e9
	s.depth, s.phase = 1000, "Bottom"
	s:PickUpArtifact(1)
	local Pursuer = H.require(H.node("src/server/Sim/Monsters/Pursuer"))
	local p = addMonster(s, Pursuer.new(s))
	s:SetEngine(true); run(s, 2)
	s:SetEngine(false); run(s, 6)
	s:SetEngine(true); run(s, 30)
	truthy(s.phase ~= "Dead", "short coast should not kill")
	truthy(p.meter < 30, "meter should drain once moving again, got " .. p.meter)
end)

test("Shark: engine on while near hurts the hull and adds cracks", function()
	local s = quiet()
	s:Tick(0.1)
	addMonster(s, Shark.new(s))
	run(s, 6 + 4 + 1)
	truthy(s.hull < 100, "hull should be damaged")
	truthy(s:CountCracks() >= 2)
end)

test("Shark: killing the engine in time avoids all damage", function()
	local s = quiet()
	addMonster(s, Shark.new(s))
	run(s, 6.5)
	s:SetEngine(false)
	run(s, 20)
	eq(s.hull, 100)
	eq(#s.monsters, 0, "shark should have left")
end)

test("Shark: two hits destroy the hull", function()
	local s = quiet()
	addMonster(s, Shark.new(s))
	run(s, 40)
	eq(s.phase, "Dead"); eq(s.deathReason, "Shark")
end)

test("Squid: unlit it closes in and crushes the cage", function()
	local s = quiet()
	addMonster(s, Squid.new(s))
	run(s, 60)
	eq(s.phase, "Dead"); eq(s.deathReason, "Squid")
end)

test("Squid: tracking it with the light pushes it away", function()
	local s = quiet()
	local sq = addMonster(s, Squid.new(s))
	s:SetLight(true, sq.bearing)
	local steps = 0
	while #s.monsters > 0 and steps < 2000 do
		s:SetLight(true, sq.bearing)
		s:Tick(0.1)
		steps = steps + 1
	end
	eq(#s.monsters, 0, "squid should retreat")
	truthy(s.phase ~= "Dead")
end)

test("Squid: light aimed the wrong way does nothing", function()
	local s = quiet()
	local sq = addMonster(s, Squid.new(s))
	s:SetLight(true, (sq.bearing + 180) % 360)
	local start = sq.dist
	run(s, 5)
	truthy(sq.dist < start)
end)

test("Crawler: needs an old unclaimed crack", function()
	local s = quiet()
	s:AddCrack("Bow")
	eq(Crawler.canSpawn(s), false)
	run(s, 16)
	eq(Crawler.canSpawn(s), true)
end)

test("Crawler: repairing the crack in time makes it give up", function()
	local s = quiet()
	local id = s:AddCrack("Midship")
	run(s, 16)
	addMonster(s, Crawler.new(s))
	s:SetPlayerSection(1, "Midship")
	for _ = 1, 50 do s:Repair(1, id, 0.1); s:Tick(0.1) end
	eq(s:CountCracks(), 0)
	run(s, 1)
	eq(#s.monsters, 0)
end)

test("Crawler: spraying it in the right section drives it out", function()
	local s = quiet()
	s:AddCrack("Stern"); run(s, 16)
	local c = addMonster(s, Crawler.new(s))
	run(s, 8.5)
	eq(c.state, "Inside")
	s:SetPlayerSection(1, "Stern"); s:GrabExtinguisher(1, 3)
	c.section = "Stern"
	for _ = 1, 60 do s:Spray(1, 0.1); s:Tick(0.1) end
	truthy(c.state == "Leaving" or c.done, "crawler should leave, state " .. c.state)
	run(s, 3)
	eq(#s.monsters, 0)
end)

test("Crawler: spraying the wrong section does nothing", function()
	local s = quiet()
	s:AddCrack("Stern"); run(s, 16)
	local c = addMonster(s, Crawler.new(s))
	run(s, 8.5)
	c.section = "Stern"
	s:SetPlayerSection(1, "Bow"); s:GrabExtinguisher(1, 1)
	for _ = 1, 60 do s:Spray(1, 0.1) end
	eq(c.state, "Inside")
end)

test("Crawler: left alone it kills a player", function()
	local s = quiet()
	s:AddCrack("Bow"); run(s, 16)
	addMonster(s, Crawler.new(s))
	run(s, 8 + 26)
	eq(s:AliveCount(), 3)
end)

test("Extinguisher runs dry and refills at the stern", function()
	local s = quiet()
	s:SetPlayerSection(1, "Bow"); s:GrabExtinguisher(1, 1)
	for _ = 1, 100 do s:Spray(1, 0.1) end
	eq(s.extinguishers[1].charge, 0)
	eq(s:Spray(1, 0.1), false)
	s:SetPlayerSection(1, "Stern")
	for _ = 1, 30 do s:Refill(1, 0.1) end
	truthy(s.extinguishers[1].charge > 100 - 1)
end)

test("Swarm: drains battery and blinds the light until scrubbed off", function()
	local s = quiet()
	local sw = addMonster(s, Swarm.new(s))
	s:SetLight(true, 0)
	run(s, 70)
	truthy(sw.coverage >= 0.99)
	eq(s:LightEffective(), false)
	s:SetPlayerSection(1, "Airlock")
	truthy(s:ExitAirlock(1))
	for _ = 1, 140 do s:Scrub(1, 0.1); s:Tick(0.1) end
	eq(#s.monsters, 0, "swarm should be gone")
	eq(s.swarmCoverage, 0)
end)

test("Swarm: only one diver at a time, and only from the airlock", function()
	local s = quiet()
	eq(s:ExitAirlock(1), false)
	s:SetPlayerSection(1, "Airlock"); s:SetPlayerSection(2, "Airlock")
	truthy(s:ExitAirlock(1))
	eq(s:ExitAirlock(2), false)
end)

test("Diver outside while the shark is near dies", function()
	local s = quiet()
	s:SetPlayerSection(1, "Airlock"); s:ExitAirlock(1)
	addMonster(s, Shark.new(s))
	run(s, 6.5 + 3)
	eq(s.players[1].alive, false)
	eq(s.phase, "Descent", "the rest of the crew survives")
end)

test("Diver can come back inside before the danger window ends", function()
	local s = quiet()
	s:SetPlayerSection(1, "Airlock"); s:ExitAirlock(1)
	addMonster(s, Shark.new(s))
	run(s, 6.5 + 1)
	truthy(s:EnterAirlock(1))
	run(s, 5)
	truthy(s.players[1].alive)
end)

test("Diver runs out of oxygen", function()
	local s = quiet()
	s:SetPlayerSection(1, "Airlock"); s:ExitAirlock(1)
	run(s, 46)
	eq(s.players[1].alive, false)
end)

test("Disconnecting does not kill the run", function()
	local s = quiet()
	s:RemovePlayer(2)
	eq(s:AliveCount(), 3)
	eq(s.phase, "Descent")
end)

test("Everyone dead ends the run", function()
	local s = quiet(2)
	s:KillPlayer(1, "x"); s:KillPlayer(2, "x")
	eq(s.phase, "Dead")
end)

test("Director spawns stacking threats over a descent", function()
	local s = Session.new(Config, { players = crew(4), noDirector = false })
	s.crackTimer = 1e9
	local seen, maxConcurrent = {}, 0
	for _ = 1, 3000 do
		s:Tick(0.1)
		-- keep the crew alive so we only measure spawning
		s.hull, s.battery = 100, s.batteryMax
		for _, m in ipairs(s.monsters) do seen[m.kind] = true; if m.kind == "Squid" then m.dist = 90 end end
		if #s.monsters > maxConcurrent then maxConcurrent = #s.monsters end
		if s.phase == "Dead" then s.phase = "Descent"; s.deathReason = nil end
	end
	local n = 0 for _ in pairs(seen) do n = n + 1 end
	truthy(n >= 2, "expected several monster kinds, saw " .. n)
end)

test("Solo is calmer than a full crew; ascent is busier than descent", function()
	local function rate(n, phase)
		local s = Session.new(Config, { players = crew(n) })
		s.phase, s.depth, s.maxDepth = phase, 750, 750
		return s.director:Rate()
	end
	truthy(rate(1, "Descent") < rate(4, "Descent"))
	truthy(rate(4, "Ascent") > rate(4, "Descent") * 1.5)
end)

test("Harder difficulties are busier and pay more", function()
	local function rate(d)
		local s = Session.new(Config, { difficulty = d, players = crew(4) })
		s.depth = 750
		return s.director:Rate()
	end
	truthy(rate("Easy") < rate("Normal") and rate("Normal") < rate("Hard") and rate("Hard") < rate("Nightmare"))
	truthy(Config.Difficulties.Hard.money > Config.Difficulties.Normal.money)
end)

test("Pursuer + shark conflict: killing the engine to hide still has a cost", function()
	local s = Session.new(Config, { players = crew(4), noDirector = true })
	s.crackTimer = 1e9
	s.depth, s.phase = 1000, "Bottom"
	s:PickUpArtifact(1)
	local Pursuer = H.require(H.node("src/server/Sim/Monsters/Pursuer"))
	local p = addMonster(s, Pursuer.new(s))
	addMonster(s, Shark.new(s))
	run(s, 7)
	s:SetEngine(false)
	run(s, 14)
	truthy(p.meter > 0, "pursuer should gain while the engine is off")
	eq(s.hull, 100)
end)

test("Traits: effects apply once crew-wide, drawbacks included", function()
	local s = Session.new(Config, { players = {
		{ id = 1, traits = { "battery_cell", "wide_beam" } },
		{ id = 2, traits = { "battery_cell" } } } })
	eq(s.batteryMax, 390)
	eq(s.stats.flicker, 1)
	truthy(s.stats.lightCone > 1.39 and s.stats.lightDrain > 1.19)
end)

test("Flicker trait cuts the light now and then", function()
	local s = Session.new(Config, { players = { { id = 1, traits = { "battery_cell" } } }, noDirector = true })
	s.crackTimer = 1e9
	s:SetLight(true, 0)
	local out = 0
	for _ = 1, 3000 do s:Tick(0.1); s.battery = s.batteryMax; if not s:LightEffective() then out = out + 1 end end
	truthy(out > 0, "light never flickered")
end)

test("Snapshot is plain data", function()
	local s = Session.new(Config, { players = crew(2) })
	addMonster(s, Shark.new(s))
	local snap = s:Snapshot()
	eq(type(snap.monsters[1].dist), "number")
	eq(#snap.players, 2)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
