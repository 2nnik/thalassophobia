-- Local first-person staging. The caller owns the parent and destroys it after blackout.
local PrisonScene = {}
PrisonScene.dialogueAsset = script:GetAttribute("DialogueAudioAssetId") or 79801240323942
local V, CF, rgb = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local origin = V(6100, 160, 5400)
local steel, trim, dark = rgb(69, 80, 82), rgb(116, 135, 131), rgb(32, 40, 43)
local concrete, tile = rgb(99, 103, 97), rgb(53, 73, 72)
local brass, amber, bone = rgb(175, 139, 76), rgb(255, 173, 81), rgb(218, 223, 207)

local function ease(t, a, b)
	local u = math.clamp((t-a)/(b-a), 0, 1)
	return u*u*(3-2*u)
end

local function piece(parent, name, size, frame, color, material, round)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Color, p.Material = color, material or M.SmoothPlastic
	if round then p.Shape = Enum.PartType.Ball end
	p.Parent = parent
	return p
end

local function model(parent, name, pivot)
	local m = Instance.new("Model")
	m.Name, m.WorldPivot = name, pivot
	m.Parent = parent
	return m
end

local function light(part, color, brightness, range)
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Brightness, lamp.Range = color, brightness*.23, range
	lamp.Parent = part
end

local function stencil(part, text, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = face or Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 60
	gui.LightInfluence,gui.Brightness = .83,.55
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1,1), 1
	label.Font, label.TextColor3, label.TextScaled = Enum.Font.GothamBold, color, true
	label.Text = text
	label.Parent = gui
end

