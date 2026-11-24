-- All interactions are validated by the run controller. This module presents its state.
local World = {}
local world = workspace:WaitForChild("Thalassa")
local stations = world.Stations
local actors = world.Contacts
local Dive = require(script.Parent:WaitForChild("DiveSimulation"))
require(script.Parent:WaitForChild("DiveShipRefit")).install(world)
local Breach = require(script.Parent:WaitForChild("DiveBreach"))
local breachEffects = Breach.install(stations)
require(script.Parent:WaitForChild("DiveExtinguisher")).install(stations)
local WormFigure = require(script.Parent:WaitForChild("DiveWormFigure"))
local ocean = world.Ocean
local floor = ocean["Trench floor"]
local head = ocean.SearchlightHead
local spot = head["Search beam"]
local scatter = head["Particle scatter"]
local screen = stations.SONAR.SonarScreen.Face.Legend
local engineLabel = stations.ENGINE.EngineStatus.Face.Legend
local engineLever = stations.ENGINE.EngineLever
local lampSwitch = stations.OPTICS.Light
local samplerRelic = stations.Sampler.Artifact
local dirs = {Vector3.new(0,0,-1), Vector3.new(1,0,0), Vector3.new(0,0,1), Vector3.new(-1,0,0)}
local bearings = {"FORE", "STBD", "AFT", "PORT"}
local lamps, prompts, leaks, snow = {}, {}, {}, {}
local hidden = CFrame.new(0,-1100,0)
local positions = {}
local meterColor = Color3.fromHex("72E8D0")
local offColor = Color3.fromHex("445556")
local amber = Color3.fromHex("F2B650")
local lastDirection, lastRender = nil, -math.huge
local activePhase = {Descent=true, Bottom=true, Ascent=true}
local dockCRT = world["Launch dock"]:FindFirstChild("Mission CRT")
local missionFace = dockCRT and dockCRT:FindFirstChild("Face")
local missionText = missionFace and missionFace:FindFirstChild("Legend")
if missionText and missionText:IsA("TextLabel") and missionText.Text:find("600 M",1,true) then
 missionText.Text = missionText.Text:gsub("%f[%d]600 M%f[%W]","10,000 M")
end
for _,item in world:GetDescendants() do
 if item:IsA("ProximityPrompt") and item:GetAttribute("Action") then
  prompts[item:GetAttribute("Action")] = item
 elseif item:IsA("ParticleEmitter") and item.Name=="Suspended sediment" then
  table.insert(snow,item)
 elseif item:IsA("PointLight") and item.Parent.Name=="Work lamp" then
  table.insert(lamps,{light=item,color=item.Color})
 end
end
for i=1,3 do leaks[i] = stations["Section"..i].Fracture:GetChildren() end

function World.bindOpticsClick(usePrompt)
	for action,caption in {Light="Open searchlight map",Camera="Open camera map"} do
		local prompt=prompts[action]
		if not prompt then continue end
		prompt.ActionText=caption
		local panel=prompt:FindFirstAncestorWhichIsA("BasePart")
		local target=if action=="Light" then stations.OPTICS else panel
		panel.CanQuery=true
		local click=Instance.new("ClickDetector")
		click.Name="Open optics"
		click.MaxActivationDistance=prompt.MaxActivationDistance
		click.MouseClick:Connect(function(player) usePrompt(prompt,player) end)
		click.Parent=target
	end
	for partName,caption in {AimLeft="BEARING",AimRight="MAP"} do
		local panel=stations.OPTICS[partName]
		panel.CanQuery=true
		panel.Face.Legend.Text=caption
	end
end

local function pose(model,cf)
 if positions[model] == cf then return end
 positions[model] = cf
 model:PivotTo(cf)
end

local function showPrompt(name,enabled)
 local prompt = prompts[name]
 if prompt and prompt.Enabled~=enabled then prompt.Enabled=enabled end
end

