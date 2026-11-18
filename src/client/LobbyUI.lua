-- Minimal lobby: difficulty buttons (queue / solo) and a trait shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LobbyUI = {}

local function button(parent, text, order, onClick)
	local b = Instance.new("TextButton")
	b.Size, b.LayoutOrder, b.Text = UDim2.new(1, 0, 0, 30), order, text
	b.BackgroundColor3, b.TextColor3, b.Font, b.TextSize = Color3.fromRGB(20, 45, 55), Color3.fromRGB(200, 235, 240), Enum.Font.Code, 16
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

function LobbyUI.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "Lobby", false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Size, panel.Position, panel.BackgroundColor3 = UDim2.new(0, 360, 0.9, 0), UDim2.new(0, 20, 0.05, 0), Color3.fromRGB(5, 15, 20)
	panel.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder, list.Padding, list.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 4), panel
	local rows = {}

	local difficulty = "Normal"
	local order = 0
	local function nextOrder() order = order + 1; return order end
	local header = button(panel, "THALASSOPHOBIA", nextOrder(), function() end)
	local diffButton = button(panel, "Difficulty: Normal (click to change)", nextOrder(), function() end)
	diffButton.Activated:Connect(function()
		for i, name in ipairs(Config.DifficultyOrder) do
			if name == difficulty then
				difficulty = Config.DifficultyOrder[i % #Config.DifficultyOrder + 1]
				break
			end
		end
		diffButton.Text = "Difficulty: " .. difficulty .. " (click to change)"
	end)
	button(panel, "Find a crew (up to 4)", nextOrder(), function() Remotes.LobbyAction:FireServer("Queue", difficulty) end)
	button(panel, "Play solo", nextOrder(), function() Remotes.LobbyAction:FireServer("Solo", difficulty) end)

	local ids = {}
	for id in pairs(Config.Traits) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local t = Config.Traits[id]
		local b = button(panel, "", nextOrder(), function() end)
		rows[id] = b
		b.TextSize, b.TextWrapped, b.Size = 13, true, UDim2.new(1, 0, 0, 44)
	end

	local state = { money = 0, owned = {}, equipped = {} }
	local function contains(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end
	local function refresh(message)
		header.Text = string.format("THALASSOPHOBIA   $%d   %s", state.money, message or "")
		for id, b in pairs(rows) do
			local t = Config.Traits[id]
			local owned, equipped = contains(state.owned, id), contains(state.equipped, id)
			local effect = t.drawback and (" | drawback: " .. t.drawback) or ""
			b.Text = string.format("%s%s  [%s]%s", t.name, effect, equipped and "EQUIPPED" or (owned and "owned" or ("$" .. t.cost)), "")
		end
	end
	for id, b in pairs(rows) do
		b.Activated:Connect(function()
			if contains(state.owned, id) then
				Remotes.LobbyAction:FireServer("Equip", id, not contains(state.equipped, id))
			else
				Remotes.LobbyAction:FireServer("Buy", id)
			end
		end)
	end
	Remotes.LobbyState.OnClientEvent:Connect(function(s)
		state = s
		refresh(s.message)
	end)
	refresh()
	Remotes.LobbyAction:FireServer("Sync")
end

return LobbyUI
