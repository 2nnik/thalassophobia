local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Dive = require(script.Parent:WaitForChild("DiveSimulation"))
local Exterior = require(script.Parent:WaitForChild("DiveExterior"))
local Sensors = require(script.Parent:WaitForChild("DiveSensors"))
local World = require(script.Parent:WaitForChild("DiveWorld"))
local Lobby = require(script.Parent:WaitForChild("DiveLobby"))
local Extinguisher = require(script.Parent:WaitForChild("DiveExtinguisher"))
local site = workspace:WaitForChild("Thalassa")
local net = ReplicatedStorage:WaitForChild("DiveNet")
local feed = net:WaitForChild("Feed")
Exterior.init(site,feed)
local active, settling
local members, receipts, throttles, held = {}, {}, {}, {}
local sceneIdle = Dive.new("Normal", 1, {})
sceneIdle.phase, sceneIdle.engine = "Lobby", false
local settle, down
local cueDuration = {WormRescue=.95,WormDeath=2.8,Angler=5,Squid=13,Flood=15}

local function cue(p,kind,duration,section,position)
	if p.Parent == Players then
		feed:FireClient(p,"Cinematic",{kind=kind,duration=duration,section=section,position=position,
			startedAt=workspace:GetServerTimeNow()})
	end
end

local function notice(p, msg)
	if p.Parent == Players then feed:FireClient(p, "Notice", msg) end
end

local function relocate(p, name, offset)
	local marker = site:FindFirstChild(name, true)
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not marker then return false end
	character:PivotTo(marker.CFrame * CFrame.new(offset or Vector3.zero))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function releaseTether(p,m)
	Exterior.stopSwim(p,m)
	if m.beam then m.beam:Destroy() end
	if m.anchor then m.anchor:Destroy() end
	if m.attach then m.attach:Destroy() end
	m.beam, m.anchor, m.attach, m.tetherMarker, m.outside = nil, nil, nil, nil, false
end

local function clearExtinguisher(m)
	if m.extinguisher then m.extinguisher:Destroy() end
	m.extinguisher,m.charges=nil,0
end

local function releaseGrab(p,m,s)
	local grip=m.grab
	if not grip then return end
	m.grab=nil
	grip.weld:Destroy()
	if grip.humanoid.Parent and grip.root:IsDescendantOf(p.Character or workspace) then
		grip.humanoid.WalkSpeed,grip.humanoid.AutoRotate=grip.speed,grip.autoRotate
	end
	if s.victim==p then s.victim,s.crawlerGrip=nil,nil end
end

local function tether(p, m)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local anchor = Instance.new("Attachment")
	anchor.Name = "DiveLifelineAnchor"
	anchor.Parent = workspace.Terrain
	anchor.WorldPosition = site.TetherAnchor.Position
	local attach = Instance.new("Attachment")
	attach.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = anchor, attach
	beam.Width0, beam.Width1 = 0.09, 0.09
	beam.Color = ColorSequence.new(Color3.fromRGB(237, 145, 56))
	beam.FaceCamera = true
	beam.Parent = attach
	m.beam, m.anchor, m.attach, m.outside = beam, anchor, attach, true
	m.tetherMarker = site.TetherAnchor
	m.oxygen = m.maxOxygen
	relocate(p, "OutsideSpawn")
	Exterior.startSwim(p,m,active)
end

local public = {"phase","difficulty","depth","maxDepth","battery","hull","engine","light","aim","cracks","shark","squid","crawler","swarm","pursuer","squidSide","crawlerSection","boarded","warning","coast","artifact"}
local function sendSnapshot(p, m, s)
	local out = {}
	for _,key in public do out[key] = s[key] end
	out.battery, out.hull = math.max(0,s.battery), math.max(0,s.hull)
	out.alive, out.outside, out.maxOxygen = m.alive, m.outside, m.maxOxygen
	out.oxygen = m.outside and m.oxygen or nil
	out.charges, out.capacity = m.charges,m.capacity
	out.hasExtinguisher = m.extinguisher~=nil and m.extinguisher.Parent~=nil
	out.extinguisherEquipped = out.hasExtinguisher and m.extinguisher.Parent==p.Character
	out.sonarOn, out.sonarRange = s.sonarOn, Sensors.range
	out.cameraView = m.cameraOrigin ~= nil
	if s.sonarOn and not m.outside then out.echoes, out.pingAt = s.echoes,s.pingAt end
	Exterior.snapshot(p,m,s,out)
	feed:FireClient(p,"Dive",out)
