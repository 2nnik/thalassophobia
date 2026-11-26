local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local dive=luau.load(fs.readFile("src/ServerScriptService/DiveSimulation.luau"))()
local roll=.3
local rng={
	NextInteger=function(_,_,hi) return hi end,
	NextNumber=function(_,lo,hi) return if lo==0 and hi==1 then roll else lo end,
}
local s=dive.new("Normal",1,{},rng)
s.depth,s.deepest,s.engine=3600,3600,false
s.nextThreat,s.nextCrack=math.huge,math.huge
assert(dive.spawn(s,"swarm"))
assert(table.concat(s.cleanSites,",")=="-1,-1,-1,0")
local first=s.nextFoulingPatch
dive.step(s,first-.25)
assert(table.concat(s.cleanSites,",")=="-1,-1,-1,0","additional patches must not spawn with the first")
dive.step(s,.25)
assert(table.concat(s.cleanSites,",")=="-1,-1,0,0","a successful area roll spawns exactly one colony")
roll=.95
dive.step(s,s.nextFoulingPatch-s.elapsed)
assert(table.concat(s.cleanSites,",")=="-1,-1,0,0","a missed roll leaves the area clean")

local folder={}
local site={ShipEnvelope={Position=roblox.Vector3.zero},Ocean={["Trench floor"]={GetChildren=function() return {} end}},BarnacleSites=folder}
site.Contacts={FindFirstChild=function() return nil end}
function folder:FindFirstChild(name)
	return {PrimaryPart={Position=roblox.Vector3.zero},GetAttribute=function() return name end}
end
local sensors=luau.load(fs.readFile("src/ServerScriptService/DiveSensors.luau"),{injectGlobals=true,
	environment={workspace={WaitForChild=function() return site end,GetServerTimeNow=function() return 1 end}},
})()
s.sonarOn=true
assert(sensors.pulse(s,{}) and #s.echoes==2 and s.echoes[1].label=="Site3" and s.echoes[2].label=="Site4")
s.cleanSites={-1,-1,3,3}
s.foulingCandidates=nil
local hull,exposure=s.hull,s.foulingExposure
dive.step(s,.25)
assert(s.hull==hull and s.foulingExposure==exposure and s.swarm==0)
s.echoes=nil
assert(sensors.pulse(s,{}) and #s.echoes==0,"inactive and cleared colonies never return an echo")
s.nextFoulingAt=s.elapsed+18
assert(not dive.spawn(s,"swarm"))
s.elapsed=s.nextFoulingAt
assert(dive.spawn(s,"swarm") and table.concat(s.cleanSites,",")=="-1,-1,-1,0","a new event can revisit a cleared site")
print("PASS: staggered area rolls, matching sonar entries, zero phantom damage, and clean recolonization")