local function holdingBlock(parent)
	local base = CF(origin)
	local function build(name, x,y,z, w,h,d, color, material)
		return piece(parent, name, V(w,h,d), base*CF(x,y,z), color, material)
	end
	build("Cell deck",0,-.26,7.9,17,.5,12,concrete,M.Concrete)
	build("Cell ceiling",0,8.65,7.9,17,.5,12,concrete,M.Concrete)
	build("Command deck",0,-.27,-17,44,.5,38,concrete,M.Concrete)
	build("Command ceiling",0,16.4,-17,44,.5,38,dark,M.Metal)
	for _,side in {-1,1} do
		build("Retaining wall",side*8.2,4.25,7.9,.5,8.5,12,concrete,M.Concrete)
		build("Painted lower wall",side*7.92,1.5,7.9,.13,3,12,tile,M.Metal)
		build("Chair rail",side*7.8,3.08,7.9,.18,.09,12,trim,M.Metal)
		build("Cell front", side*5.5,3.95,2, 5.05,7.9,.48, concrete,M.Concrete)
		build("Door jamb", side*2.89,3.9,2, .26,7.8,.68, steel,M.Metal)
		build("Transfer lane",side*2.32,.006,-5.5,.085,.018,14,brass,M.SmoothPlastic)
		build("Command wall",side*21.7,8.1,-17,.55,16.2,38,dark,M.Metal)
		build("Command wall rail",side*21.34,3.2,-17,.18,.17,38,trim,M.Metal)
		build("Rear bulkhead",side*15,8.1,1.9,13.5,16.2,.6,steel,M.Metal)
		for _,z in {7,12} do
			build("Wall pier", side*7.73,4,z, .5,8,.32, steel,M.Metal)
		end
		for _,z in {-6,-14,-22,-30} do
			build("Command rib",side*20.8,7.9,z,1.4,15.8,.7,steel,M.Metal)
			local strip=build("Aisle strip",side*14,.014,z,.11,.018,5,rgb(86,150,147),M.Neon)
			light(strip,rgb(102,211,204),.45,9)
		end
	end
	build("Cell rear", 0,4.2,13.8, 16.5,8.4,.5, concrete,M.Concrete)
	build("Command rear bulkhead",0,8.1,-35.7,44,16.2,.6,dark,M.Metal)
	build("Door overhead wall",0,12.3,1.9,17,8,.6,steel,M.Metal)
	build("Lintel", 0,7.85,2, 6.3,.55,.74, steel,M.Metal)
	build("Bunk frame", -5.39,1.45,7.9, 2.7,.26,5.7, steel,M.Metal)
	build("Thin mattress", -5.39,1.72,7.9, 2.64,.27,5.6, rgb(94,112,104),M.Fabric)
	build("Pillow", -5.39,1.99,9.9, 2.38,.28,1.15, bone,M.Fabric)
	build("Command riser",0,.31,-24.4,30,.6,18,steel,M.DiamondPlate)
	build("Forward operations display",0,7.8,-34.9,29,9,.4,rgb(22,54,60),M.SmoothPlastic)
	local sign=build("Command designation",0,12.75,-34.59,28,1.35,.13,tile,M.Metal)
	stencil(sign,"KESTREL OPERATIONS",bone)
	for i=-5,5 do
		build("Plot grid",i*2.22,7.8,-34.55,.027,7.85,.06,rgb(44,89,94),M.Neon)
	end
	for i=-3,3 do
		build("Plot grid",0,7.8+i*1.12,-34.55,25,.022,.06,rgb(44,89,94),M.Neon)
	end
	-- Survey cross-section on the rear plotting wall. Keep the contour visible
	-- around the general's shoulders in the kneeling shot.
	local function trace(name,points,color,width)
		for i=2,#points do
			local a,b=points[i-1],points[i]
			local delta=b-a
			local bar=build(name,(a.X+b.X)/2,(a.Y+b.Y)/2,-34.42,delta.Magnitude,width,.06,color,M.Neon)
			bar.CFrame*=CFrame.Angles(0,0,math.atan2(delta.Y,delta.X))
		end
	end
	local seabed={Vector2.new(-13,8.72),Vector2.new(-10,8.4),Vector2.new(-8.4,7.98),Vector2.new(-6.3,8.13),
		Vector2.new(-4.4,6.91),Vector2.new(-2.45,6.5),Vector2.new(-.8,4.7),Vector2.new(.95,4.24),
		Vector2.new(2.65,5.46),Vector2.new(4.2,7.05),Vector2.new(6.12,7.35),Vector2.new(7.45,8.17),
		Vector2.new(10.2,8.38),Vector2.new(13,9.12)}
	trace("Sounding trace",seabed,rgb(98,181,171),.085)
	trace("Survey track",{Vector2.new(-8.9,10.4),Vector2.new(-3.5,9.8),Vector2.new(.1,8.4),Vector2.new(.1,5)},amber,.065)
	for _,x in {-8.9,-3.5,.1} do
		local y=if x< -8 then 10.4 elseif x<0 then 9.8 else 5
		build("Survey fix",x,y,-34.34,.19,.19,.08,bone,M.Neon).CFrame*=CFrame.Angles(0,0,math.pi/4)
	end
	local plot=build("Plot legend",-7.7,11.2,-34.43,9,.55,.06,tile,M.Metal)
	stencil(plot,"KESTREL 04    /    SOUNDING PROFILE",bone)
	for _,z in {-5,-16,-28} do
		build("Ceiling crossbeam",0,15.3,z,44,.55,.85,steel,M.Metal)
		for _,x in {-11,0,11} do
			local bulb=build("Command light",x,14.86,z,6.6,.12,.29,bone,M.Neon)
			light(bulb,rgb(182,224,215),2.2,24)
		end
	end
	for _,side in {-1,1} do
		for row,z in {-10.8,-18.2,-26.4} do
			local x=side*(if row==1 then 7.7 else 10.1)
			local y=if row==3 then .6 else 0
			build("Station pedestal",x,y+1.22,z,4.3,2.44,1.9,steel,M.Metal)
			build("Desk edge",x,y+2.47,z,5.1,.16,2.65,trim,M.Metal)
			local display=build("Station display",x,y+3.36,z-.67,4.25,1.45,.23,tile,M.Metal)
			stencil(display,({"COMMS","SONAR","NAVIGATION"})[row],rgb(150,221,204))
			light(display,rgb(58,167,156),.62,10)
			for lamp=1,6 do
				build("Station indicators",x-1.8+lamp*.49,y+2.57,z+.55,.2,.07,.12,
					if lamp%3==0 then amber else rgb(96,202,182),M.Neon)
			end
			build("Operator stool",x,y+.71,z+2.44,1.05,1.4,1.05,dark,M.Metal)
		end
	end
	local number = build("Cell number", -4.05,4.65,2.33, 1.4,.81,.12, tile,M.Metal)
	stencil(number, "C–04", bone)
	for i=-4,4 do
		build("Drain slot", i*.19,.013,-4.55, .09,.025,1.3, dark,M.Metal)
	end
	for _,z in {-8.7,6.6} do
		build("Lamp housing", 0,8.26,z, 3.8,.22,.76, dark,M.Metal)
		local bulb = build("Porcelain fixture", 0,8.06,z, 3.5,.1,.42, bone,M.Neon)
		light(bulb, rgb(211,230,216), 1.65, 16)
	end
	local sidelight = build("Transfer lamp", 2.9,6.6,1.58, .3,1.2,.34, amber,M.Neon)
	light(sidelight, amber, 1.4, 13)
	local gate = model(parent, "Sliding cell gate", base*CF(0,0,2))
	for i=-4,4 do
		piece(gate,"Iron bar",V(.115,7.35,.15),base*CF(i*.64,3.78,2),steel,M.Metal)
	end
	for _,y in {.36,2.95,7.34} do
		piece(gate,"Cross rail",V(5.65,.13,.18),base*CF(0,y,2),trim,M.Metal)
	end
	return gate
