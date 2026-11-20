-- Run as a Studio server Command Bar script after installing DiveEVA and DiveFixture.
-- Uses an isolated copy of the normal fixture and two stand-in avatars.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local server = game:GetService("ServerScriptService")
local EVA = require(server.DiveEVA)
local world = require(server.DiveFixture).build()
world.Name = "EVATestWorld"
world:PivotTo(world:GetPivot() + Vector3.new(0, 5000, 0))
local origin = world.ShipOrigin.CFrame

local function markers(group)
	local result = {}
	for _, part in ipairs(group:GetChildren()) do result[part.Name] = part end
	return result
end

local function avatar(id, spawn)
	local character = Instance.new("Model")
	character.Name = "TestDiver" .. id
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CanCollide = false
	root.CFrame = spawn
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.Parent = character
	local removing = Instance.new("BindableEvent")
	removing.Parent = character
	character.Parent = world
	return {UserId = id, Character = character, CharacterRemoving = removing.Event}
end

local function exercise()
	local stations, sites = markers(world.Stations), markers(world.Sites)
	local eva = EVA.new(origin, stations, sites)
	local entry = stations.Airlock.CFrame + Vector3.new(0, 3, 0)
	local a, b = avatar(1, entry), avatar(2, entry)
	local voyage = {actors = {}, patches = {}, traits = {}}
	for name in pairs(sites) do voyage.patches[name] = {active = true, cuts = 0} end
	function voyage:cut(name)
		local patch = self.patches[name]
		if not patch.active then return false end
		patch.cuts += 1
		patch.active = patch.cuts < 3
		return true
	end

	local now = 1000
	local function action(diver, name, payload)
		return eva:action(diver, name, payload or {}, now, voyage)
	end
	local function step(dt)
		now += dt
		eva:step(dt, now, voyage)
	end
	local function go(diver, x, y, z)
		local target = origin:PointToWorldSpace(Vector3.new(x, y, z))
		for _ = 1, 300 do
			local delta = target - eva:position()
			if delta.Magnitude < 0.1 then break end
			assert(action(diver, "Swim", {direction = delta.Unit}))
			step(math.min(0.05, delta.Magnitude / EVA.Tuning.speed))
		end
		assert((target - eva:position()).Magnitude < 0.1, "Blocked on route to " .. tostring(target))
		assert(action(diver, "Swim", {direction = Vector3.zero}))
	end
	local function strike(diver, sequence, turn, good)
		local c = eva:snapshot().challenge
		local t = c.startedAt + (turn + (good and c.arcStart + c.arcWidth / 2 or 0.05)) * c.period
		step(t - now)
		local payload = {challengeId = c.id, sequence = sequence, strikeTime = t}
		local ok = action(diver, "Cut", payload)
		return ok, payload
	end

	assert(action(a, "Exit") and not action(b, "Exit"))
	assert((eva:position() - stations.AirlockExit.Position).Magnitude < 0.01)
	assert(not action(b, "Swim", {direction = Vector3.yAxis}))
	assert(not action(a, "Brace", {site = "Port"}))
	go(a, 16, 3, 0)
	assert(action(a, "Brace", {site = "Starboard"}) and action(a, "Cancel"))
	go(a, 16, -5, 0)
	go(a, 0, -5, 0)
	assert(action(a, "Brace", {site = "Keel"}))
	local keel = eva:position()
	assert(not action(a, "Swim", {direction = Vector3.yAxis}))
	local miss = strike(a, 1, 0, false)
	assert(not miss and voyage.patches.Keel.cuts == 0)
	local good, replay = strike(a, 2, 1, true)
	assert(good and not action(a, "Cut", replay) and voyage.patches.Keel.cuts == 1)
	assert(eva:position() == keel and action(a, "Cancel"))
	go(a, 16, -5, 0)
	go(a, 16, 3, 20)
	assert(action(a, "Return") and not a.Character.HumanoidRootPart.Anchored)

	assert(action(b, "Exit"))
	go(b, 16, -5, 20)
	go(b, 0, -5, 0)
	assert(action(b, "Brace", {site = "Keel"}))
	assert(not action(b, "Cut", replay))
	assert(strike(b, 1, 0, true) and strike(b, 2, 1, true))
	assert(not voyage.patches.Keel.active and eva:snapshot().mode == "Swimming")
	go(b, -16, -5, 0)
	go(b, -16, 3, 0)
	assert(action(b, "Brace", {site = "Port"}) and action(b, "Cancel"))
	go(b, -16, 3, 30)
	go(b, 0, 3, 30)
	assert(action(b, "Brace", {site = "Stern"}))
	voyage.patches.Stern = {active = true, cuts = 0}
	step(0.05)
	assert(eva:snapshot().mode == "Swimming" and voyage.patches.Stern.cuts == 0)
	voyage.diverDanger = 1
	local before = eva:snapshot().oxygen
	local health = b.Character.Humanoid.Health
	step(1)
	local exposed = eva:snapshot()
	assert(exposed.predatorDanger, "Voyage exposure did not reach EVA snapshot; verify installed DiveEVA reads voyage.diverDanger")
	assert(exposed.oxygen < before - 1, "Expected accelerated oxygen use at full exposure")
	assert(b.Character.Humanoid.Health < health, "Full exposure should damage the exposed diver")
	b.Character.Humanoid.Health = 0
	step(0.05)
	assert(eva:position() == nil and not b.Character.HumanoidRootPart.Anchored)

	local fallback = table.clone(stations)
	fallback.AirlockExit = nil
	eva = EVA.new(origin, fallback, sites)
	assert(action(a, "Exit"))
	assert((eva:position() - sites.Stern.Position).Magnitude < EVA.Tuning.patchReach)
	assert(action(a, "Brace", {site = "Stern"}))
	assert(action(a, "Return"))
	assert(action(a, "Exit"))
	assert(eva:release(a) and not eva:release(a))
	assert(eva:snapshot().mode == "Inside" and not a.Character.HumanoidRootPart.Anchored)
	local tether = stations.Airlock:FindFirstChild("EVATetherAnchor")
	assert(tether == nil, "Tether leaked after disconnect cleanup")
	return "EVA PASS: four sites, obstructed hull routes, keel cut, miss, replay, cancel, diver swap, exposure, cleanup and fallback hatch"
end

local ok, result = xpcall(exercise, debug.traceback)
world:Destroy()
assert(ok, result)
print(result)
