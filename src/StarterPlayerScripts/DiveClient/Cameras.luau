-- First-person lock during a dive, and the hull camera feeds while the server grants
-- snapshot.camera. Keys 1-4 pick Fore/Starboard/Stern/Port locally; X leaves the desk.
local ContextActionService = game:GetService("ContextActionService")

local Cameras = {}

local FEEDS = { "Fore", "Starboard", "Stern", "Port" }
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }

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

local function onKey(name, state)
	if state ~= Enum.UserInputState.Begin or not feed then
		return Enum.ContextActionResult.Pass
	end
	if name == "DiveCameraExit" then
		ctx.send("CameraExit")
	else
		feed = FEEDS[tonumber(string.sub(name, -1))]
		apply()
	end
	return Enum.ContextActionResult.Sink
end

function Cameras.start(c)
	ctx = c
	for i, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four } do
		ContextActionService:BindAction("DiveCameraFeed" .. i, onKey, false, key)
	end
	ContextActionService:BindAction("DiveCameraExit", onKey, false, Enum.KeyCode.X)
end

function Cameras.update(snap)
	ctx.player.CameraMode = if DIVE_PHASES[snap.phase] then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic

	local granted = snap.camera
	if granted and not feed then
		feed = if table.find(FEEDS, granted) then granted else "Fore"
		apply()
	elseif not granted and feed then
		feed = nil
		apply()
	end
end

return Cameras
