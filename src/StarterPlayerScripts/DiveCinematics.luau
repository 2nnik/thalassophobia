-- Local presentation for server-selected sequences. No damage or progression lives here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local Cinematics = {}
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local smooth = function(a)
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local durations = {Wake=2.7,WormGrab=8,WormRescue=.85,WormDeath=2.8,Flood=15,Angler=8,Squid=13}
local terminal = {Flood=true,Angler=true,Squid=true,WormDeath=true}
local hullNames = {"Bell • KESTREL 04","Pressure hull • Survey refit","Stations","BarnacleSites","Dive stage"}

local function make(class, parent, properties)
	local item = Instance.new(class)
	for k,v in properties do item[k] = v end
	item.Parent = parent
	return item
end

local function part(parent, name, color, material)
	return make("Part",parent,{Name=name,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,
		Color=color,Material=material or Enum.Material.SmoothPlastic})
end

local function ellipse(p)
	make("SpecialMesh",p,{MeshType=Enum.MeshType.Sphere})
	return p
end

local function link(p,startAt,endAt,radius,overlap)
	local distance=(endAt-startAt).Magnitude
	if distance<.001 then return end
	p.CFrame=CFrame.lookAt((startAt+endAt)*.5,endAt)
	p.Size=Vector3.new(radius,radius,distance+(overlap or radius*.65))
end

local function waterBubbles(parent,at,count)
	local spray=part(parent,"Rupture spray",rgb(149,199,207))
	spray.CFrame=at
	spray.Size=Vector3.new(.4,2.8,.4)
	spray.Transparency=1
	local particles=make("ParticleEmitter",spray,{
		Texture="rbxasset://textures/particles/smoke_main.dds",Enabled=false,
		Lifetime=NumberRange.new(.4,1.1),Speed=NumberRange.new(10,21),SpreadAngle=Vector2.new(20,33),
		Size=NumberSequence.new(.34,1.15),Transparency=NumberSequence.new(.32,1),
		Color=ColorSequence.new(rgb(161,215,216),rgb(55,104,111)),Acceleration=Vector3.new(0,-9,0),
		EmissionDirection=Enum.NormalId.Front,LightEmission=.25,
	})
	particles:Emit(count)
	return particles
end

local function cloneHull(scene, world)
	local envelope=world and world:FindFirstChild("ShipEnvelope")
	local shipOrigin=envelope and envelope.CFrame
	if not shipOrigin then return end
	scene.shipOrigin = shipOrigin
	scene.halves = {
		make("Model",scene.folder,{Name="Bow fragment",WorldPivot=shipOrigin * CFrame.new(0,0,-9)}),
		make("Model",scene.folder,{Name="Stern fragment",WorldPivot=shipOrigin * CFrame.new(0,0,9)}),
	}
	scene.rest = {scene.halves[1]:GetPivot(),scene.halves[2]:GetPivot()}
	scene.fragments={}
	for _,name in hullNames do
		local group=world:FindFirstChild(name)
		if not group then continue end
		for _,source in group:GetDescendants() do
			if not source:IsA("BasePart") or source.Transparency>=.98
				or source.LocalTransparencyModifier>=.98 then continue end
			scene.hidden[source]=source.LocalTransparencyModifier
			source.LocalTransparencyModifier=1
			local temp
			if source:IsA("MeshPart") or source:IsA("UnionOperation") then
				temp=source:Clone()
				if temp then
					temp:ClearAllChildren()
					temp.Parent=scene.halves[if shipOrigin:PointToObjectSpace(source.Position).Z<0 then 1 else 2]
					temp.Anchored,temp.CanCollide,temp.CanQuery,temp.CanTouch=true,false,false,false
					temp.LocalTransparencyModifier=0
				end
			else
				local class=if source:IsA("WedgePart") then "WedgePart" elseif source:IsA("CornerWedgePart") then "CornerWedgePart" else "Part"
				temp=make(class,scene.halves[if shipOrigin:PointToObjectSpace(source.Position).Z<0 then 1 else 2],{
					Name="Hull fragment",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
					Size=source.Size,CFrame=source.CFrame,Color=source.Color,Material=source.Material,
					Transparency=source.Transparency,Reflectance=source.Reflectance,
				})
				if class=="Part" and source:IsA("Part") then temp.Shape=source.Shape end
				local mesh=source:FindFirstChildOfClass("DataModelMesh")
				if mesh then mesh:Clone().Parent=temp end
			end
			if temp then
				local index=#scene.fragments+1
				scene.fragments[index]={part=temp,transparency=temp.Transparency,stagger=((index*37)%97)/97}
			end
		end
	end
end