local envelope=world:WaitForChild("ShipEnvelope")
local barnacles=world:WaitForChild("BarnacleSites")
local center=envelope.Position
-- The seabed and dock are 432 studs of ship travel apart. Instruments report survey depth.
local hullTravel = 432
local shipY = 0
local targetY = 0
local travelTime = 0
local travelStep = .25
local hullParts = {}
local carried = {
	"Bell • KESTREL 04", "Pressure hull • Survey refit", "Dive stage", "Stations", "BarnacleSites",
	"CageSpawn", "InsideLockSpawn", "OutsideSpawn", "ShipEnvelope", "TetherAnchor",
	"DiveCamera1", "DiveCamera2", "DiveCamera3", "DiveCamera4", "WormWindow1", "WormWindow2", "WormWindow3",
}
local function cachePart(part)
	if part:IsA("BasePart") and part.Anchored then
		table.insert(hullParts,part)
	end
end
local function cacheAssembly(root)
	cachePart(root)
	for _,part in root:GetDescendants() do cachePart(part) end
end
for _,name in carried do cacheAssembly(world:WaitForChild(name)) end
for _,name in {"Marine snow","Pelagic darkness","Pelagic current"} do
	cacheAssembly(ocean:WaitForChild(name))
end
local driver = Instance.new("Part")
driver.Name,driver.Size = "HullMotion",Vector3.one
driver.CFrame,driver.Transparency = envelope.CFrame,1
driver.Anchored,driver.CanCollide,driver.CanTouch,driver.CanQuery = true,false,false,false
driver.Parent=world
local home = driver.CFrame
for _,part in hullParts do
	local weld = Instance.new("WeldConstraint")
	weld.Part0,weld.Part1 = driver,part
	weld.Parent=driver
	part.Anchored=false
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	-- The starter plate crosses the water column. The authored dock and seabed are the playable surfaces.
	baseplate.CanCollide,baseplate.CanTouch,baseplate.CanQuery,baseplate.Transparency=false,false,false,1
	for _,surface in baseplate:GetDescendants() do
		if surface:IsA("Decal") then surface.Transparency=1 end
	end
end
local starterSpawn = workspace:FindFirstChild("SpawnLocation")
if starterSpawn and starterSpawn:IsA("SpawnLocation") then
	local lobby = world.LobbySpawn
	local deck = RaycastParams.new()
	deck.FilterType = Enum.RaycastFilterType.Include
	deck.FilterDescendantsInstances = {world["Launch dock"]}
	local support = workspace:Raycast(lobby.Position + Vector3.yAxis * 5,-Vector3.yAxis * 20,deck)
	local height = support and support.Position.Y + starterSpawn.Size.Y * .5 or lobby.Position.Y
	starterSpawn.CFrame = CFrame.new(lobby.Position.X,height,lobby.Position.Z) * lobby.CFrame.Rotation
	starterSpawn.CanCollide,starterSpawn.CanQuery,starterSpawn.Transparency=false,false,1
	for _,mark in starterSpawn:GetDescendants() do
		if mark:IsA("Decal") then mark.Transparency=1 end
	end
end
floor:ScaleTo(2.6)
floor:PivotTo(CFrame.new(0,-350,0))

-- Put the pickup across open water from the starboard hatch, within the existing tether.
local salvageSite=Instance.new("Model")
salvageSite.Name="Seabed salvage"
salvageSite.Parent=ocean
local cacheLocation=world.OutsideSpawn.Position+Vector3.new(20,0,6)
local floorRay=RaycastParams.new()
floorRay.FilterType=Enum.RaycastFilterType.Include
floorRay.FilterDescendantsInstances={floor}
local ground=workspace:Raycast(Vector3.new(cacheLocation.X,-305,cacheLocation.Z),Vector3.new(0,-90,0),floorRay)
local cacheBase=Vector3.new(cacheLocation.X,ground and ground.Position.Y or -350,cacheLocation.Z)

