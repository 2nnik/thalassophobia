-- First-person fake arms for hull repairs. They lift a replacement plate (crack) or a timber plank (breach)
-- and work it against the frame. Local only, parented to the camera, no collision or queries; no game state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SLEEVE = Color3.fromRGB(42, 56, 60)
local GLOVE = Color3.fromRGB(30, 31, 32)
local CUFF = Color3.fromRGB(232, 170, 70)
local BIND = "DiveRepairArms"

local Arms = {}
local rig = nil

local function part(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.Material = name, size, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Item pieces are {part, offset from the item centre}. grip = half the distance between the hands.
local function buildItem(model, kind)
	local pieces = {}
	if kind == "plate" then
		table.insert(pieces, {part(model, "Replacement plate", Vector3.new(1.4, 1.0, .1), Color3.fromRGB(78, 86, 88), Enum.Material.DiamondPlate), CFrame.identity})
		table.insert(pieces, {part(model, "Gasket", Vector3.new(1.62, 1.22, .04), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber), CFrame.new(0, 0, -.07)})
		pieces[2][1].Size = Vector3.new(1.52, 1.12, .04)
		for _, c in {{-.56, .38}, {.56, .38}, {-.56, -.38}, {.56, -.38}} do
			table.insert(pieces, {part(model, "Bolt", Vector3.new(.12, .12, .1), Color3.fromRGB(190, 190, 180), Enum.Material.Metal), CFrame.new(c[1], c[2], .08)})
		end
		return pieces, .66
	end
	table.insert(pieces, {part(model, "Repair plank", Vector3.new(2.3, .5, .14), Color3.fromRGB(146, 104, 61), Enum.Material.WoodPlanks), CFrame.identity})
	for _, x in {-.95, .95} do
		table.insert(pieces, {part(model, "Nail", Vector3.new(.08, .08, .12), Color3.fromRGB(170, 170, 165), Enum.Material.Metal), CFrame.new(x, 0, .09)})
	end
	return pieces, .82
end

local function destroy()
	if not rig then return end
	RunService:UnbindFromRenderStep(BIND)
	rig.model:Destroy()
	rig = nil
end

local function alive()
	local character = Players.LocalPlayer.Character
	local human = character and character:FindFirstChildOfClass("Humanoid")
	return human ~= nil and human.Health > 0
end

local function step()
	local camera = workspace.CurrentCamera
	if not rig or not camera then return end
	if not alive() then destroy() return end
	local now = os.clock()
	local t = now - rig.started
	local raise = math.min(1, t / .3)
	if rig.endAt then
		raise = math.min(raise, 1 - (now - rig.endAt) / .3)
		if raise <= 0 then destroy() return end
	end
	raise = raise * raise * (3 - 2 * raise)
	-- Hold repairs press the plate home as the hold fills; the plank patch rocks while waiting for each ring.
	local progress = if rig.duration then math.clamp(t / rig.duration, 0, 1) else nil
	if progress and rig.onTap and not rig.endAt and now >= rig.nextAuto then
		rig.nextAuto = now + .62
		rig.tapAt = now
		rig.onTap()
	end
	local push = if progress then .12 + progress * .3 else .2 + .05 * math.sin(t * 3)
	local tap = math.max(0, 1 - (now - rig.tapAt) / .2)
	tap = tap * tap
	local effort = math.sin(t * 11) * .012
	local item = camera.CFrame
		* CFrame.new(effort, -.62 - (1 - raise) * 1.6 + effort, -2.15 - push - tap * .3)
		* CFrame.Angles(math.rad(-6) + (1 - raise) * .5, math.sin(t * 1.7) * .03, math.sin(t * 2.3) * .025)
	for _, piece in rig.pieces do
		piece[1].CFrame = item * piece[2]
	end
	for _, arm in rig.arms do
		local side = arm.side
		-- Gloves wrap the item's side edges; the cuff sits back on the forearm so the glove stays visible.
		local hand = item * CFrame.new(side * rig.grip, -.12, .04)
		local shoulder = (camera.CFrame * CFrame.new(side * 1.0, -1.75, .35)).Position
		local wrist = (hand * CFrame.new(0, -.05, .38)).Position
		local length = (wrist - shoulder).Magnitude
		arm.sleeve.Size = Vector3.new(.3, .3, length)
		arm.sleeve.CFrame = CFrame.lookAt((shoulder + wrist) / 2, wrist)
		arm.cuff.CFrame = CFrame.lookAt(wrist, wrist + (wrist - shoulder))
		arm.hand.CFrame = hand * CFrame.Angles(0, 0, side * .25)
	end
end

-- kind: "plate" (crack hold) or "plank" (breach patch). duration: hold length, nil for open-ended.
-- onTap: called on each automatic work stroke during a hold (sound hook).
function Arms.start(kind, duration, onTap)
	destroy()
	local camera = workspace.CurrentCamera
	if not camera or not alive() then return end
	local model = Instance.new("Model")
	model.Name = "RepairArms"
	local pieces, grip = buildItem(model, kind)
	local arms = {}
	for _, side in {-1, 1} do
		table.insert(arms, {
			side = side,
			sleeve = part(model, "Sleeve", Vector3.new(.36, .36, 1), SLEEVE, Enum.Material.Fabric),
			cuff = part(model, "Cuff", Vector3.new(.34, .34, .1), CUFF),
			hand = part(model, "Glove", Vector3.new(.32, .4, .36), GLOVE, Enum.Material.Rubber),
		})
	end
	local now = os.clock()
	rig = {model = model, kind = kind, pieces = pieces, grip = grip, arms = arms, started = now, duration = duration,
		onTap = onTap, nextAuto = now + .45, tapAt = -1}
	step()
	model.Parent = camera
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, step)
end

-- One work stroke (a plank fastener landing).
function Arms.tap()
	if rig and not rig.endAt then rig.tapAt = os.clock() end
end

-- Lower and remove. success adds a last push; instant skips the lowering.
function Arms.stop(success, instant)
	if not rig then return end
	if instant then destroy() return end
	if rig.endAt then return end
	if success then rig.tapAt = os.clock() end
	rig.endAt = os.clock() + (if success then .15 else 0)
end

function Arms.kind()
	return if rig and not rig.endAt then rig.kind else nil
end

return Arms