local function constructMouth(scene)
	-- The entry axis matches the closing lips. Palate folds then bend away from the light.
	local stage=CFrame.new(3500,scene.cameraFrame.Y,3500)
	scene.mouth=stage
	local function contour(ring,i)
		local a=i/12*TAU+.06*math.sin(ring*.8)
		local radius=(10.6-ring*.65)*(1+.07*math.sin(3*a+ring*.48))
		return stage:PointToWorldSpace(Vector3.new(math.cos(a)*radius+1.6*math.sin(ring*.55),
			math.sin(a)*radius*.76-ring*.19,-ring*4.4))
	end
	for ring=0,8 do
		for i=0,11 do
			local a,b=contour(ring,i),contour(ring,i+1)
			local rib=ellipse(part(scene.folder,"Palate fold",if ring%2==0 then rgb(87,49,57) else rgb(64,39,53)))
			link(rib,a,b,1.85+.32*math.cos(i),1.3)
			if ring<8 then
				local wall=ellipse(part(scene.folder,"Palate wall",rgb(48+i%3*4,30,42)))
				link(wall,(a+b)*.5,(contour(ring+1,i)+contour(ring+1,i+1))*.5,5.8-ring*.27,2.4)
			end
		end
	end
	local throatEnd=ellipse(part(scene.folder,"Gullet end",rgb(32,16,27)))
	throatEnd.Size=Vector3.new(14,10,6)
	throatEnd.CFrame=stage*CFrame.new(-1.4,-1.6,-36)
	local lamp=part(scene.folder,"Reflected dive light",rgb(175,121,111))
	lamp.Transparency=1
	scene.throatLamp=lamp
	scene.throatLight=make("PointLight",lamp,{Range=28,Brightness=2.4,Color=rgb(242,177,160)})
end

local function constructBelly(scene, world)
	local envelope=world and world:FindFirstChild("ShipEnvelope")
	local ship=envelope and envelope.CFrame or scene.cameraFrame
	local size=envelope and envelope.Size or Vector3.new(45,13,50)
	scene.belly={ship=ship,size=size,folds={},lights={}}
	local belly=scene.belly
	local function wallPoint(row,angle)
		local taper=1-.6*(math.abs(row)/6)^3
		local ruffle=1+.06*math.cos(angle*5+row*.8)
		return ship:PointToWorldSpace(Vector3.new(
			math.cos(angle)*(size.X*.56+20)*taper*ruffle,
			math.sin(angle)*(size.Y*.55+30)*taper*ruffle,
			row*(size.Z+58)/12))
	end
	for row=-6,6 do
		for i=1,16 do
			local angle=i/16*TAU
			local a,b=wallPoint(row,angle),wallPoint(row,angle+TAU/16)
			local fold=ellipse(part(scene.folder,"Muscle fold",rgb(94+i%4*8,32+i%3*7,52+i%3*5)))
			fold.Reflectance=.08
			link(fold,a,b,7+(i%3),5)
			table.insert(belly.folds,{part=fold,rest=fold.CFrame,row=row})
			if row<6 then
				local tissue=part(scene.folder,"Belly wall",rgb(70+i%3*7,24,38),Enum.Material.SmoothPlastic)
				local nextA,nextB=wallPoint(row+1,angle),wallPoint(row+1,angle+TAU/16)
				local across=((b-a)+(nextB-nextA)).Unit
				local along=((nextA-a)+(nextB-b)).Unit
				tissue.CFrame=CFrame.fromMatrix((a+b+nextA+nextB)*.25,across,along:Cross(across).Unit,-along)
				tissue.Size=Vector3.new(math.max((b-a).Magnitude,(nextB-nextA).Magnitude)+2,3,(nextA-a).Magnitude+3)
			end
		end
	end
	for _,z in {-1,1} do
		local cap=ellipse(part(scene.folder,"Closed stomach passage",rgb(56,17,29)))
		cap.Size=Vector3.new(size.X*.62+22,size.Y+39,12)
		cap.CFrame=ship*CFrame.new(0,0,z*(size.Z+58)*.5)
	end
	for _,side in {-1,1} do
		for _,z in {-.34,.34} do
			local source=part(scene.folder,"Reflected cabin light",rgb(255,151,130))
			source.Transparency=1
			source.CFrame=ship*CFrame.new(side*(size.X*.5+7),4,size.Z*z)
			table.insert(belly.lights,make("PointLight",source,{Range=57,Brightness=0,Color=rgb(235,123,122)}))
		end
	end
	local nearest=math.huge
	for i=1,3 do
		local window=world and world:FindFirstChild("WormWindow"..i)
		if window then
			local distance=(window.Position-scene.cameraFrame.Position).Magnitude
			if distance<nearest then belly.window,nearest=window.CFrame,distance end
		end
	end
end

local function breakingLights(scene)
	scene.emergency={}
	local ship=scene.shipOrigin or scene.cameraFrame
	for _,z in {-15,0,15} do
		local lamp=part(scene.folder,"Emergency lamp",rgb(255,52,37))
		lamp.Transparency=1
		lamp.CFrame=ship*CFrame.new(0,3,z)
		table.insert(scene.emergency,make("PointLight",lamp,{Color=lamp.Color,Range=30,Brightness=0}))
	end
end

local function constructJaws(scene)
	scene.jaws={}
	for i=0,25 do
		local tooth=make("WedgePart",scene.folder,{Name="Needle tooth",Anchored=true,CanCollide=false,CanQuery=false,
			CanTouch=false,CastShadow=false,Transparency=1,Color=rgb(193,189,161),Material=Enum.Material.SmoothPlastic})
		local gum=ellipse(part(scene.folder,"Gum ridge",rgb(57,61,67),Enum.Material.Slate))
		gum.Transparency=1
		table.insert(scene.jaws,{part=tooth,gum=gum,angle=i/26*TAU,scale=.8+.27*math.cos(i*2.3)})
	end
	scene.jawShade=ellipse(part(scene.folder,"Gullet shadow",rgb(14,11,22)))
	scene.jawShade.Transparency=1
	local fill=part(scene.folder,"Reflected bow light",rgb(170,209,222))
	fill.Transparency=1
	scene.jawLamp=make("PointLight",fill,{Range=34,Brightness=0,Color=rgb(169,210,218)})
end

