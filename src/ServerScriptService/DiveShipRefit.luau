-- Cosmetic survey-bell refit. Existing decks, windows, and station hitboxes retain their geometry.
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

local function exterior(group, pose)
	local function block(name, size, x, y, z, color, material)
		return part(group, name, size, pose*CFrame.new(x,y,z), color, material)
	end

	-- The rounded pressure case, raised bridge crown and stepped keel break up the flat roof silhouette.
	pill(group,"Dorsal pressure case",V(31,9,57),pose*CFrame.new(0,10.3,-1.5),alloy) -- sits on the bridge roof; at 6.05 it bulged 3 studs into the cabin
	pill(group,"Fore survey crown",V(24,6.2,21),pose*CFrame.new(0,8.3,-14),orange)
	pill(group,"Keel compensation chamber",V(34,6.4,52),pose*CFrame.new(0,-8.7,1),dark) -- below the deck; at -6.05 it rose 2 studs through the floor
	pill(group,"Underwater survey transducer",V(16,5,18),pose*CFrame.new(0,-8.3,-13),alloy)
	block("Recessed service platform",V(12,.25,14),0,10.15,6,dark,Enum.Material.DiamondPlate)
	block("Transponder pedestal",V(5,2,7),0,11,9,alloy)
	local locator=block("Transponder marker",V(4.75,.16,5.9),0,12.08,9,amber,Enum.Material.Neon)
	lamp(locator,amber,13,.45)
	for _,x in {-9.5,9.5} do
		line(group,"Dorsal reinforced spine",pose:PointToWorldSpace(V(x,9.85,-9)),
			pose:PointToWorldSpace(V(x,9.85,14)),1.1,.52,dark)
		for _,z in {-10,3,14} do
			block("Spine brace",V(2.3,.78,1.46),x,9.65,z,ash)
		end
	end
	for _,side in {-1,1} do
		local outer=side*26.05
		for _,z in {-20,0,20} do
			block("Sacrificial side bumper",V(2.8,1.25,3.3),outer,-5.2,z,dark,Enum.Material.DiamondPlate)
			block("Side bumper cap",V(1.4,.51,2.4),outer+side*.68,-4.4,z,orange)
		end
		local casing=block("Aft marker housing",V(1.4,1.7,2.3),side*24.6,4.1,23.2,dark)
		local color=if side==1 then teal else rgb(237,104,86)
		local running=part(group,"Running light",V(.88,.82,.84),
			casing.CFrame*CFrame.new(0,0,1.28),color,Enum.Material.Neon)
		lamp(running,color,10,.42)

		-- Recessed spheres under the corners read as oiler and pump housings from EVA.
		pill(group,"Side compensation cell",V(5.1,3.4,12),pose*CFrame.new(side*21.8,-7.1,0),orange)
		tube(group,"Keel shock rail",pose:PointToWorldSpace(V(side*20,-8.25,-22)),
			pose:PointToWorldSpace(V(side*20,-8.25,19)),.8,alloy)
		for _,z in {-18,-7,7,16} do
			block("Keel attachment",V(2.4,2.15,.7),side*20,-7.1,z,gasket)
		end
		for _,z in {-18,18} do
			local root=pose:PointToWorldSpace(V(side*24.7,5.75,z))
			local spine=pose:PointToWorldSpace(V(side*11,9.15,z*.73))
			line(group,"Raked dorsal brace",root,spine,1.15,.62,dark)
			tube(group,"Brace hydraulic line",root+Vector3.yAxis*.41,spine+Vector3.yAxis*.41,.24,ash)
			block("Brace terminal plate",V(3.4,.75,2.6),side*23.6,5.65,z,orange)
		end
	end
	for _,x in {-19,19} do
		local case=pose*CFrame.new(x,5.15,-23.8)
		local housing=part(group,"Forward survey lamp housing",V(4.2,1.65,2.5),case,dark)
		local lens=part(group,"Survey lamp lens",V(3.6,1.1,.15),housing.CFrame*CFrame.new(0,0,-1.29),teal,Enum.Material.Neon)
		lamp(lens,teal,15,.7)
	end
	marking(group,"Forward hull registration",pose*CFrame.new(0,-3.86,-22.31),
		V(14,1.55,.09),"KESTREL  /  04",ash,dark)
	marking(group,"Aft hull registration",pose*CFrame.new(0,-3.83,22.31)*CFrame.Angles(0,math.pi,0),
		V(13,1.5,.09),"KESTREL  /  04",ash,dark)
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
	-- A reinforced lifting arch and a guarded acoustic array stand clear of glass and cameras.
	localTube("Port lifting post",V(-6,13.65,3.6),V(-4.1,16,3.6),.65,orange)
	localTube("Starboard lifting post",V(6,13.65,3.6),V(4.1,16,3.6),.65,orange)
	localTube("Lifting crosshead",V(-4.1,16,3.6),V(4.1,16,3.6),.74,orange)
	localTube("Hydrophone pedestal",V(0,13.6,-7),V(0,16,-7),.53,gasket)
	pill(group,"Ceramic hydrophone",V(1.5,1.75,1.5),pose*CFrame.new(0,16.1,-7),ash)
	for _,side in {-1,1} do
		local frame=pose*CFrame.new(side*25.45,-4.02,0)*CFrame.Angles(0,-side*math.pi/2,0)
		part(group,"Ceramic flotation stripe",V(26,.8,.12),frame,orange)
		for i=-1,1 do
			part(group,"Hull draft graduation",V(.24,.66,.13),frame*CFrame.new(i*.58,.02,-.06),ash)
		end
		marking(group,"EVA hull number",frame*CFrame.new(8,.02,-.08),V(5.8,.73,.09),"K–04",ash,dark)
		localTube("Thruster guard support",V(side*19,-1.5,25),V(side*21,-2.6,27.5),.24,ash)
		localTube("Thruster guard support",V(side*21,-2.6,27.5),V(side*23,-1.5,24),.24,ash)
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
end

function Refit.install(world)
	local shell=world:WaitForChild("Pressure hull • Survey refit")
	if shell:FindFirstChild("Kestrel expedition refit") then return end
	local pose=world:WaitForChild("ShipEnvelope").CFrame
	local group=Instance.new("Model")
	group.Name="Kestrel expedition refit"
	exterior(group,pose)
	cabin(group,pose)
	expeditionFittings(group,pose)
	group.Parent=shell
end

return Refit