end

local function segment(parent, name, color, material)
	return piece(parent,name,V(.4,1,.4),CF(origin),color,material)
end

local function span(part, a, b, width, depth)
	local d = b-a
	local direction = d.Unit
	local up = if math.abs(direction.Y)>.98 then Vector3.zAxis else Vector3.yAxis
	part.Size = V(width, depth, math.max(.05,d.Magnitude)+.045)
	part.CFrame = CFrame.lookAt((a+b)*.5,b,up)
end

local function limb(parent, sleeve, hand, bare, upperWidth, lowerWidth)
	return {
		upper=segment(parent,"Upper sleeve",sleeve,M.Fabric),
		lower=segment(parent,if bare then "Forearm" else "Lower sleeve",if bare then hand else sleeve,if bare then M.SmoothPlastic else M.Fabric),
		hand=piece(parent,"Hand",V(lowerWidth,lowerWidth*.8,lowerWidth*1.25),CF(origin),hand,nil,true),
		upperWidth=upperWidth,lowerWidth=lowerWidth,
	}
end

local function bend(arm, shoulder, elbow, wrist, handForward)
	span(arm.upper,shoulder,elbow,arm.upperWidth,arm.upperWidth)
	span(arm.lower,elbow,wrist,arm.lowerWidth,arm.lowerWidth)
	arm.hand.CFrame = CFrame.lookAt(wrist,wrist+handForward)
end

local uniforms = {
	General = {body=rgb(57,73,65), legs=rgb(40,48,45), skin=rgb(190,144,109)},
	Guard = {body=rgb(57,66,75), legs=rgb(39,49,57), skin=rgb(168,124,91)},
	Operator = {body=rgb(57,82,87), legs=rgb(43,55,61), skin=rgb(128,89,69)},
	Technician = {body=rgb(138,137,115), legs=rgb(66,74,70), skin=rgb(217,179,134)},
}

