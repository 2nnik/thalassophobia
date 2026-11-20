-- Directional and continuous actions (shared/DiveActions.md, shared/EVA.md). Station toggles
-- are server ProximityPrompts, so they are not bound here. Each action below is bound only
-- while it applies, for keyboard/mouse, gamepad and an on-screen touch button:
--   Aim (dive, near the Searchlight console): right mouse / L2 / "Aim", aims along your view.
--   Spray (holding the extinguisher): left mouse / R2 / "Spray".
--   Swimming: move with WASD / left stick / touch thumbstick; rise Space / A / "Up",
--             sink LeftControl / DPadDown / "Down"; Brace B / X; Return R / Y.
--   Braced: Cut F / R1 / "Cut"; Cancel C / B / "Cancel".
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Controls = {}

local SEND_INTERVAL = 0.1
local SWIM_INTERVAL = 0.125 -- 8 Hz, per shared/EVA.md
local SPRAY_INTERVAL = 0.25
local SEARCHLIGHT_REACH = 8
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }

local ACTIONS = {
	DiveAim = { title = "Aim", hold = true, pos = UDim2.new(1, -90, 1, -210), inputs = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 } },
	DiveSpray = { title = "Spray", hold = true, pos = UDim2.new(1, -170, 1, -140), inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 } },
	DiveUp = { title = "Up", hold = true, pos = UDim2.new(1, -90, 1, -210), inputs = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA } },
	DiveDown = { title = "Down", hold = true, pos = UDim2.new(1, -90, 1, -140), inputs = { Enum.KeyCode.LeftControl, Enum.KeyCode.DPadDown } },
	DiveBrace = { title = "Brace", pos = UDim2.new(1, -170, 1, -210), inputs = { Enum.KeyCode.B, Enum.KeyCode.ButtonX } },
	DiveReturn = { title = "Return", pos = UDim2.new(1, -170, 1, -140), inputs = { Enum.KeyCode.R, Enum.KeyCode.ButtonY } },
	DiveCut = { title = "Cut", pos = UDim2.new(1, -90, 1, -210), inputs = { Enum.KeyCode.F, Enum.KeyCode.ButtonR1 } },
	DiveCancel = { title = "Cancel", pos = UDim2.new(1, -170, 1, -210), inputs = { Enum.KeyCode.C, Enum.KeyCode.ButtonB } },
}

local ctx
local controlModule
local eva: { [string]: any }? = nil
local holder = false
local diving = false
local cutSequence = 0
local lastAim, lastSwim, lastSpray = 0, 0, 0
local lastSwimDir = Vector3.zero
local held: { [string]: boolean } = {}
local bound: { [string]: boolean } = {}

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
	return r ~= nil and console ~= nil and (r.Position - console.Position).Magnitude <= SEARCHLIGHT_REACH
end

-- Bearing: degrees clockwise from fore (-Z) toward starboard (+X). Pitch: degrees up.
function Controls.bearingPitch(dir: Vector3, shipCFrame: CFrame): (number, number)
	local d = shipCFrame:VectorToObjectSpace(dir).Unit
	return math.deg(math.atan2(d.X, -d.Z)) % 360, math.deg(math.asin(math.clamp(d.Y, -1, 1)))
end

-- Which actions apply right now.
function Controls.wanted(state: { evaMode: string?, holder: boolean, nearLight: boolean }): { [string]: boolean }
	local w = {}
	if state.nearLight then
		w.DiveAim = true
	end
	if state.holder then
		w.DiveSpray = true
	end
	if state.evaMode == "Swimming" then
		w.DiveUp, w.DiveDown, w.DiveBrace, w.DiveReturn = true, true, true, true
	elseif state.evaMode == "Braced" then
		w.DiveCut, w.DiveCancel = true, true
	end
	return w
end

-- Server drops swim input 0.65 s after the last Swim, so resend at 8 Hz while held,
-- and send one zero on release.
function Controls.shouldSendSwim(isHeld: boolean, wasMoving: boolean, sinceLast: number): boolean
	if isHeld then
		return sinceLast >= SWIM_INTERVAL
	end
	return wasMoving
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

local function onAction(name, state)
	if ACTIONS[name].hold then
		held[name] = state ~= Enum.UserInputState.End and state ~= Enum.UserInputState.Cancel
		return Enum.ContextActionResult.Sink
	end
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if name == "DiveBrace" then
		local site = nearestSite()
		if site then
			ctx.send("Brace", { site = site })
		end
	elseif name == "DiveCut" then
		local challenge = eva and eva.challenge
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

