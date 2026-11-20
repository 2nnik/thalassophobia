-- Dive client: binds to ReplicatedStorage.DiveNet (shared/DiveProtocol.md v1) and drives
-- lobby UI, HUD, actor visuals, controls, cameras and ambience from Snapshot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local net = ReplicatedStorage:WaitForChild("DiveNet")
local action: RemoteEvent = net:WaitForChild("Action")
local snapshot: RemoteEvent = net:WaitForChild("Snapshot")
local player = Players.LocalPlayer

local ctx = {}
ctx.player = player
ctx.snap = nil :: any

function ctx.send(name: string, payload: { [string]: any }?)
	action:FireServer(name, payload or {})
end

function ctx.world(): Model?
	return workspace:FindFirstChild("DiveWorld") :: Model?
end

-- EVA state may come as the player's own record or keyed by userId.
function ctx.myEva(snap): { [string]: any }?
	local eva = snap and snap.eva
	if type(eva) ~= "table" then
		return nil
	end
	if eva.userId then
		return if eva.userId == player.UserId then eva else nil
	end
	return eva[player.UserId] or eva[tostring(player.UserId)]
end

local modules = {}
for _, name in { "Ambience", "Actors", "Cameras", "Controls", "Hud", "Lobby" } do
	local m = require(script:WaitForChild(name))
	m.start(ctx)
	table.insert(modules, m)
end

snapshot.OnClientEvent:Connect(function(snap)
	if type(snap) ~= "table" or snap.version ~= 1 then
		warn("DiveClient: ignoring snapshot with unknown version", type(snap) == "table" and snap.version)
		return
	end
	ctx.snap = snap
	for _, m in modules do
		local ok, err = pcall(m.update, snap)
		if not ok then
			warn("DiveClient:", err)
		end
	end
end)
