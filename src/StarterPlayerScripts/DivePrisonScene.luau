-- Local first-person staging. The caller owns the parent and destroys it after blackout.
local PrisonScene = {}
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
	lamp.Color, lamp.Brightness, lamp.Range = color, brightness, range
	lamp.Parent = part
end

local function stencil(part, text, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = face or Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 60
	gui.LightInfluence = .4
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
	build("Poured deck", 0,-.26,0, 17,.5,28, concrete,M.Concrete)
	build("Ceiling", 0,8.65,0, 17,.5,28, concrete,M.Concrete)
	for _,side in {-1,1} do
		build("Retaining wall", side*8.2,4.25,0, .5,8.5,28, concrete,M.Concrete)
		build("Painted lower wall", side*7.92,1.5,0, .13,3,28, tile,M.Metal)
		build("Chair rail", side*7.8,3.08,0, .18,.09,28, trim,M.Metal)
		build("Cell front", side*5.5,3.95,2, 5.05,7.9,.48, concrete,M.Concrete)
		build("Door jamb", side*2.89,3.9,2, .26,7.8,.68, steel,M.Metal)
		build("Transfer lane", side*2.32,.006,-4.25, .085,.018,12, brass,M.SmoothPlastic)
		build("Cable trunk", side*7.6,7.7,0, .24,.24,26, trim,M.Metal)
		for _,z in {-9,-4,2,7,12} do
			build("Wall pier", side*7.73,4,z, .5,8,.32, steel,M.Metal)
		end
	end
	build("Cell rear", 0,4.2,13.8, 16.5,8.4,.5, concrete,M.Concrete)
	build("Intake wall", 0,4.2,-13.7, 16.5,8.4,.5, concrete,M.Concrete)
	build("Lintel", 0,7.85,2, 6.3,.55,.74, steel,M.Metal)
	build("Bunk frame", -5.39,1.45,7.9, 2.7,.26,5.7, steel,M.Metal)
	build("Thin mattress", -5.39,1.72,7.9, 2.64,.27,5.6, rgb(94,112,104),M.Fabric)
	build("Pillow", -5.39,1.99,9.9, 2.38,.28,1.15, bone,M.Fabric)
	build("Intake window frame", 0,4.2,-13.38, 8.4,2.8,.24, steel,M.Metal)
	build("Smoked glass", 0,4.2,-13.22, 8.02,2.45,.1, rgb(35,57,58),M.Glass)
	for i=-2,2 do build("Window mullion", i*1.48,4.2,-13.12, .075,2.4,.09, trim,M.Metal) end
	local sign = build("Intake sign", 0,6.61,-13.33, 7.45,.85,.18, tile,M.Metal)
	stencil(sign, "INTAKE   /   TRANSFER", bone)
	local number = build("Cell number", -4.05,4.65,2.33, 1.4,.81,.12, tile,M.Metal)
	stencil(number, "C–04", bone)
	for i=-4,4 do
		build("Drain slot", i*.19,.013,-4.55, .09,.025,1.3, dark,M.Metal)
	end
	for _,z in {-8.7,-1.3,6.6} do
		build("Lamp housing", 0,8.26,z, 3.8,.22,.76, dark,M.Metal)
		local bulb = build("Porcelain fixture", 0,8.06,z, 3.5,.1,.42, bone,M.Neon)
		light(bulb, rgb(211,230,216), 1.65, 16)
	end
	local sidelight = build("Transfer lamp", 6.6,4.6,-8.6, .3,1.2,.45, amber,M.Neon)
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

local function makeOfficer(parent, name, general)
	local figure = model(parent,name,CF(origin))
	local torso = model(figure,"Uniform",CF(origin))
	local jacket = if general then rgb(50,71,64) else rgb(60,77,79)
	local cloth = rgb(47,58,59)
	local skin = rgb(159,125,100)
	local function fixed(group,name,x,y,z,w,h,d,color,material,round,angle)
		return piece(group,name,V(w,h,d),CF(origin+V(x,y,z))*(angle or CFrame.identity),color,material,round)
	end
	fixed(torso,"Tunic",0,3.05,0,1.36,1.58,.76,jacket,M.Fabric)
	fixed(torso,"Duty belt",0,2.53,0,1.4,.2,.81,dark,M.Leather)
	fixed(torso,"Buckle",0,2.53,-.43,.29,.16,.075,brass,M.Metal)
	if general then
		fixed(torso,"Double-breasted panel",.09,3.24,-.39,.78,.97,.07,jacket,M.Fabric)
		for _,s in {-1,1} do
			fixed(torso,"Collar",s*.2,3.74,-.4,.36,.19,.08,dark,M.Fabric,false,CFrame.Angles(0,0,s*.4))
			fixed(torso,"Epaulette",s*.51,3.86,0,.34,.12,.67,brass,M.Metal)
			for i=0,2 do fixed(torso,"Brass stud",s*.23,3.42-i*.27,-.445,.065,.065,.045,brass,M.Metal,true) end
		end
		for i,color in {brass,rgb(143,74,64),bone} do fixed(torso,"Service ribbon",.25+i*.09,3.47,-.44,.09,.12,.065,color,M.Fabric) end
	else
		fixed(torso,"Armoured vest",0,3.16,-.37,1.12,1.02,.25,dark,M.Metal)
		for i=1,3 do fixed(torso,"Plate ridge",0,2.94+i*.18,-.51,.86,.055,.06,steel,M.Metal) end
		for _,s in {-1,1} do fixed(torso,"Harness",s*.55,3.39,-.39,.13,.86,.13,cloth,M.Fabric) end
	end
	local head = model(figure,"Head",CF(origin))
	fixed(head,"Head",0,.07,0,.91,1.03,.84,if general then skin else dark,nil,true)
	if general then
		fixed(head,"Nose",0,.11,-.40,.18,.24,.21,skin,nil,true)
		for _,s in {-1,1} do
			fixed(head,"Ear",s*.435,.07,0,.15,.29,.2,skin,nil,true)
			fixed(head,"Eyebrow",s*.20,.22,-.38,.25,.06,.05,cloth,M.Fabric,false,CFrame.Angles(0,0,s*.12))
			fixed(head,"Eye",s*.19,.13,-.411,.09,.06,.035,dark,nil,true)
		end
		fixed(head,"Cap crown",0,.52,.02,1.09,.34,.99,jacket,M.Fabric,true)
		fixed(head,"Cap band",0,.40,0,.94,.16,.86,dark,M.Leather,true)
		fixed(head,"Peak",0,.38,-.42,.86,.11,.45,dark,M.Leather,true)
		fixed(head,"Cap badge",0,.49,-.44,.125,.17,.07,brass,M.Metal)
	else
		fixed(head,"Helmet shell",0,.36,.04,1.05,.71,1.00,steel,M.Metal,true)
		fixed(head,"Masked visor",0,.19,-.37,.85,.23,.22,rgb(26,55,58),M.Glass,true)
		fixed(head,"Visor ridge",0,.29,-.44,.78,.055,.065,trim,M.Metal)
		fixed(head,"Respirator",0,-.15,-.34,.51,.3,.29,cloth,nil,true)
		for _,s in {-1,1} do fixed(head,"Filter",s*.29,-.13,-.30,.18,.26,.28,steel,M.Metal,true) end
	end
	local mouth = if general then fixed(figure,"Mouth",0,0,0,.23,.045,.042,rgb(85,54,48),nil,true) else nil
	local arms,legs = {},{}
	for _,s in {-1,1} do
		arms[s] = limb(figure,jacket,if general then skin else dark,false,.43,.34)
		legs[s] = {
			thigh=segment(figure,"Trouser",cloth,M.Fabric),
			shin=segment(figure,"Shin",cloth,M.Fabric),
			boot=fixed(figure,"Boot",0,0,0,.49,.46,.8,dark,M.Leather),
		}
	end
	return {torso=torso,head=head,mouth=mouth,arms=arms,legs=legs}
end

local function animateOfficer(officer, frame, t, stride, crouch, nod, reach)
	local at = function(x,y,z) return frame:PointToWorldSpace(V(x,y,z)) end
	officer.torso:PivotTo(frame*CF(0,-crouch,0))
	local face = frame*CF(0,4.34-crouch,0)*CFrame.Angles(nod,0,0)
	officer.head:PivotTo(face)
	if officer.mouth then
		local speaking = ease(t,9,9.2)*(1-ease(t,10.75,11.05))
		local open = speaking*math.abs(math.sin((t-9)*8))
		officer.mouth.Size = V(.23,.042+.09*open,.048)
		officer.mouth.CFrame = face*CF(0,-.13-open*.015,-.403)
	end
	for _,side in {-1,1} do
		local footCycle = stride*side
		local leg = officer.legs[side]
		local hip,knee = at(side*.37,2.37-crouch,0),at(side*.4,1.23-crouch*.5,-.12-footCycle*.21-crouch*.42)
		local heel = at(side*.40,.26,footCycle*.45)
		span(leg.thigh,hip,knee,.5,.52)
		span(leg.shin,knee,heel,.44,.44)
		leg.boot.CFrame = frame*CF(side*.4,.24,footCycle*.45-.12)
		local shoulder = at(side*.73,3.62-crouch,0)
		local relaxed = at(side*.88,2.22-crouch,-.22-footCycle*.21)
		local wrist = if reach then reach(side,relaxed,shoulder) else relaxed
		local elbow = shoulder:Lerp(wrist,.51)+frame:VectorToWorldSpace(V(side*.19,-.17,.29))
		bend(officer.arms[side],shoulder,elbow,wrist,(wrist-elbow).Unit)
	end
end

-- Position, look target, roll, field of view. Coordinates are relative to the floor.
local shots = {
	{0, V(-.12,4.46,6.4), V(-1.3,3.85,3.0), -2, 72},
	{1.3, V(.04,4.5,6.3), V(1.45,4.15,3.1), 2, 72},
	{2.4, V(.05,4.5,6.08), V(.15,3.7,.05), 0, 72},
	{2.95, V(-.14,4.11,4.42), V(-.34,1.65,1.2), -6, 77},
	{4.0, V(.28,4.26,1.17), V(.43,2.1,-3.8), 4, 75},
	{5.3, V(.02,4.02,-2.55), V(.05,2.15,-7.45), -2, 72},
	{5.83, V(-.18,2.08,-3.55), V(-.17,.08,-5.35), -5, 74},
	{6.25, V(-.12,2.43,-3.71), V(-.05,.18,-5.98), 2, 70},
	{7.04, V(-.10,2.34,-3.72), V(-.03,.24,-6.1), 0, 69},
	{8.8, V(-.06,2.40,-3.77), V(.02,4.31,-8.6), 0, 63},
	{11.7, V(-.03,2.42,-3.8), V(.02,4.34,-8.47), 0, 63},
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
	local general = makeOfficer(parent,"Transfer general",true)
	local guards,prisoner = {},{}
	for _,s in {-1,1} do
		guards[s] = makeOfficer(parent,if s<0 then "Left escort" else "Right escort",false)
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

	local function sample(_, t)
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
		animateOfficer(general,generalFrame,t,0,0,-.06-.095*ease(t,8.28,9.22)+.055*ease(t,10,10.65),nil)
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
			local guardAt = base+V(s*(1.79-.21*held),0,-1.45+1.8*ease(t,1.82,3.03)-1.3*settle)
			local gaze = V(-s*.90,0,-.55+.96*settle)
			local frame = CFrame.lookAt(guardAt,guardAt+gaze)
			local walking = ease(t,2.14,2.72)*(1-ease(t,5.16,5.85))
			animateOfficer(guards[s],frame,t,math.sin(t*8.4+s)*walking,.93*held,
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
