-- Glue between Roblox and the pure simulation: players, prompts, remotes, cage visuals, run lifecycle.
-- The simulation owns all game state; this file only forwards validated input and publishes state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Session = require(script.Parent.Parent.Sim.Session)
local CageBuilder = require(script.Parent.CageBuilder)
local Economy = require(script.Parent.Economy)

local RunController = {}

local function waitForCrew()
	local t0 = os.clock()
	while true do
		local list = Players:GetPlayers()
		local data = #list > 0 and list[1]:GetJoinData().TeleportData or nil
		local expected = (type(data) == "table" and tonumber(data.expected)) or 1
		if #list > 0 and (#list >= expected or os.clock() - t0 > Config.Run.JoinWait) then
			return list, type(data) == "table" and data.difficulty or nil
		end
		task.wait(0.5)
	end
end

local function moveCharacter(player, cf)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = cf end
end

function RunController.start()
	Players.RespawnTime = 1000 -- the dead spectate until the run ends
	local cage = CageBuilder.build()
	local crew, difficulty = waitForCrew()

	local list = {}
	for _, player in ipairs(crew) do
		local profile = Economy.Load(player)
		list[#list + 1] = { id = player.UserId, traits = profile.equipped }
	end
	local session = Session.new(Config, { difficulty = difficulty, players = list })
	local byId = {}
	for _, player in ipairs(crew) do byId[player.UserId] = player end

	local holds, spraying, scrubbing = {}, {}, {}
	local lightOperator = nil
	local ended = false

	-- ------------------------------------------------------------ input
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind, uid = prompt:GetAttribute("Kind"), player.UserId
		if kind == "Engine" then
			session:SetEngine(not session.engineOn)
		elseif kind == "Light" then
			lightOperator = uid
			session:SetLight(not session.lightOn, session.lightYaw)
		elseif kind == "Claw" then
			session:PickUpArtifact(uid)
		elseif kind == "Ext" then
			session:GrabExtinguisher(uid, prompt:GetAttribute("Id"))
		elseif kind == "HatchOut" then
			if session:ExitAirlock(uid) then moveCharacter(player, cage.ledgeCFrame) end
		elseif kind == "HatchIn" then
			if session:EnterAirlock(uid) then moveCharacter(player, cage.airlockCFrame) end
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		if kind == "Repair" or kind == "Refill" then
			holds[player.UserId] = { kind = kind, id = prompt:GetAttribute("Id") }
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_, player)
		holds[player.UserId] = nil
	end)

	Remotes.LightAim.OnServerEvent:Connect(function(player, yaw)
		local p = session.players[player.UserId]
		if type(yaw) == "number" and yaw == yaw and math.abs(yaw) < 1e6 and p and p.alive and p.section == "Bow" then
			session.lightYaw = yaw % 360
		end
	end)
	Remotes.Spray.OnServerEvent:Connect(function(player, on)
		spraying[player.UserId] = on == true or nil
	end)
	Remotes.Scrub.OnServerEvent:Connect(function(player, on)
		scrubbing[player.UserId] = on == true or nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local uid = player.UserId
		session:RemovePlayer(uid)
		holds[uid], spraying[uid], scrubbing[uid] = nil, nil, nil
	end)

	-- ------------------------------------------------------------ simulation events -> world
	local function onEvent(e)
		local d = e.data
		if e.name == "CrackAppeared" then
			cage.addCrack(d.id, d.section)
		elseif e.name == "CrackRepaired" then
			cage.removeCrack(d.id)
		elseif e.name == "ReachedBottom" then
			cage.prompts.Claw.Enabled = true
		elseif e.name == "ArtifactTaken" then
			cage.prompts.Claw.Enabled = false
		elseif e.name == "PlayerDied" then
			local player = byId[d.id]
			local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end
		Remotes.Events:FireAllClients(e.name, d)
	end

	-- ------------------------------------------------------------ run end
	local function endRun()
		ended = true
		local result = session:Result()
		for uid, player in pairs(byId) do
			local p = session.players[uid]
			if player.Parent and p and not p.left then Economy.Award(player, result.money) end
		end
		Remotes.Events:FireAllClients("RunEnded", result)
		task.wait(Config.Run.EndDelay)
		if Config.Places.Lobby ~= 0 then
			pcall(function() TeleportService:TeleportAsync(Config.Places.Lobby, Players:GetPlayers()) end)
		else
			print("[Thalassophobia] run over:", result.survived and "survived" or ("died: " .. tostring(result.reason)), result.money)
		end
	end

	-- ------------------------------------------------------------ main loop
	local sinceState = 0
	RunService.Heartbeat:Connect(function(dt)
		if ended then return end
		for uid, p in pairs(session.players) do
			local player = byId[uid]
			local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and p.alive and not p.outside then
				local section = cage.sectionOf(hrp.Position)
				if section then session:SetPlayerSection(uid, section) end
			end
		end
		for uid, h in pairs(holds) do
			if h.kind == "Repair" then session:Repair(uid, h.id, dt) else session:Refill(uid, dt) end
		end
		for uid in pairs(spraying) do session:Spray(uid, dt) end
		for uid in pairs(scrubbing) do session:Scrub(uid, dt) end

		session:Tick(dt)
		for _, e in ipairs(session:TakeEvents()) do onEvent(e) end

		-- the spotlight follows the sim (server-side so everyone sees the same beam)
		cage.spot.Enabled = session:LightEffective()
		local bow = cage.lightPart.Position
		cage.lightPart.CFrame = CFrame.new(bow) * CFrame.Angles(0, math.rad(session.lightYaw), 0)

		sinceState = sinceState + dt
		if sinceState >= 0.1 then
			sinceState = 0
			Remotes.State:FireAllClients(session:Snapshot())
		end
		if session.phase == "Won" or session.phase == "Dead" then task.spawn(endRun) end
	end)
end

return RunController
