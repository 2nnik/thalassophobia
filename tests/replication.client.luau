-- Install temporarily under StarterPlayerScripts for the StudioTestService two-client test.
if not game:GetService("RunService"):IsStudio() then return end
local players = game:GetService("Players")
local player = players.LocalPlayer
local net = game.ReplicatedStorage:WaitForChild("DiveNet")
local report = game.ReplicatedStorage:WaitForChild("DiveQAReport",15)
if not report then return end
local queued, operated, reported = false, false, false
local latest,dived
local function cleanKeel(first)
	local world=workspace.DiveWorld
	local function send(name,data) net.Action:FireServer(name,data or {}) end
	local function swimTo(pos)
		for _=1,100 do
			local e=latest.eva
			assert(e and e.userId==player.UserId,"Diver slot lost")
			local delta=pos-e.position
			if delta.Magnitude<1.8 then send("Swim",{direction=Vector3.zero}) return end
			send("Swim",{direction=delta.Unit})
			task.wait(.12)
		end
		error("Blocked underwater route")
	end
	player.Character:PivotTo(world.Stations.Airlock.CFrame+Vector3.new(0,2,2))
	task.wait(.4)
	send("Exit")
	task.wait(.5)
	local hatch=world.Stations.AirlockExit.Position
	local below=Vector3.new(hatch.X,world.Sites.Keel.Position.Y-4,hatch.Z+2)
	swimTo(below)
	swimTo(world.Sites.Keel.Position-Vector3.yAxis*3)
	send("Brace",{site="Keel"})
	task.wait(.45)
	local c=assert(latest.eva.challenge)
	for i=1,first and 1 or 2 do
		local phase=((workspace:GetServerTimeNow()-c.startedAt)/c.period)%1
		task.wait(((c.arcStart+c.arcWidth/2-phase)%1)*c.period)
		send("Cut",{challengeId=c.id,sequence=i,strikeTime=workspace:GetServerTimeNow()})
		task.wait(.45)
	end
	send("Cancel")
	task.wait(.25)
	swimTo(below)
	swimTo(hatch)
	send("Return")
	task.wait(.5)
	assert(latest.eva.userId~=player.UserId,"Diver stuck outside")
	report:FireServer("clean",latest.dive.patches.Keel.cuts)
end
net.Snapshot.OnClientEvent:Connect(function(s)
	latest=s
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
			report:FireServer("engine",s.dive.depth)
		end
		local patch=s.dive.patches.Keel
		local first=player==crew[1]
		if not dived and patch and patch.active and s.eva.mode=="Inside" and patch.cuts==(first and 0 or 1) then
			dived=true
			local ok,err=pcall(cleanKeel,first)
			if not ok then report:FireServer("error",tostring(err)) end
		end
	end
end)