local function approachJaws(scene,mouth,aperture,alpha)
	local function point(a)
		return mouth:PointToWorldSpace(Vector3.new(math.cos(a)*11,math.sin(a)*8.4*aperture,-math.cos(a*2)*.65))
	end
	scene.jawShade.Size=Vector3.new(23,18*aperture,4)
	scene.jawShade.CFrame=mouth*CFrame.new(0,0,-2)
	scene.jawShade.Transparency=1-alpha
	scene.jawLamp.Parent.CFrame=mouth*CFrame.new(-4,4,7)
	scene.jawLamp.Brightness=2.6*alpha
	for _,tooth in scene.jaws do
		local a=tooth.angle
		local root=point(a)
		local inward=mouth:VectorToWorldSpace(Vector3.new(-math.cos(a)*.75,-math.sin(a),.45)).Unit
		local length=3.4*tooth.scale
		local right=inward:Cross(mouth.ZVector).Unit
		tooth.part.Size=Vector3.new(.53*tooth.scale,length,.83)
		tooth.part.CFrame=CFrame.fromMatrix(root+inward*length*.5,right,inward)
		tooth.part.Transparency=1-alpha
		link(tooth.gum,root,point(a+TAU/26),1.9,1.2)
		tooth.gum.Transparency=1-alpha
	end
end

local function constructBeak(scene)
	scene.beak={}
	scene.beakTips={}
	for i=1,2 do
		local half=ellipse(part(scene.folder,"Beak plate",rgb(73,51,46)))
		half.Size,half.Transparency=Vector3.new(4.3,2.55,3.9),1
		scene.beak[i]=half
		scene.beakTips[i]=make("WedgePart",scene.folder,{Name="Hooked cutting edge",Anchored=true,CanCollide=false,CanQuery=false,
			CanTouch=false,Size=Vector3.new(1.7,1.8,2.9),Color=rgb(104,79,59),Transparency=1,CastShadow=false})
	end
	local fill=part(scene.folder,"Reflected helmet light",rgb(174,205,211))
	fill.Transparency=1
	scene.beakLamp=make("PointLight",fill,{Range=46,Brightness=0,Color=rgb(191,215,219)})
end

local function closeBeak(scene,at,bite,alpha)
	for i,half in scene.beak do
		local dir=if i==1 then 1 else -1
		half.CFrame=at*CFrame.new(0,dir*(2.8-1.85*bite),0)*CFrame.Angles(dir*(.63-.46*bite),0,if i==1 then math.pi else 0)
		half.Transparency=1-alpha
		local tip=scene.beakTips[i]
		tip.CFrame=half.CFrame*CFrame.new(0,.5,-1.48)*CFrame.Angles(-.52,0,0)
		tip.Transparency=1-alpha
	end
	scene.beakLamp.Parent.CFrame=at*CFrame.new(-3,4,-7)
	scene.beakLamp.Brightness=alpha*3.5
end

local function makeArms(scene,count,segments)
	scene.arms={}
	for i=1,count do
		local arm={segments={},suckers={}}
		for j=1,segments do
			arm.segments[j]=ellipse(part(scene.folder,"Coiling arm",rgb(47+i*4,76-j*2,73-j*2),Enum.Material.Slate))
			if j%2==1 and scene.kind=="Squid" then
				arm.suckers[j]=ellipse(part(scene.folder,"Arm sucker",rgb(112,94,76)))
				arm.suckers[j].Transparency=1
			end
			if scene.kind=="Squid" then arm.segments[j].Transparency=1 end
		end
		table.insert(scene.arms,arm)
	end
end

local function bendArms(scene,frame,t,extension)
	for i,arm in scene.arms do
		local angle=i/#scene.arms*TAU
		local side=Vector3.new(math.cos(angle),math.sin(angle),0)
		local tangent=Vector3.new(-side.Y,side.X,0)
		local last=frame:PointToWorldSpace(side*(2.3+extension*4)+Vector3.new(0,0,-3.4-extension*7))
		for j,segment in arm.segments do
			local u=j/#arm.segments
			local sweep=math.sin(u*TAU*.65+t*4.7+i)*math.sin(u*math.pi)
			local radial=(1-u)^.63*(3+extension*6)+.2
			local p=frame:PointToWorldSpace(side*radial+tangent*sweep*(.5+extension*2)+Vector3.new(0,0,-2.8-u*3.7+extension*u*5.7))
			local diameter=math.max(.13,(.71+extension*.72)*(1-u*.8))
			link(segment,last,p,diameter,diameter)
			local sucker=arm.suckers[j]
			if sucker then
				sucker.Size=Vector3.new(diameter*.75,diameter*.75,diameter*.34)
				sucker.CFrame=CFrame.lookAt((last+p)/2+frame.LookVector*-diameter*.42,frame.Position)
			end
			last=p
		end
	end
end

local function armColor()
	local body=player.Character and player.Character:FindFirstChildOfClass("BodyColors")
	return body and body.RightArmColor3 or rgb(151,123,103)
end

local function hideAvatar(scene)
	local character=player.Character
	if not character then return end
	for _,body in character:GetDescendants() do
		if body:IsA("BasePart") then
			if scene.hidden[body]==nil then scene.hidden[body]=body.LocalTransparencyModifier end
			body.LocalTransparencyModifier=1
		end
	end
end

