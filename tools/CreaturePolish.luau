-- Optional appearance pass for the authored Contacts rigs. Run only in Studio Edit.
-- apply(Contacts) can be repeated; restore(Contacts) restores the first-run materials and lighting.
local CreaturePolish = {}
local rgb = Color3.fromRGB
local skin = Enum.Material.Slate
local tissue = Enum.Material.SmoothPlastic
local glow = Enum.Material.Neon
local patchTag = "ThalassaPolishAdded"
local originals = {
	Color = "ThalassaPolishOriginalColor",
	Material = "ThalassaPolishOriginalMaterial",
	Brightness = "ThalassaPolishOriginalBrightness",
	Range = "ThalassaPolishOriginalRange",
	Shape = "ThalassaPolishOriginalShape",
	Size = "ThalassaPolishOriginalSize",
}

local function palette(groups)
	local styles = {}
	for _, group in groups do
		for _, name in group[3] do styles[name] = {group[1], group[2]} end
	end
	return styles
end

local anglerStyle = palette({
	{rgb(57, 76, 87), skin, {"Arched cranium", "Bulbous abdomen", "Caudal peduncle", "Tail keel"}},
	{rgb(76, 94, 103), skin, {"Bony orbital boss", "Operculum", "Gill pleat"}},
	{rgb(37, 53, 69), tissue, {"Crest membrane", "Pectoral fan", "Caudal web", "Pectoral ray", "Fin leading ray", "Illicium"}},
	{rgb(78, 103, 112), skin, {"Gular sac", "Countershaded belly"}},
	{rgb(57, 37, 53), tissue, {"Plicate jaw rim", "Tongue pad"}},
	{rgb(24, 18, 30), tissue, {"Black throat", "Pharynx", "Soft palate"}},
	{rgb(202, 184, 144), tissue, {"Curved glass fang"}},
	{rgb(136, 124, 105), tissue, {"Inner tooth"}},
	{rgb(145, 88, 57), tissue, {"Amber iris"}},
	{rgb(23, 29, 39), tissue, {"Lucent pupil"}},
	{rgb(115, 155, 162), tissue, {"Eyeshine"}},
	{rgb(130, 208, 232), glow, {"Bioluminescent esca"}},
	{rgb(73, 142, 168), tissue, {"Lateral photophore"}},
})

local squidStyle = palette({
	{rgb(59, 75, 74), skin, {"Muscular mantle", "Mantle apex", "Tapered apex", "Mantle collar", "Cephalic lobe", "Eye capsule"}},
	{rgb(72, 88, 80), skin, {"Ventral mantle", "Brachial crown"}},
	{rgb(88, 102, 82), skin, {"Mantle chromatophore"}},
	{rgb(45, 58, 64), tissue, {"Rhomboid fin", "Terminal fin sail", "Fin leading rim"}},
	{rgb(127, 92, 68), skin, {"Prehensile arm", "Tentacular stalk"}},
	{rgb(146, 101, 68), skin, {"Tentacular club", "Funnel siphon"}},
	{rgb(182, 136, 84), tissue, {"Sucker rim", "Club sucker"}},
	{rgb(46, 36, 32), tissue, {"Siphon aperture", "Pallial opening"}},
	{rgb(203, 146, 64), tissue, {"Opal iris"}},
	{rgb(25, 27, 29), tissue, {"Sable pupil"}},
	{rgb(237, 176, 88), glow, {"Corneal gleam"}},
})

local function targets(contacts)
	assert(typeof(contacts) == "Instance", "Pass workspace.Thalassa.Contacts")
	local angler = contacts:FindFirstChild("Leviathan")
	local squid = contacts:FindFirstChild("GiantSquid")
	assert(angler and angler:IsA("Model") and angler.PrimaryPart, "Leviathan rig is missing")
	assert(squid and squid:IsA("Model") and squid.PrimaryPart, "GiantSquid rig is missing")
	return angler, squid
end

local function recolor(part, style)
	if part:GetAttribute(originals.Color) == nil then
		part:SetAttribute(originals.Color, part.Color)
		part:SetAttribute(originals.Material, part.Material.Name)
	end
	part.Color, part.Material = style[1], style[2]
end

local eyeScale = {
	["Bony orbital boss"] = Vector3.new(.88,.70,.94),
	["Amber iris"] = Vector3.new(.63,.57,1),
	["Lucent pupil"] = Vector3.new(.61,.54,1),
	["Eyeshine"] = Vector3.new(.46,.46,.65),
}

local function toneLight(light, color, brightness, range)
	if light:GetAttribute(originals.Color) == nil then
		for _, field in {"Color", "Brightness", "Range"} do
			light:SetAttribute(originals[field], light[field])
		end
	end
	light.Color, light.Brightness, light.Range = color, brightness, range
end

local function attachedBall(base, name, size, pose, color, material)
	local detail = Instance.new("Part")
	detail.Name = name
	detail.Shape = Enum.PartType.Ball
	detail.Size, detail.CFrame = size, pose
	detail.Color, detail.Material = color, material
	detail.CanCollide, detail.CanTouch, detail.CanQuery = false, false, false
	detail.CastShadow, detail.Massless = false, true
	detail:SetAttribute(patchTag, true)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = base, detail, detail
	detail.Parent = base
	return detail
end

