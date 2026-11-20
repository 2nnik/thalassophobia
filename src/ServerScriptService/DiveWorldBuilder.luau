-- Builds the ship and the contract markers from shared/DiveProtocol.md v1.
-- Lives in ServerScriptService: DiveRuntime requires it from there and calls build(),
-- which parents the world to Workspace. Everything is anchored.
-- Ship-local axes: fore -Z, starboard +X, up +Y, deck at Y=0.
local DiveWorldBuilder = {}

DiveWorldBuilder.ORIGIN = CFrame.new(0, 130, 0)
DiveWorldBuilder.WIDTH = 25
DiveWorldBuilder.LENGTH = 52
DiveWorldBuilder.HEIGHT = 11

local W, L, H = DiveWorldBuilder.WIDTH, DiveWorldBuilder.LENGTH, DiveWorldBuilder.HEIGHT
local WALL = 1

local HULL = Color3.fromRGB(58, 64, 66)
local FLOOR = Color3.fromRGB(40, 42, 44)
local CONSOLE = Color3.fromRGB(30, 34, 36)

-- Rooms fore to stern; z0/z1 are ship-local Z bounds.
local ROOMS = {
	{ id = "Bridge", z0 = -L / 2, z1 = -L / 4 },
	{ id = "Lab", z0 = -L / 4, z1 = 0 },
	{ id = "Machinery", z0 = 0, z1 = L / 4 },
	{ id = "DiveService", z0 = L / 4, z1 = L / 2 },
}

-- Station consoles: ship-local position of the console's centre, and its size.
local STATIONS = {
	Searchlight = { Vector3.new(-5, 2, -L / 2 + 2), Vector3.new(3, 4, 1.5) },
	Sonar = { Vector3.new(0, 2, -L / 2 + 2), Vector3.new(3, 4, 1.5) },
	Camera = { Vector3.new(5, 2, -L / 2 + 2), Vector3.new(3, 4, 1.5) },
	Artifact = { Vector3.new(0, 1.5, -L / 8), Vector3.new(3, 3, 3) },
	Extinguisher = { Vector3.new(-W / 2 + 1.5, 3, -L / 8), Vector3.new(1, 3, 2) },
	Engine = { Vector3.new(0, 2.5, L / 8), Vector3.new(5, 5, 5) },
	RepairPort = { Vector3.new(-W / 2 + 1.5, 3, L / 8), Vector3.new(1, 3, 3) },
	RepairStarboard = { Vector3.new(W / 2 - 1.5, 3, L / 8), Vector3.new(1, 3, 3) },
	RepairKeel = { Vector3.new(6, 0.25, L / 8 + 6), Vector3.new(3, 0.5, 3) },
	RepairStern = { Vector3.new(-6, 3, L / 2 - 1.5), Vector3.new(3, 3, 1) },
	Refill = { Vector3.new(W / 2 - 1.5, 3, L / 2 - 6), Vector3.new(1, 3, 2) },
	Airlock = { Vector3.new(0, 4, L / 2 - 1.5), Vector3.new(5, 8, 1) },
	-- Immediately outside the stern hull, behind the airlock door.
	AirlockExit = { Vector3.new(0, 4, L / 2 + 3), Vector3.new(4, 7, 2) },
}

-- Exterior hull cameras, looking outwards.
local CAMERAS = {
	Fore = { Vector3.new(0, H - 2, -L / 2 - 1), Vector3.new(0, 0, -1) },
	Starboard = { Vector3.new(W / 2 + 1, H - 2, 0), Vector3.new(1, 0, 0) },
	Stern = { Vector3.new(0, H - 2, L / 2 + 1), Vector3.new(0, 0, 1) },
	Port = { Vector3.new(-W / 2 - 1, H - 2, 0), Vector3.new(-1, 0, 0) },
}

-- EVA work sites on the outer hull. Keel sits under the hull, so there is open water below.
local SITES = {
	Port = Vector3.new(-W / 2 - 1.5, H / 2, 6),
	Starboard = Vector3.new(W / 2 + 1.5, H / 2, -6),
	Stern = Vector3.new(8, H / 2, L / 2 + 1.5),
	Keel = Vector3.new(0, -WALL - 2, 4),
}

local function part(parent, name, size, cframe, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Metal
	p.Color = HULL
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Marker parts the server looks up by name; never collide so they don't block paths.
local function marker(parent, name, cframe, size)
	return part(parent, name, size or Vector3.new(1, 1, 1), cframe, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	})
end

local function buildHull(model, o)
	local hull = folder(model, "Hull")
	part(hull, "Floor", Vector3.new(W, WALL, L), o * CFrame.new(0, -WALL / 2, 0), { Color = FLOOR })
	part(hull, "Ceiling", Vector3.new(W, WALL, L), o * CFrame.new(0, H + WALL / 2, 0))
	part(hull, "PortWall", Vector3.new(WALL, H, L), o * CFrame.new(-W / 2 - WALL / 2, H / 2, 0))
	part(hull, "StarboardWall", Vector3.new(WALL, H, L), o * CFrame.new(W / 2 + WALL / 2, H / 2, 0))
	part(hull, "ForeWall", Vector3.new(W + 2 * WALL, H, WALL), o * CFrame.new(0, H / 2, -L / 2 - WALL / 2))

	-- Stern wall with an airlock opening (6 wide, 8 high) that the server's door logic can gate.
	local side = (W - 6) / 2
	part(hull, "SternWallPort", Vector3.new(side + WALL, H, WALL), o * CFrame.new(-3 - (side + WALL) / 2, H / 2, L / 2 + WALL / 2))
	part(hull, "SternWallStarboard", Vector3.new(side + WALL, H, WALL), o * CFrame.new(3 + (side + WALL) / 2, H / 2, L / 2 + WALL / 2))
	part(hull, "SternWallTop", Vector3.new(6, H - 8, WALL), o * CFrame.new(0, 8 + (H - 8) / 2, L / 2 + WALL / 2))

	-- Small viewports so the crew can see the dark outside.
	for _, z in { -L / 2 + 8, -6, 6 } do
		for _, x in { -W / 2 - WALL / 2, W / 2 + WALL / 2 } do
			part(hull, "Porthole", Vector3.new(WALL + 0.2, 2, 2), o * CFrame.new(x, H / 2 + 1, z), {
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(20, 40, 50),
				Transparency = 0.5,
				CanCollide = false,
			})
		end
	end

	-- Searchlight lamp on the bow; the client points it from snapshot bearing/pitch.
	local lamp = part(hull, "SearchlightLamp", Vector3.new(2, 2, 2), o * CFrame.new(0, H - 1, -L / 2 - 2), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(200, 200, 170),
		CanCollide = false,
	})
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 35
	beam.Range = 60
	beam.Brightness = 4
	beam.Enabled = false
	beam.Parent = lamp