local function sync(w)
	for name, spec in ACTIONS do
		if w[name] and not bound[name] then
			ContextActionService:BindAction(name, onAction, true, table.unpack(spec.inputs))
			ContextActionService:SetTitle(name, spec.title)
			ContextActionService:SetPosition(name, spec.pos)
			bound[name] = true
		elseif not w[name] and bound[name] then
			ContextActionService:UnbindAction(name)
			bound[name], held[name] = nil, nil
		end
	end
end

local function step()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local world = ctx.world()
	local origin = world and world:FindFirstChild("ShipOrigin") :: BasePart?

	sync(Controls.wanted({
		evaMode = eva and eva.mode,
		holder = holder,
		nearLight = diving and nearSearchlight(),
	}))

	if held.DiveAim and origin and now - lastAim >= SEND_INTERVAL then
		lastAim = now
		local bearing, pitch = Controls.bearingPitch(cam.CFrame.LookVector, origin.CFrame)
		ctx.send("Aim", { bearing = bearing, pitch = pitch })
	end

	if held.DiveSpray and now - lastSpray >= SPRAY_INTERVAL then
		lastSpray = now
		ctx.send("Spray")
	end

	if eva and eva.mode == "Swimming" then
		local move = controlModule and controlModule:GetMoveVector() or Vector3.zero
		local dir = cam.CFrame:VectorToWorldSpace(move)
		if held.DiveUp then
			dir += Vector3.yAxis
		end
		if held.DiveDown then
			dir -= Vector3.yAxis
		end
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zero
		if Controls.shouldSendSwim(dir ~= Vector3.zero, lastSwimDir ~= Vector3.zero, now - lastSwim) then
			lastSwim, lastSwimDir = now, dir
			ctx.send("Swim", { direction = dir })
		end
	else
		-- Braced/inside: forget held input so swimming resumes sending once free (EVA.md Cancel).
		lastSwimDir = Vector3.zero
	end
end

function Controls.start(c)
	ctx = c
	task.spawn(function()
		local ok, playerModule = pcall(require, ctx.player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		controlModule = ok and playerModule:GetControls() or nil
	end)
	RunService.RenderStepped:Connect(step)
end

function Controls.update(snap)
	eva = ctx.myEva(snap)
	diving = DIVE_PHASES[snap.phase] == true
	holder = snap.dive ~= nil and snap.dive.extinguisherHolder == ctx.player.UserId
end

do
	local function near(a, b)
		return math.abs(a - b) < 1e-6
	end
	-- Bearing convention: fore 0, starboard 90, stern 180, port 270.
	assert(near(Controls.bearingPitch(Vector3.new(0, 0, -1), CFrame.identity), 0))
	assert(near(Controls.bearingPitch(Vector3.new(1, 0, 0), CFrame.identity), 90))
	assert(near(Controls.bearingPitch(Vector3.new(0, 0, 1), CFrame.identity), 180))
	assert(near(Controls.bearingPitch(Vector3.new(-1, 0, 0), CFrame.identity), 270))
	assert(near(select(2, Controls.bearingPitch(Vector3.new(0, 1, -1), CFrame.identity)), 45))

	-- Held input keeps sending before the 0.65 s expiry; release sends exactly one zero.
	assert(Controls.shouldSendSwim(true, true, 0.13))
	assert(not Controls.shouldSendSwim(true, true, 0.05))
	assert(Controls.shouldSendSwim(true, false, 1))
	assert(Controls.shouldSendSwim(false, true, 0))
	assert(not Controls.shouldSendSwim(false, false, 5))

	-- Only applicable actions are bound, and no two bound at once share a touch position.
	local function key(w)
		local names = {}
		for n in w do
			table.insert(names, n)
		end
		table.sort(names)
		return table.concat(names, ",")
	end
	assert(key(Controls.wanted({ holder = false, nearLight = false })) == "")
	assert(key(Controls.wanted({ evaMode = "Inside", holder = true, nearLight = true })) == "DiveAim,DiveSpray")
	assert(key(Controls.wanted({ evaMode = "Swimming", holder = false, nearLight = false })) == "DiveBrace,DiveDown,DiveReturn,DiveUp")
	assert(key(Controls.wanted({ evaMode = "Braced", holder = false, nearLight = false })) == "DiveCancel,DiveCut")
	for _, state in { { holder = true, nearLight = true }, { evaMode = "Swimming" }, { evaMode = "Braced" } } do
		local used = {}
		for n in Controls.wanted(state :: any) do
			local p = tostring(ACTIONS[n].pos)
			assert(not used[p], "touch buttons overlap: " .. n)
			used[p] = true
		end
	end
end

return Controls
