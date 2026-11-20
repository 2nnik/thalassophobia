-- Sparse dive HUD: gauges, stacked warnings, sonar scope, EVA oxygen and cut timing bar,
-- results screen. Field meanings follow shared/Voyage.md and shared/EVA.md.
local RunService = game:GetService("RunService")

local Hud = {}

local TEXT = Color3.fromRGB(190, 210, 200)
local WARN = Color3.fromRGB(230, 90, 70)
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }
local SCOPE_RANGE = 210 -- Voyage sonarRange
local PULSE_FADE = 2.5 -- seconds for an echo to fade; Voyage pulsePeriod is 2
local KIND_COLORS = {
	Angler = Color3.fromRGB(255, 90, 70),
	Squid = Color3.fromRGB(255, 90, 70),
	Crawler = Color3.fromRGB(255, 90, 70),
	Pursuer = Color3.fromRGB(255, 40, 40),
	Diver = Color3.fromRGB(90, 220, 255),
	Port = Color3.fromRGB(230, 210, 90),
	Starboard = Color3.fromRGB(230, 210, 90),
	Stern = Color3.fromRGB(230, 210, 90),
	Keel = Color3.fromRGB(230, 210, 90),
}
local TERRAIN_COLOR = Color3.fromRGB(110, 130, 120)

local ctx
local gui: ScreenGui
local gauges: TextLabel
local warning: TextLabel
local scope: Frame
local evaPanel: Frame
local oxygenFill: Frame
local cutBar: Frame
local cutArc: Frame
local cutArcWrap: Frame
local cutNeedle: Frame
local results: TextLabel
local challenge: { [string]: any }? = nil
local lastPulse: number? = nil
local pulseAt = 0

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(props, parent): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.Code
	props.TextSize = props.TextSize or 18
	return new("TextLabel", props, parent)
end

local function onOff(v)
	return if v then "ON" else "off"
end

local function secs(deadline, now)
	return if type(deadline) == "number" then string.format(" (%ds)", math.max(0, math.ceil(deadline - now))) else ""
end

-- Every active threat and shortage, most urgent first, so overlapping events all show.
function Hud.warnings(snap, userId: number, now: number): { string }
	local list = {}
	local dive = snap.dive or {}
	local actors = dive.actors or {}

	local eva = snap.eva
	local mine = type(eva) == "table" and eva.userId == userId and eva.mode ~= "Inside"
	if mine and eva.predatorDanger then
		table.insert(list, "SOMETHING IS CLOSE")
	end
	if mine and (eva.oxygen or 0) <= 0.3 * (eva.oxygenMax or 1) then
		table.insert(list, string.format("OXYGEN %d%% · RETURN", math.floor(100 * (eva.oxygen or 0) / math.max(eva.oxygenMax or 1, 1e-6))))
	end
	if not mine and type(eva) == "table" and eva.userId and (dive.diverDanger or 0) >= 0.3 then
		table.insert(list, "DIVER IN DANGER")
	end

	local angler = actors.Angler
	if angler and angler.state == "Approach" then
		table.insert(list, (if dive.engine then "ANGLER CLOSING · ENGINE OFF" else "ANGLER CLOSING · STAY QUIET") .. secs(angler.deadline, now))
	end
	local squid = actors.Squid
	if squid and squid.state == "Approach" then
		table.insert(list, "SQUID CLOSING · LIGHT IT" .. secs(squid.deadline, now))
	end
	local crawler = actors.Crawler
	if crawler and crawler.state == "Attached" then
		table.insert(list, string.format("CRAWLER ON %s HULL · SEAL IT", string.upper(tostring(crawler.site or "?"))) .. secs(crawler.deadline, now))
	elseif crawler and crawler.state == "Boarded" then
		table.insert(list, string.format("CRAWLER IN %s · SPRAY IT", string.upper(tostring(crawler.room or "?"))) .. secs(crawler.deadline, now))
	end
	local gap = tonumber(dive.pursuerGap)
	if snap.phase == "Ascent" and gap and actors.Pursuer and actors.Pursuer.visible then
		local closing = actors.Pursuer.state == "Closing"
		table.insert(list, string.format("PURSUER %s · GAP %d%s", if closing then "CLOSING" else "FALLING BACK", math.floor(gap), if closing then " · KEEP RISING" else ""))
	end

	local cracks = {}
	for site, severity in dive.fractures or {} do
		if type(severity) == "number" and severity > 0 then
			table.insert(cracks, string.format("%s %d", tostring(site), severity))
		end
	end
	if #cracks > 0 then
		table.sort(cracks)
		table.insert(list, "FRACTURES " .. table.concat(cracks, " · "))
	end
	if dive.hull and dive.hull <= 30 then
		table.insert(list, string.format("HULL %d%%", math.floor(dive.hull)))
	end
	if dive.battery and dive.battery <= 20 then
		table.insert(list, string.format("BATTERY %d%%", math.floor(dive.battery)))
	end
	if snap.notice then
		table.insert(list, tostring(snap.notice))
	end
	return list
