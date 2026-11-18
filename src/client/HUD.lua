-- Sparse HUD: depth, hull, battery, a sonar scope and warning text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HUD = {}

local WARNINGS = {
	MonsterWarning = {
		Shark = "Something huge is circling... get ready to kill the engine.",
		Squid = "Movement in the dark. Find it with the light.",
		Crawler = "Scratching on the hull.",
		Swarm = "Something is clinging to the cage.",
		Pursuer = "Don't stop. Don't ever stop.",
	},
	SharkNear = "KILL THE ENGINE", SharkAttack = "IT HIT US", SharkLeft = "It's gone. Engine back on.",
	SquidStage = { Near = "It's getting closer.", VeryNear = "LIGHT IT UP", Lethal = "TOO CLOSE" },
	CrawlerEntered = "It's inside!", CrawlerMoved = "It moved!", CrawlerLeft = "It fled.",
	OutsideDanger = "DIVER: GET BACK IN", ArtifactTaken = "Artifact secured. Go up. Go up!",
	ReachedBottom = "We're at the bottom. Grab it.", CrackAppeared = "Hull crack!", PlayerDied = "We lost someone.",
	PursuerStage = { [1] = "It's gaining on us.", [2] = "KEEP MOVING" },
}

local function label(parent, text, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.TextColor3, l.Font = 1, Color3.fromRGB(170, 220, 230), Enum.Font.Code
	l.TextSize, l.TextXAlignment, l.Text = 18, Enum.TextXAlignment.Left, text
	l.Position, l.Size, l.Parent = pos, size, parent
	return l
end

local function bar(parent, y, color)
	local back = Instance.new("Frame")
	back.Position, back.Size, back.BackgroundColor3, back.BorderSizePixel = UDim2.new(0, 16, 0, y), UDim2.new(0, 200, 0, 10), Color3.fromRGB(15, 25, 30), 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size, fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = UDim2.new(1, 0, 1, 0), color, 0, back
	return fill
end

function HUD.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HUD", false, true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local depth = label(gui, "", UDim2.new(0, 16, 0, 14), UDim2.new(0, 300, 0, 22))
	local status = label(gui, "", UDim2.new(0, 16, 0, 70), UDim2.new(0, 400, 0, 22))
	label(gui, "HULL", UDim2.new(0, 224, 0, 32), UDim2.new(0, 60, 0, 14)).TextSize = 12
	label(gui, "POWER", UDim2.new(0, 224, 0, 50), UDim2.new(0, 60, 0, 14)).TextSize = 12
	local hull = bar(gui, 34, Color3.fromRGB(200, 90, 70))
	local power = bar(gui, 52, Color3.fromRGB(230, 200, 90))

	local warn = label(gui, "", UDim2.new(0.2, 0, 0.78, 0), UDim2.new(0.6, 0, 0, 40))
	warn.TextXAlignment, warn.TextSize, warn.TextColor3 = Enum.TextXAlignment.Center, 26, Color3.fromRGB(235, 90, 80)

	local sonar = Instance.new("Frame")
	sonar.Size, sonar.Position, sonar.AnchorPoint = UDim2.new(0, 160, 0, 160), UDim2.new(1, -16, 1, -16), Vector2.new(1, 1)
	sonar.BackgroundColor3, sonar.BackgroundTransparency, sonar.Parent = Color3.fromRGB(5, 25, 20), 0.2, gui
	Instance.new("UICorner", sonar).CornerRadius = UDim.new(1, 0)
	local blips = {}

	local function say(text, secs)
		if not text then return end
		warn.Text = text
		local mine = text
		task.delay(secs or 3, function() if warn.Text == mine then warn.Text = "" end end)
	end

	Remotes.Events.OnClientEvent:Connect(function(name, data)
		local entry = WARNINGS[name]
		if name == "MonsterWarning" then say(entry[data.kind])
		elseif name == "SquidStage" then say(entry[data.stage])
		elseif name == "PursuerStage" then say(entry[data.stage])
		elseif name == "RunDied" then say("The cage is lost: " .. tostring(data.reason), 30)
		elseif name == "RunWon" then say("Surface reached.", 30)
		elseif name == "RunEnded" then
			say(string.format("%s  Depth %dm  +$%d", data.survived and "SURVIVED" or "LOST", data.depth, data.money), 30)
		elseif type(entry) == "string" then say(entry) end
	end)

	local me = Players.LocalPlayer.UserId
	Remotes.State.OnClientEvent:Connect(function(s)
		depth.Text = string.format("DEPTH %dm  %s", s.depth, s.phase:upper())
		hull.Size = UDim2.new(math.clamp(s.hull, 0, 1), 0, 1, 0)
		power.Size = UDim2.new(math.clamp(s.battery, 0, 1), 0, 1, 0)
		local where = ""
		for _, p in ipairs(s.players) do if p.id == me then where = p.outside and "OUTSIDE" or p.section end end
		status.Text = string.format("%s | engine %s | light %s", where, s.engineOn and "ON" or "OFF", s.lightOn and "ON" or "OFF")
		for _, b in ipairs(blips) do b:Destroy() end
		blips = {}
		for _, m in ipairs(s.monsters) do
			if m.bearing and m.dist then
				local r = math.clamp(m.dist / 110, 0, 1) * 0.5
				local a = math.rad(m.bearing)
				local blip = Instance.new("Frame")
				blip.Size, blip.AnchorPoint, blip.BorderSizePixel = UDim2.new(0, 8, 0, 8), Vector2.new(0.5, 0.5), 0
				blip.BackgroundColor3 = Color3.fromRGB(120, 255, 170)
				blip.Position = UDim2.new(0.5 - math.sin(a) * r, 0, 0.5 - math.cos(a) * r, 0)
				blip.Parent = sonar
				blips[#blips + 1] = blip
			end
		end
	end)
end

return HUD
