-- Builds the cage procedurally so the prototype needs no hand-made map. Replace with a real model later:
-- the controller only needs zones (Zone_<Section> parts), prompts (with Kind/Id attributes) and a light part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage.Shared.Config)

local CageBuilder = {}

local ORIGIN = Vector3.new(0, 300, 0)
local LEN, WIDTH, HEIGHT = 9, 12, 9 -- per section
local FLOOR_Y = -HEIGHT / 2

local function make(parent, name, size, cf, color, extra)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.Color = color or Color3.fromRGB(60, 62, 66)
	p.Material = Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(extra or {}) do p[k] = v end
	p.Parent = parent
	return p
end

local function prompt(part, kind, text, hold, id)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText, pp.ObjectText = text, ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 9
	pp.RequiresLineOfSight = false
	pp:SetAttribute("Kind", kind)
	if id then pp:SetAttribute("Id", id) end
	pp.Parent = part
	return pp
end

function CageBuilder.sectionCenter(section)
	for i, name in ipairs(Config.Sections) do
		if name == section then
			return ORIGIN + Vector3.new(0, 0, -18 + (i - 1) * LEN + LEN / 2)
		end
	end
end

local function atmosphere()
	Lighting.Ambient = Color3.fromRGB(8, 12, 18)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 12, 18)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogColor = Color3.fromRGB(2, 8, 12)
	Lighting.FogStart, Lighting.FogEnd = 5, 160
	local a = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	a.Density, a.Color, a.Parent = 0.55, Color3.fromRGB(10, 30, 40), Lighting
end

