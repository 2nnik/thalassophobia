-- Renders server-owned actors locally, interpolating between 5 Hz snapshot poses.
-- Also places colony models on hull sites listed as actors by site ID.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DiveCreatures = require(ReplicatedStorage:WaitForChild("DiveCreatures"))

local Actors = {}

-- Render this far behind server time so there are two samples to blend between.
local DELAY = 0.25

local folder: Folder
local tracks: { [string]: { model: Model, a: { t: number, cf: CFrame }?, b: { t: number, cf: CFrame } } } = {}

local function lerp(track, now)
	local a, b = track.a, track.b
	if not a or b.t <= a.t then
		return b.cf
	end
	local alpha = math.clamp((now - a.t) / (b.t - a.t), 0, 1)
	return a.cf:Lerp(b.cf, alpha)
end

function Actors.start(_ctx)
	folder = Instance.new("Folder")
	folder.Name = "DiveActors"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow() - DELAY
		for _, track in tracks do
			track.model:PivotTo(lerp(track, now))
		end
	end)
end

function Actors.update(snap)
	local actors = snap.dive and snap.dive.actors or {}
	local seen = {}
	for id, actor in actors do
		id = tostring(id)
		if actor.visible ~= false and typeof(actor.pose) == "CFrame" then
			seen[id] = true
			local track = tracks[id]
			if not track then
				local model = DiveCreatures.make(id)
				model:PivotTo(actor.pose)
				model.Parent = folder
				track = { model = model, b = { t = snap.time, cf = actor.pose } }
				tracks[id] = track
			elseif snap.time > track.b.t then
				track.a = track.b
				track.b = { t = snap.time, cf = actor.pose }
			end
		end
	end
	for id, track in tracks do
		if not seen[id] then
			track.model:Destroy()
			tracks[id] = nil
		end
	end
end

return Actors
