-- Install temporarily under StarterPlayerScripts for the StudioTestService two-client test.
if not game:GetService("RunService"):IsStudio() then return end
local players = game:GetService("Players")
local player = players.LocalPlayer
local net = game.ReplicatedStorage:WaitForChild("DiveNet")
local report = game.ReplicatedStorage:WaitForChild("DiveQAReport",15)
if not report then return end
local queued, operated, reported = false, false, false
net.Snapshot.OnClientEvent:Connect(function(s)
	if #players:GetPlayers() ~= 2 then return end
	local crew = players:GetPlayers()
	table.sort(crew, function(a,b) return a.UserId < b.UserId end)
	if s.phase == "Lobby" and s.lobby.state == "Ready" and not queued then
		queued = true
		net.Action:FireServer("Public", {})
	elseif s.phase == "Descent" then
		if player == crew[1] and not operated then
			operated = true
			player.Character:PivotTo(workspace.DiveWorld.Stations.Engine.CFrame + Vector3.new(0,3,2))
			task.wait(0.4)
			net.Action:FireServer("Engine", {enabled=true})
		end
		if s.dive.engine and s.dive.depth > 2 and not reported then
			reported = true
			report:FireServer(s.dive.depth)
		end
	end
end)
