-- Exercise the controller's real launch, remote and clock handlers with a staggered crew.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local now, start, snapshots, ticks = 0, nil, {}, 0
local offline=false
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
local site={ShipEnvelope={},HullMotion={},CageSpawn={Position=roblox.Vector3.zero},FindFirstChild=function() return {CFrame=roblox.CFrame.identity} end}
local latestWeld
local function player()
	local root={Position=roblox.Vector3.zero}
	local character={HumanoidRootPart=root, PivotTo=function() end,
		FindFirstChild=function(_, name) return if name=="HumanoidRootPart" then root else nil end}
	return {Parent=players,Character=character}
end
local host,guest=player(),player()
local modules={
	DiveIntercom={start=function() return {wake=function() end,update=function() end,destroy=function() end} end},
	DiveMedical={start=function() return {remove=function() end,destroy=function() end} end},
	DiveParasite={start=function() return {step=function() end,destroy=function() end} end},
	DiveSimulation={
		new=function() return {difficulty="Easy",phase="Descent",depth=0,elapsed=0,battery=100,hull=100,swarm=0} end,
		step=function(s,dt) ticks+=1 s.elapsed+=dt s.systemsOffline=offline end,
	},
	DiveSensors={pulse=function() end},
	DiveWorld={update=function() end,travel=function() return roblox.Vector3.zero end,bindOpticsClick=function() end,
		squidBearing=function() return 1 end,setDepth=function() end},
	DiveLobby={trait=function() return "" end,init=function(callbacks) start=callbacks.start end},
	DiveExterior={init=function() end,snapshot=function() end,stopSwim=function() end,input=function() return false end},
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
		Instance={new=function(class)
			if class=="RemoteEvent" then return {OnServerEvent=signal()} end
			latestWeld={Destroy=function(self) self.Parent=nil end}
			return latestWeld
		end},
		task={delay=function() end}, Vector3=roblox.Vector3,CFrame=roblox.CFrame,typeof=type,os={clock=function() return now end},
	}, injectGlobals=true,
})
boot()
assert(start({host,guest},"Easy"))
local id=snapshots[host].intakeId
assert(snapshots[host].engine==false,"propulsion must be off at the start of a new dive")
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

local function opticsPrompt(action)
	local panel={Position=roblox.Vector3.zero}
	return {Enabled=true,Parent={IsA=function() return false end},MaxActivationDistance=6,
		IsDescendantOf=function() return true end,FindFirstAncestorWhichIsA=function() return panel end,
		GetAttribute=function() return action end}
end

local trigger=services.ProximityPromptService.PromptTriggered.fire
local lamp, camera=opticsPrompt("Light"),opticsPrompt("Camera")
send(host,"AimSearchlight",3)
assert(snapshots[host].aim==nil,"a player away from the console cannot aim the beam")
trigger(lamp,host)
assert(snapshots[host].searchlightView==true and not snapshots[host].light,"opening the console must not turn on the beam")
local lampHold=latestWeld
assert(lampHold.Name=="DiveOpticsHold" and lampHold.Part0==site.HullMotion and lampHold.Part1==host.Character.HumanoidRootPart,
	"the searchlight operator must be held to the moving hull")
for _,bad in {0,5,2.5,"3",0/0} do send(host,"AimSearchlight",bad) end
assert(snapshots[host].aim==nil,"invalid bearings must be rejected")
send(host,"AimSearchlight",3)
assert(snapshots[host].aim==3 and snapshots[host].light,"direct selection must aim and power the beam")
send(host,"AimSearchlight",4)
assert(snapshots[host].aim==4,"each valid click sets an absolute bearing")
send(host,"AimSearchlight",false)
assert(snapshots[host].aim==4 and not snapshots[host].light,"lamp off preserves the last bearing")
send(host,"CloseOptics")
assert(not snapshots[host].searchlightView and not lampHold.Parent,"exiting must release the operator")
trigger(camera,host)
assert(snapshots[host].cameraView and not snapshots[host].searchlightView)
local cameraHold=latestWeld
assert(cameraHold.Name=="DiveOpticsHold" and cameraHold.Part0==site.HullMotion)
send(host,"AimSearchlight",1)
assert(snapshots[host].aim==4 and not snapshots[host].light,"a camera session cannot move the searchlight")
send(host,"CloseOptics")
assert(not snapshots[host].cameraView)
heartbeat(.25)
heartbeat(.25)
trigger(camera,host)
assert(snapshots[host].cameraView)
cameraHold=latestWeld
offline=true
heartbeat(1)
assert(not snapshots[host].cameraView and not cameraHold.Parent,"power loss must close the camera console and release the operator")
heartbeat(.25)
trigger(lamp,host)
heartbeat(1)
assert(snapshots[host].searchlightView,"a breach must leave the lamp console available")
latestWeld:Destroy()
send(host,"AimSearchlight",1)
heartbeat(1)
assert(snapshots[host].aim==4 and not snapshots[host].searchlightView,"losing the console hold revokes beam control")
print("PASS: direct optics selection and server-owned searchlight")

local third,fourth=player(),player()
id=embark({host,guest,third,fourth})
send(host,"IntakeSkip",id)
assert(snapshots[host].skipVotes==0 and snapshots[host].skipNeeded==2)
send(host,"IntakeStarted",id)
send(host,"IntakeSkip",id+1)
assert(snapshots[host].skipVotes==0)
send(host,"IntakeSkip",id)
send(host,"IntakeSkip",id)
heartbeat(.25)
assert(snapshots[host].skipVotes==1 and ticks==0,"one voter cannot skip a four-person intro")
send(guest,"IntakeStarted",id)
send(guest,"IntakeSkip",id)
heartbeat(.25)
assert(ticks>0 and not snapshots[third].intakeId and not snapshots[fourth].intakeId and snapshots[host].engine==false)

id=embark({host})
send(host,"IntakeStarted",id)
send(host,"IntakeSkip",id)
heartbeat(.25)
assert(ticks>0 and not snapshots[host].intakeId,"Space can skip the solo intro")
print("PASS: intake skip needs half the crew, counts each player once, and keeps propulsion off")