local function constructPursuer(scene)
	local squid=scene.kind=="Squid"
	local skin=if squid then rgb(37,49,54) else rgb(32,59,66)
	local pieces={}
	local function feature(name,color,material,size,pose)
		local piece=ellipse(part(scene.folder,name,color,material))
		piece.Size,piece.Transparency=size,1
		table.insert(pieces,{part=piece,offset=pose})
		return piece
	end
	feature("Approaching head",skin,Enum.Material.Slate,if squid then Vector3.new(22,19,22) else Vector3.new(34,27,31),CFrame.new())
	feature("Approaching mantle",skin,Enum.Material.Slate,if squid then Vector3.new(18,22,48) else Vector3.new(27,25,48),CFrame.new(0,2,21))
	if not squid then
		feature("Approaching tail",skin,Enum.Material.Slate,Vector3.new(12,14,36),CFrame.new(-4,1,46)*CFrame.Angles(0,-.24,0))
		local lure=feature("Faint lure",rgb(81,185,196),Enum.Material.Neon,Vector3.new(.9,.9,.9),CFrame.new(0,15,-13))
		scene.pursuerLight=make("PointLight",lure,{Brightness=0,Range=29,Color=rgb(105,195,201)})
		feature("Lure stalk",skin,Enum.Material.Slate,Vector3.new(.9,.9,11),CFrame.new(0,14,-8)*CFrame.Angles(.25,0,0))
	end
	for _,side in {-1,1} do
		feature("Approaching eye",if squid then rgb(173,100,48) else rgb(63,121,131),Enum.Material.Neon,
			Vector3.new(1.35,1.1,1.05),CFrame.new(side*(if squid then 8 else 12),if squid then 3 else 5,if squid then -7 else -10))
	end
	scene.predator=pieces
end

local function beginEscape(scene)
	local heading=scene.heading
	local ship=scene.shipOrigin
	local origin=scene.cameraFrame.Position+heading*7
	if ship then
		local localCamera=ship:PointToObjectSpace(scene.cameraFrame.Position)
		local side=if localCamera.X<0 then -1 else 1
		heading=ship.RightVector*side
		origin=ship:PointToWorldSpace(Vector3.new(side*(scene.shipWidth*.5+8),2,math.clamp(localCamera.Z,-15,15)))
	end
	scene.escape={origin=origin,position=origin,heading=heading,yaw=0,pitch=0}
	scene.bubbles=waterBubbles(scene.folder,CFrame.new(origin),16)
	scene.bubbles.Parent.Name="Escaping bubbles"
	scene.bubbles.Lifetime=NumberRange.new(.55,1.6)
	scene.bubbles.Speed=NumberRange.new(.8,2.6)
	scene.bubbles.Acceleration=Vector3.new(0,5,0)
	scene.bubbles.Size=NumberSequence.new(.06,.2)
	scene.bubbles.Rate,scene.bubbles.Enabled=9,true
end

local function swimView(scene, dt, lookTouch, moveTouch, locked)
	local escape=scene.escape
	local x,y,z,lookX,lookY=0,0,0,0,0
	local preferred=Input.PreferredInput
	if not locked and not GuiService.MenuIsOpen and not Input:GetFocusedTextBox() then
		if preferred==Enum.PreferredInput.Touch then
			local drag=moveTouch and moveTouch.delta or Vector2.zero
			x,z=math.clamp(drag.X/64,-1,1),math.clamp(drag.Y/64,-1,1)
			lookX,lookY=lookTouch.X*.006,lookTouch.Y*.006
		elseif preferred==Enum.PreferredInput.Gamepad then
			for _,event in Input:GetGamepadState(Enum.UserInputType.Gamepad1) do
				if event.KeyCode==Enum.KeyCode.Thumbstick1 then
					x,z=event.Position.X,-event.Position.Y
				elseif event.KeyCode==Enum.KeyCode.Thumbstick2 then
					lookX,lookY=event.Position.X*dt*2.4,-event.Position.Y*dt*2.2
				elseif event.KeyCode==Enum.KeyCode.ButtonR2 then
					y+=event.Position.Z
				elseif event.KeyCode==Enum.KeyCode.ButtonL2 then
					y-=event.Position.Z
				end
			end
		else
			local function key(code) return if Input:IsKeyDown(code) then 1 else 0 end
			x=key(Enum.KeyCode.D)-key(Enum.KeyCode.A)
			z=key(Enum.KeyCode.S)-key(Enum.KeyCode.W)
			y=key(Enum.KeyCode.Space)-key(Enum.KeyCode.C)
			Input.MouseBehavior=Enum.MouseBehavior.LockCenter
			local delta=Input:GetMouseDelta()
			lookX,lookY=delta.X*.004,delta.Y*.004
		end
	end
	escape.yaw-=lookX
	escape.pitch=math.clamp(escape.pitch-lookY,-1.05,1.05)
	local facing=CFrame.lookAt(escape.position,escape.position+escape.heading)*CFrame.Angles(0,escape.yaw,0)*CFrame.Angles(escape.pitch,0,0)
	local direction=facing.RightVector*x-facing.LookVector*z+Vector3.yAxis*y
	local motion=if direction.Magnitude>.12 then direction.Unit*math.min(direction.Magnitude,1)*8 else escape.heading*.72
	local offset=escape.position+motion*dt-escape.origin
	local outward=math.clamp(offset:Dot(escape.heading),-3,24)
	local side=Vector3.yAxis:Cross(escape.heading)
	local lateral=math.clamp(offset:Dot(side),-22,22)
	escape.position=escape.origin+escape.heading*outward+side*lateral+Vector3.yAxis*math.clamp(offset.Y,-9,9)
	return facing.Rotation+escape.position
end