-- Uniform assemblies move with the three rigid body sections. Sleeve and leg meshes
-- remain free to bend for the restraint choreography.
local function dress(figure, role, uniform)
	local jacket=model(figure,"Jacket fittings",CF(origin))
	local belt=model(figure,"Web belt",CF(origin))
	local hat=model(figure,"Headgear",CF(origin))
	local leather=rgb(44,39,35)
	local web=rgb(54,62,54)
	local function sew(group,name,x,y,z,w,h,d,color,material,roll,oval)
		local frame=CF(origin+V(x,y,z))*CFrame.Angles(0,0,math.rad(roll or 0))
		local detail=piece(group,name,V(w,h,d),frame,color,material,oval)
		detail.CastShadow=false
		return detail
	end
	sew(belt,"Belt strap",0,0,0,1.64,.16,.86,if role=="General" then leather else web,M.Leather)
	sew(belt,"Buckle",0,0,-.44,.24,.17,.06,if role=="General" then brass else trim,M.Metal)
	if role=="General" then
		local lapel=rgb(42,58,52)
		sew(jacket,"Shirt front",0,.46,-.416,.45,.34,.052,bone,M.Fabric)
		sew(jacket,"Tie",0,.39,-.46,.115,.43,.055,dark,M.Fabric)
		for _,s in {-1,1} do
			sew(jacket,"Folded lapel",s*.24,.39,-.449,.26,.56,.08,lapel,M.Fabric,-s*32)
			sew(jacket,"Shoulder board",s*.62,.688,0,.39,.095,.62,brass,M.Fabric)
			sew(jacket,"Pocket flap",s*.48,.02,-.438,.37,.13,.055,lapel,M.Fabric)
			for row=0,2 do
				sew(jacket,"Tunic button",s*.17,.04-row*.235,-.47,.092,.092,.05,brass,M.Metal,0,true)
			end
		end
		for i,c in {rgb(148,56,52),bone,rgb(61,107,128),brass} do
			sew(jacket,"Service ribbon",-.67+i*.085,.205,-.46,.085,.11,.055,c,M.Fabric)
		end
		sew(hat,"Peaked cap crown",0,.5,.025,1.14,.34,1.06,uniform.body,M.Fabric,0,true)
		sew(hat,"Black cap band",0,.39,0,.98,.16,.96,dark,M.Leather,0,true)
		sew(hat,"Polished peak",0,.34,-.42,.92,.09,.53,leather,M.Leather,0,true)
		sew(hat,"Officer cord",0,.403,-.466,.65,.044,.05,brass,M.Metal)
		sew(hat,"Cap cockade",0,.51,-.481,.16,.17,.05,brass,M.Metal,45)
	elseif role=="Guard" then
		local plate=rgb(43,52,54)
		sew(jacket,"Carrier back",0,.03,.38,1.35,.98,.20,plate,M.Fabric)
		sew(jacket,"Carrier front",0,-.02,-.40,1.39,1.03,.2,plate,M.Fabric)
		for _,s in {-1,1} do
			sew(jacket,"Carrier yoke",s*.49,.45,-.32,.24,.6,.27,web,M.Fabric,-s*7)
			sew(jacket,"Equipment pouch",s*.43,-.34,-.54,.36,.36,.21,web,M.Fabric)
			sew(jacket,"Pouch flap",s*.43,-.25,-.65,.37,.12,.045,plate,M.Fabric)
		end
		for row=0,2 do
			sew(jacket,"Webbing",0,.18-row*.14,-.517,1.15,.06,.05,web,M.Fabric)
		end
		local tape=sew(jacket,"Unit tape",0,.35,-.53,.71,.17,.045,dark,M.Fabric)
		stencil(tape,"KESTREL",bone,Enum.NormalId.Front)
		sew(hat,"Patrol helmet",0,.30,.035,1.13,.67,1.08,plate,M.Metal,0,true)
		sew(hat,"Helmet rim",0,.18,.01,1.14,.14,1.13,web,M.Fabric,0,true)
		for _,s in {-1,1} do
			sew(hat,"Ear guard",s*.47,.075,.03,.16,.36,.46,plate,M.Fabric,0,true)
		end
	else
		local trimColor=if role=="Technician" then rgb(193,150,76) else rgb(110,158,155)
		sew(jacket,"Storm placket",0,0,-.425,.13,1.2,.05,uniform.legs,M.Fabric)
		for _,s in {-1,1} do
			sew(jacket,"Stand collar",s*.22,.59,-.32,.29,.19,.2,uniform.legs,M.Fabric,s*20)
			sew(jacket,"Chest pocket",s*.45,.06,-.415,.39,.32,.07,uniform.body,M.Fabric)
			sew(jacket,"Branch tape",s*.45,.21,-.463,.40,.073,.04,trimColor,M.Fabric)
		end
		sew(hat,"Headset band",0,.39,.04,1,.15,.21,dark,M.Leather)
		for _,s in {-1,1} do
			sew(hat,"Headset cup",s*.48,.02,.055,.19,.45,.36,uniform.legs,M.SmoothPlastic,0,true)
		end
		sew(hat,"Microphone boom",-.4,-.13,-.2,.06,.06,.44,dark,M.Metal)
		sew(hat,"Microphone",-.35,-.13,-.423,.17,.095,.12,dark,M.Fabric,0,true)
	end
	return jacket,belt,hat
end

