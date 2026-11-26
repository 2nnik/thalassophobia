-- Client displays the server's synchronized cutter and sends only movement intent and input times.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Lighting=game:GetService("Lighting")
local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local Client={}
local net, controls, screen
local overlay,card,dial,pivot,headline,progress,feedback,travel,rise,down,cancel,help,scale
local active,challenge=false,nil
local ticks,travelPoints={},{}
local heldRise,heldDown=false,false
local riseTouch,downTouch
local pending,lastSend=nil,0
local needleOffset,needleCorrectUntil=0,0
local color={
	paper=Color3.fromRGB(226,241,234),steel=Color3.fromRGB(43,70,74),dark=Color3.fromRGB(12,29,33),
	panel=Color3.fromRGB(17,40,44),foam=Color3.fromRGB(105,237,198),muted=Color3.fromRGB(147,178,177),
	amber=Color3.fromRGB(252,186,94)
}
local function make(class,parent,props)
	local v=Instance.new(class)
	for key,val in props do v[key]=val end
	v.Parent=parent
	return v
end
local function frame(parent,pos,size,col,z)
	return make("Frame",parent,{Position=pos,Size=size,BorderSizePixel=0,BackgroundColor3=col,ZIndex=z})
end
local function label(parent,text,pos,size,font,textSize,col,z)
	return make("TextLabel",parent,{Text=text,Position=pos,Size=size,Font=font,TextSize=textSize,
		TextColor3=col,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=z})
end
local function button(parent,text,pos,size)
	local b=make("TextButton",parent,{Text=text,Position=pos,Size=size,BackgroundColor3=color.steel,TextColor3=color.paper,
		Font=Enum.Font.Code,TextSize=14,AutoButtonColor=true,BorderSizePixel=0,ZIndex=27})
	return b
end
local function round(obj)
	make("UICorner",obj,{CornerRadius=UDim.new(1,0)})
end

local REVEAL_RANGE, BLACKOUT_RANGE = 25, 52
local WINDOW_REVEAL_RANGE, WINDOW_BLACKOUT_RANGE = 74, 110
local BEAM_REVEAL_RANGE, BEAM_BLACKOUT_RANGE = 122, 182
local contactNames = {"Leviathan","GiantSquid","CrackCrawler","Pursuer"}
local shallowWater, twilightWater, deepWater = Color3.fromRGB(143,218,207), Color3.fromRGB(58,112,143), Color3.fromRGB(18,42,55)
local shallowDecay, twilightDecay, deepDecay = Color3.fromRGB(65,133,137), Color3.fromRGB(31,61,95), Color3.fromRGB(8,18,31)
local invisible = NumberSequence.new(1)
local footsteps, contacts = {}, {}
local observedCharacter, footstepMode, footstepAdded
local atmosphere, originalAtmosphere, originalExposure, originalOutdoor
local targetDarkness, darkness, nextWaterUpdate = 0, 0, 0
local strokes, breathing, bubblePool, headlamp
local steelStep, strideDistance = nil, 0
local random = Random.new()
local nextContactCheck, nextBubble, bubbleIndex = 0, 0, 0
local inDive, searchlight, cabinSteps = false, false, false
local jellyBloom=require(script.Parent:WaitForChild("DiveJellyBloomView"))

local function beginWater()
	originalExposure,originalOutdoor=Lighting.ExposureCompensation,Lighting.OutdoorAmbient
	atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		originalAtmosphere={}
		for _,property in {"Color","Decay","Density","Haze","Glare","Offset"} do
			originalAtmosphere[property]=atmosphere[property]
		end
	end
	darkness,nextWaterUpdate=targetDarkness,0
end

