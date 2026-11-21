local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Dive = luau.load(fs.readFile("src/ServerScriptService/DiveSimulation.luau"))()
local rng = {NextInteger = function(_, low) return low end, NextNumber = function(_, low) return low end}
local function fresh(difficulty)
	local s = Dive.new(difficulty or "Normal", 1, {}, rng)
	s.nextThreat, s.nextCrack, s.nextInfestation = math.huge, math.huge, math.huge
	return s
end

for difficulty, approach in {Easy=27, Normal=24, Hard=21, Nightmare=18} do
	local warning = fresh(difficulty)
	warning.deepest,warning.depth = 500,500
	warning.crewCount = 4
	assert(Dive.spawn(warning,"shark"))
	for _ = 1, approach*4-1 do Dive.step(warning,.25) end
	assert(warning.shark<.93 and warning.anglerStrikes==0, "The angler attacked before the warning window elapsed.")
	warning.engine=false
	for _ = 1, 13 do Dive.step(warning,.25) end
	assert(warning.shark==0 and warning.anglerStrikes==0 and warning.phase=="Descent")
end

local s = fresh()
s.shark, s.hull = .94, 20
Dive.step(s,.25)
assert(s.phase=="Results" and s.sequence=="Angler" and not s.survived)
s = fresh()
s.shark, s.hull, s.engine = .94, 20, false
Dive.step(s,.25)
assert(s.phase=="Descent" and s.hull==20)

s = fresh("Easy")
s.shark = .94
Dive.step(s,.25)
s.hull = .01
Dive.step(s,.25)
assert(s.phase=="Results" and s.sequence=="Flood","An angler breach that later collapses should play the wreck ending")

for difficulty, strikes in {Easy=3,Normal=2,Hard=1,Nightmare=1} do
	s = fresh(difficulty)
	s.sonarOn,s.echoes,s.light = true,{},true
	for strike = 1,strikes do
		s.shark = .94
		Dive.step(s,.25)
		assert(s.anglerStrikes==strike)
		if strike<strikes then
			assert(s.phase=="Descent" and s.systemsOffline and not s.sonarOn and not s.echoes)
			assert(s.light,"A breach took the searchlight offline")
			assert(s.breaches[strike]==1)
		else
			assert(s.phase=="Results" and s.sequence=="Angler")
		end
	end
end

s = fresh("Easy")
s.shark,s.cracks[1]=.94,true
Dive.step(s,.25)
local damagedHull = s.hull
assert(Dive.patchBreach(s,1))
assert(not s.systemsOffline and s.cracks[1] and s.hull>damagedHull)
assert(not Dive.patchBreach(s,1) and not Dive.patchBreach(s,4))
s.shark=.94
Dive.step(s,.25)
assert(s.phase=="Descent" and s.anglerStrikes==2,"Patching reset the difficulty's strike limit")

for difficulty, fatalSqueeze in {Easy=4,Normal=3,Hard=2,Nightmare=1} do
	s = fresh(difficulty)
	s.squid = 1
	Dive.step(s,.25)
	assert(s.squidSqueezes==1)
	if fatalSqueeze==1 then
		assert(s.phase=="Results" and s.sequence=="Squid")
	else
		assert(s.phase=="Descent" and s.squidLatched and s.systemsOffline)
		local elapsed = 0
		while s.phase~="Results" and elapsed<25 do Dive.step(s,.25) elapsed+=.25 end
		assert(s.phase=="Results" and s.sequence=="Squid" and s.squidSqueezes==fatalSqueeze)
	end
end

s = fresh("Hard")
s.squid=1
Dive.step(s,.25)
s.light,s.aim = true,s.squidSide
for _ = 1,12 do Dive.step(s,.25) end
assert(s.squid==0 and not s.squidLatched and s.systemsOffline,"The searchlight should dislodge, not repair")

s = Dive.new("Nightmare",1,{},rng)
s.depth,s.deepest=3000,3000
s.nextThreat,s.nextCrack,s.nextInfestation = math.huge,math.huge,0
Dive.step(s,.25)
assert(s.crawler>0 and s.nextInfestation>=s.elapsed)
s.nextInfestation=s.elapsed
Dive.step(s,.25)
assert(s.swarm>0,"Nightmare's second ambient roll should allow overlapping infestations")

s = fresh()
s.depth,s.deepest=3000,3000
Dive.spawn(s,"swarm")
s.swarm, s.foulingExposure, s.cleanSites = 1,35.98,{0,0,0,0}
Dive.step(s,.25)
assert(s.phase=="Results" and s.sequence=="Flood")
s = fresh()
s.swarm, s.foulingExposure, s.cleanSites = 1,35.98,{3,3,3,3}
Dive.step(s,.25)
assert(s.phase=="Descent" and s.foulingExposure==35.98)

s = fresh()
s.crawler,s.boarded,s.victim=.99,true,{}
Dive.step(s,.25)
assert(s.boarded and s.crawler==.99,"A pinned crawler must wait for rescue or timeout")
print("PASS: difficulty strike limits, staged squid damage, repair/lockout, Nightmare infestations, fouling and crawler hold")
