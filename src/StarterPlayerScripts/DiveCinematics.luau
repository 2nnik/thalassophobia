-- Local presentation for server-selected sequences. No damage or progression lives here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Cinematics = {}
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local smooth = function(a)
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local durations = {Wake=2.7,WormGrab=8,WormRescue=.85,WormDeath=2.8,Flood=7.2,Angler=5.0,Squid=6.4}
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
	-- This chamber sits below the scenery and is seen only after the engulfing cut.
	local stage=CFrame.new(3500,-3000,3500)
	scene.mouth=stage
	local shell=ellipse(part(scene.folder,"Throat",rgb(29,19,29),Enum.Material.Slate))
	shell.Size=Vector3.new(74,62,95)
	shell.CFrame=stage*CFrame.new(0,0,-18)
	shell.Transparency=.55
	for ring=0,7 do
		local radial=11-ring*.57
		for i=0,15 do
			local a, b=i/16*TAU,(i+1)/16*TAU
			local z=-ring*5
			local rib=ellipse(part(scene.folder,"Inner cartilage",if ring%2==0 then rgb(66,48,61) else rgb(45,39,54)))
			link(rib,stage:PointToWorldSpace(Vector3.new(math.cos(a)*radial,math.sin(a)*radial*.78,z)),
				stage:PointToWorldSpace(Vector3.new(math.cos(b)*radial,math.sin(b)*radial*.78,z)),2.3,1.3)
		end
	end
	for i=0,15 do
		local a=i/16*TAU
		local at=stage:PointToWorldSpace(Vector3.new(math.cos(a)*9.9,math.sin(a)*7.7,-.7))
		local inward=stage.Position+stage.LookVector*3.5
		local fang=make("WedgePart",scene.folder,{Name="Silhouette tooth",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
			Material=Enum.Material.SmoothPlastic,Color=rgb(173,158,130),Size=Vector3.new(1.7,4.6,2.9),
			CFrame=CFrame.lookAt(at,inward)*CFrame.Angles(-.95,0,0)})
		fang.CastShadow=false
	end
	local lure=ellipse(part(scene.folder,"Fading lure",rgb(100,210,219),Enum.Material.Neon))
	lure.Size=Vector3.new(1,1,1)
	lure.CFrame=stage*CFrame.new(-.4,2.8,-11)
	make("PointLight",lure,{Range=32,Brightness=1.65,Color=rgb(112,224,233)})
end