-- Fixed scenery gives the windows and exterior feeds parallax as the bell travels.
-- All formations sit outside its swept hull and the hatch-to-artifact corridor.
local function installWaterColumn()
	local scenery=Instance.new("Model")
	scenery.Name="Trench water column"
	local rng=Random.new(72403)
	local function dressing(name,frame,size,color,material,class)
		local p=Instance.new(class or "Part")
		p.Name,p.CFrame,p.Size,p.Color,p.Material=name,frame,size,color,material
		p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
		p.CastShadow=false
		p.Parent=scenery
		return p
	end
	local function socket(point,offset)
		local a=Instance.new("Attachment")
		a.Position=offset
		a.Parent=point
		return a
	end
	local rgb=Color3.fromRGB
	local v=Vector3.new
	local shaftAnchor=dressing("Shallow sunlight",CFrame.new(center),Vector3.one,rgb(8,20,24),Enum.Material.SmoothPlastic)
	shaftAnchor.Transparency=1
	for i=1,8 do
		local angle=math.pi*2*i/8
		local x,z=math.cos(angle)*49,math.sin(angle)*49
		local ray=Instance.new("Beam")
		ray.Name="Surface light shaft"
		ray.Attachment0=socket(shaftAnchor,v(x+12,30,z-4))
		ray.Attachment1=socket(shaftAnchor,v(x-9,-38,z+7))
		ray.Width0,ray.Width1=rng:NextNumber(1.2,2.9),rng:NextNumber(5,9)
		ray.Color=ColorSequence.new(rgb(186,231,207),rgb(76,149,160))
		ray.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
			NumberSequenceKeypoint.new(.15,.93),NumberSequenceKeypoint.new(.63,.97),NumberSequenceKeypoint.new(1,1)})
		ray.LightEmission,ray.LightInfluence,ray.FaceCamera=.57,.22,true
		ray.Parent=shaftAnchor
	end
	-- Discontinuous shelves cross the sight lines of the four camera bearings.
	for row,drop in {65,137,232,319,388} do
		local angle=row*2.19
		local shelf=CFrame.new(center+v(math.cos(angle)*69,-drop,math.sin(angle)*69))*CFrame.Angles(0,-angle,0)
		for i=-2,2 do
			local foot=shelf*CFrame.new(rng:NextNumber(-2.5,2.5),rng:NextNumber(-2,2),i*7)
				*CFrame.Angles(math.rad(rng:NextNumber(-9,9)),math.rad(rng:NextNumber(-26,26)),.14)
			local rock=rgb(37+row*2,61-row,66-row)
			dressing("Fractured escarpment",foot,v(13+rng:NextNumber(2,8),12+rng:NextNumber(2,7),11),rock,Enum.Material.Slate,"WedgePart")
			dressing("Sedimentary ledge",foot*CFrame.new(0,-4.2,0),v(17,.6,11),rgb(76,85,80),Enum.Material.Limestone)
		end
	end
	for i,offset in {v(11,0,-9),v(16,0,13),v(-8,0,16)} do
		local location=cacheBase+offset
		local hit=workspace:Raycast(location+Vector3.yAxis*24,-Vector3.yAxis*55,floorRay)
		local foot=hit and hit.Position or location
		for j=1,3 do
			local base=foot+v((j-1)*1.4,0,rng:NextNumber(-1.2,1.2))
			local height=if j==1 then 5.7+i*.45 else rng:NextNumber(2.1,4.4)
			local cf=CFrame.new(base+Vector3.yAxis*height*.42)*CFrame.Angles(0,j,.07*j)
			local chimney=dressing("Mineral chimney",cf,v(1.55,height,1.45),rgb(53,54,50),Enum.Material.Basalt)
			dressing("Sulfur rim",cf*CFrame.new(0,height*.49,0),v(1.66,.19,1.56),rgb(133,119,78),Enum.Material.Limestone)
			if j==1 then
				local plume=Instance.new("ParticleEmitter")
				plume.Name="Vent plume"
				plume.Texture="rbxasset://textures/particles/smoke_main.dds"
				plume.Color=ColorSequence.new(rgb(55,66,68),rgb(72,92,96))
				plume.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.58),NumberSequenceKeypoint.new(.45,.73),NumberSequenceKeypoint.new(1,1)})
				plume.Size=NumberSequence.new(.65,3.3)
				plume.Rate,plume.Lifetime,plume.Speed=2.2,NumberRange.new(2,3.3),NumberRange.new(1.5,2.4)
				plume.Acceleration=v(.42,.25,-.21)
				plume.Rotation,plume.RotSpeed=NumberRange.new(0,360),NumberRange.new(-12,12)
				plume.Parent=socket(chimney,v(0,height*.5,0))
			end
		end
		for j=1,7 do
			local a=j*2.4
			local cf=CFrame.new(foot+v(3.5*math.cos(a),.49,2.1*math.sin(a)))*CFrame.Angles(.13*math.sin(a),a,.24)
			local tube=dressing("Vent tubeworm",cf,v(1.4,.18,.18),rgb(157,155,130),Enum.Material.Sandstone)
			tube.Shape=Enum.PartType.Cylinder
			tube.CFrame=cf*CFrame.Angles(0,0,math.pi/2)
			local crown=dressing("Branchial crown",tube.CFrame*CFrame.new(.75,0,0),v(.3,.3,.31),rgb(139,61,49),Enum.Material.SmoothPlastic)
			crown.Shape=Enum.PartType.Ball
		end
	end
	scenery.Parent=ocean