end

-- Scope position (0..1 scale) for an echo; 0.5 radius is SCOPE_RANGE.
function Hud.scopePoint(bearing: number, range: number): (number, number)
	local rel = math.clamp(range / SCOPE_RANGE, 0, 1) * 0.5
	local a = math.rad(bearing)
	return 0.5 + math.sin(a) * rel, 0.5 - math.cos(a) * rel
end

local function drawScope(returns)
	for _, child in scope:GetChildren() do
		if child.Name == "Blip" then
			child:Destroy()
		end
	end
	if type(returns) ~= "table" then
		return
	end
	for id, r in returns do
		if type(r) == "table" and type(r.bearing) == "number" and type(r.range) == "number" then
			local x, y = Hud.scopePoint(r.bearing, r.range)
			local color = KIND_COLORS[r.kind] or KIND_COLORS[tostring(id)] or TERRAIN_COLOR
			local blip = new("Frame", {
				Name = "Blip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(7, 7),
				Position = UDim2.fromScale(x, y),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, scope)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, blip)
			local elev = tonumber(r.elevation) or 0
			if math.abs(elev) >= 5 then
				label({ Name = "Elevation", Size = UDim2.fromOffset(30, 10), Position = UDim2.fromOffset(8, -2), TextSize = 10, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s%d", if elev > 0 then "↑" else "↓", math.floor(math.abs(elev))) }, blip)
			end
		end
	end
end

-- Arc in turns [start, start+width) may wrap past 1, so it is drawn as up to two frames.
function Hud.arcSegments(start: number, width: number): { { number } }
	start = start % 1
	if start + width <= 1 then
		return { { start, width } }
	end
	return { { start, 1 - start }, { 0, start + width - 1 } }
end

local function render()
	local now = workspace:GetServerTimeNow()
	if challenge and cutBar.Visible then
		local period = challenge.period or 1
		local t = ((now - (challenge.startedAt or 0)) / period) % 1
		cutNeedle.Position = UDim2.fromScale(t, 0.5)
	end
	-- Echoes fade until the next pulse replaces them.
	local fade = math.clamp((now - pulseAt) / PULSE_FADE, 0, 0.85)
	for _, child in scope:GetChildren() do
		if child.Name == "Blip" then
			child.BackgroundTransparency = fade
			local tag = child:FindFirstChild("Elevation")
			if tag then
				tag.TextTransparency = fade
			end
		end
	end
end

function Hud.start(c)
	ctx = c
	gui = new("ScreenGui", { Name = "DiveHud", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false }, ctx.player:WaitForChild("PlayerGui"))

	gauges = label({ Size = UDim2.fromOffset(360, 120), Position = UDim2.fromOffset(16, 16), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, gui)
	warning = label({ Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromScale(0, 0.16), TextColor3 = WARN, TextSize = 24, TextYAlignment = Enum.TextYAlignment.Top, Text = "" }, gui)

	scope = new("Frame", {
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.new(1, -176, 0, 16),
		BackgroundColor3 = Color3.fromRGB(5, 20, 12),
		BackgroundTransparency = 0.3,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, scope)
	for _, r in { 0.5, 0.25 } do
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(r * 2, r * 2), BackgroundTransparency = 1 }, scope)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		new("UIStroke", { Color = Color3.fromRGB(40, 110, 70), Transparency = 0.4 }, ring)
	end
	-- Ship at the centre, nose toward the top (bearing 0 = fore).
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 9), BackgroundColor3 = TEXT, BorderSizePixel = 0 }, scope)

	evaPanel = new("Frame", { Size = UDim2.fromOffset(320, 80), Position = UDim2.new(0.5, -160, 1, -120), BackgroundTransparency = 1, Visible = false }, gui)
	local oxygen = new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(20, 30, 35), BorderSizePixel = 0 }, evaPanel)
	oxygenFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 230), BorderSizePixel = 0 }, oxygen)

	cutBar = new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 30), BackgroundColor3 = Color3.fromRGB(20, 30, 35), BorderSizePixel = 0, Visible = false }, evaPanel)
	cutArc = new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 200, 120), BorderSizePixel = 0 }, cutBar)
	cutArcWrap = new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 200, 120), BorderSizePixel = 0 }, cutBar)
	cutNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 3, 1, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, cutBar)
	label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 58), TextSize = 14, Text = "Swim: Brace · Return   Braced: Cut on green · Cancel" }, evaPanel)

	results = label({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.2, BackgroundColor3 = Color3.new(0, 0, 0), TextSize = 32, Visible = false }, gui)

	RunService.RenderStepped:Connect(render)