-- Returns { model, zones, prompts, lightPart, claw, ledge, airlockCFrame, addCrack(id, section), removeCrack(id) }
function CageBuilder.build()
	atmosphere()
	local old = Workspace:FindFirstChild("Cage")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "Cage"
	local cage = { model = model, zones = {}, cracks = {}, prompts = {} }

	make(model, "Floor", Vector3.new(WIDTH, 1, LEN * 4), CFrame.new(ORIGIN + Vector3.new(0, FLOOR_Y - 0.5, 0)))
	make(model, "Roof", Vector3.new(WIDTH, 1, LEN * 4), CFrame.new(ORIGIN + Vector3.new(0, HEIGHT / 2 + 0.5, 0)))
	-- vertical bars on both sides, every 3 studs
	for zi = 0, 12 do
		for _, x in ipairs({ -WIDTH / 2, WIDTH / 2 }) do
			make(model, "Bar", Vector3.new(0.4, HEIGHT, 0.4),
				CFrame.new(ORIGIN + Vector3.new(x, 0, -18 + zi * 3)), Color3.fromRGB(40, 42, 46))
		end
	end
	for _, z in ipairs({ -18, 18 }) do -- end walls
		make(model, "EndWall", Vector3.new(WIDTH, HEIGHT, 0.6), CFrame.new(ORIGIN + Vector3.new(0, 0, z)))
	end

	for _, name in ipairs(Config.Sections) do
		local c = CageBuilder.sectionCenter(name)
		cage.zones[name] = make(model, "Zone_" .. name, Vector3.new(WIDTH, HEIGHT + 4, LEN), CFrame.new(c),
			nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local lamp = make(model, "Lamp_" .. name, Vector3.new(1, 0.3, 1), CFrame.new(c + Vector3.new(0, HEIGHT / 2 - 0.3, 0)),
			Color3.fromRGB(90, 40, 30), { Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Brightness, light.Range, light.Color = 0.7, 14, Color3.fromRGB(255, 120, 90)
		light.Parent = lamp
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored, spawn.Neutral, spawn.Transparency, spawn.CanCollide = true, true, 1, false
	spawn.Size, spawn.Duration = Vector3.new(6, 1, 6), 0
	spawn.CFrame = CFrame.new(CageBuilder.sectionCenter("Midship") + Vector3.new(0, FLOOR_Y + 0.5, 0))
	spawn.Parent = model

	-- Stern: engine switch + extinguisher refill
	local sternC = CageBuilder.sectionCenter("Stern")
	local engine = make(model, "Engine", Vector3.new(2, 3, 2), CFrame.new(sternC + Vector3.new(-4, FLOOR_Y + 1.5, 0)),
		Color3.fromRGB(150, 60, 40))
	cage.prompts.Engine = prompt(engine, "Engine", "Toggle engine", 0)
	local refill = make(model, "Refill", Vector3.new(2, 3, 2), CFrame.new(sternC + Vector3.new(4, FLOOR_Y + 1.5, 0)),
		Color3.fromRGB(40, 110, 150))
	cage.prompts.Refill = prompt(refill, "Refill", "Refill extinguisher (hold)", 1)

	-- Bow: light console + claw
	local bowC = CageBuilder.sectionCenter("Bow")
	local console = make(model, "LightConsole", Vector3.new(3, 3, 1.5), CFrame.new(bowC + Vector3.new(-3, FLOOR_Y + 1.5, -2)),
		Color3.fromRGB(200, 190, 90))
	cage.prompts.Light = prompt(console, "Light", "Toggle light (aim with camera)", 0)
	local claw = make(model, "Claw", Vector3.new(3, 3, 1.5), CFrame.new(bowC + Vector3.new(3, FLOOR_Y + 1.5, -2)),
		Color3.fromRGB(90, 200, 120))
	cage.prompts.Claw = prompt(claw, "Claw", "Grab artifact", 0)
	cage.prompts.Claw.Enabled = false

	cage.lightPart = make(model, "Spotlight", Vector3.new(1, 1, 1), CFrame.new(bowC + Vector3.new(0, 1, -4)),
		Color3.fromRGB(255, 255, 220), { Material = Enum.Material.Neon, CanCollide = false })
	local spot = Instance.new("SpotLight")
	spot.Face, spot.Range, spot.Angle, spot.Brightness, spot.Enabled = Enum.NormalId.Front, 140, 50, 8, false
	spot.Parent = cage.lightPart
	cage.spot = spot

	-- Extinguishers on the wall mounts
	for i, section in ipairs(Config.Extinguisher.Sections) do
		local c = CageBuilder.sectionCenter(section)
		local ext = make(model, "Extinguisher" .. i, Vector3.new(1, 2.5, 1),
			CFrame.new(c + Vector3.new(WIDTH / 2 - 1, FLOOR_Y + 3, 3)), Color3.fromRGB(190, 30, 30))
		prompt(ext, "Ext", "Take extinguisher", 0, i)
	end

	-- Airlock: hatch out, with a ledge outside for the diver
	local airC = CageBuilder.sectionCenter("Airlock")
	local hatch = make(model, "Hatch", Vector3.new(4, 6, 0.5), CFrame.new(airC + Vector3.new(0, FLOOR_Y + 3, LEN / 2 - 0.5)),
		Color3.fromRGB(110, 110, 120))
	prompt(hatch, "HatchOut", "Exit cage", 0)
	cage.ledge = make(model, "Ledge", Vector3.new(10, 1, 8), CFrame.new(airC + Vector3.new(0, FLOOR_Y - 0.5, LEN / 2 + 4.5)))
	local back = make(model, "HatchBack", Vector3.new(3, 3, 0.5), CFrame.new(airC + Vector3.new(0, FLOOR_Y + 2, LEN / 2 + 1)),
		Color3.fromRGB(110, 110, 120))
	prompt(back, "HatchIn", "Enter cage", 0)
	cage.ledgeCFrame = CFrame.new(airC + Vector3.new(0, FLOOR_Y + 3.5, LEN / 2 + 5))
	cage.airlockCFrame = CFrame.new(airC + Vector3.new(0, FLOOR_Y + 3.5, 0))

	model.PrimaryPart = cage.zones.Midship
	model.Parent = Workspace

	function cage.sectionOf(position)
		for name, zone in pairs(cage.zones) do
			local rel = zone.CFrame:PointToObjectSpace(position)
			local s = zone.Size
			if math.abs(rel.X) <= s.X / 2 and math.abs(rel.Y) <= s.Y / 2 and math.abs(rel.Z) <= s.Z / 2 then
				return name
			end
		end
		return nil
	end

	function cage.addCrack(id, section)
		local c = CageBuilder.sectionCenter(section)
		local side = (id % 2 == 0) and 1 or -1
		local z = (math.random() - 0.5) * (LEN - 2)
		local part = make(model, "Crack" .. id, Vector3.new(0.3, 3, 1.4),
			CFrame.new(c + Vector3.new(side * (WIDTH / 2 - 0.2), FLOOR_Y + 3, z)), Color3.fromRGB(20, 120, 160),
			{ Material = Enum.Material.Neon, CanCollide = false })
		prompt(part, "Repair", "Repair crack (hold)", Config.Cracks.RepairTime, id)
		cage.cracks[id] = part
	end

	function cage.removeCrack(id)
		if cage.cracks[id] then cage.cracks[id]:Destroy() end
		cage.cracks[id] = nil
	end

	return cage
end

return CageBuilder