local function makeOfficer(parent, name, role)
	local figure = script:WaitForChild("CommandR15"):Clone()
	figure.Humanoid.AutomaticScalingEnabled=false
	local uniform = uniforms[role]
	figure.Name = name
	local torso, waist, head = figure.UpperTorso, figure.LowerTorso, figure.Head
	for _,joint in figure:GetDescendants() do
		if joint:IsA("JointInstance") or joint:IsA("Constraint") then joint.Enabled = false end
	end
	for _,bodyPart in figure:GetChildren() do
		if not bodyPart:IsA("BasePart") then continue end
		bodyPart.Anchored, bodyPart.CanCollide, bodyPart.CanQuery, bodyPart.CanTouch = true, false, false, false
		bodyPart.Size *= .82
		local name = bodyPart.Name
		bodyPart.Color = if name=="Head" or name:find("Hand") then uniform.skin
			elseif name:find("Leg") then uniform.legs elseif name:find("Foot") then dark else uniform.body
		if name:find("Torso") or name:find("Arm") or name:find("Leg") then bodyPart.Material=M.Fabric end
		if name:find("Foot") then bodyPart.Material=M.Leather end
	end
	figure.Parent = parent
	local jacket,belt,hat=dress(figure,role,uniform)
	local arms,legs = {},{}
	for _,side in {-1,1} do
		local prefix=if side<0 then "Left" else "Right"
		arms[side]={upper=figure[prefix.."UpperArm"],lower=figure[prefix.."LowerArm"],hand=figure[prefix.."Hand"]}
		legs[side]={thigh=figure[prefix.."UpperLeg"],shin=figure[prefix.."LowerLeg"],boot=figure[prefix.."Foot"]}
	end
	return {torso=torso,waist=waist,head=head,jacket=jacket,belt=belt,hat=hat,arms=arms,legs=legs}
end

local function poseSegment(part, a, b)
	local delta=b-a
	if delta.Magnitude<.02 then return end
	local up=if math.abs(delta.Unit.Y)>.98 then Vector3.zAxis else Vector3.yAxis
	part.CFrame=CFrame.lookAt((a+b)*.5,b,up)*CFrame.Angles(math.pi/2,0,0)
	local size=part.Size
	part.Size=V(size.X,delta.Magnitude+.16,size.Z)
end

local function animateOfficer(officer, frame, stride, crouch, nod, reach)
	local function at(x,y,z) return frame:PointToWorldSpace(V(x,y,z)) end
	officer.torso.CFrame=frame*CF(0,3.01-crouch,0)
	officer.waist.CFrame=frame*CF(0,2.16-crouch,0)
	local face=frame*CF(0,4.18-crouch,0)*CFrame.Angles(nod,0,0)
	officer.head.CFrame=face
	officer.jacket:PivotTo(officer.torso.CFrame*CF(0,0,-.035))
	officer.belt:PivotTo(officer.waist.CFrame)
	officer.hat:PivotTo(face*CF(0,.055,-.025))
	for _,side in {-1,1} do
		local step=stride*side
		local leg=officer.legs[side]
		local hip=at(side*.42,2.04-crouch,0)
		local knee=at(side*.42,1.03-crouch*.35,-.20-step*.24-crouch*.59)
		local heel=at(side*.42,.22,step*.53)
		poseSegment(leg.thigh,hip,knee)
		poseSegment(leg.shin,knee,heel)
		leg.boot.CFrame=frame*CF(side*.42,.14,step*.53-.13)
		local arm=officer.arms[side]
		local shoulder=at(side*.99,3.58-crouch,0)
		local relaxed=at(side*1.14,2.28-crouch,-.24-step*.22)
		local wrist=if reach then reach(side,relaxed) else relaxed
		local elbow=shoulder:Lerp(wrist,.5)+frame:VectorToWorldSpace(V(side*.14,-.09,.13))
		poseSegment(arm.upper,shoulder,elbow)
		poseSegment(arm.lower,elbow,wrist)
		arm.hand.CFrame=CFrame.lookAt(wrist,wrist+(wrist-elbow).Unit)*CFrame.Angles(math.pi/2,0,0)
	end
