local Http = game:GetService("HttpService")
local Breach = {}
local rng = Random.new()
local targetsByLevel = {Easy=4,Normal=5,Hard=6,Nightmare=7}
local hitWindow = {Easy=.30,Normal=.255,Hard=.215,Nightmare=.18}
local spacing = {Easy=.98,Normal=.89,Hard=.80,Nightmare=.72}

local function panelPart(parent,name,size,cf,color,material,transparency)
	local part=Instance.new("Part")
	part.Name,part.Size,part.CFrame,part.Color,part.Material=name,size,cf,color,material
	part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery=true,false,false,false
	part.Transparency,part.CastShadow=transparency,transparency<1
	part.Parent=parent
	return part
end

local function prompt(parent,id,title,verb,key)
	local p=Instance.new("ProximityPrompt")
	p.Name,p.ObjectText,p.ActionText="ActionPrompt",title,verb
	p.KeyboardKeyCode,p.GamepadKeyCode=key,Enum.KeyCode.ButtonX
	p.MaxActivationDistance,p.HoldDuration,p.RequiresLineOfSight=6,.18,false
	p.Enabled=false
	p:SetAttribute("Action",id)
	p.Parent=parent
	return p
end

function Breach.install(stations)
	local rack=Instance.new("Model")
	rack.Name="Breach repair supplies"
	-- The forward bulkhead keeps planks reachable from the central passage.
	local at=stations.Parent.ShipEnvelope.CFrame*CFrame.new(.8,-3,-20.05)
	local amber=Color3.fromRGB(232,170,70)
	local metal=Enum.Material.Metal
	local plate=panelPart(rack,"Supply placard",Vector3.new(3.1,.64,.15),at*CFrame.new(0,2.12,-.25),amber,metal,0)
	local sign=Instance.new("SurfaceGui")
	sign.Face,sign.PixelsPerStud,sign.LightInfluence=Enum.NormalId.Back,64,.2
	sign.Parent=plate
	local title=Instance.new("TextLabel")
	title.Size,title.BackgroundTransparency,title.Text=UDim2.fromScale(1,1),1,"REPAIR PLANKS"
	title.Font,title.TextScaled,title.TextColor3=Enum.Font.GothamBold,true,Color3.fromRGB(28,29,22)
	title.Parent=sign
	panelPart(rack,"Deck rack",Vector3.new(3.2,.48,.89),at*CFrame.new(0,-.9,0),amber,metal,0)
	local middle
	for i=-2,2 do
		local plank=panelPart(rack,"Timber plank",Vector3.new(.48,2.28,.19),
			at*CFrame.new(i*.54,.33,0)*CFrame.Angles(.16,0,-i*.024),Color3.fromRGB(146+i*7,104+i*4,61+i*2),Enum.Material.WoodPlanks,0)
		if i==0 then middle=plank end
	end
	prompt(middle,"Planks","Repair planks","Take a plank",Enum.KeyCode.E)
	rack.Parent=stations

	local effects={}
	for section=1,3 do
		local station=stations["Section"..section]
		local outlet=station["Spray point"]
		local at=outlet.CFrame
		local marker=panelPart(station,"Breach patch point",Vector3.one,at+Vector3.yAxis*.55,amber,metal,1)
		prompt(marker,"Patch"..section,"Hull breach • 0"..section,"Fit repair plank",Enum.KeyCode.R)
		local inward=if section==1 then Vector3.zAxis elseif section==2 then Vector3.xAxis else -Vector3.zAxis
		local jet=panelPart(station,"Water ingress",Vector3.one,CFrame.lookAt(at.Position,at.Position+inward),amber,metal,1)
		local spray=Instance.new("ParticleEmitter")
		spray.Name,spray.Texture="Pressure spray","rbxasset://textures/particles/smoke_main.dds"
		spray.Enabled,spray.EmissionDirection=false,Enum.NormalId.Front
		spray.Color=ColorSequence.new(Color3.fromRGB(159,218,233))
		spray.Size=NumberSequence.new(.15,.5)
		spray.Transparency=NumberSequence.new(.25,1)
		spray.Lifetime,spray.Speed=NumberRange.new(.35,.65),NumberRange.new(7,12)
		spray.SpreadAngle,spray.Acceleration=Vector2.new(19,16),Vector3.new(0,-11,0)
		spray.Parent=jet
		local waterCenter=at.Position+inward*3.3
		local water=panelPart(station,"Bilge water",Vector3.new(6,.07,6),CFrame.new(waterCenter.X,120.1,waterCenter.Z),
			Color3.fromRGB(35,98,112),Enum.Material.Glass,1)
		effects[section]={spray=spray,water=water,marker=marker}
	end
	return effects
end

function Breach.render(effect,severity)
	local wet=severity>0
	effect.spray.Enabled=wet
	if wet then
		effect.spray.Rate=16+severity*17
		effect.water.Size=Vector3.new(4+severity*2,.09+severity*.055,4+severity*2)
	end
	effect.water.Transparency=if wet then .53-severity*.07 else 1
end

function Breach.newChallenge(difficulty,section,kind)
	local count=targetsByLevel[difficulty] or targetsByLevel.Normal
	local interval=spacing[difficulty] or spacing.Normal
	local thruster=kind=="Thruster"
	if thruster then interval*=.83 end
	local start=workspace:GetServerTimeNow()+(if thruster then 1.25 else 1.45)
	local sequence={}
	local x,y
	for i=1,count do
		local u,v
		repeat u,v=rng:NextNumber(.13,.87),rng:NextNumber(.16,.84)
		until not x or (Vector2.new(u-x,v-y)).Magnitude>.23
		x,y=u,v
		sequence[i]={x=x,y=y,at=start+(i-1)*interval}
	end
	return {id=Http:GenerateGUID(false),section=section,kind=kind,targets=sequence,completed=0,
		window=hitWindow[difficulty] or hitWindow.Normal}
end

function Breach.hit(challenge,arg,now,ping)
	local index=challenge.completed+1
	if type(arg)~="table" or arg.id~=challenge.id or arg.index~=index then return "Ignore" end
	local strike=arg.time
	local allowance=math.clamp(ping+.14,.17,.36)
	if type(strike)~="number" or strike~=strike or strike>now+.04 or strike<now-allowance then return "Ignore" end
	local target=challenge.targets[index]
	if not target then return "Ignore" end
	if math.abs(strike-target.at)>challenge.window then return "Miss" end
	challenge.completed=index
	return if index==#challenge.targets then "Complete" else "Hit"
end

function Breach.hasExpired(challenge,now)
	local target=challenge.targets[challenge.completed+1]
	return target and now>target.at+challenge.window+.37
end

return Breach