local function revealPursuer(scene,p,seconds,view,squid)
	local escape=scene.escape
	local reveal=smooth((p-.49)/.16)
	local closing=smooth((p-.5)/(if squid then .33 else .19))
	local gap=(if squid then 104 else 91)-closing*(if squid then 88 else 73)
	local direction=escape.heading
	local target=escape.origin+direction*gap
	local playerOffset=escape.position-escape.origin
	target+=playerOffset*(closing*.84)+Vector3.new(0,5-3*closing+math.sin(seconds*1.1),0)
	local actor=CFrame.lookAt(target,escape.position)
	for _,piece in scene.predator do
		piece.part.CFrame=actor*piece.offset
		piece.part.Transparency=1-reveal*.96
	end
	if scene.pursuerLight then scene.pursuerLight.Brightness=reveal*.75 end
	-- Free look persists through the sighting. Reframe the predator when it reaches the player.
	local focus=smooth((p-.60)/.14)
	view=view:Lerp(CFrame.lookAt(view.Position,target),focus)
	return view,actor,reveal,closing
end

local function spreadApproachArms(scene,actor,view,seconds,alpha,grab)
	for i,arm in scene.arms do
		local a=i/#scene.arms*TAU
		local outward=Vector3.new(math.cos(a),math.sin(a),0)
		local right=Vector3.new(-outward.Y,outward.X,0)
		local last=actor:PointToWorldSpace(outward*3.2+Vector3.new(0,0,-8))
		for j,segment in arm.segments do
			local u=j/#arm.segments
			local extended=actor:PointToWorldSpace(outward*(3.2+12*u)+right*(5*u*u*math.sin(u*3+seconds*2+i))
				+Vector3.new(0,0,-8-31*u+8*u*u))
			local angle=a+.95*u
			local tip=view:PointToWorldSpace(Vector3.new(math.cos(angle)*1.18,math.sin(angle)*.8,-1.55))
			local base=actor:PointToWorldSpace(outward*3.2+Vector3.new(0,0,-8))
			local arched=base:Lerp(tip,u)+actor:VectorToWorldSpace(outward)*math.sin(math.pi*u)*4.6
			local at=extended:Lerp(arched,smooth(grab*1.45-(i%3)*.18))
			local diameter=2.3*(1-u*.86)
			link(segment,last,at,diameter,diameter)
			segment.Transparency=1-alpha
			local sucker=arm.suckers[j]
			if sucker then
				sucker.Size=Vector3.new(diameter*.74,diameter*.74,diameter*.31)
				local center=last:Lerp(at,.5)-actor:VectorToWorldSpace(outward)*diameter*.42
				sucker.CFrame=CFrame.lookAt(center,actor.Position)
				sucker.Transparency=1-alpha
			end
			last=at
		end
	end
end

