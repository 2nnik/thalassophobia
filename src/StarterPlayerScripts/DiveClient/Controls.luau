-- Directional and continuous actions (shared/DiveActions.md). Station toggles are server
-- ProximityPrompts, so they are not bound here.
--   Searchlight: hold right mouse near the Searchlight console to aim along your view.
--   Extinguisher: hold left mouse while holding it to Spray.
--   EVA: move keys + Space/LeftControl swim, B brace at nearest site, F cut, R return, C cancel.
-- shortcut: keyboard/mouse only, add touch buttons before a mobile release.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controls = {}

local SEND_INTERVAL = 0.1
local SPRAY_INTERVAL = 0.25
local SEARCHLIGHT_REACH = 8

local ctx
local controlModule
local eva: { [string]: any }? = nil
local holder = false
local cutSequence = 0
local lastAim, lastSwim, lastSpray = 0, 0, 0
local lastSwimDir = Vector3.zero

local function root(): BasePart?
	local char = ctx.player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function worldPart(folderName, name): BasePart?
	local world = ctx.world()
	local f = world and world:FindFirstChild(folderName)
	return f and f:FindFirstChild(name) :: BasePart?
end

local function nearSearchlight()
	local r, console = root(), worldPart("Stations", "Searchlight")
	return r and console and (r.Position - console.Position).Magnitude <= SEARCHLIGHT_REACH
end

-- Bearing: degrees clockwise from fore (-Z) toward starboard (+X). Pitch: degrees up.
function Controls.bearingPitch(dir: Vector3, shipCFrame: CFrame): (number, number)
	local d = shipCFrame:VectorToObjectSpace(dir).Unit
	return math.deg(math.atan2(d.X, -d.Z)) % 360, math.deg(math.asin(math.clamp(d.Y, -1, 1)))
end

local function nearestSite(): string?
	local world, r = ctx.world(), root()
	local sites = world and world:FindFirstChild("Sites")
	if not (sites and r) then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, site in sites:GetChildren() do
		local d = (site.Position - r.Position).Magnitude
		if d < bestDist then
			best, bestDist = site.Name, d
		end
	end
	return best
end

local function onKey(name, state)
	if state ~= Enum.UserInputState.Begin or not eva or eva.mode == "Inside" then
		return Enum.ContextActionResult.Pass
	end
	if name == "DiveBrace" then
		local site = nearestSite()
		if site then
			ctx.send("Brace", { site = site })
		end
	elseif name == "DiveCut" then
		local challenge = eva.challenge
		if type(challenge) == "table" and challenge.id ~= nil then
			cutSequence += 1
			ctx.send("Cut", { challengeId = challenge.id, strikeTime = workspace:GetServerTimeNow(), sequence = cutSequence })
		end
	elseif name == "DiveReturn" then
		ctx.send("Return")
	elseif name == "DiveCancel" then
		ctx.send("Cancel")
	end
	return Enum.ContextActionResult.Sink
end

local function step()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local world = ctx.world()
	local origin = world and world:FindFirstChild("ShipOrigin") :: BasePart?

	if origin and now - lastAim >= SEND_INTERVAL and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and nearSearchlight() then
		lastAim = now
		local bearing, pitch = Controls.bearingPitch(cam.CFrame.LookVector, origin.CFrame)
		ctx.send("Aim", { bearing = bearing, pitch = pitch })
	end

	if holder and now - lastSpray >= SPRAY_INTERVAL and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		lastSpray = now
		ctx.send("Spray")
	end

	if eva and eva.mode == "Swimming" and now - lastSwim >= SEND_INTERVAL then
		local move = controlModule and controlModule:GetMoveVector() or Vector3.zero
		local dir = cam.CFrame:VectorToWorldSpace(move)
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			dir -= Vector3.yAxis
		end
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zero
		if (dir - lastSwimDir).Magnitude > 0.05 then
			lastSwim, lastSwimDir = now, dir
			ctx.send("Swim", { direction = dir })
		end
	end
end

function Controls.start(c)
	ctx = c
	task.spawn(function()
		local ok, playerModule = pcall(require, ctx.player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		controlModule = ok and playerModule:GetControls() or nil
	end)
	ContextActionService:BindAction("DiveBrace", onKey, false, Enum.KeyCode.B)
	ContextActionService:BindAction("DiveCut", onKey, false, Enum.KeyCode.F)
	ContextActionService:BindAction("DiveReturn", onKey, false, Enum.KeyCode.R)
	ContextActionService:BindAction("DiveCancel", onKey, false, Enum.KeyCode.C)
	RunService.RenderStepped:Connect(step)
end

function Controls.update(snap)
	eva = ctx.myEva(snap)
	holder = snap.dive ~= nil and snap.dive.extinguisherHolder == ctx.player.UserId
end

-- Self-check of the bearing convention: fore 0, starboard 90, stern 180, port 270.
do
	local function near(a, b)
		return math.abs(a - b) < 1e-6
	end
	assert(near(Controls.bearingPitch(Vector3.new(0, 0, -1), CFrame.identity), 0))
	assert(near(Controls.bearingPitch(Vector3.new(1, 0, 0), CFrame.identity), 90))
	assert(near(Controls.bearingPitch(Vector3.new(0, 0, 1), CFrame.identity), 180))
	assert(near(Controls.bearingPitch(Vector3.new(-1, 0, 0), CFrame.identity), 270))
	assert(near(select(2, Controls.bearingPitch(Vector3.new(0, 1, -1), CFrame.identity)), 45))
end

return Controls
