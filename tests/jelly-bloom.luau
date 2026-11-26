local fs=require("@lune/fs")
local luau=require("@lune/luau")
local function load(name)
	return luau.load(fs.readFile("src/ServerScriptService/"..name..".luau"))()
end
local Dive=load("DiveSimulation")
local Bloom=load("DiveJellyBloom")
local quiet={NextNumber=function(_,low) return low or .1 end,NextInteger=function(_,low) return low end}
local noSpawn={NextNumber=function() return .8 end}

local function dive()
	local s=Dive.new("Normal",1,{},quiet)
	s.depth,s.deepest=4000,4000
	s.nextThreat,s.nextInfestation=8,8
	return s
end

local s=dive()
Bloom.new(noSpawn):update(s)
assert(s.jellyBloom==nil,"a bloom should not occur on every run")
local bloom=Bloom.new(quiet)
s.squid=.6
bloom:update(s)
assert(s.jellyBloom==nil,"a bloom must not appear during an attack")
s.squid=0
bloom:update(s,{isBusy=function() return true end})
assert(s.jellyBloom==nil,"an active or incubating parasite postpones the bloom")
bloom:update(s)
assert(s.jellyBloom==4000)

local before=s.nextThreat
for _=1,90 do
	Dive.step(s,.25)
	assert(s.shark==0 and s.squid==0 and s.swarm==0 and s.crawler==0)
	assert(not Dive.spawn(s,"shark"),"explicit monster spawn requests must also respect the bloom")
end
assert(s.nextThreat==before+22.5 and s.nextInfestation==before+22.5)
assert(s.depth>4000 and s.depth<4460,"the ship should keep descending through the bloom")
s.depth=4460
bloom:update(s)
assert(s.jellyBloom==nil and Dive.spawn(s,"shark"),"threats resume beyond the bloom")
s.shark=0
bloom:update(s)
assert(s.jellyBloom==nil,"the event is limited to one per run")

s=dive()
bloom=Bloom.new(quiet)
bloom:update(s)
s.engine=false
s.elapsed=86
bloom:update(s)
assert(s.jellyBloom==nil,"leaving propulsion off cannot make the grace period permanent")

s=dive()
s.phase="Ascent"
Bloom.new(quiet):update(s)
assert(s.jellyBloom==nil,"the bloom must not interrupt the pursuit on ascent")

luau.compile(fs.readFile("src/StarterPlayerScripts/DiveJellyBloomView.luau"))
print("PASS: rare bloom, quiet entry, paused threats, continuous descent, and depth/time exit")
