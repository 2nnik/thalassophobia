-- Dark silhouette models for actors. The client creates them locally and moves them to
-- snapshot poses; nothing here replicates. Root part is at the model's pivot, facing -Z.
-- shortcut: primitive-part silhouettes; swap for meshes once art exists.
local DiveCreatures = {}

local DARK = Color3.fromRGB(14, 16, 18)
local BELLY = Color3.fromRGB(26, 30, 30)

local function part(model, size, offset, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = DARK
	p.Size = size
	p.CFrame = offset
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local function glow(p, color, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = p
end

local builders = {}

-- Big hunter that follows engine noise.
function builders.Angler(model)
	part(model, Vector3.new(14, 12, 24), CFrame.new(0, 0, 0), { Shape = Enum.PartType.Ball })
	part(model, Vector3.new(13, 3, 10), CFrame.new(0, -4, -10) * CFrame.Angles(math.rad(-15), 0, 0), { Color = BELLY })
	part(model, Vector3.new(1, 10, 6), CFrame.new(0, 2, 14) * CFrame.Angles(math.rad(20), 0, 0))
	for _, x in { -4, 4 } do
		part(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(x, 3, -10), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(120, 140, 110),
		})
	end
	part(model, Vector3.new(0.4, 0.4, 9), CFrame.new(0, 8, -12) * CFrame.Angles(math.rad(30), 0, 0))
	local lure = part(model, Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 10, -17), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(160, 255, 220),
	})
	glow(lure, Color3.fromRGB(120, 255, 210), 14)
end

-- Huge squid; mantle trails behind the tentacles, which reach toward -Z.
function builders.Squid(model)
	part(model, Vector3.new(10, 10, 26), CFrame.new(0, 0, 12), { Shape = Enum.PartType.Ball })
	part(model, Vector3.new(14, 2, 6), CFrame.new(0, 0, 24))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, y = math.cos(a) * 3, math.sin(a) * 3
		part(model, Vector3.new(1, 1, 22), CFrame.new(x, y, -10) * CFrame.Angles(-y * 0.04, x * 0.04, 0))
	end
	for _, x in { -5, 5 } do
		part(model, Vector3.new(3, 3, 3), CFrame.new(x, 1, 0), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(90, 80, 40),
		})
	end
end

-- Boarder small enough to fit inside a room.
function builders.Crawler(model)
	part(model, Vector3.new(3, 1.2, 4), CFrame.new(0, 0, 0))
	part(model, Vector3.new(2, 1, 1.5), CFrame.new(0, 0.2, -2.5), { Color = BELLY })
	for _, z in { -1.2, 0, 1.2 } do
		for _, x in { -1, 1 } do
			part(model, Vector3.new(2.5, 0.3, 0.3), CFrame.new(x * 2, -0.4, z) * CFrame.Angles(0, 0, x * math.rad(-30)))
		end
	end
	for _, x in { -0.5, 0.5 } do
		part(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(x, 0.5, -3.2), {
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 60, 40),
		})
	end
end

-- Ascent-only eel; a long segmented shadow.
function builders.Pursuer(model)
	for i = 0, 9 do
		local s = 6 - i * 0.45
		part(model, Vector3.new(s, s, 7), CFrame.new(math.sin(i * 0.7) * 1.5, 0, i * 6.5))
	end
	part(model, Vector3.new(7, 3, 6), CFrame.new(0, -2.5, -3), { Color = BELLY })
	for _, x in { -2, 2 } do
		part(model, Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, 1.8, -2.5), {
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 30, 30),
		})
	end
end

-- Barnacle colony on a hull site.
local function colony(model)
	local rng = Random.new(7)
	for _ = 1, 14 do
		part(model, Vector3.one * rng:NextNumber(0.6, 1.6), CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(50, 56, 40),
			Material = Enum.Material.Slate,
		})
	end
end

-- Returns a Model for an actor ID (Angler, Squid, Crawler, Pursuer) or a colony site ID.
function DiveCreatures.make(actorId: string): Model
	local model = Instance.new("Model")
	model.Name = actorId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.one
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	;(builders[actorId] or colony)(model)
	return model
end

return DiveCreatures