end
-- Position, look target, roll, field of view. Coordinates are relative to the floor.
local shots = {
	{0, V(-.12,4.46,6.4), V(-1.3,3.85,3.0), -2, 72},
	{1.3, V(.04,4.5,6.3), V(1.45,4.15,3.1), 2, 72},
	{2.4, V(.05,4.5,6.08), V(.15,3.7,.05), 0, 72},
	{2.95, V(-.14,4.11,4.42), V(-.34,1.65,1.2), -6, 77},
	{4.0, V(.28,4.26,1.17), V(2.33,3.86,-15), 4, 82},
	{5.3, V(.02,4.02,-2.55), V(.05,2.15,-7.45), -2, 72},
	{5.83, V(-.18,2.08,-3.55), V(-.17,.08,-5.35), -5, 74},
	{6.25, V(-.12,2.43,-3.71), V(-.05,.18,-5.98), 2, 70},
	{7.04, V(-.10,2.34,-3.72), V(-.03,.24,-6.1), 0, 69},
	{8.8, V(-.06,2.40,-3.77), V(.02,4.21,-8.6), 0, 68},
	{11.7, V(-.03,2.42,-3.8), V(.02,4.24,-8.47), 0, 68},
	{13.15, V(-.16,2.22,-3.67), V(-1.25,2.13,-5.22), -6, 68},
	{14.72, V(.02,2.22,-3.65), V(.78,1.7,-4.75), 3, 66},
	{16.5, V(.02,2.22,-3.65), V(.71,1.56,-4.78), 2, 64},
	{18.1, V(.01,2.27,-3.61), V(.85,2.38,-5.52), 4, 70},
	{20, V(-.24,1.64,-3.52), V(-.17,.18,-5.18), -16, 65},
}

