-- Sparse dive HUD: gauges, sonar scope, EVA oxygen and cut timing bar, results screen.
local RunService = game:GetService("RunService")

local Hud = {}

local TEXT = Color3.fromRGB(190, 210, 200)
local WARN = Color3.fromRGB(230, 90, 70)
local DIVE_PHASES = { Descent = true, Seabed = true, Ascent = true }
local SCOPE_RANGE = 210 -- Voyage sonarRange

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

local function drawScope(returns)
	for _, child in scope:GetChildren() do
		if child.Name == "Blip" then
			child:Destroy()
		end
	end
	if type(returns) ~= "table" then
		return
	end
	for _, r in returns do
		local bearing = type(r) == "table" and r.bearing
		local dist = type(r) == "table" and (r.distance or r.range)
		if type(bearing) == "number" and type(dist) == "number" then
			local rel = math.clamp(dist / SCOPE_RANGE, 0, 1) * 0.5
			local a = math.rad(bearing)
			new("Frame", {
				Name = "Blip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.fromScale(0.5 + math.sin(a) * rel, 0.5 - math.cos(a) * rel),
				BackgroundColor3 = Color3.fromRGB(120, 255, 160),
				BorderSizePixel = 0,
			}, scope)
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

local function stepCut()
	if not challenge or not cutBar.Visible then
		return
	end
	local period = challenge.period or 1
	local t = ((workspace:GetServerTimeNow() - (challenge.startedAt or 0)) / period) % 1
	cutNeedle.Position = UDim2.fromScale(t, 0.5)
end

function Hud.start(c)
	ctx = c
	gui = new("ScreenGui", { Name = "DiveHud", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false }, ctx.player:WaitForChild("PlayerGui"))

	gauges = label({ Size = UDim2.fromOffset(360, 120), Position = UDim2.fromOffset(16, 16), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, gui)
	warning = label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.18), TextColor3 = WARN, TextSize = 28, Text = "" }, gui)

	scope = new("Frame", {
		Size = UDim2.fromOffset(140, 140),
		Position = UDim2.new(1, -156, 0, 16),
		BackgroundColor3 = Color3.fromRGB(5, 20, 12),
		BackgroundTransparency = 0.3,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, scope)

	evaPanel = new("Frame", { Size = UDim2.fromOffset(320, 80), Position = UDim2.new(0.5, -160, 1, -120), BackgroundTransparency = 1, Visible = false }, gui)
	local oxygen = new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(20, 30, 35), BorderSizePixel = 0 }, evaPanel)
	oxygenFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 230), BorderSizePixel = 0 }, oxygen)

	cutBar = new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 30), BackgroundColor3 = Color3.fromRGB(20, 30, 35), BorderSizePixel = 0, Visible = false }, evaPanel)
	cutArc = new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 200, 120), BorderSizePixel = 0 }, cutBar)
	cutArcWrap = new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 200, 120), BorderSizePixel = 0 }, cutBar)
	cutNeedle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 3, 1, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, cutBar)
	label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 58), TextSize = 14, Text = "B brace · F cut · R return · C cancel" }, evaPanel)

	results = label({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.2, BackgroundColor3 = Color3.new(0, 0, 0), TextSize = 32, Visible = false }, gui)

	RunService.RenderStepped:Connect(stepCut)
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
	drawScope(dive.returns)

	local eva = ctx.myEva(snap)
	local outside = eva ~= nil and eva.mode ~= "Inside"
	evaPanel.Visible = outside
	warning.Text = if outside and eva.predatorDanger then "SOMETHING IS CLOSE"
		elseif snap.notice then tostring(snap.notice)
		elseif (dive.battery or 100) <= 15 then "BATTERY LOW"
		else ""
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

-- Self-check of arc wrapping.
do
	local s = Hud.arcSegments(0.9, 0.2)
	assert(#s == 2 and math.abs(s[1][1] - 0.9) < 1e-9 and math.abs(s[2][2] - 0.1) < 1e-9)
	assert(#Hud.arcSegments(0.2, 0.3) == 1)
end

return Hud
