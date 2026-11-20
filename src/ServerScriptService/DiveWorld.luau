-- All interactions are validated by the run controller. This module presents its state.
local World = {}
local world = workspace:WaitForChild("Thalassa")
local stations = world.Stations
local actors = world.Contacts
local ocean = world.Ocean
local floor = ocean["Trench floor"]
local head = ocean.SearchlightHead
local spot = head["Search beam"]
local scatter = head["Particle scatter"]
local screen = stations.SONAR.SonarScreen.Face.Legend
local engineLabel = stations.ENGINE.EngineStatus.Face.Legend
local engineLever = stations.ENGINE.EngineLever
local lampSwitch = stations.OPTICS.Light
local relic = stations.Sampler.Artifact
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
for _,item in world:GetDescendants() do
 if item:IsA("ProximityPrompt") and item:GetAttribute("Action") then
  prompts[item:GetAttribute("Action")] = item
 elseif item:IsA("ParticleEmitter") and item.Name=="Suspended sediment" then
  table.insert(snow,item)
 elseif item:IsA("PointLight") and item.Parent.Name=="Work lamp" then
  table.insert(lamps,item)
 end
end
for i=1,3 do leaks[i] = stations["Section"..i].Fracture:GetChildren() end

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
local depthScale = .72
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

local leviathan = actors.Leviathan
local _, anglerSize = leviathan:GetBoundingBox()
local scale = (10 * math.max(envelope.Size.X,envelope.Size.Z)) / math.max(anglerSize.X,anglerSize.Y,anglerSize.Z)
leviathan:ScaleTo(leviathan:GetScale() * scale)

-- Preserve the crawler's existing joints while making its elongated segments visible.
for _,part in actors.CrackCrawler:GetDescendants() do
	if part:IsA("Part") and part.Name=="Vermiform segment" and part.Shape==Enum.PartType.Ball and not part.CanCollide then
		part.Shape=Enum.PartType.Block
		local surface=Instance.new("SpecialMesh")
		surface.MeshType=Enum.MeshType.Sphere
		surface.Parent=part
	end
end

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
	local goal = -math.clamp(depth,0,600)*depthScale
	if goal ~= targetY then targetY,travelTime = goal,travelStep end
end

function World.resetDepth()
	targetY,travelTime = 0,0
	driver.AssemblyLinearVelocity=Vector3.zero
	setShipY(0)
end
local cameraHeads, windows, sites, joints, lighting = {}, {}, {}, {}, {}
local labels={Leviathan="ANGLER",GiantSquid="GIANT SQUID",CrackCrawler="HULL CRAWLER",Pursuer="DEEP PURSUER"}
local runService=game:GetService("RunService")
for i=1,4 do
 cameraHeads[i]=world:WaitForChild("DiveCamera"..i)
 local patch=barnacles:WaitForChild("Site"..i)
 sites[i]={}
 for _,part in patch:GetDescendants() do
  if part:IsA("BasePart") then
   local rest=part:GetAttribute("RestTransparency")
   table.insert(sites[i],{part=part,rest=rest or part.Transparency})
  end
 end
end
for i=1,3 do windows[i]=world:WaitForChild("WormWindow"..i) end
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
local anglerCruise,squidCruise=515,328
local anglerRange,squidRange=anglerCruise,squidCruise
local oldElapsed
local function bearing(pos)
 local delta=pos-center
 if math.abs(delta.X)>math.abs(delta.Z) then return delta.X>0 and 2 or 4 end
 return delta.Z<0 and 1 or 3