local function cameraPose(t)
	local a,b = shots[#shots-1],shots[#shots]
	for i=2,#shots do
		if t<=shots[i][1] then a,b = shots[i-1],shots[i] break end
	end
	local u = ease(t,a[1],b[1])
	local position, target = a[2]:Lerp(b[2],u),a[3]:Lerp(b[3],u)
	local struggle = ease(t,16.1,16.52)*(1-ease(t,17.4,18.15))
	local breath = .021*math.sin(t*2.2)
	position += V(.065*struggle*math.sin(t*15),breath+.05*struggle*math.sin(t*18),0)
	target += V(.22*struggle*math.sin(t*13),breath,0)
	local roll = a[4]+(b[4]-a[4])*u+struggle*2.0*math.sin(t*15)
	return CFrame.lookAt(origin+position,origin+target)*CFrame.Angles(0,0,math.rad(roll)),a[5]+(b[5]-a[5])*u,position
end

function PrisonScene.new(parent, skinColor)
	local gate = holdingBlock(parent)
	local general = makeOfficer(parent,"Transfer general","General")
	local staff = {
		{makeOfficer(parent,"Comms operator","Operator"), V(-7.7,0,-8.36), -1},
		{makeOfficer(parent,"Watch officer","Guard"), V(7.7,0,-8.36), 1},
		{makeOfficer(parent,"Sonar operator","Operator"), V(10.1,0,-15.76), -1},
		{makeOfficer(parent,"Duty technician","Technician"), V(-10.1,0,-15.76), 1},
		{makeOfficer(parent,"Plot officer","Operator"), V(5.6,.6,-26.3), -1},
	}
	local guards,prisoner = {},{}
	for _,s in {-1,1} do
		guards[s] = makeOfficer(parent,if s<0 then "Left escort" else "Right escort","Guard")
		prisoner[s] = limb(parent,rgb(133,91,62),skinColor or rgb(177,138,107),true,.35,.26)
	end
	local injector = model(parent,"Medical injector",CF(origin))
	local function instrument(name,z,width,length,color,material)
		return piece(injector,name,V(width,width,length),CF(origin+V(0,0,z)),color,material)
	end
	instrument("Tip",-.47,.041,.26,trim,M.Metal)
	instrument("Nose",-.306,.11,.09,steel,M.Metal)
	instrument("Ampoule",-.08,.19,.38,rgb(91,193,192),M.Glass)
	instrument("Rear fitting",.14,.215,.09,bone,M.Metal)
	instrument("Plunger",.245,.09,.14,steel,M.Metal)
	instrument("Thumb stop",.35,.24,.08,dark,M.Metal)

	local mouth = general.head:FindFirstChildOfClass("FaceControls")
	local function sample(_, t, speech)
		local camera, fov, position = cameraPose(t)
		local base = origin+V(position.X,0,position.Z)
		local shoved = ease(t,2.38,2.84)*(1-ease(t,3.53,4.14))
		local kneel = ease(t,5.27,5.85)
		local held = ease(t,11.66,14.0)
		local fight = ease(t,15.95,16.46)*(1-ease(t,17.53,18.18))
		local slump = ease(t,18,20)
		gate:PivotTo(CF(origin+V(5.82*ease(t,.46,2.18),0,2)))
		local officerAt = origin+V(.08,0,-8.82+.37*ease(t,7.5,8.83))
		local generalFrame = CFrame.lookAt(officerAt,officerAt+Vector3.zAxis)
		animateOfficer(general,generalFrame,0,0,-.06-.095*ease(t,8.28,9.22)+.055*ease(t,10,10.65))
		if mouth then mouth.JawDrop=math.clamp((speech or 0)/420,0,.75) end
		for index,entry in staff do
			local position=origin+entry[2]
			local glance=ease(t,3.1+index*.17,4.35+index*.19)*(1-ease(t,7.1+index*.22,8.7+index*.18))
			local frame=CF(position)*CFrame.Angles(0,entry[3]*glance*1.18,0)
			animateOfficer(entry[1],frame,0,if index==2 then 0 else .49,.12+.057*math.sin(t*1.6+index),
				function(side,rest)
					if index==2 or index==5 then return rest end
					local key=frame:PointToWorldSpace(V(side*.7,2.55+.027*math.sin(t*10+side+index),-1.31))
					return key:Lerp(rest,glance)
				end)
		end
		local playerHands = {}
		for _,s in {-1,1} do
			local shoulder = base+V(s*.49,position.Y-.37,.13)
			local lowered = base+V(s*.63,position.Y-1.55,-.06)
			local catch = base+V(s*.65,position.Y-1.0,-1.27)
			local brace = base+V(s*.61,.38,-1.12)
			local pinned = base+V(s*(.69+.065*fight*math.sin(t*12)),1.52-.23*slump+.055*fight*math.sin(t*16),-1.12)
			local hand = lowered:Lerp(catch,shoved):Lerp(brace,kneel*(1-.72*ease(t,7,8.5))):Lerp(pinned,held)
			local elbow = shoulder:Lerp(hand,.5)+V(s*.21,-.25,.07)
			bend(prisoner[s],shoulder,elbow,hand,(hand-elbow).Unit)
			playerHands[s] = hand
		end
		local rightHand = playerHands[1]
		local injection = ease(t,14.1,16.32)*(1-ease(t,17.12,18.12))
		local needleAt = rightHand+V(.64-.55*injection,.40-.33*injection,.15)
		local axis = V(-.81,-.57,-.09).Unit
		local instrumentCenter = needleAt-axis*.60
		for _,s in {-1,1} do
			local settle = ease(t,4.62,6.95)
			local stepAside=ease(t,4.2,6.2)*(1-ease(t,11.3,13.1))
			local guardAt = base+V(s*(1.79+.89*stepAside-.21*held),0,-1.45+1.8*ease(t,1.82,3.03)-1.3*settle)
			local gaze = V(-s*.90,0,-.55+.96*settle)
			local frame = CFrame.lookAt(guardAt,guardAt+gaze)
			local walking = ease(t,2.14,2.72)*(1-ease(t,5.16,5.85))
			animateOfficer(guards[s],frame,math.sin(t*8.4+s)*walking,.93*held,
				-.16-.20*held,function(side,relaxed)
					local shoveTarget = base+V(s*.5,position.Y-.38,-.32)
					local target = relaxed:Lerp(shoveTarget,shoved)
					local grab = playerHands[s]+V(s*.04,.085,.14)
					if s==1 and side==-1 then
						local draw = ease(t,12.2,14.5)
						local wrist = target:Lerp(instrumentCenter-axis*.14,draw)
						local aim = Vector3.yAxis:Lerp(axis,draw).Unit
						local center = wrist+aim*.14
						injector:PivotTo(CFrame.lookAt(center,center+aim,if draw<.16 then Vector3.zAxis else Vector3.yAxis))
						return wrist
					elseif side==1 then
						grab += V(s*.14,.14,.33)
					end
					return target:Lerp(grab,held)
				end)
		end
		return camera,fov
	end
	local self = {sample=sample}
	self:sample(0)
	return self
end

return PrisonScene
