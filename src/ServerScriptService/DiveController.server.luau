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
local site = workspace:WaitForChild("Thalassa")
local net = ReplicatedStorage:WaitForChild("DiveNet")
local feed = net:WaitForChild("Feed")
Exterior.init(site,feed)
local active, settling
local members, receipts, throttles, held = {}, {}, {}, {}
local sceneIdle = Dive.new("Normal", 1, {})
sceneIdle.phase, sceneIdle.engine = "Lobby", false
local settle, down

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
	m.beam, m.anchor, m.attach, m.outside = nil, nil, nil, false
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
	out.charges, out.capacity, out.hasExtinguisher = m.charges, m.capacity, m.hasExtinguisher
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
				hasExtinguisher=false, maxOxygen=trait == "Diver" and 105 or 80, lastAction={}}
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

settle = function(s)
	if active ~= s or settling then return end
	settling = true
	local groups = {{},{}}
	for p,m in members do
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
	World.update(sceneIdle)
end

down = function(p, reason)
	local s,m = active,members[p]
	if not s or settling or not m or not m.alive then return end
	m.alive, m.death = false, reason
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
	if not active or settling or not m or not m.alive or not prompt.Enabled or not prompt:IsDescendantOf(site) then return end
	local base = prompt:FindFirstAncestorWhichIsA("BasePart")
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not base or not root then return end
	local position = prompt.Parent:IsA("Attachment") and prompt.Parent.WorldPosition or base.Position
	if (root.Position-position).Magnitude > prompt.MaxActivationDistance+2 then return end
	return prompt:GetAttribute("Action")
end

local function sprayFoam(p, section)
	local rack = site.Stations:FindFirstChild("Section"..section)
	local outlet = rack and rack:FindFirstChild("Spray point")
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not outlet or not outlet:IsA("BasePart") or not root then return end
	local nozzle = Instance.new("Attachment")
	nozzle.Parent = root
	local origin = root.Position + root.CFrame.RightVector * 0.65 + Vector3.new(0,0.5,0)
	nozzle.WorldCFrame = CFrame.lookAt(origin,outlet.Position)
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
	if not m or not s then return end
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
		m.hasExtinguisher, m.charges = true, m.capacity
		notice(p,"Extinguisher ready. Use the spray point beside a boarder.")
	elseif string.match(action,"^Spray[1-3]$") then
		if not s.boarded or s.crawlerSection ~= tonumber(action:sub(-1)) then return end
		if m.charges == 0 then notice(p,"Collect a charged extinguisher from the rack.") return end
		m.charges -= 1
		sprayFoam(p,s.crawlerSection)
		s.crawler, s.boarded = 0, false
		Dive.warn(s,"The crawler fled through the grate.")
	elseif action == "Airlock" then
		for _,other in members do
			if other.outside then notice(p,"Airlock occupied. One tether available.") return end
		end
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
				local anglerNear=s.shark>0.82 and (actors.Leviathan:GetPivot().Position-root.Position).Magnitude<75
				local squidNear=s.squid>0.86 and (actors.GiantSquid:GetPivot().Position-root.Position).Magnitude<74
				if anglerNear or squidNear then down(p,"A nearby predator took the exposed diver.") end
			end
		elseif root and root.Position.Y < 112 then
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
		releaseTether(p,m)
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
RunService.Heartbeat:Connect(function(dt)
	accumulator += math.min(0.5,dt)
	if accumulator < 0.25 then return end
	local step = accumulator
	accumulator = 0
	local s = active
	if not s or settling then return end
	local hadSwarm = s.swarm > 0
	s.patrolSquidSide = World.squidBearing()
	Dive.step(s,step)
	if s.swarm>0 and not hadSwarm then Exterior.newSwarm(s) end
	if s.phase == "Results" then settle(s) return end
	handleCrew(s,step)
	if active == s then sync(s) end
end)