end
function World.squidBearing()
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
local function megafauna(model,angle,radius,height,clock,heading,aim,lit)
 local radial=Vector3.new(math.sin(angle),0,-math.cos(angle))
 local tangent=Vector3.new(math.cos(angle),0,math.sin(angle))
 local pos=center+radial*radius+Vector3.new(0,height,0)
 local forward=(tangent*heading.X+radial*heading.Z+Vector3.new(0,.036*math.sin(clock*.12),0)).Unit
 local cf=CFrame.lookAt(pos,pos+forward)*CFrame.Angles(0,0,.042*math.sin(clock*.21))
 face(model,cf)
 model:SetAttribute("Detectable",true)
 local fill=lighting[model]
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
 for _,id in {"Engine","Light","AimLeft","AimRight","Extinguisher","Airlock","Return","Sonar","Camera"} do showPrompt(id,active) end
 showPrompt("ClearSwarm",false)
 for i,parts in sites do
  local progress=state.cleanSites and state.cleanSites[i] or 0
  local show=active and swarm>0 and progress<3
  showPrompt("Clean"..i,show)
  for _,item in parts do
   local faded=show and item.rest or 1
   if item.part.Transparency~=faded then item.part.Transparency=faded end
  end
 end
 showPrompt("Artifact",phase=="Bottom")
 relic.Transparency=phase=="Bottom" and .12 or 1
 for i=1,3 do
  local cracked=active and state.cracks and state.cracks[i]==true or false
  showPrompt("Repair"..i,cracked)
  showPrompt("Spray"..i,active and state.boarded==true and crawler>0 and section==i)
  for _,line in leaks[i] do line.Transparency=cracked and .08 or 1 end
  local cell=stations["Battery stack"]["CellIndicator"..i]
  local charge=state.battery or 100
  cell.Color=charge>((i-1)*100/3) and (charge<27 and amber or meterColor) or offColor
 end
 local depth=math.clamp(state.depth or 0,0,600)
 local message="CLEAR"
 if shark>0 then message="LARGE WAKE" elseif squid>0 then message="MASS / "..bearings[sqSide] elseif crawler>0 then message="HULL BREACH" elseif swarm>0 then message="HULL FOULING" elseif pursuer>.12 then message="WAKE BELOW" end
 if not state.sonarOn then message="PASSIVE" elseif message=="CLEAR" then message="PELAGIC RETURNS" end
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
 if lastDirection~=phase..tostring(state.engine) then
  lastDirection=phase..tostring(state.engine)
  local vertical=phase=="Ascent" and -1 or 1
  for _,em in snow do
   em.Acceleration=Vector3.new(.08,state.engine and vertical*1.1 or .04,.03)
   em.EmissionDirection=vertical==1 and Enum.NormalId.Top or Enum.NormalId.Bottom
   em.Rate=active and 3.3 or .35
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
 anglerRange=approach(anglerRange,anglerCruise-(anglerCruise-192)*math.clamp(shark*1.4,0,1),35,dt)
 if squid>0 then
  local target=(sqSide-1)*math.pi/2
  local delta=math.atan2(math.sin(target-phaseAngle.squid),math.cos(target-phaseAngle.squid))
  phaseAngle.squid+=math.clamp(delta,-.062*dt,.062*dt)
 else
  phaseAngle.squid-=.012*dt
 end
 squidRange=approach(squidRange,squidCruise-(squidCruise-88)*math.clamp(squid*1.55,0,1),23,dt)
 -- Megafauna stay beyond the pressure hull even when the feeding tentacles pass broadside.
 megafauna(leviathan,phaseAngle.angler,anglerRange,7.5+18*math.sin(elapsed*.035),elapsed,Vector3.new(1,0,-.14*shark),aim,lit)
 megafauna(actors.GiantSquid,phaseAngle.squid,squidRange,12+14*math.sin(elapsed*.028+1.4),elapsed,Vector3.new(-1,0,-.26*squid),aim,lit)
 local crawlerPresent=active and crawler>0
 actors.CrackCrawler:SetAttribute("Detectable",crawlerPresent)
 if crawlerPresent then
  local glass=windows[section].CFrame
  local at=glass.Position+glass.LookVector*(state.boarded and -1.65 or .21)
  local cf=CFrame.lookAt(at,at-glass.LookVector)*CFrame.Angles(0,0,.12*math.sin(elapsed*.43))
  face(actors.CrackCrawler,cf)
  animate(actors.CrackCrawler,elapsed,1.64)
 else face(actors.CrackCrawler,hidden) end
 pose(actors.HullSwarm,hidden)
 local trailing=active and phase=="Ascent" and pursuer>0
 actors.Pursuer:SetAttribute("Detectable",trailing)
 local pursuerPos=center+Vector3.new(-6+math.cos(elapsed*.11)*3,-12-(1-pursuer)*19,-32-(1-pursuer)*32)
 pose(actors.Pursuer,trailing and CFrame.lookAt(pursuerPos,center) or hidden)
 local dim=(state.battery or 100)<21 and (.66+.12*math.sin(now*7)) or .86
 for _,lamp in lamps do lamp.Brightness=dim end
end
return World