local function lureTendrils(head)
	if head:FindFirstChild("Auxiliary esca -1") then return 0 end
	local scale = head.Size.X / 50.4
	local total = 0
	for _, side in {-1, 1} do
		local drop = if side == -1 then 4 else 8
		local points = {
			Vector3.new(side * 11, 6, -7), Vector3.new(side * 15, 11, -10),
			Vector3.new(side * 20, 11, -15), Vector3.new(side * 23, 7, -22),
			Vector3.new(side * 23, 2 - drop, -26),
		}
		for i = 1, #points - 1 do
			local from = head.CFrame:PointToWorldSpace(points[i] * scale)
			local to = head.CFrame:PointToWorldSpace(points[i+1] * scale)
			local width = (1.6 - i * .22) * scale
			attachedBall(head, "Auxiliary lure stalk", Vector3.new(width, width, (from-to).Magnitude * 1.25),
				CFrame.lookAt((from+to)/2, to), rgb(53, 80, 99), tissue)
			total += 1
		end
		local size = (if side == -1 then 1.9 else 2.4) * scale
		attachedBall(head, "Auxiliary esca "..side, Vector3.new(size * .78, size, size * .78),
			head.CFrame * CFrame.new(points[#points] * scale), rgb(113, 195, 227), glow)
		total += 1
	end
	return total
end

local function cupCenters(squid)
	local arms, cups = {}, {}
	for _, part in squid:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "Prehensile arm" or part.Name == "Tentacular club" then
				table.insert(arms, part)
			elseif part.Name == "Club sucker" or (part.Name == "Sucker rim" and part.Size.Magnitude > 1.35) then
				table.insert(cups, part)
			end
		end
	end
	local added = 0
	for _, cup in cups do
		if cup:FindFirstChild("Sucker well") then continue end
		local best, bestDistance
		for _, arm in arms do
			local localPosition = arm.CFrame:PointToObjectSpace(cup.Position)
			local nearest = arm.CFrame:PointToWorldSpace(Vector3.new(0, 0, math.clamp(localPosition.Z, -arm.Size.Z/2, arm.Size.Z/2)))
			local distance = (cup.Position - nearest).Magnitude
			if distance > .001 and (not bestDistance or distance < bestDistance) then
				best, bestDistance = nearest, distance
			end
		end
		if best then
			local normal = (cup.Position - best).Unit
			local localNormal = cup.CFrame:VectorToObjectSpace(normal)
			local radii = cup.Size / 2
			local depth = 1 / (localNormal / radii).Magnitude
			local diameter = math.min(cup.Size.X, cup.Size.Y, cup.Size.Z)
			local center = cup.Position + normal * depth * .98
			attachedBall(cup, "Sucker well", Vector3.new(diameter * .59, diameter * .59, diameter * .19),
				CFrame.lookAt(center, center + normal), rgb(71, 42, 31), tissue)
			added += 1
		end
	end
	return added
end

function CreaturePolish.apply(contacts)
	local angler, squid = targets(contacts)
	local result = {}
	for _, set in {{angler, anglerStyle}, {squid, squidStyle}} do
		local model, style = set[1], set[2]
		local changed, lights, ellipsoids = 0, 0, 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and style[part.Name] then
				recolor(part, style[part.Name])
				changed += 1
				local factor = model == angler and eyeScale[part.Name]
				if factor then
					local original = part:GetAttribute(originals.Size) or part.Size
					part:SetAttribute(originals.Size, original)
					part.Size = original * factor
				end
				-- Native Ball parts render rounded to a sphere. Keep the authored
				-- sizes and welds, and use an ellipsoid surface for elongated anatomy.
				if part:IsA("Part") and part.Shape == Enum.PartType.Ball
					and not part:FindFirstChildOfClass("DataModelMesh") and not part.CanCollide then
					local s = part.Size
					if math.max(s.X,s.Y,s.Z) > 1.2 * math.min(s.X,s.Y,s.Z) then
						part:SetAttribute(originals.Shape, part.Shape.Name)
						part.Shape = Enum.PartType.Block
						local mesh = Instance.new("SpecialMesh")
						mesh.MeshType = Enum.MeshType.Sphere
						mesh:SetAttribute(patchTag,true)
						mesh.Parent = part
						ellipsoids += 1
					end
				end
			elseif part:IsA("PointLight") and part.Name == "Reflected water light" then
				toneLight(part, rgb(91, 146, 170), .78, 42)
				lights += 1
			elseif part:IsA("PointLight") and part.Parent.Name == "Bioluminescent esca" then
				toneLight(part, rgb(113, 194, 236), 2.05, 21)
				lights += 1
			end
		end
		result[model.Name] = {recolored = changed, lights = lights, added = 0, ellipsoids = ellipsoids}
	end
	local head = angler:FindFirstChild("Arched cranium")
	if head and head:IsA("BasePart") then result.Leviathan.added = lureTendrils(head) end
	result.GiantSquid.added = cupCenters(squid)
	return result
end

function CreaturePolish.restore(contacts)
	local angler, squid = targets(contacts)
	for _, model in {angler, squid} do
		local additions = {}
		for _, part in model:GetDescendants() do
			if part:GetAttribute(patchTag) == true then
				table.insert(additions, part)
			else
				for field, attribute in originals do
					local value = part:GetAttribute(attribute)
					if value ~= nil then
						part[field] = if field == "Material" then Enum.Material[value]
							elseif field == "Shape" then Enum.PartType[value] else value
						part:SetAttribute(attribute, nil)
					end
				end
			end
		end
		for _, part in additions do part:Destroy() end
	end
end

return CreaturePolish