local function stepWater(dt)
	local bloom=jellyBloom.render(dt)
	darkness+=(targetDarkness-darkness)*(1-math.exp(-2.2*dt))
	local now=os.clock()
	if now<nextWaterUpdate then return end
	nextWaterUpdate=now+.075
	Lighting.ExposureCompensation=originalExposure+.57*(1-darkness)-.18*darkness
	Lighting.OutdoorAmbient=originalOutdoor:Lerp(Color3.fromRGB(102,158,173),(1-darkness)*.8)
		:Lerp(Color3.fromRGB(109,76,142),bloom*.54)
	if not atmosphere then return end
	-- A green shelf gives way to blue twilight before the last light drains from the trench.
	local shelf=math.clamp(darkness/.48,0,1)
	local trench=math.clamp((darkness-.48)/.52,0,1)
	atmosphere.Color=shallowWater:Lerp(twilightWater,shelf):Lerp(deepWater,trench)
	atmosphere.Decay=shallowDecay:Lerp(twilightDecay,shelf):Lerp(deepDecay,trench)
	atmosphere.Density=.20+.45*darkness
	atmosphere.Haze=.65+1.9*darkness
	atmosphere.Glare=0
	atmosphere.Offset=.19-.16*darkness
	if bloom>0 then
		atmosphere.Color=atmosphere.Color:Lerp(Color3.fromRGB(108,126,195),bloom*.67)
		atmosphere.Decay=atmosphere.Decay:Lerp(Color3.fromRGB(119,46,123),bloom*.64)
		atmosphere.Density*=1-.48*bloom
		atmosphere.Haze*=1-.39*bloom
	end
end

local function resetWater()
	if originalExposure~=nil then
		Lighting.ExposureCompensation,Lighting.OutdoorAmbient=originalExposure,originalOutdoor
	end
	if atmosphere and atmosphere.Parent then
		for property,value in originalAtmosphere do atmosphere[property]=value end
	end
	atmosphere,originalAtmosphere,originalExposure,originalOutdoor=nil,nil,nil,nil
end

local function muteFootstep(object)
	if not (object:IsA("Sound") or object:IsA("AudioPlayer")) then return end
	local name = object.Name:lower()
	local asset = tostring(if object:IsA("Sound") then object.SoundId else object.AssetId)
	local walking = name=="running" or name:find("footstep",1,true) or asset:find("action_footsteps",1,true)
	local exteriorContact = footstepMode=="Swim" and (name=="climbing" or name=="landing")
	if footsteps[object] or not (walking or exteriorContact) then return end
	local original = object.Volume
	object.Volume = 0
	footsteps[object] = {
		volume=original,
		connection=object:GetPropertyChangedSignal("Volume"):Connect(function()
			if object.Volume~=0 then object.Volume=0 end
		end),
	}
end

local function listenToCharacter(character,mode)
	if observedCharacter==character and footstepMode==mode then return end
	if footstepAdded then footstepAdded:Disconnect() footstepAdded=nil end
	for object, state in footsteps do
		state.connection:Disconnect()
		if object.Parent then object.Volume=state.volume end
	end
	table.clear(footsteps)
	observedCharacter,footstepMode=character,mode
	if character then
		footstepAdded=character.DescendantAdded:Connect(muteFootstep)
		for _,descendant in character:GetDescendants() do muteFootstep(descendant) end
	end
end

local function stopSteelSteps()
	if footstepMode=="Steel" then listenToCharacter(nil) end
	if steelStep then steelStep:Destroy() steelStep=nil end
	strideDistance=0
end

local function stepSteelSteps(dt)
	local character=Players.LocalPlayer.Character
	if observedCharacter~=character then stopSteelSteps() end
	listenToCharacter(character,"Steel")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health<=0 or not root or humanoid.FloorMaterial==Enum.Material.Air
		or humanoid.MoveDirection.Magnitude<.1 then
		strideDistance=0
		return
	end
	local velocity=root.AssemblyLinearVelocity
	local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
	if speed<1 then strideDistance=0 return end
	strideDistance+=speed*math.min(dt,.1)
	if strideDistance<3.5 then return end
	strideDistance%=3.5
	if not steelStep then
		-- A short stock impact plus closely spaced echoes gives the deck its metal ring.
		steelStep=make("Sound",SoundService,{Name="SteelDeckStep",SoundId="rbxasset://sounds/action_jump_land.mp3"})
		make("EqualizerSoundEffect",steelStep,{LowGain=-13,MidGain=3,HighGain=2})
		make("EchoSoundEffect",steelStep,{Delay=.038,Feedback=.27,DryLevel=-2,WetLevel=-11})
		make("ReverbSoundEffect",steelStep,{DecayTime=.32,Density=.46,Diffusion=.58,DryLevel=0,WetLevel=-13})
	end
	steelStep.Volume=.085+math.min(speed/16,1)*.045
	steelStep.PlaybackSpeed=random:NextNumber(1.32,1.49)
	steelStep:Stop()
	steelStep:Play()
end