end
installWaterColumn()
local stand=Instance.new("Part")
stand.Name="Survey cradle"
stand.Size=Vector3.new(5,1.3,4)
stand.CFrame=CFrame.new(cacheBase+Vector3.yAxis*.6)*CFrame.Angles(0,math.rad(15),0)
stand.Color=Color3.fromRGB(56,80,75)
stand.Material=Enum.Material.DiamondPlate
stand.Anchored,stand.CanCollide,stand.CanTouch=true,false,false
stand.Parent=salvageSite
local relic=samplerRelic:Clone()
relic:ClearAllChildren()
relic.Name="Trench artifact"
relic.CFrame=stand.CFrame*CFrame.new(0,1.5,0)
relic.Anchored,relic.CanCollide,relic.CanTouch=true,false,false
relic.Parent=salvageSite
local pickup=prompts.Artifact
pickup.Parent=relic
pickup.ActionText,pickup.ObjectText="Recover","Trench artifact"
pickup.RequiresLineOfSight=true
samplerRelic.Transparency=1
local beacon=Instance.new("PointLight")
beacon.Name="Salvage beacon"
beacon.Color=Color3.fromRGB(86,236,208)
beacon.Range=24
beacon.Parent=relic
local returnLight=Instance.new("PointLight")
returnLight.Name="Airlock return light"
returnLight.Color=Color3.fromRGB(255,169,69)
returnLight.Range=21
returnLight.Parent=prompts.Return:FindFirstAncestorWhichIsA("BasePart")

local leviathan = actors.Leviathan
local _, anglerSize = leviathan:GetBoundingBox()
local scale = (20 * math.max(envelope.Size.X,envelope.Size.Z)) / math.max(anglerSize.X,anglerSize.Y,anglerSize.Z)
leviathan:ScaleTo(leviathan:GetScale() * scale)

WormFigure.build(actors.CrackCrawler)

local function setShipY(y)
	local delta = Vector3.new(0,y-shipY,0)
	if delta.Y == 0 then return delta end
	driver.CFrame=home+Vector3.new(0,y,0)
	head.CFrame += delta
	shipY=y
	center=envelope.Position
	return delta
end

function World.travel(dt)
	if travelTime <= 0 then
		driver.AssemblyLinearVelocity=Vector3.zero
		return Vector3.zero
	end
	local slice = math.min(dt,travelTime)
	local y = shipY+(targetY-shipY)*(slice/travelTime)
	travelTime -= slice
	local delta=setShipY(y)
	driver.AssemblyLinearVelocity=delta/dt
	return delta
end

function World.setDepth(depth)
	local goal = -hullTravel * math.clamp(depth / Dive.targetDepth, 0, 1)
	if goal ~= targetY then targetY,travelTime = goal,travelStep end
end

function World.resetDepth()
	targetY,travelTime = 0,0
	driver.AssemblyLinearVelocity=Vector3.zero
	setShipY(0)
end
local cameraHeads, windows, sites, joints, lighting, crawlerLamps = {}, {}, {}, {}, {}, {}
local pursuerPosition
local labels={Leviathan="ANGLER",GiantSquid="GIANT SQUID",CrackCrawler="HULL CRAWLER",Pursuer="DEEP PURSUER"}
local runService=game:GetService("RunService")
for i=1,4 do
 cameraHeads[i]=world:WaitForChild("DiveCamera"..i)
 local lens=cameraHeads[i].CFrame*CFrame.new(0,0,-1.2)
 cameraHeads[i]:SetAttribute("HullMount",envelope.CFrame:ToObjectSpace(lens))
 local patch=barnacles:WaitForChild("Site"..i)
 sites[i]={}
 for _,part in patch:GetDescendants() do
  if part:IsA("BasePart") then
   local rest=part:GetAttribute("RestTransparency")
   table.insert(sites[i],{part=part,rest=rest or part.Transparency})
  end
 end
