-- Kestrel pressure shell and cabin fittings. Station transforms remain the gameplay reference.
local Refit = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local alloy = rgb(57, 81, 87)
local dark = rgb(21, 35, 41)
local gasket = rgb(13, 23, 26)
local ash = rgb(132, 156, 148)
local orange = rgb(181, 87, 43)
local amber = rgb(239, 188, 106)
local teal = rgb(162, 233, 216)

local function part(parent, name, size, frame, color, material, shape)
	local item = Instance.new("Part")
	item.Name, item.Size, item.CFrame = name, size, frame
	item.Color, item.Material, item.Shape = color, material or Enum.Material.Metal, shape or Enum.PartType.Block
	item.Anchored, item.Massless = true, true
	item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
	item.CastShadow = false
	item.Parent = parent
	return item
end

local function line(parent, name, from, to, width, height, color, material)
	return part(parent, name, V(width, height, (to-from).Magnitude), CFrame.lookAt((from+to)*.5, to), color, material)
end

local function tube(parent, name, from, to, diameter, color)
	local frame = CFrame.lookAt((from+to)*.5, to)*CFrame.Angles(0, math.pi*.5, 0)
	return part(parent, name, V((to-from).Magnitude, diameter, diameter), frame, color, nil, Enum.PartType.Cylinder)
end

local function pill(parent, name, size, frame, color)
	local item = part(parent, name, size, frame, color)
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = item
	return item
end

local function marking(parent, name, frame, size, value, textColor, fillColor)
	local item = part(parent, name, size, frame, fillColor, Enum.Material.SmoothPlastic)
	local face = Instance.new("SurfaceGui")
	face.Name, face.Face = "Paint", Enum.NormalId.Front
	face.CanvasSize, face.LightInfluence = Vector2.new(720, 130), .8
	face.Parent = item
	local text = Instance.new("TextLabel")
	text.Name, text.Size, text.BackgroundTransparency = "Stencilled text", UDim2.fromScale(1, 1), 1
	text.Font, text.TextScaled, text.TextColor3, text.Text = Enum.Font.GothamBold, true, textColor, value
	text.Parent = face
	return item
end

local function lamp(parent, color, range, power)
	local source = Instance.new("PointLight")
	source.Color, source.Range, source.Brightness = color, range, power
	source.Parent = parent
	return source
end

local function panelTriangle(parent, a, b, c, tint, solid)
	-- Split the triangle along the altitude to its longest edge.
	if (b-a).Magnitude>(c-b).Magnitude and (b-a).Magnitude>(a-c).Magnitude then
		a,b,c=c,a,b
	elseif (c-a).Magnitude>(c-b).Magnitude then
		a,b,c=b,c,a
	end
	local ab,ac,bc=b-a,c-a,c-b
	local cross=ac:Cross(ab)
	if cross.Magnitude<.0001 then return end
	local right,back=cross.Unit,bc.Unit
	local up=back:Cross(right).Unit
	local height=math.abs(ab:Dot(up))
	for _,edge in {{b,c,ab,right,back},{c,b,ac,-right,-back}} do
		local length=math.abs(edge[3]:Dot(back))
		if length<.025 then continue end
		local wedge=Instance.new("WedgePart")
		wedge.Name,wedge.Size="Rolled pressure plate",V(.24,height,length)
		wedge.CFrame=CFrame.fromMatrix((a+edge[1])*.5,edge[4],up,edge[5])
		wedge.Color,wedge.Material=tint,Enum.Material.Metal
		wedge.Anchored,wedge.Massless=true,true
		wedge.CanCollide,wedge.CanTouch,wedge.CanQuery=solid,false,solid
		wedge.CastShadow=false
		wedge.Parent=parent
	end
end