end

local function recalculate(s)
	local crew, traits = 0, {}
	for p,m in members do
		if m.alive and p.Parent == Players then
			crew += 1
			if m.trait ~= "" then traits[m.trait] = true end
		end
	end
	s.crewCount, s.traits = math.max(1,crew), traits
	return crew
end

local function sync(s)
	World.update(s)
	Sensors.pulse(s,members)
	for p,m in members do
		if p.Parent == Players then sendSnapshot(p,m,s) end
	end
end

local function start(party, difficulty)
	if active or settling or #party == 0 or #party > 4 then return false end
	local crew = {}
	for _,p in party do
		if p.Parent == Players and not crew[p] then
			local trait = Lobby.trait(p) or ""
			local capacity = trait == "Tank" and 5 or 3
			crew[p] = {alive=true, outside=false, trait=trait, charges=0, capacity=capacity,
				maxOxygen=trait == "Diver" and 105 or 80, lastAction={}}
		end
	end
	if next(crew) == nil then return false end
	members = crew
	active = Dive.new(difficulty, #party, {})
	recalculate(active)
	for index,p in party do
		if members[p] then
			receipts[p] = nil
			relocate(p,"CageSpawn",Vector3.new((index-1)%2 * 2.5,0,math.floor((index-1)/2) * 2.5))
		end
	end
	sync(active)
	return true
end

local function finishResults(s)
	if active ~= s then return end
	local groups = {{},{}}
	for p,m in members do
		releaseGrab(p,m,s)
		clearExtinguisher(m)
		releaseTether(p,m)
		if p.Parent == Players then
			table.insert(groups[(s.survived and m.alive) and 1 or 2],p)
			relocate(p,"LobbySpawn")
		end
	end
	for index,group in groups do
		if #group == 0 then continue end
		local survived = index == 1
		local payouts = Lobby.finish(group, s.deepest, s.artifact, survived, s.difficulty)
		for _,p in group do
			if p.Parent == Players then
				local r = {survived=survived,reason=members[p].death or s.reason,depth=math.floor(s.deepest),
					artifact=s.artifact,money=payouts[p.UserId] or 0,difficulty=s.difficulty}
				receipts[p] = r
				feed:FireClient(p,"Results",r)
			end
		end
	end
	members, active, settling = {}, nil, false
	World.resetDepth()
	World.update(sceneIdle)
end

settle = function(s)
	if active ~= s or settling then return end
	settling=true
	local kind=s.sequence
	if kind then
		local model=site.Contacts[if kind=="Squid" then "GiantSquid" else "Leviathan"]
		for p,m in members do
			releaseGrab(p,m,s)
			if m.alive then cue(p,kind,cueDuration[kind],s.crawlerSection,model:GetPivot().Position) end
		end
		task.delay(cueDuration[kind]+.2,function() finishResults(s) end)
	else
		finishResults(s)
	end
end

down = function(p, reason)
	local s,m = active,members[p]
	if not s or settling or not m or not m.alive then return end
	m.alive, m.death = false, reason
	releaseGrab(p,m,s)
	clearExtinguisher(m)
	releaseTether(p,m)
	notice(p, reason)
	relocate(p,"LobbySpawn")
	if recalculate(s) == 0 then
		Dive.endRun(s, false, reason)
		settle(s)
	else
		sendSnapshot(p,m,s)
	end
end

local function validPrompt(p, prompt)
	local m = members[p]
	if not active or active.elapsed<2.7 or settling or not m or not m.alive or m.grab or not prompt.Enabled or not prompt:IsDescendantOf(site) then return end
	local base = prompt:FindFirstAncestorWhichIsA("BasePart")
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not base or not root then return end
	local position = prompt.Parent:IsA("Attachment") and prompt.Parent.WorldPosition or base.Position
	if (root.Position-position).Magnitude > prompt.MaxActivationDistance+2 then return end
	return prompt:GetAttribute("Action")
end

local function sprayFoam(p, target)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local nozzle = Instance.new("Attachment")
	nozzle.Parent = root
	local origin = root.Position + root.CFrame.RightVector * 0.65 + Vector3.new(0,0.5,0)
	nozzle.WorldCFrame = CFrame.lookAt(origin,target)
	local foam = Instance.new("ParticleEmitter")
	foam.Enabled = false
	foam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	foam.EmissionDirection = Enum.NormalId.Front
	foam.Color = ColorSequence.new(Color3.fromRGB(216,236,232))
	foam.Size = NumberSequence.new(0.36,1.4)
	foam.Transparency = NumberSequence.new(0.2,1)
	foam.Lifetime = NumberRange.new(0.3,0.55)
	foam.Speed = NumberRange.new(8,13)
	foam.SpreadAngle = Vector2.new(13,13)
	foam.Parent = nozzle
	foam:Emit(28)
	game:GetService("Debris"):AddItem(nozzle,1)
end

local function interact(p, action)
	local m,s = members[p],active
	if not m or not s or settling or not m.alive or m.grab then return end
	if m.cleaning or m.cameraOrigin then return end
	local cleanIndex = tonumber(action:match("^Clean([1-4])$"))
	local exterior = cleanIndex ~= nil or action == "Return"
	if exterior ~= m.outside then return end
	if (m.lastAction[action] or -2) + 0.35 > s.elapsed then return end
	m.lastAction[action] = s.elapsed
	if action == "Engine" then
		s.engine = not s.engine
		Dive.warn(s,s.engine and "Propulsion restored." or "Propulsion offline.",2)
	elseif action == "Light" then
		s.light = not s.light
	elseif action == "AimLeft" or action == "AimRight" then
		s.aim = ((s.aim-1 + (action == "AimLeft" and -1 or 1)) % 4) + 1
	elseif string.match(action, "^Repair[1-3]$") then
		local section = tonumber(action:sub(-1))
		if not s.cracks[section] then return end
		s.cracks[section] = false
		s.hull = math.min(100, s.hull+5)
		Dive.warn(s,"Section 0"..section.." sealed.",2.5)
	elseif action == "Extinguisher" then
		local character,backpack=p.Character,p:FindFirstChildOfClass("Backpack")
		local human=character and character:FindFirstChildOfClass("Humanoid")
		if not human or not backpack then return end
		if not m.extinguisher or not m.extinguisher.Parent then
			local tool=Extinguisher.makeTool()
			m.extinguisher=tool
			tool.Parent=backpack
			tool.Activated:Connect(function()
				if active==s and members[p]==m and tool.Parent==p.Character then
					interact(p,"Spray"..s.crawlerSection)
				end
			end)
		end
		m.charges=m.capacity
		human:EquipTool(m.extinguisher)
		notice(p,"Extinguisher equipped. Get close to the boarder and discharge foam.")
	elseif string.match(action,"^Spray[1-3]$") then
		if not s.boarded or s.crawlerSection ~= tonumber(action:sub(-1)) then return end
		if not m.extinguisher or m.extinguisher.Parent~=p.Character or m.charges<=0 then
			notice(p,"Equip a charged extinguisher from the red wall rack by the bridge.")
			return
		end
		local char=p.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local crawler=site.Contacts.CrackCrawler
		local target=if s.crawlerGrip then s.crawlerGrip.Position else crawler:GetPivot().Position
		if not root or (root.Position-target).Magnitude>10 then notice(p,"Get closer to the boarder.") return end
		local ray=RaycastParams.new()
		ray.FilterType=Enum.RaycastFilterType.Exclude
		local ignore={site.Contacts}
		for player in members do if player.Character then table.insert(ignore,player.Character) end end
		ray.FilterDescendantsInstances=ignore
		ray.RespectCanCollide=true
		local from=root.Position+Vector3.yAxis*.5
		if workspace:Raycast(from,target-from,ray) then notice(p,"Move into the boarder's section.") return end
		local victim=s.victim
		local trapped=victim and members[victim]
		if trapped and trapped.grab and trapped.grab.fatal then return end
		m.charges -= 1
		sprayFoam(p,target)
		if trapped then
			releaseGrab(victim,trapped,s)
			cue(victim,"WormRescue",cueDuration.WormRescue,s.crawlerSection)
		end
		s.crawler, s.boarded = 0, false
		Dive.warn(s,"The crawler fled through the grate.")
	elseif action == "Airlock" then
		for _,other in members do
			if other.outside then notice(p,"Airlock occupied. One tether available.") return end
		end
		local human=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if human then human:UnequipTools() end
		tether(p,m)
	elseif cleanIndex then
		Exterior.beginClean(p,m,s,cleanIndex)
	elseif action == "Return" then
		releaseTether(p,m)
		relocate(p,"InsideLockSpawn")
	elseif action == "Artifact" then
		Dive.pickup(s)
	elseif action == "Sonar" then
		s.sonarOn = not s.sonarOn
		s.echoes = nil
		s.nextPing = 0
	elseif action == "Camera" then
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		m.cameraOrigin = root and root.Position
	else
		return
	end
	sync(s)
end

local function updateCrawler(s)
	if not s.boarded then return end
	if s.victim then
		local p,m=s.victim,members[s.victim]
		local grab=m and m.grab
		if not grab or not grab.root.Parent then
			if m then releaseGrab(p,m,s) end
			s.victim,s.crawlerGrip=nil,nil
			return
		end
		if grab.fatal or s.elapsed<grab.deadline then return end
		grab.fatal=true
		cue(p,"WormDeath",cueDuration.WormDeath,s.crawlerSection)
		task.delay(cueDuration.WormDeath+.15,function()
			if active~=s or settling or members[p]~=m or m.grab~=grab then return end
			releaseGrab(p,m,s)
			s.crawler,s.boarded=0,false
			down(p,"The worm creature overwhelmed the crew member.")
		end)
		return
	end
	if s.crawler<.57 then return end
	local outlet=site.Stations["Section"..s.crawlerSection]["Spray point"]
	local victim,distance,root,humanoid=nil,13,nil,nil
	for p,m in members do
		local c=p.Character
		local r=c and c:FindFirstChild("HumanoidRootPart")
		local h=c and c:FindFirstChildOfClass("Humanoid")
		if m.alive and not m.outside and r and h and h.Health>0 then
			local d=(r.Position-outlet.Position).Magnitude
			if d<distance then victim,distance,root,humanoid=p,d,r,h end
		end
	end
	if not victim then return end
	local m=members[victim]
	local toward=Vector3.new(outlet.Position.X-root.Position.X,0,outlet.Position.Z-root.Position.Z)
	local direction=if toward.Magnitude>.2 then toward.Unit else Vector3.zAxis
	local spot=Vector3.new(root.Position.X,outlet.Position.Y+1.7,root.Position.Z)+direction*2.35
	local face=Vector3.new(root.Position.X,spot.Y,root.Position.Z)
	if (face-spot).Magnitude<.2 then face=spot+Vector3.zAxis end
	local duration=if s.crewCount==1 then 4.2 else 13
	local weld=Instance.new("WeldConstraint")
	weld.Name,weld.Part0,weld.Part1="CrawlerGrip",site.HullMotion,root
	weld.Parent=root
	m.grab={weld=weld,root=root,humanoid=humanoid,speed=humanoid.WalkSpeed,autoRotate=humanoid.AutoRotate,
		deadline=s.elapsed+duration}
	humanoid.WalkSpeed,humanoid.AutoRotate=0,false
	m.cameraOrigin=nil
	s.victim,s.crawlerGrip=victim,CFrame.lookAt(spot,face)
	Dive.warn(s,"Crew member restrained. Use the extinguisher in section 0"..s.crawlerSection..".",duration)
	cue(victim,"WormGrab",duration+1,s.crawlerSection,spot)
end

Prompts.PromptTriggered:Connect(function(prompt,p)
	local action = validPrompt(p,prompt)
	if action then interact(p,action) end
end)
Prompts.PromptButtonHoldBegan:Connect(function(prompt,p)
	local action = validPrompt(p,prompt)
	if not action or not action:match("^Repair") or members[p].trait ~= "Welder" then return end
	local token = {}
	held[p] = token
	task.delay(prompt.HoldDuration * 0.55,function()
		if held[p] == token and validPrompt(p,prompt) == action then interact(p,action) end
	end)
end)
Prompts.PromptButtonHoldEnded:Connect(function(_,p) held[p] = nil end)

local function handleCrew(s,dt)
	for p,m in members do
		if not m.alive then continue end
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if m.cameraOrigin and root and (root.Position-m.cameraOrigin).Magnitude>9 then m.cameraOrigin=nil end
		if m.outside then
			Exterior.tick(p,m,s,dt)
			m.oxygen -= dt
			if m.oxygen <= 0 then down(p,"The diver exhausted their oxygen.")
			elseif root then
				local actors=site.Contacts
				local anglerNear=s.shark>0.82 and World.predatorNear(actors.Leviathan,root.Position,22)
				local squidNear=s.squid>0.86 and World.predatorNear(actors.GiantSquid,root.Position,18)
				if anglerNear or squidNear then down(p,"A nearby predator took the exposed diver.") end
			end
		elseif root and root.Position.Y < site.CageSpawn.Position.Y-11 then
			relocate(p,"CageSpawn")
		end
		if active ~= s then return end
	end
end

local function configureCharacter(p, character)
	local humanoid = character:WaitForChild("Humanoid",10)
	local root = character:WaitForChild("HumanoidRootPart",10)
	if not root or not humanoid or character ~= p.Character then return end
	local function group(item)
		if item:IsA("BasePart") then item.CollisionGroup = "DiveCrew" end
	end
	for _,item in character:GetDescendants() do group(item) end
	character.DescendantAdded:Connect(group)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
	p.CameraMode = Enum.CameraMode.LockFirstPerson
	local m = members[p]
	relocate(p,m and m.alive and (m.outside and "OutsideSpawn" or "CageSpawn") or "LobbySpawn")
	humanoid.Died:Connect(function() down(p,"A crew member was lost under pressure.") end)
end
pcall(function() PhysicsService:RegisterCollisionGroup("DiveCrew") end)
PhysicsService:CollisionGroupSetCollidable("DiveCrew","DiveCrew",false)
local function joined(p)
	p.CharacterAdded:Connect(function(character) configureCharacter(p,character) end)
	if p.Character then task.spawn(configureCharacter,p,p.Character) end
end
Players.PlayerAdded:Connect(joined)
for _,p in Players:GetPlayers() do joined(p) end

Players.PlayerRemoving:Connect(function(p)
	local m,s = members[p],active
	if m then
		if s then releaseGrab(p,m,s) end
		releaseTether(p,m)
		clearExtinguisher(m)
		members[p] = nil
		if s and not settling and recalculate(s) == 0 then
			Dive.endRun(s,false,"The last crew member left the cage.")
			settle(s)
		end
	end
	receipts[p], throttles[p], held[p] = nil,nil,nil
end)

World.update(sceneIdle)
Lobby.init({start=start, isBusy=function() return active ~= nil or settling == true end})
net.Input.OnServerEvent:Connect(function(p, action, arg)
	if typeof(action) ~= "string" or #action > 48 then return end
	local now = os.clock()
	local rate = throttles[p]
	if not rate or now - rate.at > 1 then rate = {at=now,count=0} throttles[p]=rate end
	rate.count += 1
	if rate.count > 16 then return end
	if members[p] and active and not settling and action=="CloseCamera" then
		members[p].cameraOrigin=nil
		sendSnapshot(p,members[p],active)
	elseif members[p] and active and not settling and Exterior.input(p,members[p],active,action,arg) then
		if action~="SwimMove" then sync(active) end
	elseif action == "Sync" and members[p] and active then
		sendSnapshot(p,members[p],active)
	elseif action == "DismissResults" and not members[p] then
		receipts[p]=nil
		Lobby.input(p,"Sync")
	elseif receipts[p] then
		feed:FireClient(p,"Results",receipts[p])
	elseif not members[p] then
		Lobby.input(p,action,arg)
	end
end)

local accumulator = 0
local function carryCrew(delta)
	if delta.Y == 0 then return end
	if active.crawlerGrip then active.crawlerGrip += delta end
	for p,m in members do
		if not m.alive then continue end
		if m.tetherMarker and m.anchor then m.anchor.WorldPosition = m.tetherMarker.Position end
		if m.outside then
			Exterior.followShip(m,delta)
		else
			if m.cameraOrigin then m.cameraOrigin += delta end
		end
	end
end
RunService.Heartbeat:Connect(function(dt)
	local s = active
	if not s or settling then accumulator=0 return end
	carryCrew(World.travel(math.min(0.5,dt)))
	accumulator += math.min(0.5,dt)
	if accumulator < 0.25 then return end
	local step = accumulator
	accumulator = 0
	local hadSwarm = s.swarm > 0
	s.patrolSquidSide = World.squidBearing()
	Dive.step(s,step)
	if s.swarm>0 and not hadSwarm then Exterior.newSwarm(s) end
	if s.phase == "Results" then settle(s) return end
	World.setDepth(s.depth)
	updateCrawler(s)
	handleCrew(s,step)
	if active == s then sync(s) end
end)
