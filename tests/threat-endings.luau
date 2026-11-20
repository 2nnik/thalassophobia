local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Dive = luau.load(fs.readFile("src/ServerScriptService/DiveSimulation.luau"))()
local rng = {NextInteger = function(_, low) return low end, NextNumber = function(_, low) return low end}
local function fresh()
	local s = Dive.new("Normal", 1, {}, rng)
	s.nextThreat, s.nextCrack = math.huge, math.huge
	return s
end

local s = fresh()
s.shark, s.hull = .94, 20
Dive.step(s,.25)
assert(s.phase=="Results" and s.sequence=="Angler" and not s.survived)
s = fresh()
s.shark, s.hull, s.engine = .94, 20, false
Dive.step(s,.25)
assert(s.phase=="Descent" and s.hull==20)

s = fresh()
s.squid = 1
Dive.step(s,.25)
assert(s.phase=="Results" and s.sequence=="Squid")

s = fresh()
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
print("PASS: angler impact vs engine cutoff, squid fracture, fouling rupture vs cleared patches, crawler hold")
