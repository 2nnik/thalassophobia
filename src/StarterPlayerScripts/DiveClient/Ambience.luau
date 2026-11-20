-- Local mood: water darkens with depth, the bow searchlight follows bearing/pitch,
-- and sounds follow engine, sonar and Pursuer distance.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ambience = {}

-- shortcut: only a built-in ping; fill these with uploaded or licensed audio IDs.
local SOUNDS = {
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Engine = "",
	Creak = "",
	Dread = "",
}
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }
local SURFACE_WATER = Color3.fromRGB(20, 60, 80)
local DEEP_WATER = Color3.fromRGB(1, 3, 5)
local DARK_AT = 200 -- metres where the water is fully dark

local ctx
local sounds: { [string]: Sound } = {}
local correction: ColorCorrectionEffect
local saved = {}
local lastSonar = false
local lastReturns = 0

local function sound(name, looped, volume): Sound
	local s = Instance.new("Sound")
	s.Name = "Dive" .. name
	s.SoundId = SOUNDS[name]
	s.Looped = looped
	s.Volume = volume
	s.Parent = SoundService
	sounds[name] = s
	return s
end

local function setLoop(name, on, volume)
	local s = sounds[name]
	if s.SoundId == "" then
		return
	end
	s.Volume = volume or s.Volume
	if on and not s.IsPlaying then
		s:Play()
	elseif not on and s.IsPlaying then
		s:Stop()
	end
end

-- Direction in ship space for a bearing (clockwise from fore -Z) and pitch (up).
function Ambience.aimVector(bearing: number, pitch: number): Vector3
	local b, p = math.rad(bearing), math.rad(pitch)
	return Vector3.new(math.sin(b) * math.cos(p), math.sin(p), -math.cos(b) * math.cos(p))
end

local function aimSearchlight(dive)
	local world = ctx.world()
	local hull = world and world:FindFirstChild("Hull")
	local lamp = hull and hull:FindFirstChild("SearchlightLamp") :: BasePart?
	local origin = world and world:FindFirstChild("ShipOrigin") :: BasePart?
	if not (lamp and origin) then
		return
	end
	local dir = origin.CFrame:VectorToWorldSpace(Ambience.aimVector(dive.bearing or 0, dive.pitch or 0))
	lamp.CFrame = CFrame.lookAt(lamp.Position, lamp.Position + dir)
	local beam = lamp:FindFirstChild("Beam") :: SpotLight?
	if beam then
		beam.Enabled = dive.searchlight == true
	end
end

function Ambience.start(c)
	ctx = c
	sound("Ping", false, 0.6)
	sound("Engine", true, 0.4)
	sound("Creak", true, 0.3)
	sound("Dread", true, 0)
	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "DiveWater"
	correction.Enabled = false
	correction.Parent = Lighting
	for _, key in { "Ambient", "OutdoorAmbient", "FogColor", "FogEnd", "Brightness", "ClockTime" } do
		saved[key] = Lighting[key]
	end
end

function Ambience.update(snap)
	local diving = DIVE_PHASES[snap.phase] == true
	local dive = snap.dive or {}
	correction.Enabled = diving

	if not diving then
		for key, value in saved do
			Lighting[key] = value
		end
		for name in sounds do
			setLoop(name, false)
		end
		lastSonar, lastReturns = false, 0
		return
	end

	local dark = math.clamp((dive.depth or 0) / DARK_AT, 0, 1)
	local water = SURFACE_WATER:Lerp(DEEP_WATER, dark)
	TweenService:Create(Lighting, TweenInfo.new(0.2), {
		FogColor = water,
		FogEnd = 60 - dark * 30,
		Ambient = water,
		OutdoorAmbient = water,
		Brightness = 1 - dark,
	}):Play()
	Lighting.ClockTime = 0
	correction.TintColor = Color3.fromRGB(170, 210, 220)
	correction.Saturation = -0.4

	aimSearchlight(dive)

	setLoop("Engine", dive.engine == true)
	setLoop("Creak", true, 0.2 + (1 - (dive.hull or 100) / 100) * 0.6)
	-- pursuerGap: 150 (Voyage pursuerLimit) far .. 0 caught; only hunts on the ascent.
	local gap = tonumber(dive.pursuerGap)
	setLoop("Dread", snap.phase == "Ascent" and gap ~= nil, gap and math.clamp(1 - gap / 150, 0, 1) or 0)

	-- Ping when sonar comes on or a new contact appears. returns is keyed by actor ID.
	local returns = 0
	for _ in type(dive.returns) == "table" and dive.returns or {} do
		returns += 1
	end
	if dive.sonar and (not lastSonar or returns > lastReturns) then
		sounds.Ping:Play()
	end
	lastSonar, lastReturns = dive.sonar == true, returns
end

-- Self-check: aimVector matches Controls' bearing convention.
do
	local function near(a: Vector3, b: Vector3)
		return (a - b).Magnitude < 1e-6
	end
	assert(near(Ambience.aimVector(0, 0), Vector3.new(0, 0, -1)))
	assert(near(Ambience.aimVector(90, 0), Vector3.new(1, 0, 0)))
	assert(near(Ambience.aimVector(0, 90), Vector3.new(0, 1, 0)))
end

return Ambience
