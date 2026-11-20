-- Lobby screen: Solo/Public/Private/Leave, difficulty, invites, and the trait shop.
local Players = game:GetService("Players")

local Lobby = {}

-- shortcut: difficulty IDs guessed from the design doc; confirm with the server's list.
local DIFFICULTIES = { "Easy", "Normal", "Hard", "Nightmare" }
local TEXT = Color3.fromRGB(190, 210, 200)

local ctx
local gui: ScreenGui
local status: TextLabel
local difficultyButton: TextButton
local lists: { [string]: Frame } = {}
local listKeys: { [string]: string } = {}
local lobbyState: { [string]: any } = {}

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function button(text, onClick, parent): TextButton
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(30, 40, 44),
		TextColor3 = TEXT,
		Font = Enum.Font.Code,
		TextSize = 16,
		Text = text,
		AutoButtonColor = true,
	}, parent)
	b.Activated:Connect(onClick)
	return b
end

local function column(name, x, title): Frame
	local f = new("Frame", { Name = name, Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.fromScale(x, 0.2), BackgroundTransparency = 1 }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, TextColor3 = TEXT, Font = Enum.Font.Code, TextSize = 20, Text = title, LayoutOrder = -1 }, f)
	return f
end

-- Membership in either a list ({"Battery"}) or a set ({Battery=true}).
local function has(t, id)
	return type(t) == "table" and (t[id] == true or table.find(t, id) ~= nil)
end

local function nameOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.DisplayName or tostring(userId)
end

-- Rebuilds a dynamic list only when its contents change, so buttons aren't destroyed mid-click.
local function setList(name, key, fill)
	if listKeys[name] == key then
		return
	end
	listKeys[name] = key
	for _, child in lists[name]:GetChildren() do
		if child:IsA("GuiButton") or child.Name == "Row" then
			child:Destroy()
		end
	end
	fill(lists[name])
end

function Lobby.start(c)
	ctx = c
	gui = new("ScreenGui", { Name = "DiveLobby", ResetOnSpawn = false, Enabled = false }, ctx.player:WaitForChild("PlayerGui"))
	status = new("TextLabel", { Size = UDim2.new(1, 0, 0.15, 0), BackgroundTransparency = 1, TextColor3 = TEXT, Font = Enum.Font.Code, TextSize = 20 }, gui)

	local play = column("Play", 0.03, "DIVE")
	for _, name in { "Solo", "Public", "Private", "Leave" } do
		button(name, function()
			ctx.send(name)
		end, play).LayoutOrder = 0
	end
	difficultyButton = button("Difficulty", function()
		local i = table.find(DIFFICULTIES, lobbyState.difficulty) or 0
		ctx.send("Difficulty", { difficulty = DIFFICULTIES[i % #DIFFICULTIES + 1] })
	end, play)
	difficultyButton.LayoutOrder = 1

	lists.Crew = column("Crew", 0.35, "CREW")
	lists.Shop = column("Shop", 0.67, "TRAITS")
end

function Lobby.update(snap)
	gui.Enabled = snap.phase == "Lobby"
	if not gui.Enabled then
		return
	end
	lobbyState = snap.lobby or {}
	local l = lobbyState
	status.Text = string.format("%s · credits %s\n%s", tostring(l.state or "Idle"), tostring(l.credits or 0), tostring(l.notice or ""))
	difficultyButton.Text = "Difficulty: " .. tostring(l.difficulty or "?")

	-- Crew: invite players in this server who aren't members; join hosts who invited us.
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= ctx.player and not has(l.members, p.UserId) then
			table.insert(others, p.UserId)
		end
	end
	local members, invites = l.members or {}, l.invites or {}
	setList("Crew", table.concat(members, ",") .. "|" .. table.concat(others, ",") .. "|" .. table.concat(invites, ","), function(f)
		for _, id in members do
			new("TextLabel", { Name = "Row", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, TextColor3 = TEXT, Font = Enum.Font.Code, TextSize = 16, Text = (if id == l.hostId then "★ " else "· ") .. nameOf(id) }, f)
		end
		for _, id in others do
			button("Invite " .. nameOf(id), function()
				ctx.send("Invite", { userId = id })
			end, f)
		end
		for _, hostId in invites do
			button("Join " .. nameOf(hostId), function()
				ctx.send("Join", { hostId = hostId })
			end, f)
		end
	end)

	-- Shop: traits maps trait ID -> price.
	local traitIds = {}
	for id in l.traits or {} do
		table.insert(traitIds, id)
	end
	table.sort(traitIds)
	local shopKey = {}
	for _, id in traitIds do
		table.insert(shopKey, id .. (if has(l.owned, id) then "o" else "") .. (if has(l.equipped, id) then "e" else ""))
	end
	setList("Shop", table.concat(shopKey, ","), function(f)
		for _, id in traitIds do
			if has(l.equipped, id) then
				new("TextLabel", { Name = "Row", Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, TextColor3 = TEXT, Font = Enum.Font.Code, TextSize = 16, Text = id .. " (equipped)" }, f)
			elseif has(l.owned, id) then
				button("Equip " .. id, function()
					ctx.send("Equip", { trait = id })
				end, f)
			else
				button(string.format("Buy %s (%s)", id, tostring(l.traits[id])), function()
					ctx.send("Buy", { trait = id })
				end, f)
			end
		end
	end)
end

return Lobby