function Cinematics.new(gui,onOwnershipChanged)
	local self={}
	local ui=make("ScreenGui",gui.Parent,{Name="DiveCinematics",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=gui.DisplayOrder+40})
	local shade=make("Frame",ui,{Name="Light exposure",Size=UDim2.fromScale(1,1),BorderSizePixel=0,
		BackgroundColor3=Color3.new(),BackgroundTransparency=1})
	local grade=make("ColorCorrectionEffect",Lighting,{Name="DiveIncidentGrade",Enabled=false})
	local instructions=make("TextLabel",ui,{Name="Escape controls",AnchorPoint=Vector2.new(.5,1),
		Position=UDim2.new(.5,0,.94,0),Size=UDim2.new(.95,0,0,26),Font=Enum.Font.GothamMedium,
		TextSize=14,TextColor3=rgb(212,239,240),TextStrokeTransparency=.42,BackgroundTransparency=1,Visible=false})
	local scene=nil
	local renderName="ThalassaDiveIncident"

	local function release()
		local old=scene
		if not old then return end
		scene=nil
		RunService:UnbindFromRenderStep(renderName)
		for p,value in old.hidden do
			if p.Parent then p.LocalTransparencyModifier=value end
		end
		old.folder:Destroy()
		if old.audio then old.audio:Destroy() end
		if old.escapeAudio then old.escapeAudio:Destroy() end
		if old.inputConnections then
			for _,connection in old.inputConnections do connection:Disconnect() end
		end
		if old.mouseBehavior then Input.MouseBehavior=old.mouseBehavior end
		instructions.Visible=false
		grade.Enabled=false
		shade.BackgroundTransparency=1
		local camera=workspace.CurrentCamera
		if camera then
			camera.CameraType=old.cameraType
			camera.FieldOfView=old.fov
			local character=player.Character
			if character then camera.CameraSubject=character:FindFirstChildOfClass("Humanoid") end
		end
		if onOwnershipChanged then onOwnershipChanged(false) end
	end

	local function sound(parent,asset,speed,volume)
		local cue=make("Sound",parent,{SoundId="rbxasset://sounds/"..asset,PlaybackSpeed=speed,Volume=volume})
		make("EqualizerSoundEffect",cue,{HighGain=-19,MidGain=-9,LowGain=3})
		cue:Play()
		return cue
	end

	local function render(current,dt)
		local camera=workspace.CurrentCamera
		if not camera or current~=scene then return end
		local seconds=math.max(0,os.clock()-current.started)
		local p=math.clamp(seconds/current.duration,0,1)
		local kind=current.kind
		if p>=1 then
			if terminal[kind] and kind~="WormDeath" then
				-- Wait on black until the authoritative result arrives.
				shade.BackgroundTransparency=0
				instructions.Visible=false
				return
			end
			release()
			return
		end
		camera.CameraType=Enum.CameraType.Scriptable
		grade.Enabled=true
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local start=current.cameraFrame
		local livePosition=root and root.Position or start.Position-Vector3.yAxis*1.35
		local heading=current.heading
		local view=start
		local opacity=0
		grade.TintColor=Color3.new(1,1,1)
		grade.Brightness=0
		grade.Contrast=0
		grade.Saturation=0
		if kind=="Angler" or kind=="Squid" or kind=="Flood" then hideAvatar(current) end
		if current.emergency then
			local pulse=.5+.5*math.cos(seconds*math.pi*1.7)
			for _,lamp in current.emergency do lamp.Brightness=(.2+2.5*pulse)*(1-smooth((p-.20)/.16)) end
		end

		if kind=="Wake" then
			hideAvatar(current)
			local rise=smooth((p-.14)/.74)
			local floorHeight=if root then root.Position.Y-1.95 else start.Position.Y-2.9
			local eye=Vector3.new(livePosition.X,floorHeight+.45+rise*2.81,livePosition.Z)-heading*(.36*(1-rise))
			view=CFrame.lookAt(eye,eye+heading)*CFrame.Angles(-.53*(1-rise),0,-.41*(1-rise))
			opacity=1-smooth((p-.035)/.68)
			grade.Saturation=-.35*(1-rise)
			grade.Brightness=-.18*(1-rise)
			if current.hands then
				for i,arm in current.hands do
					local side=if i==1 then -1 else 1
					local hand=view:PointToWorldSpace(Vector3.new(side*(.56+.22*rise),-.42-rise*1.8,-.91+rise*.34))
					local shoulder=view:PointToWorldSpace(Vector3.new(side*1.1,-.7-rise*1.5,-.17))
					link(arm,shoulder,hand,.35,.04)
				end
			end
		elseif kind=="WormGrab" or kind=="WormRescue" or kind=="WormDeath" then
			local free=kind=="WormRescue" and smooth(p) or 0
			local grip=(1-free)*smooth(p*8)
			local fatal=kind=="WormDeath" and smooth(p*1.2) or 0
			local at= if root then livePosition+Vector3.yAxis*(1.19-fatal*1.95) else start.Position
			local focus=current.crawler and current.crawler.Parent and current.crawler:GetPivot().Position or current.target
			if focus and (focus-at).Magnitude>.2 then
				heading=(focus-at).Unit:Lerp(heading,free).Unit
			end
			local struggle=math.sin(seconds*19)*.058*grip
			view=CFrame.lookAt(at,at+heading)*CFrame.Angles(-.21*grip+fatal*.34,struggle,.17*grip+struggle)
			grade.TintColor=rgb(228,196,185)
			grade.Brightness=-.16*grip
			grade.Saturation=-.23*grip
			if current.arms then
				bendArms(current,view,seconds,.45+.4*grip)
				if free>0 then
					for _,arm in current.arms do
						for _,segment in arm.segments do segment.Transparency=free end
					end
				end
			end
			opacity=if kind=="WormDeath" then smooth((p-.44)/.53) elseif kind=="WormRescue" then .2*(1-p) else .14*grip
		elseif kind=="Squid" then
			local breakOpen=smooth((p-.035)/.21)
			local seize=smooth((p-.73)/.21)
			if current.halves then
				local side=current.shipOrigin.RightVector
				for i,model in current.halves do
					local dir=if i==1 then -1 else 1
					model:PivotTo((current.rest[i]+side*dir*12*breakOpen+Vector3.new(0,-i*3*breakOpen,dir*2*breakOpen))
						*CFrame.Angles(dir*.17*breakOpen,dir*.24*breakOpen,dir*.31*breakOpen))
				end
				local ship=current.shipOrigin.Position
				local wide=CFrame.lookAt(ship+current.shipOrigin.RightVector*(28+15*breakOpen)+Vector3.yAxis*(7+4*seize),ship)
				view=start:Lerp(wide,smooth(p*7))
			end
			if p>=.20 then
				if not current.escape then beginEscape(current) end
				local swim=swimView(current,dt,current.lookTouch,current.moveTouch,p>.65)
				current.lookTouch=Vector2.zero
				local actor,reveal
				view,actor,reveal=revealPursuer(current,p,seconds,swim,true)
				local grab=smooth((p-.715)/.14)
				local pull=smooth((p-.82)/.15)
				local bite=smooth((p-.905)/.067)
				local beak=actor*CFrame.new(0,-.9,-12)
				local eye=view.Position:Lerp(beak:PointToWorldSpace(Vector3.new(.15,.15,-2.5)),pull)
				local look=CFrame.lookAt(eye,beak.Position)*CFrame.Angles(0,0,grab*.18-pull*.32)
				view=view:Lerp(look,grab)
				spreadApproachArms(current,actor,view,seconds,reveal,grab)
				closeBeak(current,beak,bite,reveal)
			end
			grade.TintColor=rgb(180,216,210)
			grade.Brightness=-.035+.045*seize
			opacity=math.max(.86*(1-math.clamp(math.abs(p-.20)/.035,0,1)),smooth((p-.94)/.045))
		elseif kind=="Angler" then
			local belly=current.belly
			local ship,size=belly.ship,belly.size
			local swallowed=smooth((p-.06)/.36)
			local pulse=.5+.5*math.sin(seconds*3.2)
			for _,lamp in belly.lights do lamp.Brightness=swallowed*(1.65+.6*pulse) end
			for _,fold in belly.folds do
				local radial=fold.rest.Position-ship:PointToWorldSpace(Vector3.new(0,0,fold.row*(size.Z+58)/12))
				fold.part.CFrame=fold.rest-radial*(.025+.025*math.sin(seconds*3-fold.row*.65))*swallowed
			end
			if p<.46 then
				local window=belly.window
				if window then
					local eye=window:PointToWorldSpace(Vector3.new(.9-.7*swallowed,.3,6-1.5*swallowed))
					view=CFrame.lookAt(eye,window.Position+window.LookVector*12)
				end
			else
				local glide=smooth((p-.46)/.46)
				local eye=ship:PointToWorldSpace(Vector3.new(size.X*(.67-.25*glide),10+7*glide,size.Z*(.32+.63*glide)))
				view=CFrame.lookAt(eye,ship:PointToWorldSpace(Vector3.new(0,-1,-size.Z*.06)))
			end
			grade.TintColor=rgb(249,208,210)
			grade.Brightness=.015-swallowed*.07
			opacity=math.max(1-smooth(p/.06),.92*(1-math.clamp(math.abs(p-.46)/.044,0,1)),smooth((p-.88)/.115))
		elseif kind=="Flood" then
			local gulp = .77
			if p>=gulp then
				if current.jaws then
					for _,tooth in current.jaws do
						tooth.part.Transparency=1
						tooth.gum.Transparency=1
					end
					current.jawShade.Transparency=1
				end
				local q=smooth((p-gulp)/(1-gulp))
				local bend=math.sin(q*3.8)
				view=current.mouth*CFrame.new(1.5*bend,-q*1.4,4-q*29)
					*CFrame.Angles(-.035*q,-.06*math.cos(q*3.8),.085*bend)
				current.throatLamp.CFrame=view*CFrame.new(.65,.45,-1.5)
				current.throatLight.Brightness=4.2*(1-.58*q)
				grade.TintColor=rgb(244,221,222)
				grade.Brightness=.035
				opacity=math.max(1-smooth((p-gulp)/.026),smooth((q-.76)/.24))
			else
				local liquid=smooth(p/.28)
				local at=current.breach.Position
				view=start:Lerp(CFrame.lookAt(start.Position+heading*.15,at),smooth(p*6))
				view=view*CFrame.new(.13*math.sin(seconds*13)*liquid,.12*math.sin(seconds*7)*liquid,0)
					*CFrame.Angles(0,0,liquid*.12*math.sin(seconds*6))
				local hull=current.shipOrigin or start
				current.water.CFrame=CFrame.new(hull.Position+Vector3.new(0,-7+liquid*8,0))
				current.water.Transparency=.68-(liquid*.37)
				current.water.Size=Vector3.new(71,math.max(.1,liquid*12),62)
				if not current.breachFX and p>.045 then
					current.breachFX=waterBubbles(current.folder,current.breach,34)
					current.breachFX.Enabled=true
					current.breachFX.Rate=32
				end
				for _,piece in current.fragments or {} do
					local vanish=smooth((liquid-.16-piece.stagger*.47)/.34)
					piece.part.Transparency=piece.transparency+(1-piece.transparency)*vanish
				end
				grade.TintColor=rgb(141,197,206)
				grade.Brightness=-liquid*.23
				grade.Saturation=-liquid*.32
				if p>=.22 then
					if not current.escape then beginEscape(current) end
					local swim=swimView(current,dt,current.lookTouch,current.moveTouch,p>.64)
					current.lookTouch=Vector2.zero
					local actor,reveal
					view,actor,reveal=revealPursuer(current,p,seconds,swim,false)
					local bite=smooth((p-.69)/.08)
					local lips=actor*CFrame.new(0,-1,-17)*CFrame.Angles(0,math.pi,0)
					approachJaws(current,lips,1-.65*bite,reveal)
				end
				opacity=math.max(.86*(1-math.clamp(math.abs(p-.22)/.035,0,1)),smooth((p-(gulp-.032))/.032))
			end
		end
		local swimming=(kind=="Flood" and p>=.22 and p<=.64) or (kind=="Squid" and p>=.20 and p<=.65)
		instructions.Visible=swimming
		if swimming then
			instructions.Text=if Input.PreferredInput==Enum.PreferredInput.Touch then "Left drag: swim   •   Right drag: look"
				elseif Input.PreferredInput==Enum.PreferredInput.Gamepad then "Left stick: swim   •   Right stick: look   •   Triggers: rise / sink"
				else "WASD: swim   •   Mouse: look   •   Space / C: rise / sink"
		end
		if current.escape then
			current.bubbles.Parent.CFrame=view*CFrame.new(.3,-.45,-1.45)
			current.bubbles.Enabled=swimming
			if swimming and not current.escapeAudio then
				current.escapeAudio=sound(SoundService,"action_swim.mp3",.79,.24)
				current.escapeAudio.Looped=true
			elseif not swimming and current.escapeAudio then
				current.escapeAudio:Destroy()
				current.escapeAudio=nil
			end
		end
		shade.BackgroundColor3=if kind=="WormRescue" then rgb(100,136,136) else Color3.new()
		shade.BackgroundTransparency=1-opacity
		camera.CFrame=view
		camera.Focus=view*CFrame.new(0,0,-13)
		camera.FieldOfView=current.fov+(if kind=="Wake" then 7*(1-smooth(p)) elseif kind=="Squid" then 11*p else 0)
	end

	function self:play(payload)
		local kind=type(payload)=="table" and payload.kind
		if not kind or not durations[kind] then return end
		local camera=workspace.CurrentCamera
		if not camera then return end
		local previousType=scene and scene.cameraType or camera.CameraType
		local previousFov=scene and scene.fov or camera.FieldOfView
		release()
		local frame=camera.CFrame
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if kind=="Wake" and root then frame=root.CFrame+Vector3.yAxis*1.32 end
		local look=frame.LookVector
		local heading=Vector3.new(look.X,0,look.Z)
		local current={
			kind=kind,duration=math.max(.25,tonumber(payload.duration) or durations[kind]),started=os.clock(),
			cameraType=previousType,fov=previousFov,cameraFrame=frame,heading=if heading.Magnitude>.001 then heading.Unit else -Vector3.zAxis,
			folder=make("Folder",workspace,{Name="LocalDiveIncident"}),hidden={},
			target=if typeof(payload.position)=="Vector3" then payload.position else nil,
		}
		if typeof(payload.startedAt)=="number" then
			current.started-=math.clamp(workspace:GetServerTimeNow()-payload.startedAt,0,.5)
		end
		scene=current
		local world=workspace:FindFirstChild("Thalassa")
		if kind=="Squid" or kind=="Flood" then
			cloneHull(current,world)
			breakingLights(current)
		end
		if kind=="Squid" or kind=="Flood" then
			local envelope=world and world:FindFirstChild("ShipEnvelope")
			current.shipWidth=envelope and envelope.Size.X or 40
			current.lookTouch=Vector2.zero
			current.mouseBehavior=Input.MouseBehavior
			constructPursuer(current)
			current.inputConnections={
				Input.InputBegan:Connect(function(touch,processed)
					if processed or not current.escape or touch.UserInputType~=Enum.UserInputType.Touch then return end
					local position=Vector2.new(touch.Position.X,touch.Position.Y)
					if position.X<camera.ViewportSize.X*.48 then
						current.moveTouch={id=touch,origin=position,delta=Vector2.zero}
					else
						current.touchLookId=touch
					end
				end),
				Input.InputChanged:Connect(function(touch)
					if current.moveTouch and touch==current.moveTouch.id then
						current.moveTouch.delta=Vector2.new(touch.Position.X,touch.Position.Y)-current.moveTouch.origin
					elseif touch==current.touchLookId then
						current.lookTouch+=Vector2.new(touch.Delta.X,touch.Delta.Y)
					end
				end),
				Input.InputEnded:Connect(function(touch)
					if current.moveTouch and touch==current.moveTouch.id then current.moveTouch=nil end
					if touch==current.touchLookId then current.touchLookId=nil end
				end),
			}
		end
		if kind=="Angler" then constructBelly(current,world) end
		if kind=="Flood" then
			constructMouth(current)
			constructJaws(current)
		end
		if kind=="Squid" then
			makeArms(current,6,8)
			constructBeak(current)
		end
		if kind=="WormGrab" or kind=="WormDeath" or kind=="WormRescue" then
			local contacts=world and world:FindFirstChild("Contacts")
			current.crawler=contacts and contacts:FindFirstChild("CrackCrawler")
			makeArms(current,5,6)
		end
		if kind=="Flood" then
			local marker=world and world:FindFirstChild("WormWindow"..tostring(payload.section or 1))
			current.breach=if marker then (marker.CFrame*CFrame.Angles(0,math.pi,0))+Vector3.yAxis*.15 else frame*CFrame.new(0,0,-6)*CFrame.Angles(0,math.pi,0)
			local rupture=part(current.folder,"Breach opening",rgb(2,17,25),Enum.Material.Slate)
			rupture.Size=Vector3.new(4.4,3.5,.17)
			rupture.CFrame=current.breach*CFrame.new(0,0,-1.12)*CFrame.Angles(0,0,.21)
			for i=1,6 do
				local rim=make("WedgePart",current.folder,{Name="Bent hull plate",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
					Material=Enum.Material.DiamondPlate,Color=rgb(58,76,78),Size=Vector3.new(.4,1.05,.94)})
				rim.CFrame=current.breach*CFrame.Angles(0,0,i/6*TAU)*CFrame.new(1.94,0,-.94)*CFrame.Angles(.45,i*.25,-.3)
			end
			current.water=part(current.folder,"Floodwater",rgb(18,75,84),Enum.Material.Glass)
			current.water.Transparency=1
		elseif kind=="Wake" then
			hideAvatar(current)
			current.hands={}
			for i=1,2 do current.hands[i]=ellipse(part(current.folder,"Bracing forearm",armColor())) end
		end
		if kind=="Flood" then current.audio=sound(SoundService,"impact_water.mp3",.55,.4)
		elseif kind=="Angler" then current.audio=sound(SoundService,"action_falling.ogg",.27,.42)
		elseif terminal[kind] then current.audio=sound(SoundService,"impact_explosion_03.mp3",.49,.42)
		elseif kind=="WormRescue" then current.audio=sound(SoundService,"action_swim.mp3",1.1,.22) end
		camera.CameraType=Enum.CameraType.Scriptable
		if onOwnershipChanged then onOwnershipChanged(true) end
		if kind=="Wake" then
			shade.BackgroundTransparency=0
			task.delay(current.duration,function()
				if scene==current then release() end
			end)
		end
		RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+7,function(dt) render(current,dt) end)
	end

	function self:reset() release() end
	function self:isPlaying() return scene~=nil end
	return self
end

return Cinematics
