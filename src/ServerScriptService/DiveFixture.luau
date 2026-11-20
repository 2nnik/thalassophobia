-- Integration fixture. A delivered DiveWorld or an installed scene builder takes precedence.
local Fixture = {}

function Fixture.build()
	local world = Instance.new("Model")
	world.Name = "DiveWorld"
	local origin = CFrame.new(0, 130, 0)
	local steel = Color3.fromRGB(40, 62, 68)
	local brass = Color3.fromRGB(172, 134, 76)
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name, f.Parent = name, world
		return f
	end
	local function part(parent, name, size, pos, color, solid)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Size = name, true, size
		p.CFrame = origin * CFrame.new(pos)
		p.Material, p.Color = Enum.Material.Metal, color or steel
		p.CanCollide, p.Parent = solid ~= false, parent
		return p
	end
	local function marker(parent, name, pos, look)
		local p = part(parent, name, Vector3.one, pos, nil, false)
		p.Transparency, p.CanQuery = 1, false
		if look then p.CFrame = CFrame.lookAt(p.Position,p.Position+look) end
		return p
	end
	local function sign(p, label)
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(150,24),Vector3.new(0,1.7,0),24
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.Size,t.BackgroundTransparency,t.Text,t.Font,t.TextSize,t.TextColor3 = UDim2.fromScale(1,1),1,label,Enum.Font.GothamMedium,14,Color3.fromRGB(195,236,221)
		t.Parent = gui
	end
	local v = Vector3.new
	local rooms, stations, sites, cams = folder("Rooms"),folder("Stations"),folder("Sites"),folder("Cameras")
	marker(world,"ShipOrigin",Vector3.zero)
	marker(world,"SpawnCrew",v(0,4,-17))
	marker(world,"SpawnLobby",v(0,5,-64))
	part(world,"Dock",v(38,1,32),v(0,0,-64))
	for i,id in ipairs({"Bridge","Lab","Machinery","DiveService"}) do
		local z = (i-2.5)*13
		local deck = part(rooms,id,v(25,1,13),v(0,-0.5,z))
		sign(deck,id)
		part(rooms,id.."Ceiling",v(25,1,13),v(0,10,z))
		for _,x in ipairs({-12.5,12.5}) do
			part(rooms,"Sill",v(1,2,13),v(x,1,z))
			local glass=part(rooms,"Viewport",v(0.4,6,12),v(x,5,z))
			glass.Material,glass.Transparency = Enum.Material.Glass,0.72
			part(rooms,"Frame",v(1,2,13),v(x,9,z))
		end
		if i<4 then
			for _,x in ipairs({-8.5,8.5}) do part(rooms,"Bulkhead",v(8,9,0.6),v(x,4.5,z+6.5)) end
		end
		local lamp=part(rooms,"CabinLamp",v(4,.2,1),v(0,9.4,z),Color3.fromRGB(154,221,203),false)
		lamp.Material=Enum.Material.Neon
		local light=Instance.new("PointLight")
		light.Range,light.Brightness,light.Color,light.Parent=18,1.2,lamp.Color,lamp
	end
	for _,z in ipairs({-26,26}) do
		local glass=part(rooms,"PressureGlass",v(25,10,.6),v(0,5,z))
		glass.Material,glass.Transparency=Enum.Material.Glass,.7
	end
	local positions={Engine=v(-6,1,7),Searchlight=v(7,1,-22),Sonar=v(-7,1,-22),Camera=v(0,1,-23),Artifact=v(-5,1,-7),Airlock=v(7,1,20),
		Extinguisher=v(6,1,5),Refill=v(-6,1,20),RepairPort=v(-10,1,0),RepairStarboard=v(10,1,-5),RepairStern=v(0,1,23),RepairKeel=v(-7,1,3)}
	for id,pos in pairs(positions) do
		local p=part(stations,id,v(2,2,1.6),pos,brass)
		sign(p,id)
	end
	marker(stations,"AirlockExit",v(16,3,20),v(1,0,0))
	for id,pos in pairs({Port=v(-13,2,0),Starboard=v(13,2,0),Stern=v(0,2,27),Keel=v(0,-2,0)}) do marker(sites,id,pos) end
	for id,dir in pairs({Fore=v(0,0,-1),Starboard=v(1,0,0),Stern=v(0,0,1),Port=v(-1,0,0)}) do
		marker(cams,id,dir*(dir.Z~=0 and 28 or 14)+v(0,4,0),dir)
	end
	world.Parent=workspace
	return world
end
return Fixture