end
for i=1,3 do
 local window=world:WaitForChild("WormWindow"..i)
 windows[i]=window
 local lens=Instance.new("Part")
 lens.Name="Window contact alarm"
 lens.Size=Vector3.new(.68,.25,.25)
 lens.CFrame=window.CFrame*CFrame.new(0,1.45,.9)
 lens.Material,lens.Color=Enum.Material.SmoothPlastic,Color3.fromRGB(51,45,32)
 lens.CanCollide,lens.CanTouch,lens.CanQuery,lens.Massless=false,false,false,true
 lens.Parent=world["Dive stage"]
 local weld=Instance.new("WeldConstraint")
 weld.Part0,weld.Part1=window,lens
 weld.Parent=lens
 local lamp=Instance.new("PointLight")
 lamp.Range,lamp.Enabled=14,false
 lamp.Parent=lens
 crawlerLamps[i]=lamp
end
for name,label in labels do
 local model=actors[name]
 model:SetAttribute("ContactLabel",label)
 model:SetAttribute("Detectable",false)
 joints[model]={}
 for _,joint in model:GetDescendants() do
  if joint:IsA("Motor6D") and joint:GetAttribute("Axis") then
   table.insert(joints[model],{joint=joint,rest=joint.C0,axis=joint:GetAttribute("Axis"),
    amplitude=joint:GetAttribute("Amplitude"),phase=joint:GetAttribute("Phase")})
  end
 end
 if name=="Leviathan" or name=="GiantSquid" then
  local attachment=model.PrimaryPart:FindFirstChild("Pelagic fill") or Instance.new("Attachment")
  attachment.Name="Pelagic fill"
  attachment.Parent=model.PrimaryPart
  local light=attachment:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
  light.Name="Reflected water light"
  light.Range=60
  light.Shadows=false
  light.Parent=attachment
  lighting[model]={attachment=attachment,light=light,reveal=model:FindFirstChild("Beam return")}
 end
end
local phaseAngle={angler=-.14,squid=math.pi*.51}
local anglerCruise,squidCruise=740,328
local anglerRange,squidRange=anglerCruise,squidCruise
local oldElapsed
local function bearing(pos)
 local delta=pos-center
 if math.abs(delta.X)>math.abs(delta.Z) then return delta.X>0 and 2 or 4 end
 return delta.Z<0 and 1 or 3
end
function World.squidBearing()
 if not actors.GiantSquid:GetAttribute("Detectable") then
  return bearing(center+Vector3.new(math.sin(phaseAngle.squid),0,-math.cos(phaseAngle.squid)))
 end
 return bearing(actors.GiantSquid:GetPivot().Position)
end

function World.predatorNear(model,position,range)
	local names = if model == leviathan then {"Arched cranium","Bulbous abdomen"}
		else {"Cephalic lobe","Brachial crown"}
	for _,name in names do
		local part=model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local at=part.CFrame:PointToObjectSpace(position)
			local half=part.Size*.5
			local offset=at-Vector3.new(math.clamp(at.X,-half.X,half.X),math.clamp(at.Y,-half.Y,half.Y),math.clamp(at.Z,-half.Z,half.Z))
			if offset.Magnitude<=range then return true end
		end
	end
	return false
end
local function approach(value,target,speed,dt)
 return value+math.clamp(target-value,-speed*dt,speed*dt)
end
local function animate(model,t,frequency)
 for _,entry in joints[model] do
  entry.joint.C0=entry.rest*CFrame.fromAxisAngle(entry.axis,math.sin(t*frequency+entry.phase)*entry.amplitude)
 end
end
local function face(model,cf)
 -- The welded body follows one root. The tentacles, tail and fins have separate joints.
 if model.PrimaryPart and runService:IsRunning() then model.PrimaryPart.CFrame=cf else model:PivotTo(cf) end
