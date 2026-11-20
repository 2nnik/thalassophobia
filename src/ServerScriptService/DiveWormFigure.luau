-- Woven silhouette for the existing crawler contact. Forward is local -Z.
local WormFigure = {}
local V = Vector3.new
local TAU = 2 * math.pi

local tones = {
	Color3.fromRGB(86, 59, 55),
	Color3.fromRGB(104, 71, 65),
	Color3.fromRGB(120, 80, 69),
	Color3.fromRGB(89, 62, 67),
	Color3.fromRGB(112, 84, 68),
	Color3.fromRGB(69, 52, 57),
}
local seam = Color3.fromRGB(47, 33, 34)

local function curve(a, b, c, d, t)
	local tt = t * t
	return .5 * ((2 * b) + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * tt
		+ (3 * b - a - 3 * c + d) * tt * t)
end

local function sample(points, fraction)
	local scaled = fraction * (#points - 1)
	local i = math.min(math.floor(scaled) + 1, #points - 1)
	return curve(points[math.max(i - 1, 1)], points[i], points[i + 1],
		points[math.min(i + 2, #points)], scaled - i + 1)
end

function WormFigure.build(model)
	if model:FindFirstChild("WormFigure") then return model end
	local root = assert(model.PrimaryPart, "Crawler requires its existing PrimaryPart")
	local origin = root.CFrame
	local figure = Instance.new("Folder")
	figure.Name = "WormFigure"

	local function part(name, pose, size, color, visible)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, origin * pose
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.Material, p.Color, p.Reflectance = Enum.Material.SmoothPlastic, color, .045
		p.Transparency, p.CastShadow = visible and 0 or 1, visible
		p.Parent = figure
		return p
	end

	local function joint(name, parent, position, axis, amount, phase)
		local child = part(name .. " root", CFrame.new(position), V(.12,.12,.12), seam, false)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0, motor.Part1 = parent, child
		motor.C0 = parent.CFrame:ToObjectSpace(child.CFrame)
		motor:SetAttribute("Axis", axis)
		motor:SetAttribute("Amplitude", amount)
		motor:SetAttribute("Phase", phase)
		motor.Parent = child
		return child
	end

	local function oval(name, bone, position, facing, width, length, tint)
		local p = part(name, CFrame.lookAt(position, position + facing), V(width,width,length), tint, true)
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Parent = p
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = bone, p
		weld.Parent = p
	end

	local serial = 0
	local function strand(bone, points, segments, width, variation)
		serial += 1
		local baseColor = tones[(serial - 1) % #tones + 1]
		for i = 1, segments do
			local u = (i - .5) / segments
			local a, b = sample(points, (i - 1) / segments), sample(points, i / segments)
			local span = b - a
			if span.Magnitude < .025 then continue end
			local thickness = width * (.78 + .21 * math.sin(u * math.pi)) * (1 + .09 * math.sin(i + serial))
			if variation then thickness *= 1 - .62 * u^3 end
			local tint = baseColor:Lerp(seam, (1 + math.sin(i * 1.8 + serial)) * .12)
			oval("Worm body", bone, (a + b) / 2, span, thickness, span.Magnitude + thickness * .77, tint)
			if width > .27 and i % 3 == 2 then
				oval("Annular ridge", bone, (a + b) / 2, span, thickness * 1.025, thickness * .22, tint:Lerp(seam,.47))
			end
		end
	end

	local function coil(bone, from, to, across, depth, turns, phase, pieces, width)
		local points = table.create(9)
		for i = 0, 8 do
			local u = i / 8
			local angle = phase + turns * TAU * u
			local offset = V(math.cos(angle)*across,0,math.sin(angle)*depth)
			points[i+1] = from:Lerp(to,u) + offset
		end
		strand(bone, points, pieces, width)
	end

	local chest = joint("Shoulder mass", root, V(0,.75,0), Vector3.yAxis,.19,.9)
	local skull = joint("Head bundle", chest, V(.08,2.39,-.12), Vector3.zAxis,.23,1.5)

	-- Interleaved worms across the ribs and shoulders. Their curves overlap
	-- irregularly so the silhouette reads as a mass of bodies and open seams.
	for i = 0, 8 do
		local angle = i * TAU / 9
		local x, z = math.cos(angle), math.sin(angle)
		strand(chest, {
			V(.99*x,-1.05,.50*z), V(.71*x,-.32,.61*z - .07),
			V(1.00*math.cos(angle+.34),.67,.68*math.sin(angle+.34)),
			V(1.36*math.cos(angle+.71),1.59,.58*math.sin(angle+.71)),
			V(.36*math.cos(angle+1.1),2.27,.39*math.sin(angle+1.1) - .09),
		}, 9, .31 + .033 * (i%3))
	end
	for i = 0, 5 do
		local side = i%2 == 0 and 1 or -1
		local rise = i * .26
		strand(chest, {
			V(-1.15*side,1.93-rise,.11), V(-.71*side,1.58-rise,-.63),
			V(.15*side,1.32-rise,-.71), V(.86*side,1.03-rise,-.37), V(.92*side,.52-rise,.19),
		}, 7,.29,true)
	end

	-- The head is a knot of worms, with two holes between the coils.
	for i = 0, 6 do
		local t = i / 6
		local w = .44 + .32 * math.sin(t * math.pi)
		local y = 2.44 + t * 1.11
		strand(skull, {
			V(-w,y,.13), V(-w*.77,y+.15,-.53), V(.08,y+.04,-.71),
			V(w*.79,y-.12,-.48), V(w,y+.05,.14), V(.04,y+.13,.56), V(-w*.82,y+.24,.32),
		}, 9, .24 + .018 * (i%3))
	end
	for _, side in {-1,1} do
		strand(skull, {
			V(.11*side,3.58,-.04), V(.44*side,3.34,-.56), V(.62*side,3.04,-.67),
			V(.33*side,2.77,-.60), V(.52*side,2.47,-.38), V(.92*side,2.10,-.32),
		}, 8,.19,true)
	end

	for _, side in {-1,1} do
		local swing = if side == 1 then .49 else .67
		local arm = joint("Grasping shoulder " .. side, chest, V(1.15*side,1.63,-.02), Vector3.xAxis,swing,2.8+side)
		local elbow = V(1.87*side,.49,-.57)
		local forearm = joint("Grasping elbow " .. side, arm, elbow, Vector3.yAxis,.26,3.7+side)
		local hand = V(2.08*side,.28,-1.73 - side*.19)
		for i = 0, 2 do
			local lateral, phase = (i - 1)*.22, i * TAU / 3
			coil(arm,V((1.10+lateral)*side,1.71,.05),elbow+V(lateral,0,0),.20,.22,1.08,phase,8,.245)
			coil(forearm,elbow+V(lateral,0,.06),hand+V(lateral,.04,0),.15,.12,1.02,phase+.48,8,.21)
		end
		for i = 1, 4 do
			local x = (i - 2.5) * .18
			strand(forearm, {
				hand+V(x,.17,.16), hand+V(x*1.16,.14,-.32),
				hand+V(x*1.67,-.14,-.61-i%2*.15), hand+V(x*1.78,-.42,-.53),
			}, 5,.17,true)
		end
		strand(forearm,{
			hand+V(-side*.16,.14,.28), hand+V(-side*.47,.17,.06), hand+V(-side*.53,-.03,-.27),
		}, 4,.19,true)

		local hip = V(.61*side,-.88,.08)
		local knee = V(.69*side,-1.86,-.13+side*.16)
		local leg = joint("Hip bundle " .. side, root, hip, Vector3.xAxis,.31,side*1.6)
		local calf = joint("Knee bundle " .. side, leg, knee, Vector3.xAxis,.23,1.4+side*1.6)
		local ankle = V(.81*side,-3.29,.18+side*.17)
		for i = 0, 3 do
			local angle = i * TAU / 4
			coil(leg,hip+V(math.cos(angle)*.14,0,0),knee,.29,.28,1.03,angle,7,.24)
			coil(calf,knee,ankle,.21,.25,.94,angle+.38,8,.23)
		end
		for i = 1, 3 do
			local offset = (i-2) * .19
			strand(calf,{
				ankle+V(offset,.14,.15), ankle+V(offset,-.16,-.28),
				ankle+V(offset*1.32,-.25,-.73), ankle+V(offset*1.49,-.13,-.91-i%2*.22),
			}, 5,.21,true)
		end
	end

	-- Clear just the old runtime geometry. The root, model identity and
	-- attributes stay in place for perception, beams and station scripts.
	for _, child in model:GetChildren() do
		if child ~= root then child:Destroy() end
	end
	for _, child in root:GetChildren() do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") then child:Destroy() end
	end
	figure.Parent = model
	return model
end

return WormFigure