end

function Hud.update(snap)
	local dive = snap.dive or {}
	gui.Enabled = DIVE_PHASES[snap.phase] == true or snap.phase == "Results"

	gauges.Text = string.format(
		"%s  %dm (deepest %dm)\nBATTERY %d%%   HULL %d%%\nENGINE %s  LIGHT %s  SONAR %s",
		snap.phase,
		math.floor(dive.depth or 0),
		math.floor(dive.deepest or dive.depth or 0),
		math.floor(dive.battery or 0),
		math.floor(dive.hull or 0),
		onOff(dive.engine),
		onOff(dive.searchlight),
		onOff(dive.sonar)
	)

	scope.Visible = dive.sonar == true
	if not scope.Visible then
		lastPulse = nil
	elseif dive.pulseAt ~= lastPulse then
		lastPulse = dive.pulseAt
		pulseAt = tonumber(dive.pulseAt) or snap.time or 0
		drawScope(dive.returns)
	end

	warning.Text = table.concat(Hud.warnings(snap, ctx.player.UserId, workspace:GetServerTimeNow()), "\n")

	local eva = ctx.myEva(snap)
	local outside = eva ~= nil and eva.mode ~= "Inside"
	evaPanel.Visible = outside
	if outside then
		oxygenFill.Size = UDim2.fromScale(math.clamp((eva.oxygen or 0) / math.max(eva.oxygenMax or 1, 1e-6), 0, 1), 1)
		challenge = type(eva.challenge) == "table" and eva.challenge or nil
		cutBar.Visible = challenge ~= nil
		if challenge then
			local segs = Hud.arcSegments(challenge.arcStart or 0, challenge.arcWidth or 0)
			for i, frame in { cutArc, cutArcWrap } do
				local seg = segs[i]
				frame.Visible = seg ~= nil
				if seg then
					frame.Position = UDim2.fromScale(seg[1], 0)
					frame.Size = UDim2.fromScale(seg[2], 1)
				end
			end
		end
	else
		challenge = nil
	end

	-- The server sends Results with dive=nil and the summary in snap.result.
	local result = snap.result or dive
	results.Visible = snap.phase == "Results"
	if results.Visible then
		results.Text = string.format("%s\n%s\ndeepest %dm", if result.survived then "YOU SURFACED" else "LOST AT DEPTH", tostring(result.reason or ""), math.floor(result.deepest or 0))
	end
end

do
	-- Arc wrapping.
	local s = Hud.arcSegments(0.9, 0.2)
	assert(#s == 2 and math.abs(s[1][1] - 0.9) < 1e-9 and math.abs(s[2][2] - 0.1) < 1e-9)
	assert(#Hud.arcSegments(0.2, 0.3) == 1)

	-- Scope: fore is up, starboard is right, full range on the rim.
	local x, y = Hud.scopePoint(0, 210)
	assert(math.abs(x - 0.5) < 1e-9 and math.abs(y - 0) < 1e-9)
	x, y = Hud.scopePoint(90, 105)
	assert(math.abs(x - 0.75) < 1e-9 and math.abs(y - 0.5) < 1e-9)

	-- Overlapping threats all show (Voyage.md: angler warning and Pursuer gap together).
	local w = Hud.warnings({
		phase = "Ascent",
		dive = {
			engine = true,
			battery = 12,
			hull = 80,
			pursuerGap = 42.7,
			fractures = { Keel = 2, Port = 0 },
			actors = {
				Angler = { state = "Approach", visible = true, deadline = 103.2 },
				Pursuer = { state = "Closing", visible = true },
				Crawler = { state = "Boarded", visible = true, room = "Lab" },
			},
		},
		eva = { mode = "Inside", predatorDanger = false },
		notice = "Hold still",
	}, 1, 100)
	assert(table.concat(w, "|") == "ANGLER CLOSING · ENGINE OFF (4s)|CRAWLER IN LAB · SPRAY IT|PURSUER CLOSING · GAP 42 · KEEP RISING|FRACTURES Keel 2|BATTERY 12%|Hold still", table.concat(w, "|"))

	-- Diver's own warnings; crewmates see the danger instead.
	local diverSnap = { phase = "Descent", dive = { diverDanger = 0.6 }, eva = { mode = "Swimming", userId = 7, oxygen = 10, oxygenMax = 55, predatorDanger = true } }
	assert(table.concat(Hud.warnings(diverSnap, 7, 0), "|") == "SOMETHING IS CLOSE|OXYGEN 18% · RETURN")
	assert(table.concat(Hud.warnings(diverSnap, 8, 0), "|") == "DIVER IN DANGER")
	assert(#Hud.warnings({ phase = "Lobby" }, 1, 0) == 0)
end

return Hud