end
local dormant={}
local function megafauna(model,unlocked,angle,radius,height,clock,heading,aim,lit,target,turn)
 local fill=lighting[model]
 if not unlocked then
  if not dormant[model] then
   model:SetAttribute("Detectable",false)
   fill.light.Enabled=false
   if fill.reveal then fill.reveal.Enabled=false end
   face(model,CFrame.new(0,0,-5000))
   dormant[model]=true
  end
  return
 end
 dormant[model]=false
 local radial=Vector3.new(math.sin(angle),0,-math.cos(angle))
 local tangent=Vector3.new(math.cos(angle),0,math.sin(angle))
 local pos=center+radial*radius+Vector3.new(0,height,0)
 local forward=(tangent*heading.X+radial*heading.Z+Vector3.new(0,.036*math.sin(clock*.12),0)).Unit
 local cf=CFrame.lookAt(pos,pos+forward)
 if target then cf=cf:Lerp(CFrame.lookAt(pos,target),turn) end
 cf*=CFrame.Angles(0,0,.042*math.sin(clock*.21))
 face(model,cf)
 model:SetAttribute("Detectable",true)
 local illuminated=lit and (bearing(pos)==aim or dirs[aim]:Dot(radial)>.68)
 local lightOffset=(-radial*24+Vector3.new(0,19,0))
 fill.attachment.Position=cf:VectorToObjectSpace(lightOffset)
 fill.light.Color=illuminated and Color3.fromRGB(174,226,215) or Color3.fromRGB(99,163,185)
 fill.light.Brightness=illuminated and 4.5 or .92
 fill.light.Enabled=true
 if fill.reveal then fill.reveal.Enabled=illuminated end
 animate(model,clock,model==actors.Leviathan and .67 or .52)
end

