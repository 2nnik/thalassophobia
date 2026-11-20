local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local server = script.Parent
local function loadModule(name)
	return require(server:WaitForChild(name))
end
local Voyage, EVA, Lobby = loadModule("Voyage"), loadModule("DiveEVA"), loadModule("DiveLobby")
local world = workspace:FindFirstChild("DiveWorld")
if not world then
	local builder=server:FindFirstChild("DiveWorldBuilder")
	world = if builder then require(builder).build() else loadModule("DiveFixture").build()
end
local function markers(folder)
	local map={}
	for _,p in ipairs(folder:GetChildren()) do if p:IsA("BasePart") then map[p.Name]=p end end
	return map
end
local stations,sites=markers(world.Stations),markers(world.Sites)
local net=Instance.new("Folder")
net.Name="DiveNet"
local function remote(name)
	local r=Instance.new("RemoteEvent")
	r.Name,r.Parent=name,net
	return r
end
local input,output=remote("Action"),remote("Snapshot")
local run,lobby
local notices,cameras,limits,results={},{},{},{}
local function clock() return workspace:GetServerTimeNow() end
local function move(p,marker)
	local c=p.Character
	if c and c:FindFirstChild("HumanoidRootPart") then c:PivotTo(marker.CFrame+Vector3.new((p.UserId%3-1)*2,2,0)) end
