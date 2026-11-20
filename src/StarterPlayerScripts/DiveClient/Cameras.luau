-- First-person lock during a dive, and the hull camera feeds while the server grants
-- snapshot.camera. Feed controls are bound only at the desk:
--   keys 1-4 pick Fore/Starboard/Stern/Port; Next: DPadRight / touch "Next cam";
--   Leave: X / ButtonB / touch "Leave".
local ContextActionService = game:GetService("ContextActionService")

local Cameras = {}

local FEEDS = { "Fore", "Starboard", "Stern", "Port" }
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }
local PICK_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local ctx
local feed: string? = nil

local function apply()
	local cam = workspace.CurrentCamera
	local world = ctx.world()
	local part = feed and world and world:FindFirstChild("Cameras") and world.Cameras:FindFirstChild(feed)
	if part then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = part.CFrame
		cam.FieldOfView = 80
	else
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

-- Feed after `current` in FEEDS order, wrapping.
function Cameras.nextFeed(current: string?): string
	local i = table.find(FEEDS, current) or 0
	return FEEDS[i % #FEEDS + 1]
end

local function onAction(name, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if name == "DiveCameraExit" then
		ctx.send("CameraExit")
		return Enum.ContextActionResult.Sink
	elseif name == "DiveCameraNext" then
		feed = Cameras.nextFeed(feed)
	else
		feed = FEEDS[tonumber(string.sub(name, -1))]
	end
	apply()
	return Enum.ContextActionResult.Sink
end

local function bindDesk(on)
	if on then
		for i, key in PICK_KEYS do
			ContextActionService:BindAction("DiveCameraFeed" .. i, onAction, false, key)
		end
		ContextActionService:BindAction("DiveCameraNext", onAction, true, Enum.KeyCode.DPadRight)
		ContextActionService:SetTitle("DiveCameraNext", "Next cam")
		ContextActionService:SetPosition("DiveCameraNext", UDim2.new(1, -90, 1, -210))
		ContextActionService:BindAction("DiveCameraExit", onAction, true, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("DiveCameraExit", "Leave")
		ContextActionService:SetPosition("DiveCameraExit", UDim2.new(1, -170, 1, -210))
	else
		for i in PICK_KEYS do
			ContextActionService:UnbindAction("DiveCameraFeed" .. i)
		end
		ContextActionService:UnbindAction("DiveCameraNext")
		ContextActionService:UnbindAction("DiveCameraExit")
	end
end

function Cameras.start(c)
	ctx = c
end

function Cameras.update(snap)
	ctx.player.CameraMode = if DIVE_PHASES[snap.phase] then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic

	local granted = snap.camera
	if granted and not feed then
		feed = if table.find(FEEDS, granted) then granted else "Fore"
		bindDesk(true)
		apply()
	elseif not granted and feed then
		feed = nil
		bindDesk(false)
		apply()
	end
end

do
	assert(Cameras.nextFeed(nil) == "Fore")
	assert(Cameras.nextFeed("Fore") == "Starboard")
	assert(Cameras.nextFeed("Port") == "Fore")
end

return Cameras