function World.update(state)
 local phase=state.phase or "Lobby"
 local active=activePhase[phase] == true
 local aim=math.clamp(math.floor(state.aim or 1),1,4)
 local sqSide=math.clamp(math.floor(state.squidSide or 1),1,4)
 local section=math.clamp(math.floor(state.crawlerSection or 1),1,3)
 local shark, squid = state.shark or 0, state.squid or 0
 local crawler, swarm, pursuer = state.crawler or 0, state.swarm or 0, state.pursuer or 0
 local powered = (state.battery or 100)>0
 local lit = active and powered and state.light==true
 for _,id in {"Engine","Light","Extinguisher","Airlock","Return","Planks"} do showPrompt(id,active) end
 showPrompt("AimLeft",false)
 showPrompt("AimRight",false)
 showPrompt("Sonar",active and not state.systemsOffline)
 showPrompt("Camera",active and not state.systemsOffline)
 showPrompt("ClearSwarm",false)
 local recovering=phase=="Bottom" and state.recoveryDeadline~=nil
 for i,parts in sites do
  local progress=state.cleanSites and state.cleanSites[i] or 0
  local show=active and swarm>0 and progress<3
  showPrompt("Clean"..i,show)
  for _,item in parts do
   local faded=show and item.rest or 1
   if item.part.Transparency~=faded then item.part.Transparency=faded end
  end
 end
 local artifactAvailable=phase=="Bottom" and not state.salvageTaken
 showPrompt("Artifact",artifactAvailable)
 relic.Transparency=if artifactAvailable then .1 else 1
 stand.Transparency=if phase=="Bottom" then 0 else 1
 beacon.Enabled=artifactAvailable
 beacon.Brightness=1.9+.45*math.sin((state.elapsed or 0)*3)
 returnLight.Enabled=phase=="Bottom"
 returnLight.Brightness=if recovering then 2.8+.7*math.sin((state.elapsed or 0)*5) else 1.5
 for i=1,3 do
  local cracked=active and state.cracks and state.cracks[i]==true or false
  local breach=if active and state.breaches then state.breaches[i] else 0
  showPrompt("Repair"..i,cracked and breach==0)
  showPrompt("Patch"..i,active and breach>0)
  Breach.render(breachEffects[i],breach)
  showPrompt("Spray"..i,false)
  for _,line in leaks[i] do line.Transparency=cracked and .08 or 1 end
  local lamp=crawlerLamps[i]
  local warned=active and crawler>0 and i==section
  local urgent=state.crawlerEntryWarning and cracked
  local pulse=.5+.5*math.cos((state.elapsed or 0)*(urgent and 13 or 6))
  local color=if not warned then Color3.fromRGB(51,45,32) elseif state.boarded
   then Color3.fromRGB(255,61,43) else Color3.fromRGB(255,174,65)
  lamp.Enabled,lamp.Color=warned,color
  lamp.Brightness=if warned then .55+1.4*pulse else 0
  lamp.Parent.Color=if warned then color:Lerp(Color3.fromRGB(55,38,25),.52*(1-pulse)) else color
  lamp.Parent.Material=if warned then Enum.Material.Neon else Enum.Material.SmoothPlastic
  local cell=stations["Battery stack"]["CellIndicator"..i]
  local charge=state.battery or 100
  cell.Color=charge>((i-1)*100/3) and (charge<27 and amber or meterColor) or offColor
 end
 local depth=math.clamp(state.depth or 0,0,Dive.targetDepth)
 local message="CLEAR"
 if shark>0 then message="LARGE WAKE" elseif squid>0 then message="MASS / "..bearings[sqSide] elseif crawler>0 then message="HULL BREACH" elseif swarm>0 then message="HULL FOULING" elseif pursuer>.12 then message="WAKE BELOW" end
 if state.systemsOffline then message="OFFLINE / HULL BREACHED"
 elseif not state.sonarOn then message="PASSIVE" elseif message=="CLEAR" then message="PELAGIC RETURNS" end
 screen.Text=string.format("%03d M    %02d%%\n%s   •   %s",math.floor(depth+.5),math.max(0,math.floor(state.battery or 100)),bearings[aim],message)
 engineLabel.Text=state.engine and "• RUN" or "○ STOP"
 engineLabel.TextColor3=state.engine and meterColor or amber
 engineLever.Color=state.engine and amber or offColor
 lampSwitch.Face.Legend.Text=lit and "LAMP ON" or "LAMP OFF"
 lampSwitch.Face.Legend.TextColor3=lit and meterColor or amber
 local d=dirs[aim]
 local pos=cameraHeads[aim].Position+d*1.7+Vector3.yAxis*.8
 head.CFrame=CFrame.lookAt(pos,pos+d)
 spot.Enabled=lit scatter.Enabled=lit
 local moving=active and phase~="Bottom" and (state.engine or (phase=="Ascent" and (state.coast or 0)>.2))
 if lastDirection~=phase..tostring(moving) then
  lastDirection=phase..tostring(moving)
  local vertical=phase=="Ascent" and -1 or 1
  for _,em in snow do
   local slip=if not moving then .15 elseif phase=="Ascent" then 5 else 2.4
   em.Acceleration=Vector3.new(.08,vertical*slip,.03)
   em.Speed=if not moving then NumberRange.new(.12,.4) elseif phase=="Ascent" then NumberRange.new(3.5,6) else NumberRange.new(1.6,2.8)
   em.EmissionDirection=vertical==1 and Enum.NormalId.Top or Enum.NormalId.Bottom
   em.Rate=if not active then .35 elseif not moving then 1.2 elseif phase=="Ascent" then 6 else 4
  end
 end
 local now=os.clock()
 if now-lastRender<.10 and active then return end
 lastRender=now
 local elapsed=state.elapsed or 0
 local restarted=not oldElapsed or elapsed<oldElapsed
 if restarted then
  phaseAngle.angler, phaseAngle.squid=-.14,math.pi*.51
  anglerRange,squidRange=anglerCruise,squidCruise
 end
 local dt=math.clamp(elapsed-(oldElapsed or elapsed),0,.75)
 oldElapsed=active and elapsed or nil
 phaseAngle.angler+=(shark>0 and .022 or .011)*dt
 anglerRange=approach(anglerRange,anglerCruise-(anglerCruise-294)*math.clamp(shark*1.4,0,1),48,dt)
 if squid>0 then
  local target=(sqSide-1)*math.pi/2
  local delta=math.atan2(math.sin(target-phaseAngle.squid),math.cos(target-phaseAngle.squid))
  phaseAngle.squid+=math.clamp(delta,-.062*dt,.062*dt)
 else
  phaseAngle.squid-=.012*dt
 end
 squidRange=approach(squidRange,squidCruise-(squidCruise-88)*math.clamp(squid*1.55,0,1),23,dt)
 -- Megafauna stay beyond the pressure hull even when the feeding tentacles pass broadside.
 megafauna(leviathan,active and Dive.isUnlocked(state,"shark"),phaseAngle.angler,anglerRange,7.5+18*math.sin(elapsed*.035),elapsed,Vector3.new(1,0,-.08*shark),aim,lit)
 local target=if squid>0 then state.squidTarget or center else nil
 megafauna(actors.GiantSquid,active and Dive.isUnlocked(state,"squid"),phaseAngle.squid,squidRange,12+14*math.sin(elapsed*.028+1.4),
  elapsed,Vector3.new(-1,0,-.26*squid),aim,lit,target,math.min(1,.44+squid*2.8))
 local retreat=state.crawlerRetreat
 local escaping=active and retreat and elapsed-retreat.started<2.15
 if retreat and not escaping then state.crawlerRetreat=nil end
 local crawlerPresent=active and (crawler>0 or escaping==true)
 actors.CrackCrawler:SetAttribute("Detectable",crawlerPresent)
 if escaping then
  local glass=windows[section].CFrame
  local from=envelope.CFrame*retreat.from
  local t=math.clamp((elapsed-retreat.started)/2.15,0,1)
  local opening=glass.Position+glass.LookVector*(t*5-2)
  local run=math.clamp((t-.16)/.84,0,1)
  local at=from.Position:Lerp(opening-Vector3.yAxis*(1.88*run^3),run)
  at+=Vector3.yAxis*(math.sin(elapsed*19)*.19*run)
  local direction=opening-at
  local look=if direction.Magnitude>.1 then CFrame.lookAt(at,opening) else glass.Rotation+at
  local recoil=from:Lerp(look,math.min(1,t*5))
  face(actors.CrackCrawler,recoil*CFrame.Angles(-.58*math.sin(t*math.pi),0,.28*math.sin(elapsed*16)))
  animate(actors.CrackCrawler,elapsed,5.85)
 elseif crawlerPresent then
  local glass=windows[section].CFrame
  local entry=if state.boarded then math.clamp((elapsed-(state.crawlerBoardAt or elapsed-1.25))/1.25,0,1) else 0
  local offset=if state.boarded then .21-1.86*entry else .21+5*math.clamp(1-crawler/.47,0,1)
  local at=glass.Position+glass.LookVector*offset
  local cf=(state.crawlerGrip or CFrame.lookAt(at,at-glass.LookVector))*CFrame.Angles(0,0,.12*math.sin(elapsed*.43))
  face(actors.CrackCrawler,cf)
  animate(actors.CrackCrawler,elapsed,1.64)
 else face(actors.CrackCrawler,hidden) end
 pose(actors.HullSwarm,hidden)
 local trailing=active and pursuer>0 and (recovering or phase=="Ascent")
 actors.Pursuer:SetAttribute("Detectable",trailing)
 if trailing then
  local target=if recovering then world.OutsideSpawn.Position else center
  local approachPoint=cacheBase+Vector3.new(51,7,-43)
  local nearHatch=target+Vector3.new(5,0,-9)
  local trail=if recovering then approachPoint:Lerp(nearHatch,pursuer)
   else center+Vector3.new(-6+math.cos(elapsed*.11)*3,-12-(1-pursuer)*19,-32-(1-pursuer)*32)
  if not pursuerPosition then pursuerPosition=trail end
  local offset=trail-pursuerPosition
  if offset.Magnitude>0 then pursuerPosition+=offset.Unit*math.min(offset.Magnitude,dt*26) end
  pose(actors.Pursuer,CFrame.lookAt(pursuerPosition,target))
 else
  pursuerPosition=nil
  pose(actors.Pursuer,hidden)
 end
 local dim=(state.battery or 100)<21 and (.66+.12*math.sin(now*7)) or .86
 local emergency=active and state.systemsOffline
 local pulse=.5+.5*math.cos(elapsed*math.pi*1.7)
 for _,fixture in lamps do
  fixture.light.Color=if emergency then Color3.fromRGB(255,43,30) else fixture.color
  fixture.light.Brightness=if emergency then .3+pulse*1.65 else dim
 end
end
return World