-- A model's pivot can be hundreds of studs from the tip of a fin or tentacle.
-- Use the nearest visible part's oriented bounds as the first surface contact.
local function distanceToPart(point,part)
	local p=part.CFrame:PointToObjectSpace(point)
	local radius=part.Size*.5
	local x=math.max(math.abs(p.X)-radius.X,0)
	local y=math.max(math.abs(p.Y)-radius.Y,0)
	local z=math.max(math.abs(p.Z)-radius.Z,0)
	return math.sqrt(x*x+y*y+z*z)
end

local function contactObjects(record,object)
	local property, hidden
	if object:IsA("BasePart") then
		property="LocalTransparencyModifier"
	elseif object:IsA("Light") then
		property,hidden="Range",0
	elseif object:IsA("ParticleEmitter") then
		property,hidden="Rate",0
	elseif object:IsA("Beam") or object:IsA("Trail") then
		property,hidden="Transparency",invisible
	end
	if property then
		record.objects[object]={property=property,original=object[property],hidden=hidden}
		record.alpha=nil
	end
end

local function releaseContact(record)
	record.added:Disconnect()
	record.removing:Disconnect()
	for object,entry in record.objects do
		if object.Parent then object[entry.property]=entry.original end
	end
end

local function updateContacts(cameraPosition)
	local world=workspace:FindFirstChild("Thalassa")
	local models=world and world:FindFirstChild("Contacts")
	local ocean=searchlight and world and world:FindFirstChild("Ocean")
	local beam=ocean and ocean:FindFirstChild("SearchlightHead")
	for _,name in contactNames do
		local model=models and models:FindFirstChild(name)
		local record=contacts[name]
		if record and record.model~=model then
			releaseContact(record)
			contacts[name],record=nil,nil
		end
		if model and not record then
			record={model=model,objects={}}
			contacts[name]=record
			record.added=model.DescendantAdded:Connect(function(object) contactObjects(record,object) end)
			record.removing=model.DescendantRemoving:Connect(function(object)
				local entry=record.objects[object]
				if entry then object[entry.property]=entry.original record.objects[object]=nil end
			end)
			for _,object in model:GetDescendants() do contactObjects(record,object) end
		end
		if not record then continue end
		local reveal,blackout=REVEAL_RANGE,BLACKOUT_RANGE
		if not active then
			reveal,blackout=WINDOW_REVEAL_RANGE,WINDOW_BLACKOUT_RANGE
			local direction=beam and model:GetPivot().Position-beam.Position
			if direction and direction.Magnitude>0 and beam.CFrame.LookVector:Dot(direction.Unit)>.68 then
				reveal,blackout=BEAM_REVEAL_RANGE,BEAM_BLACKOUT_RANGE
			end
		end
		local nearest=blackout
		for object,entry in record.objects do
			if entry.property=="LocalTransparencyModifier" and object.Transparency<.98 then
				nearest=math.min(nearest,distanceToPart(cameraPosition,object))
				if nearest<=reveal then break end
			end
		end
		local ratio=math.clamp((nearest-reveal)/(blackout-reveal),0,1)
		local alpha=math.round(ratio*12)/12
		if record.alpha~=alpha then
			record.alpha=alpha
			for object,entry in record.objects do
				if entry.property=="LocalTransparencyModifier" then
					object.LocalTransparencyModifier=1-(1-entry.original)*(1-alpha)
				elseif entry.property=="Range" then
					-- Range is not animated by the server. Preserve its ownership
					-- of Brightness and Enabled while cutting distant glow.
					object.Range=entry.original*(1-alpha)
				else
					object[entry.property]=if alpha==1 then entry.hidden else entry.original
					if alpha==1 and object:IsA("ParticleEmitter") then object:Clear() end
				end
			end
		end
	end
end

local function swimSound(name,speed,volume)
	local sound=make("Sound",SoundService,{Name=name,SoundId="rbxasset://sounds/action_swim.mp3",
		PlaybackSpeed=speed,Volume=volume,Looped=true})
	make("EqualizerSoundEffect",sound,{LowGain=1,MidGain=-8,HighGain=-24})
	return sound
end

