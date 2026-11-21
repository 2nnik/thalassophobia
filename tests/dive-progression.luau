local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Dive = luau.load(fs.readFile("src/ServerScriptService/DiveSimulation.luau"))()
local rng = {NextInteger = function(_, low) return low end, NextNumber = function(_, low) return low end}
local unlocks = {shark = 500, squid = 1250, crawler = 2000, swarm = 3000}
local dt = 0.25

for _, difficulty in {"Easy", "Normal", "Hard", "Nightmare"} do
	local s = Dive.new(difficulty, 1, {}, rng)
	assert(s.maxDepth == 10000)
	for name in unlocks do assert(not Dive.spawn(s, name)) end
	-- Ignore attack outcomes to isolate travel, but allow the actual spawner and
	-- power draw to run for an entire descent and ascent with sonar engaged.
	s.sonarOn = true
	local seen = {}
	local function tick()
		for name in unlocks do s[name] = 0 end
		s.cracks = {false, false, false}
		Dive.step(s, dt)
		for name, threshold in unlocks do
			if s[name] > 0 then
				assert(s.deepest >= threshold, name .. " appeared early")
				if not seen[name] then
					assert(s.depth < threshold + 3, name .. " missed its first milestone")
					seen[name] = true
				end
			end
		end
	end
	while s.phase == "Descent" and s.elapsed < 902 do tick() end
	assert(s.phase == "Bottom" and s.depth == 10000 and math.abs(s.elapsed - 900) <= dt)
	for name in unlocks do assert(seen[name]) end
	assert(not Dive.isUnlocked(s,"pursuer") and not Dive.reboard(s))
	assert(Dive.pickup(s) and not Dive.pickup(s))
	assert(s.phase=="Bottom" and not s.artifact and Dive.isUnlocked(s,"pursuer"))
	for _ = 1, 20 do tick() end
	assert(s.depth==10000 and s.phase=="Bottom" and s.pursuer>.2)
	assert(Dive.reboard(s) and s.artifact and s.phase=="Ascent")
	local boardedAt = s.elapsed
	while s.phase == "Ascent" and s.elapsed - boardedAt < 422 do tick() end
	assert(s.survived and s.depth == 0 and math.abs(s.elapsed - boardedAt - 420) <= dt)
	for name in unlocks do assert(Dive.isUnlocked(s, name)) end
	assert(s.battery > 17.5, "Sustained normal equipment use caused an unavoidable stall")
end

local s = Dive.new("Nightmare", 1, {}, rng)
s.engine = false
for _ = 1, 400 do
	s.cracks = {false, false, false}
	Dive.step(s, dt)
end
for name in unlocks do assert(s[name] == 0) end
assert(s.depth == 0, "Engine off should delay the first encounter")
assert(not Dive.pickup(s))

local late = Dive.new("Nightmare",1,{},rng)
late.phase,late.depth,late.deepest="Bottom",10000,10000
assert(Dive.pickup(late))
for _ = 1, 28 do Dive.step(late,dt) end
local deadline=late.recoveryDeadline
late.salvageTaken=false
assert(Dive.pickup(late) and late.recoveryDeadline==deadline)
for _ = 1, 28 do Dive.step(late,dt) end
assert(late.phase=="Results" and not late.artifact and not Dive.reboard(late))
print("PASS: four difficulties, milestone first sightings, 900 s down, timed exterior recovery, 420 s up and ascent unlocks")
