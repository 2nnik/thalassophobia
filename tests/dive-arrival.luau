-- Exercise the controller's real launch, remote and clock handlers with a staggered crew.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local now, start, snapshots, ticks = 0, nil, {}, 0
local function signal()
	return {Connect=function(self, fn) self.fire=fn end}
end
local players={PlayerAdded=signal(), PlayerRemoving=signal(), GetPlayers=function() return {} end}
local runService={Heartbeat=signal()}
local feed={FireClient=function(_,p,kind,payload)
	if kind=="Dive" then snapshots[p]=payload end
end}
local input={OnServerEvent=signal()}
local net={Input=input, WaitForChild=function() return feed end}
local site={ShipEnvelope={},CageSpawn={Position=roblox.Vector3.zero},FindFirstChild=function() return {CFrame=roblox.CFrame.identity} end}
local function player()
	local root={Position=roblox.Vector3.zero}
	local character={HumanoidRootPart=root, PivotTo=function() end,
		FindFirstChild=function(_, name) return if name=="HumanoidRootPart" then root else nil end}
	return {Parent=players,Character=character}
end
local host,guest=player(),player()
local modules={
	DiveSimulation={
		new=function() return {difficulty="Easy",phase="Descent",depth=0,elapsed=0,battery=100,hull=100,swarm=0} end,
		step=function(s,dt) ticks+=1 s.elapsed+=dt end,
	},
	DiveSensors={pulse=function() end},
	DiveWorld={update=function() end,travel=function() return roblox.Vector3.zero end,
		squidBearing=function() return 1 end,setDepth=function() end},
	DiveLobby={trait=function() return "" end,init=function(callbacks) start=callbacks.start end},
	DiveExterior={init=function() end,snapshot=function() end,stopSwim=function() end},
}
local services={Players=players,RunService=runService,
	ReplicatedStorage={WaitForChild=function() return net end},
	ProximityPromptService={PromptTriggered=signal(),PromptButtonHoldBegan=signal(),PromptButtonHoldEnded=signal()},
	PhysicsService={RegisterCollisionGroup=function() end,CollisionGroupSetCollidable=function() end}}
local boot=luau.load(fs.readFile("src/ServerScriptService/DiveController.server.luau"),{
	environment={
		game={GetService=function(_,name) return services[name] end},
		workspace={WaitForChild=function() return site end},
		script={Parent={WaitForChild=function(_,name) return name end}},
		require=function(name) return modules[name] or {} end,
		Instance={new=function() return {Destroy=function(self) self.Parent=nil end} end},
		task={delay=function() end}, Vector3=roblox.Vector3,CFrame=roblox.CFrame,typeof=type,os={clock=function() return now end},
	}, injectGlobals=true,
})
boot()
assert(start({host,guest},"Easy"))
local id=snapshots[host].intakeId
assert(type(id)=="number" and snapshots[guest].intakeId==id,"crew must receive a run-specific opening")
local function heartbeat(seconds)
	now+=seconds
	runService.Heartbeat.fire(.25)
end
local function send(p,action,token) input.OnServerEvent.fire(p,action,token) end
heartbeat(32)
assert(ticks==0,"slow loading must not spend dive time")
send(host,"IntakeStarted",id)
send(host,"IntakeFinished",id)
heartbeat(3)
assert(ticks==0,"premature completion must not advance the ship")
send(guest,"IntakeStarted",id)
send(guest,"IntakeFinished",id+1)
heartbeat(20)
assert(ticks==0,"first ready player must wait for crew")
send(guest,"IntakeFinished",id)
heartbeat(3)
heartbeat(.25)
assert(ticks>0 and not snapshots[host].intakeId and not snapshots[guest].intakeId,"completed crew should start descending")

local function embark(crew)
	now,ticks=0,0
	boot()
	assert(start(crew,"Easy"))
	return snapshots[host].intakeId
end
id=embark({host,guest})
send(host,"IntakeStarted",id)
heartbeat(22.7)
send(host,"IntakeFinished",id)
heartbeat(.25)
assert(ticks==0)
heartbeat(46)
assert(ticks>0 and not snapshots[host].intakeId and snapshots[guest].intakeId==id,"a stalled transfer must not strand the crew")
send(guest,"IntakeStarted",id)
heartbeat(2)
assert(snapshots[guest].intakeId==id,"a late loader still receives the whole scene")
send(guest,"IntakeFinished",id)
heartbeat(21)
assert(not snapshots[guest].intakeId)

id=embark({host,guest})
send(host,"IntakeStarted",id)
heartbeat(23)
send(host,"IntakeFinished",id)
players.PlayerRemoving.fire(guest)
heartbeat(.25)
assert(ticks>0 and not snapshots[host].intakeId,"disconnected members must not block departure")

id=embark({host})
send(host,"IntakeStarted",id)
heartbeat(22)
send(host,"IntakeFinished",id)
heartbeat(.25)
assert(ticks==0)
heartbeat(.5)
assert(ticks>0 and not snapshots[host].intakeId)
print("PASS: solo and staggered crew openings, minimum presentation time, stale messages, late loading and disconnect")