local function constructJaws(scene)
	scene.jaws={}
	for i=0,23 do
		local angle=i/24*TAU
		local fang=make("WedgePart",scene.folder,{Name="Closing jaws",Anchored=true,CanCollide=false,CanQuery=false,
			CanTouch=false,CastShadow=false,Transparency=1,Color=rgb(187,174,147),Material=Enum.Material.SmoothPlastic})
		scene.jaws[#scene.jaws+1]={part=fang,angle=angle,offset=(i%3)*.8}
	end
	local pad=ellipse(part(scene.folder,"Shadow in the jaws",rgb(4,9,15)))
	pad.Transparency=1
	scene.jawShade=pad
end

local function approachJaws(scene,view,distance,opening,alpha)
	local mouth=view*CFrame.new(0,0,-distance)
	local shade=scene.jawShade
	shade.Size=Vector3.new(22,17,5)
	shade.CFrame=mouth*CFrame.new(0,0,-4.8)
	shade.Transparency=1-alpha*.91
	for _,tooth in scene.jaws do
		local a=tooth.angle
		local at=mouth:PointToWorldSpace(Vector3.new(math.cos(a)*opening,math.sin(a)*opening*.74,tooth.offset))
		tooth.part.Size=Vector3.new(1.42,4.1+tooth.offset,2.68)
		tooth.part.CFrame=CFrame.lookAt(at,mouth.Position)*CFrame.Angles(-1.15,0,0)
		tooth.part.Transparency=1-alpha
	end
end

local function constructBeak(scene)
	scene.beak={}
	for i=1,2 do
		scene.beak[i]=make("WedgePart",scene.folder,{Name="Chitin beak",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
			Size=Vector3.new(5.2,3.4,5.8),Color=rgb(63,49,42),Transparency=1,CastShadow=false})
	end
end

local function closeBeak(scene,view,seize)
	local reach=smooth((seize-.57)/.43)
	local at=view*CFrame.new(0,0,-(15-12*reach))
	for i,half in scene.beak do
		local dir=if i==1 then -1 else 1
		half.CFrame=at*CFrame.new(0,dir*(3.0-1.85*reach),0)*CFrame.Angles(dir*-.42,0,i==1 and math.pi or 0)
		half.Transparency=1-reach
	end
end

local function makeArms(scene,count,segments)
	scene.arms={}
	for i=1,count do
		local arm={segments={},suckers={}}
		for j=1,segments do
			arm.segments[j]=ellipse(part(scene.folder,"Coiling arm",rgb(47+i*4,76-j*2,73-j*2),Enum.Material.Slate))
			if j%2==1 and scene.kind=="Squid" then
				arm.suckers[j]=ellipse(part(scene.folder,"Arm sucker",rgb(112,94,76)))
			end
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

function Cinematics.new(gui,onOwnershipChanged)
	local self={}
	local ui=make("ScreenGui",gui.Parent,{Name="DiveCinematics",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=gui.DisplayOrder+40})
	local shade=make("Frame",ui,{Name="Light exposure",Size=UDim2.fromScale(1,1),BorderSizePixel=0,
		BackgroundColor3=Color3.new(),BackgroundTransparency=1})
	local grade=make("ColorCorrectionEffect",Lighting,{Name="DiveIncidentGrade",Enabled=false})
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

	local function render(current)
		local camera=workspace.CurrentCamera
		if not camera or current~=scene then return end
		local seconds=math.max(0,os.clock()-current.started)
		local p=math.clamp(seconds/current.duration,0,1)
		local kind=current.kind
		if p>=1 then
			if terminal[kind] and kind~="WormDeath" then
				-- Wait on black until the authoritative result arrives.
				shade.BackgroundTransparency=0
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

		if kind=="Wake" then
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
			local breakOpen=smooth((p-.10)/.35)
			local seize=smooth((p-.43)/.48)
			if current.halves then
				local side=current.shipOrigin.RightVector
				for i,model in current.halves do
					local dir=if i==1 then -1 else 1
					model:PivotTo((current.rest[i]+side*dir*12*breakOpen+Vector3.new(0,-i*3*breakOpen,dir*2*breakOpen))
						*CFrame.Angles(dir*.17*breakOpen,dir*.24*breakOpen,dir*.31*breakOpen))
				end
				local ship=current.shipOrigin.Position
				local wide=CFrame.lookAt(ship+current.shipOrigin.RightVector*(28+15*breakOpen)+Vector3.yAxis*(7+4*seize),ship)
				view=start:Lerp(wide,smooth(p*4))
			end
			view=view*CFrame.new(seize*.9,seize*2.2,-seize*3.5)*CFrame.Angles(.15*seize,0,.15*math.sin(seconds*19)*(1-seize)+seize*.45)
			bendArms(current,view,seconds,seize)
			closeBeak(current,view,seize)
			grade.TintColor=rgb(180,216,210)
			grade.Brightness=-.08-.22*seize
			opacity=smooth((p-.72)/.25)
		elseif kind=="Angler" or kind=="Flood" then
			local flood=kind=="Flood"
			local gulp = if flood then .68 else .47
			if p>=gulp then
				if current.jaws then
					for _,tooth in current.jaws do tooth.part.Transparency=1 end
					current.jawShade.Transparency=1
				end
				local q=smooth((p-gulp)/(1-gulp))
				view=current.mouth*CFrame.new(math.sin(seconds*4)*.48,-q*1.5,4-q*27)
					*CFrame.Angles(.045*math.sin(seconds*8),0,.035*math.cos(seconds*5))
				grade.TintColor=rgb(170,201,211)
				grade.Brightness=-.12
				opacity=math.max(1-smooth(q*10),smooth((q-.51)/.48))
			elseif flood then
				local liquid=smooth(p/gulp)
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
				local rush=smooth((p-.36)/.30)
				view=view:Lerp(start*CFrame.new(0,-1.05,-2),rush)
				approachJaws(current,view,40-rush*34,11.5-rush*5,smooth((p-.34)/.16))
				opacity=smooth((p-(gulp-.075))/.075)
			else
				local rush=smooth(p/gulp)
				view=start*CFrame.new(math.sin(seconds*21)*rush*.16,-.9*rush,-3*rush)
					*CFrame.Angles(.13*rush,.05*math.sin(seconds*18)*rush,.28*rush)
				grade.TintColor=rgb(162,201,205)
				grade.Brightness=-rush*.24
				approachJaws(current,view,44-rush*38,11-rush*4,smooth(p*7))
				opacity=smooth((p-(gulp-.16))/.16)
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
		if kind=="Squid" or kind=="Flood" then cloneHull(current,world) end
		if kind=="Angler" or kind=="Flood" then
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
			current.hands={}
			for i=1,2 do current.hands[i]=ellipse(part(current.folder,"Bracing forearm",armColor())) end
		end
		if kind=="Flood" then current.audio=sound(SoundService,"impact_water.mp3",.55,.4)
		elseif terminal[kind] then current.audio=sound(SoundService,"impact_explosion_03.mp3",.49,.42)
		elseif kind=="WormRescue" then current.audio=sound(SoundService,"action_swim.mp3",1.1,.22) end
		camera.CameraType=Enum.CameraType.Scriptable
		if onOwnershipChanged then onOwnershipChanged(true) end
		if kind=="Wake" then shade.BackgroundTransparency=0 end
		RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+7,function() render(current) end)
	end

	function self:reset() release() end
	function self:isPlaying() return scene~=nil end
	return self
end

return Cinematics