end
local function launch(crew,difficulty,equipped)
	if run or #crew<1 or #crew>4 then return false end
	local members,traits={},{}
	for _,p in ipairs(crew) do
		if p.Parent~=Players then return false end
		members[p.UserId]=true
		if equipped[p.UserId] then traits[equipped[p.UserId]]=true end
	end
	local ship=world.ShipOrigin.CFrame
	local v=Voyage.new(difficulty,#crew,traits,ship)
	v.sites={}
	for site,marker in pairs(sites) do v.sites[site]=marker.Position end
	run={id=Http:GenerateGUID(false),crew=table.clone(crew),members=members,active=table.clone(members),equipped=equipped,difficulty=difficulty,
		v=v,eva=EVA.new(ship,stations,sites)}
	for _,p in ipairs(crew) do
		results[p]=nil
		move(p,world.SpawnCrew)
		p.CameraMode=Enum.CameraMode.LockFirstPerson
	end
	return true
end
lobby=Lobby.new(launch)
local function alive(p)
	local c=p.Character
	local h=c and c:FindFirstChildOfClass("Humanoid")
	return h and h.Health>0 and c:FindFirstChild("HumanoidRootPart")
end
local function near(p,part,distance)
	local root=alive(p)
	return root and part and (root.Position-part.Position).Magnitude<=(distance or 10)
end
local function finish(r,reason)
	if run~=r or r.finishing then return end
	r.finishing=true
	local snap=r.v:snapshot()
	local survived=snap.survived==true and reason==nil
	local survivors={}
	for _,p in ipairs(r.crew) do survivors[p.UserId]=survived and r.active[p.UserId]==true end
	local result={deepest=snap.deepest or snap.depth or 0,artifact=snap.artifact==true,survived=survived,
		difficulty=r.difficulty,survivors=survivors,reason=reason or snap.reason or "Returned"}
	for _,p in ipairs(r.crew) do
		r.eva:release(p)
		cameras[p]=nil
		if p.Parent==Players then
			results[p]={summary=result,expires=clock()+7}
			p.CameraMode=Enum.CameraMode.Classic
			move(p,world.SpawnLobby)
		end
	end
	lobby:finish(r.crew,r.id,result)
	if run==r then run=nil end
end
local stationActions={Engine="Engine",Searchlight="Searchlight",Aim="Searchlight",Sonar="Sonar",Camera="Camera",Collect="Extinguisher",Refill="Refill",Recover="Artifact"}
local evaActions={Exit=true,Swim=true,Brace=true,Cut=true,Cancel=true,Return=true}
local lobbyActions={Solo=true,Public=true,Private=true,Invite=true,Join=true,Leave=true,Difficulty=true,Buy=true,Equip=true}
local function action(p,name,data)
	if type(name)~="string" or type(data)~="table" then return end
	local now=clock()
	local function note(msg)
		if type(msg)=="string" then notices[p]={text=msg,untilTime=now+3} end
	end
	if lobbyActions[name] then
		if run and run.active[p.UserId] then return end
		local _,msg=lobby:action(p,name,data)
		note(msg)
		return
	end
	local r=run
	if not r or r.finishing or not r.active[p.UserId] or not alive(p) then return end
	if name=="CameraExit" then cameras[p]=nil return end
	if evaActions[name] then
		local _,msg=r.eva:action(p,name,data,now,r.v)
		note(msg)
		return
	end
	if r.eva.session and r.eva.session.player==p then return end
	local required=stationActions[name]
	if name=="Repair" and type(data.site)=="string" then required="Repair"..data.site end
	if required then
		if not near(p,stations[required]) then return end
	elseif name~="Spray" then return end
	if name=="Camera" then cameras[p]=true return end
	if name=="Engine" or name=="Searchlight" or name=="Sonar" then
		if type(data.enabled)~="boolean" then return end
	end
	if name=="Aim" then
		for _,n in ipairs({"bearing","pitch"}) do
			if typeof(data[n])~="number" or math.abs(data[n])>360 then return end
		end
	end
	local safe={enabled=data.enabled,bearing=data.bearing,pitch=data.pitch,site=data.site,userId=p.UserId}
	if name=="Spray" then
		local at=world.ShipOrigin.CFrame:PointToObjectSpace(alive(p).Position)
		if math.abs(at.X)>13 or math.abs(at.Z)>26 or at.Y<0 or at.Y>10 then return end
		safe.room=if at.Z < -13 then "Bridge" elseif at.Z < 0 then "Lab" elseif at.Z < 13 then "Machinery" else "DiveService"
	end
	local ok,msg=r.v:action(name,safe,now)
	if not ok then note(msg) end
end
input.OnServerEvent:Connect(function(p,name,data)
	local t=clock()
	local bucket=limits[p] or {t=t,tokens=28}
	bucket.tokens=math.min(28,bucket.tokens+(t-bucket.t)*24)
	bucket.t=t
	limits[p]=bucket
	if bucket.tokens<1 then return end
	bucket.tokens-=1
	action(p,name,data or {})
end)
local promptSpecs={Engine={"Engine","Toggle engine"},Searchlight={"Searchlight","Toggle searchlight"},Sonar={"Sonar","Toggle sonar"},Camera={"Camera","View cameras"},Artifact={"Recover","Recover artifact"},Airlock={"Exit","Exit airlock"},AirlockExit={"Return","Enter airlock"},Extinguisher={"Collect","Take extinguisher"},Refill={"Refill","Refill extinguisher"}}
local function prompt(part,label,callback)
	local a=Instance.new("ProximityPrompt")
	a.Name="DiveInteract"
	a.ActionText,a.ObjectText,a.RequiresLineOfSight=label,part.Name,false
	a.MaxActivationDistance,a.HoldDuration,a.Parent=9,.12,part
	a.Triggered:Connect(function(p) if near(p,part) then callback(p) end end)
end
prompt(world.SpawnLobby,"Launch solo dive",function(p) action(p,"Solo",{}) end)
for id,part in pairs(stations) do
	local spec=promptSpecs[id]
	if spec then
		prompt(part,spec[2],function(p)
			if not run then return end
			local state=run.v:snapshot()
			local keys={Engine="engine",Searchlight="searchlight",Sonar="sonar"}
			local key=keys[spec[1]]
			action(p,spec[1],if key then {enabled=not state[key]} else {})
		end)
	elseif id:sub(1,6)=="Repair" then prompt(part,"Seal fracture",function(p) action(p,"Repair",{site=id:sub(7)}) end) end
end
for site,part in pairs(sites) do prompt(part,"Brace at colony",function(p) action(p,"Brace",{site=site}) end) end
local function retire(p)
	local r=run
	if not r or not r.active[p.UserId] then return end
	r.eva:release(p)
	r.active[p.UserId]=nil
	r.v:release(p.UserId)
	local remaining=0
	for _ in pairs(r.active) do remaining+=1 end
	if remaining>0 then r.v:setCrewCount(remaining) end
	cameras[p]=nil
	p.CameraMode=Enum.CameraMode.Classic
	if not next(r.active) then task.spawn(finish,r,"Crew lost") end
end
local function added(p)
	local function character(c)
		local h=c:WaitForChild("Humanoid",10)
		if h then h.Died:Connect(function() retire(p) end) end
		if not c:WaitForChild("HumanoidRootPart",10) or c~=p.Character then return end
		move(p,if run and run.active[p.UserId] then world.SpawnCrew else world.SpawnLobby)
	end
	p.CharacterAdded:Connect(character)
	if p.Character then task.spawn(character,p.Character) end
end
Players.PlayerAdded:Connect(added)
for _,p in ipairs(Players:GetPlayers()) do added(p) end
Players.PlayerRemoving:Connect(function(p)
	retire(p)
	results[p],notices[p],cameras[p],limits[p]=nil,nil,nil,nil
end)
local accumulator=0
RunService.Heartbeat:Connect(function(dt)
	local now=clock()
	local r=run
	if r and not r.finishing then
		r.v:step(dt,now,r.eva:position())
		r.eva:step(dt,now,r.v)
		if r.v.phase=="Results" then task.spawn(finish,r) end
	end
	accumulator+=dt
	if accumulator<.2 then return end
	accumulator%=.2
	for _,p in ipairs(Players:GetPlayers()) do
		local active=run and not run.finishing and run.active[p.UserId]
		local res=results[p]
		if res and res.expires<now then results[p]=nil res=nil end
		if cameras[p] and not near(p,stations.Camera) then cameras[p]=nil end
		local n=notices[p]
		output:FireClient(p,{version=1,time=now,phase=if active then run.v.phase elseif res then "Results" else "Lobby",lobby=lobby:snapshot(p),
			dive=if active then run.v:snapshot() else nil,eva=if active then run.eva:snapshot() else nil,camera=cameras[p]==true,result=res and res.summary,notice=n and n.untilTime>now and n.text or nil})
	end
end)
net.Parent=Storage