local function beginEffects()
	listenToCharacter(Players.LocalPlayer.Character,"Swim")
	strokes=swimSound("EVAStrokes",1.13,0)
	breathing=swimSound("EVABubbles",.68,.065)
	breathing:Play()
	headlamp=make("Part",workspace,{Name="LocalEVAHeadlamp",Size=Vector3.new(.1,.1,.1),Transparency=1,
		Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
	if workspace.CurrentCamera then headlamp.CFrame=workspace.CurrentCamera.CFrame end
	make("SpotLight",headlamp,{Name="HeadlampBeam",Face=Enum.NormalId.Front,Range=14,Angle=54,
		Brightness=1.8,Color=Color3.fromRGB(189,230,226),Shadows=true})
	bubblePool={}
	nextContactCheck,nextBubble,bubbleIndex=0,0,0
	for i=1,16 do
		bubblePool[i]={part=make("Part",nil,{Name="LocalAirBubble",Anchored=true,CanCollide=false,CanTouch=false,
			CanQuery=false,CastShadow=false,Shape=Enum.PartType.Ball,Material=Enum.Material.Glass,
			Color=Color3.fromRGB(128,187,193),Reflectance=.3,Transparency=1})}
	end
end

local function endEffects()
	listenToCharacter(nil)
	if headlamp then headlamp:Destroy() headlamp=nil end
	if strokes then strokes:Destroy() strokes=nil end
	if breathing then breathing:Destroy() breathing=nil end
	if bubblePool then
		for _,bubble in bubblePool do bubble.part:Destroy() end
		bubblePool=nil
	end
end

local function stepEffects(camera,dt)
	local character=Players.LocalPlayer.Character
	listenToCharacter(character,"Swim")
	headlamp.CFrame=camera.CFrame*CFrame.new(.18,.16,-.35)
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local swim=root and root:FindFirstChild("SwimVelocity")
	local speed=swim and swim:IsA("LinearVelocity") and not challenge and swim.VectorVelocity.Magnitude or 0
	local moving=speed>1
	local amount=math.clamp(speed/13,0,1)
	local now=os.clock()
	if moving and not strokes.IsPlaying then strokes:Play() end
	if not moving and strokes.IsPlaying then strokes:Stop() end
	strokes.Volume=.13+.30*amount
	strokes.PlaybackSpeed=.88+.44*amount
	breathing.Volume=moving and .045 or .09+darkness*.045
	if now>=nextBubble then
		nextBubble=now+random:NextNumber(.23,.48)*(moving and 1 or 2)
		bubbleIndex=bubbleIndex%#bubblePool+1
		local bubble=bubblePool[bubbleIndex]
		local size=random:NextNumber(.085,.22)
		bubble.part.Size=Vector3.one*size
		bubble.position=camera.CFrame:PointToWorldSpace(Vector3.new(random:NextNumber(.45,1.10),-.70,-1.9))
		bubble.age,bubble.duration=0,random:NextNumber(.8,1.65)
		bubble.velocity=Vector3.new(random:NextNumber(-.9,.9),random:NextNumber(1.8,3.2),.1)
		bubble.part.Parent=camera
	end
	for _,bubble in bubblePool do
		if not bubble.age then continue end
		bubble.age+=dt
		if bubble.age>=bubble.duration then
			bubble.part.Parent=nil
			bubble.age=nil
		else
			bubble.position+=bubble.velocity*dt
			bubble.part.Position=bubble.position
			bubble.part.Transparency=.42+.57*(bubble.age/bubble.duration)
		end
	end
end

local function hit()
	local c=challenge
	if not active or not c or pending==c.id then return end
	local now=workspace:GetServerTimeNow()
	if now<c.started then return end
	-- At most one attempt per server-issued sweep. Retry if a packet missed the server's timing window.
	pending=c.id
	net.Input:FireServer("CleanStrike",{id=c.id,time=now})
	task.delay(.72,function() if pending==c.id then pending=nil end end)
end
local function cancelGrip()
	if active and challenge then net.Input:FireServer("CleanCancel") end
end
local function bindSwim(enable)
	for _,name in {"DiveRise","DiveSink","DiveCut","DiveRelease"} do CAS:UnbindAction(name) end
	heldRise,heldDown=false,false
	riseTouch,downTouch=nil,nil
	if not enable then return end
	local priority=Enum.ContextActionPriority.High.Value+15
	if challenge then
		CAS:BindActionAtPriority("DiveCut",function(_,state)
			if state==Enum.UserInputState.Begin then hit() end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
		CAS:BindActionAtPriority("DiveRelease",function(_,state)
			if state==Enum.UserInputState.Begin then cancelGrip() end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.Q,Enum.KeyCode.ButtonB)
	else
		local function vertical(name,state)
			local isHeld=state~=Enum.UserInputState.End and state~=Enum.UserInputState.Cancel
			if name=="DiveRise" then heldRise=isHeld else heldDown=isHeld end
			return Enum.ContextActionResult.Sink
		end
		CAS:BindActionAtPriority("DiveRise",vertical,false,priority,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
		CAS:BindActionAtPriority("DiveSink",vertical,false,priority,Enum.KeyCode.C,Enum.KeyCode.LeftControl,Enum.KeyCode.ButtonB)
	end
end

local function refreshBindings(oldActive,oldChallenge)
	if oldActive~=active or oldChallenge~=(challenge~=nil) then bindSwim(active) end
	overlay.Visible=challenge~=nil
	travel.Visible=active and not challenge
	local touch=UIS.PreferredInput==Enum.PreferredInput.Touch
	rise.Visible=travel.Visible and touch
	down.Visible=rise.Visible
end
local function populate(c,s)
	headline.Text=string.upper(c.label).."   /   HULL CLEANING"
	for index,tick in ticks do
		local angle=(index-1)*5
		local inBand=math.abs((angle-c.center+180)%360-180)<=c.arc/2
		tick.BackgroundColor3=inBand and color.foam or color.steel
		tick.Size=UDim2.fromOffset(inBand and 4 or 2,inBand and 13 or 7)
	end
	progress.Text=string.format("%d / 3",s.cleanSites and s.cleanSites[c.index] or 0)
	feedback.Text=c.feedback~="" and c.feedback or "SET THE CUTTER"
	feedback.TextColor3=c.feedback=="MISSED" and color.amber or color.foam
end

local function needleAngle(c,time)
	return (c.startAngle+c.sign*math.max(0,time-c.started)*360/c.period)%360
end

local function travelStatus(s)
	local completed=0
	if s.cleanSites and s.swarm>0 then
		for _,count in s.cleanSites do if count>=3 then completed+=1 end end
	end
	local text
	if UIS.PreferredInput==Enum.PreferredInput.Touch then
		text="Swim where you look  ·  Hold ↑ or ↓"
	elseif UIS.PreferredInput==Enum.PreferredInput.Gamepad then
		text="Swim where you look  ·  A rise  /  B dive"
	else
		text="Swim where you look  ·  Space rise  /  C dive"
	end
	if s.difficulty=="Easy" and s.phase=="Bottom" then
		local destination=if s.carryingArtifact then "RETURN TO THE AIRLOCK" else "FOLLOW THE SALVAGE BEACON"
		text=destination.."\n"..text
	elseif s.swarm and s.swarm>0 and s.cleanSites then
		local origin=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local near,distance=nil,math.huge
		for i,point in travelPoints do
			if origin and point.Parent and (s.cleanSites[i] or 0)<3 then
				local d=(origin.Position-point.Position).Magnitude
				if d<distance then near,distance=point.Parent,d end
			end
		end
		text=string.format("HULL   %d/4",completed)..(near and "   •   "..string.upper(near:GetAttribute("Label") or near.Name).."   "..math.round(distance).." st" or "").."\n"..text
	end
	travel.Text=text
end

function Client.init(network,rootGui)
	net,screen=network,rootGui
	task.spawn(function()
		local playerScripts=Players.LocalPlayer:WaitForChild("PlayerScripts")
		local module=playerScripts:WaitForChild("PlayerModule",10)
		if module then local ok,result=pcall(function() return require(module):GetControls() end) if ok then controls=result end end
	end)
	local holder=make("Frame",screen,{Name="ExteriorOperations",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=23})
	overlay=frame(holder,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(1,11,14),24)
	overlay.Name="CutterView"
	overlay.BackgroundTransparency=.35
	overlay.Visible=false
	card=frame(overlay,UDim2.fromScale(.5,.5),UDim2.fromOffset(390,338),color.dark,25)
	card.AnchorPoint=Vector2.new(.5,.5)
	make("UIStroke",card,{Color=color.steel,Thickness=1})
	scale=make("UIScale",card,{Scale=1})
	local function resize()
		local size=holder.AbsoluteSize
		if size.X>0 and size.Y>0 then scale.Scale=math.min(1.08,(size.X-20)/390,(size.Y-24)/338) end
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	headline=label(card,"",UDim2.fromOffset(10,8),UDim2.fromOffset(370,24),Enum.Font.Code,14,color.foam,26)
	help=label(card,"Strike when the needle crosses the green arc",UDim2.fromOffset(9,34),UDim2.fromOffset(372,21),Enum.Font.Gotham,15,color.paper,26)
	dial=make("TextButton",card,{Name="Strike",Text="",Size=UDim2.fromOffset(210,210),Position=UDim2.fromOffset(90,59),
		BackgroundColor3=color.panel,BorderSizePixel=0,Modal=true,AutoButtonColor=false,Selectable=false,ZIndex=26})
	round(dial)
	for i=1,72 do
		local angle=math.rad((i-1)*5)
		local tick=frame(dial,UDim2.fromOffset(105+math.sin(angle)*94,105-math.cos(angle)*94),UDim2.fromOffset(2,7),color.steel,27)
		tick.AnchorPoint=Vector2.new(.5,.5)
		tick.Rotation=(i-1)*5
		ticks[i]=tick
	end
	pivot=frame(dial,UDim2.fromScale(.5,.5),UDim2.fromOffset(184,184),color.panel,28)
	pivot.AnchorPoint=Vector2.new(.5,.5)
	pivot.BackgroundTransparency=1
	local needle=frame(pivot,UDim2.fromScale(.5,0),UDim2.fromOffset(4,57),color.amber,29)
	needle.AnchorPoint=Vector2.new(.5,0)
	local hub=frame(dial,UDim2.fromScale(.5,.5),UDim2.fromOffset(75,75),color.dark,29)
	hub.AnchorPoint=Vector2.new(.5,.5)
	round(hub)
	progress=label(hub,"0 / 3",UDim2.fromOffset(0,16),UDim2.fromOffset(75,25),Enum.Font.Code,20,color.paper,30)
	label(hub,"CUTS",UDim2.fromOffset(0,38),UDim2.fromOffset(75,16),Enum.Font.Code,11,color.muted,30)
	feedback=label(card,"",UDim2.fromOffset(0,271),UDim2.fromOffset(390,19),Enum.Font.Code,13,color.foam,27)
	local stroke=button(card,"STRIKE",UDim2.fromOffset(24,297),UDim2.fromOffset(179,30))
	stroke.Name="StrikeControl"
	cancel=button(card,"RELEASE",UDim2.fromOffset(212,297),UDim2.fromOffset(154,30))
	cancel.Name="ReleaseControl"
	local function pressed(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then hit() end
	end
	dial.InputBegan:Connect(pressed)
	stroke.InputBegan:Connect(pressed)
	cancel.Activated:Connect(cancelGrip)
	local function deviceText()
		local gamepad=UIS.PreferredInput==Enum.PreferredInput.Gamepad
		local touch=UIS.PreferredInput==Enum.PreferredInput.Touch
		stroke.Text=touch and "TAP TO STRIKE" or gamepad and "STRIKE  •  A" or "STRIKE  •  SPACE"
		cancel.Text=touch and "RELEASE" or gamepad and "RELEASE  •  B" or "RELEASE  •  Q"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(deviceText)
	deviceText()
	travel=label(holder,"",UDim2.new(.5,0,1,-12),UDim2.new(.94,0,0,44),Enum.Font.Code,13,color.paper,24)
	travel.AnchorPoint=Vector2.new(.5,1)
	travel.TextStrokeTransparency=.35
	travel.Visible=false
	rise=button(holder,"↑",UDim2.new(1,-65,.54,0),UDim2.fromOffset(47,43))
	down=button(holder,"↓",UDim2.new(1,-65,.54,49),UDim2.fromOffset(47,43))
	rise.TextSize,down.TextSize=24,24
	rise.Visible,down.Visible=false,false
	rise.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then riseTouch=input end end)
	down.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then downTouch=input end end)
	UIS.InputEnded:Connect(function(input)
		if input==riseTouch then riseTouch=nil end
		if input==downTouch then downTouch=nil end
	end)
	local cut=make("Sound",SoundService,{Name="Barnacle cutter bite",SoundId="rbxassetid://9113133466",Volume=.26,PlaybackSpeed=1.37})
	local cleared=make("Sound",SoundService,{Name="Barnacle shell snap",SoundId="rbxassetid://9120490790",Volume=.47,PlaybackSpeed=1.04})
	make("EqualizerSoundEffect",cut,{LowGain=1,MidGain=-2,HighGain=-9})
	make("EqualizerSoundEffect",cleared,{LowGain=2,MidGain=0,HighGain=-6})
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync({cut,cleared}) end) end)
	network.Feed.OnClientEvent:Connect(function(kind,outcome)
		if kind~="CleanFeedback" or not active then return end
		if outcome=="Cut" then cut:Play() elseif outcome=="Cleared" then cleared:Play() end
	end)
	local world=workspace:FindFirstChild("Thalassa")
	local function register(item)
		if item:IsA("BasePart") and item.Name=="Target" and item.Parent and item.Parent.Parent and item.Parent.Parent.Name=="BarnacleSites" then
			local index=tonumber(item.Parent.Name:match("^Site(%d+)$"))
			if index then travelPoints[index]=item end
		end
	end
	if world then for _,item in world:GetDescendants() do register(item) end end
	workspace.DescendantAdded:Connect(register)
	RunService.Heartbeat:Connect(function(dt)
		if inDive then stepWater(dt) end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not inDive then return end
		local camera=workspace.CurrentCamera
		if not camera then return end
		if os.clock()>=nextContactCheck then
			nextContactCheck=os.clock()+.10
			updateContacts(camera.CFrame.Position)
		end
		if not active then
			if cabinSteps then stepSteelSteps(dt) end
			return
		end
		stepEffects(camera,dt)
		if challenge then
			local now=workspace:GetServerTimeNow()
			local correction=needleOffset*math.clamp((needleCorrectUntil-now)/.12,0,1)
			pivot.Rotation=needleAngle(challenge,now)+correction
			return
		end
		local now=os.clock()
		if now-lastSend<0.13 then return end
		lastSend=now
		local move=Vector3.zero
		local vertical=0
		if not UIS:GetFocusedTextBox() and not GuiService.MenuIsOpen then
			if controls then
				move=controls:GetMoveVector()
			else
				local function key(k) return UIS:IsKeyDown(k) and 1 or 0 end
				move=Vector3.new(key(Enum.KeyCode.D)-key(Enum.KeyCode.A),0,key(Enum.KeyCode.S)-key(Enum.KeyCode.W))
			end
			vertical=((heldRise or riseTouch) and 1 or 0)-((heldDown or downTouch) and 1 or 0)
		end
		local cf=camera.CFrame
		local direction=cf.RightVector*move.X - cf.LookVector*move.Z + Vector3.yAxis*vertical
		if direction.Magnitude>1 then direction=direction.Unit end
		net.Input:FireServer("SwimMove",{direction=direction,look=cf.LookVector})
	end)
end

function Client.update(s)
	jellyBloom.update(s)
	local oldActive,oldChallenge=active,challenge~=nil
	local previousId=challenge and challenge.id
	targetDarkness=math.sqrt(math.clamp((s.depth or 0)/math.max(1,s.maxDepth or 10000),0,1))
	if not inDive then beginWater() end
	inDive,searchlight=true,s.light==true and (s.battery or 100)>0
	active=s.outside==true and s.alive~=false
	local playSteps=s.alive~=false and not active and not (s.cameraView or s.searchlightView)
	if cabinSteps and not playSteps then stopSteelSteps() end
	cabinSteps=playSteps
	challenge=active and s.cleaning or nil
	if active and not oldActive then beginEffects()
	elseif oldActive and not active then endEffects() end
	if challenge and previousId~=challenge.id then
		pending=nil
		local now=workspace:GetServerTimeNow()
		local currentAngle=needleAngle(challenge,now)
		-- Blend the small correction from a delayed snapshot. Hit timing uses the server angle.
		needleOffset=if previousId then (pivot.Rotation-currentAngle+180)%360-180 else 0
		needleCorrectUntil=now+.12
		if not previousId then pivot.Rotation=currentAngle end
		populate(challenge,s)
	end
	refreshBindings(oldActive,oldChallenge)
	if active and not challenge then travelStatus(s) end
end

function Client.reset()
	if not overlay then return end
	jellyBloom.reset()
	local oldActive,oldChallenge=active,challenge~=nil
	inDive,searchlight,cabinSteps=false,false,false
	resetWater()
	stopSteelSteps()
	for _,record in contacts do releaseContact(record) end
	table.clear(contacts)
	nextContactCheck=0
	active,challenge,pending=false,nil,nil
	if oldActive then endEffects() end
	refreshBindings(oldActive,oldChallenge)
end

return Client
