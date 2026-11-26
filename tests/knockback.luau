local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local function load(name,environment)
	return luau.load(fs.readFile("src/ServerScriptService/"..name..".luau"),{
		injectGlobals=environment~=nil,environment=environment,
	})()
end
local Dive=load("DiveSimulation")
local Knockback=load("DiveKnockback")
local rng={NextNumber=function(_,minimum) return minimum or .15 end,NextInteger=function(_,minimum) return minimum end}
local mock={Name="The Knockback",GetAttribute=function() return true end}
local site={
	ShipEnvelope={Position=roblox.Vector3.zero},
	Ocean={["Trench floor"]={GetChildren=function() return {} end}},
	Contacts={FindFirstChild=function(_,name) return if name==mock.Name then mock else nil end},
}
local Sensors=load("DiveSensors",{workspace={WaitForChild=function() return site end,GetServerTimeNow=function() return 1 end}})

local function make(crew,difficulty)
	local s=Dive.new(difficulty,crew,{},rng)
	s.depth,s.deepest,s.sonarOn=4400,4400,true
	return s,Knockback.new(rng)
end
local function ping(s,k)
	assert(Sensors.pulse(s,{}) and #s.echoes==0,"Knockback cannot become a sonar echo")
	return k:pulse(s)
end

local s,k=make(1,"Nightmare")
s.jellyBloom=s.depth
k:update(s)
assert(k.stage=="Idle")
s.jellyBloom=nil
s.squid=.1
k:update(s)
assert(k.stage=="Idle","arrival must wait for a quiet encounter slot")
s.squid=0
k:update(s)
assert(k.stage=="Stalking" and ping(s,k)=="Knock")
s.sonarOn=false
s.elapsed=12
k:update(s)
assert(k.stage=="Done" and not s.knockbackSonar,"one warning and sustained silence prevents a strike")

for _,crew in {1,4} do
	s,k=make(crew,"Normal")
	k:update(s)
	for i=1,3 do
		s.elapsed=(i-1)*3.25
		s.echoes=nil
		assert(ping(s,k)=="Knock")
		s.sonarOn=false
		Sensors.pulse(s,{})
		s.sonarOn=true
		s.elapsed+=.5
		assert(ping(s,k)==nil,"power flickers must not reset or accelerate the approach")
	end
	s.elapsed=9.75
	s.echoes=nil
	assert(ping(s,k)=="Strike")
	assert(s.knockbackSonar=="Damaged" and not s.sonarOn and not s.systemsOffline)
	assert(not Sensors.pulse(s,{}) and not s.echoes)
	s.elapsed+=13.9
	assert(k:update(s)==nil and s.hull==100,"solo crew gets the full breaker window")
	s.elapsed+=.2
	assert(k:update(s)=="FirstRam")
	Dive.knockbackRam(s,true)
	assert(s.cracks[1] and s.hull==100 and not s.systemsOffline)
	s.elapsed+=11.1
	assert(k:update(s)=="Ram")
	Dive.knockbackRam(s,false)
	assert(s.hull==91)
	assert(k:breaker(s)=="Isolate" and k:breaker(s)==nil and s.knockbackSonar=="Isolated")
	s.elapsed+=3.1
	assert(k:update(s)=="Clear" and k:breaker(s)=="Reset" and not s.knockbackSonar)
	assert(s.cracks[1] and s.hull==91 and not s.sonarOn,"reset does not auto-start sonar or repair the hull")
	s.sonarOn=true
	assert(Sensors.pulse(s,{}) and #s.echoes==0)
end

print("PASS: invisible sonar, sustained silence, isolated outage, solo and crew rams, safe reset")