end

local function buildRooms(model, o)
	local rooms = folder(model, "Rooms")
	local hull = model:FindFirstChild("Hull")
	for i, room in ROOMS do
		local depth = room.z1 - room.z0
		-- Room volume: the server's Spray uses it to find which room a player is in.
		marker(rooms, room.id, o * CFrame.new(0, H / 2, (room.z0 + room.z1) / 2), Vector3.new(W, H, depth))

		local lamp = part(hull, room.id .. "Lamp", Vector3.new(2, 0.3, 2), o * CFrame.new(0, H - 0.15, (room.z0 + room.z1) / 2), {
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 170, 110),
			CanCollide = false,
		})
		local glow = Instance.new("PointLight")
		glow.Range = 22
		glow.Brightness = 2
		glow.Color = Color3.fromRGB(255, 170, 110)
		glow.Parent = lamp

		-- Bulkhead with a 5-wide door between this room and the next.
		if i < #ROOMS then
			local side = (W - 5) / 2
			part(hull, "Bulkhead", Vector3.new(side, H, 0.5), o * CFrame.new(-W / 2 + side / 2, H / 2, room.z1))
			part(hull, "Bulkhead", Vector3.new(side, H, 0.5), o * CFrame.new(W / 2 - side / 2, H / 2, room.z1))
			part(hull, "Bulkhead", Vector3.new(5, H - 7, 0.5), o * CFrame.new(0, 7 + (H - 7) / 2, room.z1))
		end
	end
end

local function buildMarkers(model, o)
	local stations = folder(model, "Stations")
	for id, def in STATIONS do
		part(stations, id, def[2], o * CFrame.new(def[1]), {
			Color = CONSOLE,
			Material = Enum.Material.DiamondPlate,
			CanCollide = id ~= "AirlockExit" and id ~= "RepairKeel",
		})
	end
	stations.AirlockExit.Transparency = 1

	local cameras = folder(model, "Cameras")
	for id, def in CAMERAS do
		local pos = o * def[1]
		part(cameras, id, Vector3.new(1, 1, 1.5), CFrame.lookAt(pos, pos + o:VectorToWorldSpace(def[2])), {
			Color = CONSOLE,
			CanCollide = false,
		})
	end

	local sites = folder(model, "Sites")
	for id, pos in SITES do
		marker(sites, id, o * CFrame.new(pos), Vector3.new(4, 4, 4))
	end

	marker(model, "SpawnCrew", o * CFrame.new(6, 0.5, -4), Vector3.new(4, 1, 4))
end

-- Lobby dock above the dive site, well away from the ship.
local function buildLobby(model, o)
	local lobby = folder(model, "Lobby")
	local dock = o * CFrame.new(0, 60, -L / 2 - 60)
	part(lobby, "Dock", Vector3.new(40, 1, 40), dock, { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(90, 70, 50) })
	marker(model, "SpawnLobby", dock * CFrame.new(0, 1, 0), Vector3.new(6, 1, 6))
end

function DiveWorldBuilder.build(): Model
	local model = Instance.new("Model")
	model.Name = "DiveWorld"
	local o = DiveWorldBuilder.ORIGIN

	local origin = marker(model, "ShipOrigin", o)
	model.PrimaryPart = origin

	buildHull(model, o)
	buildRooms(model, o)
	buildMarkers(model, o)
	buildLobby(model, o)
	-- DiveRuntime expects build() to parent the world, like DiveFixture does.
	model.Parent = workspace
	return model
end

-- Self-check: every contract name exists. Returns a list of missing paths (empty = ok).
function DiveWorldBuilder.check(model: Model): { string }
	local missing = {}
	local required = {
		Stations = { "Engine", "Searchlight", "Sonar", "Camera", "RepairPort", "RepairStarboard", "RepairStern", "RepairKeel", "Extinguisher", "Refill", "Airlock", "Artifact", "AirlockExit" },
		Cameras = { "Fore", "Starboard", "Stern", "Port" },
		Sites = { "Port", "Starboard", "Stern", "Keel" },
		Rooms = { "Bridge", "Machinery", "Lab", "DiveService" },
	}
	for folderName, names in required do
		for _, name in names do
			local f = model:FindFirstChild(folderName)
			if not (f and f:FindFirstChild(name) and f[name]:IsA("BasePart")) then
				table.insert(missing, folderName .. "." .. name)
			end
		end
	end
	for _, name in { "ShipOrigin", "SpawnLobby", "SpawnCrew" } do
		if not model:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	return missing
end

return DiveWorldBuilder