local function exterior(group, pose)
	local pressure=Instance.new("Model")
	pressure.Name="Tapered pressure hull"
	pressure.Parent=group
	local hardware=Instance.new("Model")
	hardware.Name="External survey equipment"
	hardware.Parent=group
	local topPaint=rgb(52,74,75)
	local bellyPaint=rgb(61,71,71)
	local rescuePaint=rgb(175,85,46)
	local trim=rgb(104,127,124)
	local function beam(name,a,b,w,h,tint,material)
		return line(hardware,name,pose:PointToWorldSpace(a),pose:PointToWorldSpace(b),w,h,tint,material)
	end
	local function pipe(name,a,b,d,tint)
		return tube(hardware,name,pose:PointToWorldSpace(a),pose:PointToWorldSpace(b),d,tint)
	end
	local function block(name,size,x,y,z,tint,material)
		return part(hardware,name,size,pose*CFrame.new(x,y,z),tint,material)
	end
	-- Each section is depth, half-beam, upper shoulder/crown, and lower shoulder/keel.
	-- The separated half-shells leave the existing sight lines and side-hatch corridor open.
	local sections={
		{-39.2,.48,1.9,2.12,-1.75,-1.97},
		{-38.55,4.8,2.35,3.4,-2.15,-3.4},
		{-36.4,10.7,3.0,5.8,-2.7,-5.9},
		{-32.1,17.7,3.65,8.6,-3.2,-8.6},
		{-26.7,23.1,4.02,11.3,-3.52,-10.9},
		{-21.9,25.65,4.18,12.2,-3.66,-11.6},
		{-.45,26.04,4.18,12.9,-3.66,-11.6},
		{21.9,25.65,4.18,12.22,-3.66,-11.4},
		{26.75,22.1,3.9,10.4,-3.5,-10.3},
		{31.55,15.8,3.2,7.75,-3.0,-7.8},
		{35.3,9.25,2.6,5.0,-2.45,-5.2},
		{37.2,3.3,1.9,2.9,-1.8,-3},
		{37.8,.48,1.6,1.81,-1.55,-1.77},
	}
	local divisions=10
	local function position(row,i,upper)
		local angle=math.pi*i/divisions
		local shoulder=if upper then row[3] else row[5]
		local crest=if upper then row[4] else row[6]
		return V(row[2]*math.cos(angle),shoulder+(crest-shoulder)*math.sin(angle),row[1])
	end
	for _,upper in {true,false} do
		for section=2,#sections do
			local a,b=sections[section-1],sections[section]
			for i=0,divisions-1 do
				local color=if upper and (section<=4 or section>=13) then rescuePaint elseif upper then topPaint else bellyPaint
				local tint=color:Lerp(if i%2==0 then trim else dark, .055+((section+i*3)%4)*.025)
				local p,q,r,t=pose:PointToWorldSpace(position(a,i,upper)),pose:PointToWorldSpace(position(a,i+1,upper)),
					pose:PointToWorldSpace(position(b,i,upper)),pose:PointToWorldSpace(position(b,i+1,upper))
				panelTriangle(pressure,p,q,r,tint,true)
				panelTriangle(pressure,r,q,t,tint,true)
			end
		end
	end
	-- Close the tapered tips into a single pressure profile. The bow approach
	-- stays open at viewport height between the tip and the existing bridge.
	for _,side in {-1,1} do
		local ringSide=if side==1 then 0 else divisions
		for _,i in {2,3,#sections-1,#sections} do
			local a,b=sections[i-1],sections[i]
			local p=pose:PointToWorldSpace(position(a,ringSide,true))
			local q=pose:PointToWorldSpace(position(a,ringSide,false))
			local r=pose:PointToWorldSpace(position(b,ringSide,true))
			local t=pose:PointToWorldSpace(position(b,ringSide,false))
			panelTriangle(pressure,p,q,r,rescuePaint,true)
			panelTriangle(pressure,r,q,t,rescuePaint,true)
		end
	end
	for _,row in {sections[1],sections[#sections]} do
		local frame=pose*CFrame.new(0,(row[3]+row[5])*.5,row[1])
		part(pressure,"Pressure end cap",V(row[2]*2,row[3]-row[5],.32),frame,rescuePaint)
	end
	for _,side in {-1,1} do
		for i=2,#sections do
			local a,b=sections[i-1],sections[i]
			for _,upper in {true,false} do
				local ringSide=if side==1 then 0 else divisions
				local p=position(a,ringSide,upper)+V(side*.2,0,0)
				local q=position(b,ringSide,upper)+V(side*.2,0,0)
				beam(if upper then "Deck sheer rail" else "Rescue orange waterline",p,q,.52,if upper then .46 else .56,
					if upper then dark else rescuePaint)
			end
		end

		-- Strakes and two tailplanes give the profile sternward direction without fencing in the EVA exit.
		local extA,extB=V(side*20,-3.4,19),V(side*32,-3.9,29)
		local extC,extD=V(side*30,-3.7,35),V(side*14,-3.4,32)
		local function fin(a,b,c) panelTriangle(hardware,pose:PointToWorldSpace(a),pose:PointToWorldSpace(b),pose:PointToWorldSpace(c),topPaint,false) end
		fin(extA,extB,extD)
		fin(extB,extC,extD)
		beam("Hydroplane leading edge",extA,extB,.64,.52,trim)
		beam("Rescue painted hydroplane tip",extB,extC,.81,.62,rescuePaint)
		beam("Hydroplane trailing edge",extC,extD,.48,.4,dark)
		pipe("Hydroplane actuator",V(side*17.8,-5,22.8),V(side*28.2,-4.1,30),.62,dark)
		for _,z in {-16,2,18} do
			local start=V(side*25.8,-3.5,z)
			local stop=V(side*23.8,-5.9,z+.7)
			pipe("Rescue rail bracket",start,stop,.34,trim)
		end
		local marker=block("Navigation light",V(.58,.46,1.18),side*26.45,4.12,18.3,
			if side==1 then teal else rgb(244,99,69),Enum.Material.Neon)
		lamp(marker,marker.Color,10,.46)
		local signPose=pose*CFrame.new(side*26.45,-4.12,6)*CFrame.Angles(0,-side*math.pi*.5,0)
		marking(hardware,"Submarine registration",signPose,V(12.5,.89,.08),"KESTREL   /   04",ash,dark)
	end

	-- Low nose lights sit below both the forward camera and the existing bridge glazing.
	for _,side in {-1,1} do
		local x=side*7.7
		local housing=pose*CFrame.new(x,-1.77,-36.28)*CFrame.Angles(0,side*.26,0)
		part(hardware,"Nose survey light shroud",V(2.8,1.55,1.65),housing,dark)
		local lens=part(hardware,"Nose survey lamp",V(2.29,.8,.13),
			housing*CFrame.new(0,0,-.86),teal,Enum.Material.Neon)
		lamp(lens,teal,19,.87)
	end

	pill(hardware,"Bridge sail base",V(13,4.4,19),pose*CFrame.new(0,12.4,-6),dark)
	pill(hardware,"Raked conning sail",V(8.4,9.3,15),pose*CFrame.new(0,15,-6.1)*CFrame.Angles(-.16,0,0),topPaint)
	pill(hardware,"Rescue sail crown",V(7.7,1.75,11),pose*CFrame.new(0,18.46,-6.55),rescuePaint)
	pipe("Survey mast",V(0,18.1,-5.7),V(0,22.1,-5.7),.54,dark)
	pipe("Hydrophone crossbar",V(-2.25,21.55,-5.7),V(2.25,21.55,-5.7),.27,trim)
	for _,x in {-2.25,2.25} do
		local beacon=block("Survey mast beacon",V(.54,.47,.54),x,21.7,-5.7,amber,Enum.Material.Neon)
		lamp(beacon,amber,12,.5)
	end
	pipe("Periscope tube",V(0,18,-9),V(0,20.7,-9),.54,trim)
	pipe("Periscope head",V(0,20.7,-9),V(0,20.7,-10.2),.68,dark)
	for _,side in {-1,1} do
		local placard=pose*CFrame.new(side*4.28,16.62,-6.7)*CFrame.Angles(0,-side*math.pi*.5,0)
		marking(hardware,"Sail marking",placard,V(4.1,1.15,.08),"04",ash,dark)
	end

	-- The thrusters keep their working nozzles. Add an open pressure spine between them.
	local spine=pose*CFrame.new(0,2.05,29)
	pill(hardware,"Aft steering root",V(6.1,6.3,17),spine,dark)
	panelTriangle(hardware,pose:PointToWorldSpace(V(0,7.5,25)),pose:PointToWorldSpace(V(0,4.3,37)),
		pose:PointToWorldSpace(V(0,12.4,34)),topPaint,false)
	beam("Rudder leading edge",V(0,7.5,25),V(0,12.4,34),.48,.5,trim)
	beam("Rescue rudder stripe",V(0,12.4,34),V(0,4.3,37),.57,.47,rescuePaint)

	for _,face in {
		{z=-39.52,y=2.94,turn=0,name="Bow"},
		{z=38.3,y=2.64,turn=math.pi,name="Stern"},
	} do
		local cf=pose*CFrame.new(0,face.y,face.z)*CFrame.Angles(0,face.turn,0)
		part(hardware,face.name.." CCTV shroud",V(2.2,1.19,1.35),cf,dark)
		part(hardware,face.name.." CCTV lens",V(1.06,.6,.12),cf*CFrame.new(0,0,-.717),teal,Enum.Material.Glass)
	end

	-- The outer rim surrounds the existing starboard hatch; its opening stays empty.
	local lockCenter=V(25.57,-.47,-11)
	for i=0,11 do
		local a,b=math.pi*i/6,math.pi*(i+1)/6
		local p=lockCenter+V(0,3.25*math.sin(a),3.48*math.cos(a))
		local q=lockCenter+V(0,3.25*math.sin(b),3.48*math.cos(b))
		beam("EVA rescue collar",p,q,.79,.5,if i%3==0 then amber else rescuePaint)
	end
end

local function cabin(group, pose)
	for _,zone in {
		{x=13,z=-11,color=rgb(161,209,218)}, {x=-13,z=-12,color=rgb(230,173,107)},
		{x=12,z=10,color=rgb(150,207,207)}, {x=-13,z=10,color=rgb(195,224,202)},
	} do
		local frame=pose*CFrame.new(zone.x,4.46,zone.z)
		part(group,"Overhead cold rail casing",V(1.5,.48,12.3),frame,dark)
		for _,side in {-1,1} do
			part(group,"Lamp guard channel",V(.13,.21,12.2),frame*CFrame.new(side*.60,-.24,0),ash)
		end
		for _,dz in {-4,0,4} do
			local strip=part(group,"Recessed ceiling strip",V(.68,.07,3.45),frame*CFrame.new(0,-.269,dz),
				zone.color,Enum.Material.SmoothPlastic)
			strip.Reflectance=.10
		end
		local bulb=part(group,"Work lamp",V(.45,.09,2.0),frame*CFrame.new(0,-.309,0),zone.color,Enum.Material.Neon)
		lamp(bulb,zone.color,16,.87)
	end

	-- Low service lighting distinguishes the bow-facing controls from the colder overhead lights.
	for _,x in {7.4,20.3} do
		local frame=pose*CFrame.new(x,-3.95,-19.73)
		part(group,"Service spill guard",V(3.2,.46,.35),frame,dark)
		local bulb=part(group,"Work lamp",V(2.65,.105,.12),frame*CFrame.new(0,-.14,.205),
			rgb(251,191,126),Enum.Material.Neon)
		lamp(bulb,rgb(246,180,109),10,.36):SetAttribute("OutputScale",.43)
		for _,side in {-1,1} do
			part(group,"Service cover captive fastener",V(.23,.24,.17),frame*CFrame.new(side*1.42,0,.207),ash)
		end
	end

	for _,entry in {
		{x=13,z=-4.8,heading=0,text="01  /  BRIDGE",ink=teal},
		{x=-13,z=.3,heading=math.pi,text="04  /  WET LAB",ink=amber},
		{x=1.8,z=10,heading=math.pi*.5,text="03  /  DIVER SERVICE",ink=teal},
	} do
		local frame=pose*CFrame.new(entry.x,-4.775,entry.z)*CFrame.Angles(math.pi*.5,0,entry.heading)
		marking(group,"Route stencil",frame,V(7.6,1.3,.025),entry.text,entry.ink,dark)
	end
	for _,x in {20.8,22.5} do
		local decal=pose*CFrame.new(x,-4.78,-11)*CFrame.Angles(math.pi*.5,0,math.pi*.5)
		marking(group,"Airlock approach stencil",decal,V(4.4,.94,.025),"AIRLOCK  ›",amber,dark)
	end
	for _,gate in {
		{x=12,z=-2,angle=0}, {x=-13,z=-2,angle=0},
		{x=-1,z=-12,angle=math.pi*.5}, {x=-1,z=10,angle=math.pi*.5},
	} do
		local frame=pose*CFrame.new(gate.x,-4.765,gate.z)*CFrame.Angles(0,gate.angle,0)
		part(group,"Watertight threshold warning stripe",V(6.5,.026,.38),frame,orange,Enum.Material.SmoothPlastic)
		for i=-3,3 do
			part(group,"Threshold caution dash",V(.15,.031,.36),frame*CFrame.new(i*.86,.002,0)*CFrame.Angles(0,.42,0),
				dark,Enum.Material.SmoothPlastic)
		end
	end
end

-- Flush graphics carry the fine detail without adding dozens of welded hull parts.
local function trenchChart(group,frame)
	local mount=part(group,"Trench survey chart",V(6.1,2.58,.16),frame,ash)
	local face=Instance.new("SurfaceGui")
	face.Name,face.Face,face.CanvasSize="Hydrographic chart",Enum.NormalId.Front,Vector2.new(600,250)
	face.LightInfluence,face.MaxDistance=.48,48
	face.Parent=mount
	local function rect(x,y,w,h,color,angle)
		local mark=Instance.new("Frame")
		mark.AnchorPoint,mark.Position=Vector2.new(.5,.5),UDim2.fromOffset(x,y)
		mark.Size,mark.BorderSizePixel=UDim2.fromOffset(w,h),0
		mark.Rotation,mark.BackgroundColor3=angle or 0,color
		mark.Parent=face
	end
	local function caption(x,y,w,h,value,color)
		local text=Instance.new("TextLabel")
		text.Position,text.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
		text.BackgroundTransparency,text.Font,text.TextSize=1,Enum.Font.Code,h*.82
		text.TextXAlignment,text.TextColor3,text.Text=Enum.TextXAlignment.Left,color,value
		text.Parent=face
	end
	local paper=rgb(31,54,59)
	local grid=rgb(62,86,87)
	rect(300,125,600,250,paper)
	caption(17,8,560,30,"KESTREL 04   /   TRENCH PROFILE",teal)
	for i=0,4 do rect(262,55+i*38,476,1,grid) end
	for i=0,8 do rect(24+i*59.5,131,1,152,grid) end
	local points={Vector2.new(24,68),Vector2.new(90,75),Vector2.new(150,65),Vector2.new(210,100),
		Vector2.new(246,106),Vector2.new(289,142),Vector2.new(321,149),Vector2.new(351,192),
		Vector2.new(380,201),Vector2.new(419,164),Vector2.new(455,125),Vector2.new(500,110)}
	for i=2,#points do
		local delta=points[i]-points[i-1]
		local mid=(points[i]+points[i-1])*.5
		rect(mid.X,mid.Y,delta.Magnitude+1,3,ash,math.deg(math.atan2(delta.Y,delta.X)))
	end
	rect(380,201,9,9,amber,45)
	caption(512,44,88,20,"0 m",ash)
	caption(512,120,88,20,"5,000",ash)
	caption(512,196,88,20,"10,000",amber)
	caption(16,219,540,21,"SECTION A–A     /     BENTHIC SURVEY",ash)
end

local function expeditionFittings(group,pose)
	local function localTube(name,a,b,d,color)
		return tube(group,name,pose:PointToWorldSpace(a),pose:PointToWorldSpace(b),d,color)
	end
	for _,side in {-1,1} do
		local station=pose*CFrame.new(side*25.46,-2.72,1)*CFrame.Angles(0,-side*math.pi/2,0)
		for i=-1,1 do
			part(group,"Hull draft graduation",V(.21,.57,.12),station*CFrame.new(i*.56,.02,-.06),ash)
		end
	end
	trenchChart(group,pose*CFrame.new(20.5,.82,-2.43))
	for _,z in {-17,-7,4,15} do
		-- Warm port and grey starboard stiffeners stay against the top corners.
		for _,side in {-1,1} do
			line(group,"Deckhead gusset",pose:PointToWorldSpace(V(side*24,3.2,z)),
				pose:PointToWorldSpace(V(side*21.8,4.84,z)),.25,.31,if side<0 then orange else ash)
		end
	end
	-- Color-coded pipework in the machinery room. Brackets clear the passage and wheel.
	for i,color in {rgb(174,108,64),rgb(114,143,143)} do
		local y=2.25+i*.46
		localTube("Heat exchanger return",V(-24.2,y,-18),V(-24.2,y,-5),.27,color)
		for _,z in {-16,-11,-6} do
			localTube("Compression coupling",V(-24.2,y,z-.10),V(-24.2,y,z+.10),.41,gasket)
		end
	end
	local pipe=pose*CFrame.new(-21.1,.55,-2.46)
	part(group,"Machinery service cover",V(4.5,2.45,.24),pipe,dark,Enum.Material.DiamondPlate)
	for i=-2,2 do
		part(group,"Extractor louvre",V(3.6,.11,.21),pipe*CFrame.new(0,i*.34,-.19)*CFrame.Angles(-.25,0,0),ash)
	end
	-- Reflective direction bands run along the diver-service floor edge.
	for _,x in {4.1,20.1} do
		part(group,"Diver lane inlay",V(.10,.025,14),pose*CFrame.new(x,-4.77,9),teal,Enum.Material.SmoothPlastic)
	end

	for _,zone in {
		{x=12,z=-12,paint=rgb(94,126,126)}, {x=-13,z=-12,paint=rgb(120,97,75)},
		{x=12,z=10,paint=rgb(72,103,111)}, {x=-13,z=10,paint=rgb(94,116,100)},
	} do
		for _,dz in {-7,2,7} do
			local function at(x,y) return pose:PointToWorldSpace(V(zone.x+x,y,zone.z+dz)) end
			line(group,"Overhead pressure rib",at(-8.1,4.74),at(8.1,4.74),.41,.28,zone.paint)
			for _,side in {-1,1} do
				line(group,"Rolled rib shoulder",at(side*8.1,4.74),at(side*10.2,3.91),.41,.28,zone.paint)
				line(group,"Inset cable chase",at(side*10.2,3.91),at(side*11.0,3.25),.35,.23,dark)
			end
		end
		for _,side in {-1,1} do
			local from=V(zone.x+side*9.6,4.1,zone.z-7.6)
			local to=V(from.X,from.Y,zone.z+7.6)
			localTube("Overhead pipe run",from,to,.24,zone.paint)
		end
	end
end

function Refit.install(world)
	local shell=world:WaitForChild("Pressure hull • Survey refit")
	if shell:FindFirstChild("Kestrel expedition refit") then return end
	local pose=world:WaitForChild("ShipEnvelope").CFrame
	local group=Instance.new("Model")
	group.Name="Kestrel expedition refit"
	group:SetAttribute("HullDesign","Tapered submarine")
	exterior(group,pose)
	cabin(group,pose)
	expeditionFittings(group,pose)

	-- Keep the authored structural parts and prompts. Retire the above-water
	-- lifting wires and exterior trim that belongs to the original square bell.
	local bell=world["Bell • KESTREL 04"]
	for _,item in bell:GetChildren() do
		if item:IsA("BasePart") and (item.Name=="Suspension wire" or item.Name=="Bearing") then
			item.Transparency=1
			item.CanCollide,item.CanTouch,item.CanQuery=false,false,false
		end
	end
	local glazing=shell["Observation glazing"]
	for _,item in glazing:GetChildren() do
		if item:IsA("BasePart") then
			if item.Name=="Window post" or item.Name=="Top coaming" then item.Color=dark
			elseif item.Name=="Post strap" or item.Name=="Outer sill" then item.Color=alloy
			elseif item.Name=="Ballast plating" then item.Color=rgb(57,74,74) end
		end
	end
	local oldDrive=shell["External ballast and propulsors"]
	for _,item in oldDrive:GetChildren() do
		if item:IsA("BasePart") then
			if item.Name=="Ballast flask" or item.Name=="Domed end" then item.Color=rgb(91,108,104)
			elseif item.Name=="Shrouded aft thruster" then item.Color=alloy
			elseif item.Name=="Nozzle rim" then item.Color=orange end
		end
	end

	-- The two camera lenses sit beyond the new ends and remain in the hull-motion assembly.
	world.DiveCamera1.CFrame=pose*CFrame.new(0,2.94,-40.36)
	world.DiveCamera3.CFrame=pose*CFrame.new(0,2.64,39.13)*CFrame.Angles(0,math.pi,0)
	local keel=world.BarnacleSites.Site2
	local mount=keel.PrimaryPart
	keel:PivotTo(keel:GetPivot()+pose:PointToWorldSpace(V(5,-11.85,5))-mount.Position)
	group.Parent=shell
end

return Refit
