-- Client feel layer for the dive. It only reads the Dive snapshot: station sounds and light flashes,
-- impact shakes, leak spray at broken frames, the list of required prompts that DiveClient outlines,
-- the predator arrival sting, repair arms, background music and the Wet lab hull status monitor.
-- Nothing here changes game state.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local PromptService = game:GetService("ProximityPromptService")
local arms = require(script.Parent:WaitForChild("DiveRepairArms"))

-- Roblox library sounds (Pro Sound Effects uploads). Swap any id after listening; nothing else changes.
local SFX = {
	click = {id = 9120090466, volume = .5},
	engineOn = {id = 9116921176, volume = .45, speed = .8, length = 2.4},
	engineOff = {id = 9116238554, volume = .45, speed = .75, from = 1.9, length = 2.2}, -- clip starts with a spin-up; skip to the wind-down
	sonarOn = {id = 9117060548, volume = .4},
	sonarOff = {id = 9120146680, volume = .35, speed = .8},
	aim = {id = 9118971641, volume = .3, speed = 1.3, length = .7},
	hammer = {id = 9114756916, volume = .55, length = .45},
	sealed = {id = 9116644054, volume = .55},
	plank = {id = 9114756916, volume = .3, speed = 1.5, length = .3},
	crack = {id = 9125668193, volume = .5, speed = 1.15},
	leak = {id = 9120592189, volume = .3},
	growl = {id = 9114628818, volume = .85, speed = .55},
	newTask = {id = 9120146680, volume = .25, speed = 1.35},
}
-- Background music, APM library tracks (Roblox-licensed). Played in turn, ducked under the angler and cinematics.
local MUSIC = {1843018526, 113239382558168} -- "The Uninvited", "Lying In Wait"
local MUSIC_VOLUME = {Lobby = .16, Dive = .26, Duck = .05}

local AMBER = Color3.fromRGB(255, 176, 74)
local GREEN = Color3.fromRGB(111, 238, 192)
local SIDES = {"FORE", "STBD", "AFT", "PORT"}

return function(screen, blocked)
	local site = workspace:WaitForChild("Thalassa")
	local stations = site:WaitForChild("Stations")
	local api = {required = {}}
	local prev = nil
	local leaks = {}
	local shake, rumble = 0, 0
	local lastArrival = {}

	local function find(path)
		local o = stations
		for name in path:gmatch("[^/]+") do o = o and o:FindFirstChild(name) end
		return o
	end
	local function partOf(o)
		if not o then return nil end
		if o:IsA("BasePart") then return o end
		return o:FindFirstChildWhichIsA("BasePart", true)
	end

	local function play(name, parent)
		local def = SFX[name]
		local s = Instance.new("Sound")
		s.Name = "Feedback" .. name
		s.SoundId = "rbxassetid://" .. def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.speed or 1
		s.RollOffMinDistance, s.RollOffMaxDistance = 8, 70
		s.Parent = parent or SoundService
		if def.from then s.TimePosition = def.from end
		s:Play()
		if def.length then
			task.delay(def.length, function()
				if s.Parent then TweenService:Create(s, TweenInfo.new(.25), {Volume = 0}):Play() end
			end)
		end
		task.delay((def.length or 7) + .5, s.Destroy, s)
	end

	local function flash(part, color)
		if not part then return end
		local light = Instance.new("PointLight")
		light.Name = "FeedbackFlash"
		light.Color, light.Range, light.Brightness = color, 9, 4
		light.Parent = part
		TweenService:Create(light, TweenInfo.new(.7, Enum.EasingStyle.Quad), {Brightness = 0}):Play()
		task.delay(.8, light.Destroy, light)
	end

	local function kick(amount) shake = math.min(1.2, shake + amount) end

	RunService:BindToRenderStep("DiveImpactShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0 and rumble <= 0 then return end
		local strength = shake * shake + (if rumble > 0 then .06 else 0)
		shake = math.max(0, shake - dt * 1.7)
		rumble = math.max(0, rumble - dt)
		if blocked() then return end
		local t = os.clock() * 17
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame
			* CFrame.new(math.noise(t, .3) * .22 * strength, math.noise(t, 1.7) * .22 * strength, 0)
			* CFrame.Angles(math.noise(t, 2.9) * .045 * strength, math.noise(t, 4.1) * .045 * strength, math.noise(t, 5.3) * .03 * strength)
	end)

	-- Leak spray: a jet, mist and a looping hiss at each broken frame, scaled by how bad it is.
	local function leakAt(i)
		if leaks[i] then return leaks[i] end
		local fracture = find("Section" .. i .. "/Fracture")
		local base = partOf(fracture)
		if not base then return nil end
		local center = if fracture:IsA("Model") then (fracture:GetBoundingBox()).Position else base.Position
		-- Aim along the authored spray point (the wall normal), not at the hull centre.
		local spray = find("Section" .. i .. "/Spray point")
		local inward = ((if spray then spray.Position else site.ShipEnvelope.Position) - center) * Vector3.new(1, 0, 1)
		inward = if inward.Magnitude > 0 then inward.Unit else Vector3.zAxis
		-- Shorten the throw where something stands in front of the frame (Section 2 faces the induction motor).
		local ray = RaycastParams.new()
		ray.FilterDescendantsInstances = {stations["Section" .. i]}
		local hit = workspace:Raycast(center + inward * .3, inward * 7, ray)
		local reach = math.clamp((if hit then hit.Distance else 7) / 7, .45, 1)
		local at = Instance.new("Attachment")
		at.Name = "LeakSpray"
		at.Parent = base
		at.WorldCFrame = CFrame.lookAt(center, center + inward - Vector3.new(0, .2, 0))
		local function emitter(name, texture, props)
			local e = Instance.new("ParticleEmitter")
			e.Name, e.Texture, e.Rate, e.EmissionDirection = name, texture, 0, Enum.NormalId.Front
			for k, v in props do e[k] = v end
			e.Parent = at
			return e
		end
		-- Smoke texture stretched along velocity reads as water streaks (the sparkle texture read as stars).
		local jet = emitter("Jet", "rbxasset://textures/particles/smoke_main.dds", {
			Color = ColorSequence.new(Color3.fromRGB(196, 232, 240)), LightEmission = .25, LightInfluence = .6,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-1.6),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .18), NumberSequenceKeypoint.new(1, .45)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .1), NumberSequenceKeypoint.new(1, 1)}),
			Speed = NumberRange.new(11 * reach, 18 * reach), SpreadAngle = Vector2.new(22, 14),
			Acceleration = Vector3.new(0, -36, 0), Drag = .7, Lifetime = NumberRange.new(.5, .9),
		})
		local sheet = emitter("Sheet", "rbxasset://textures/particles/smoke_main.dds", {
			Color = ColorSequence.new(Color3.fromRGB(150, 205, 220)), LightInfluence = .6, LightEmission = .1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .6), NumberSequenceKeypoint.new(1, 1.8)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .45), NumberSequenceKeypoint.new(1, 1)}),
			Speed = NumberRange.new(6 * reach, 10 * reach), SpreadAngle = Vector2.new(35, 12),
			Acceleration = Vector3.new(0, -30, 0), Lifetime = NumberRange.new(.4, .7),
		})
		local mist = emitter("Mist", "rbxasset://textures/particles/smoke_main.dds", {
			Color = ColorSequence.new(Color3.fromRGB(170, 210, 215)), LightInfluence = .7,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .7), NumberSequenceKeypoint.new(1, 1)}),
			Speed = NumberRange.new(2.5 * reach, 5 * reach), SpreadAngle = Vector2.new(40, 40), Lifetime = NumberRange.new(1.2, 2.2),
		})
		-- A run of water down the wall to the deck.
		local stream = emitter("Stream", "rbxasset://textures/particles/smoke_main.dds", {
			Color = ColorSequence.new(Color3.fromRGB(180, 222, 232)), LightInfluence = .6, LightEmission = .25,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-1.6),
			Size = NumberSequence.new(.22),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(1, 1)}),
			Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -40, 0),
			Lifetime = NumberRange.new(.4, .55),
		})
		local hiss = Instance.new("Sound")
		hiss.Name = "LeakHiss"
		hiss.SoundId = "rbxassetid://" .. SFX.leak.id
		hiss.Looped, hiss.Volume = true, 0
		hiss.RollOffMinDistance, hiss.RollOffMaxDistance = 5, 45
		hiss.Parent = at
		leaks[i] = {at = at, jet = jet, sheet = sheet, mist = mist, stream = stream, hiss = hiss}
		return leaks[i]
	end

	local function setLeak(i, level)
		local leak = if level > 0 then leakAt(i) else leaks[i]
		if not leak then return end
		local on = level > 0
		leak.jet.Rate = if on then 70 + 60 * level else 0
		leak.sheet.Rate = if on then 18 + 18 * level else 0
		leak.mist.Rate = if on then 8 + 7 * level else 0
		leak.stream.Rate = if on then 30 + 20 * level else 0
		if level > 0 and not leak.hiss.IsPlaying then leak.hiss:Play() end
		TweenService:Create(leak.hiss, TweenInfo.new(.4), {Volume = if level > 0 then SFX.leak.volume + .1 * level else 0}):Play()
	end

	-- Arrival sting: banner, red edge pulse, light dip, growl and a low rumble. Controls stay live.
	local overlay = Instance.new("Frame")
	overlay.Name = "ArrivalSting"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 40
	overlay.Visible = false
	overlay.Parent = screen
	local edges = {}
	for _, e in {{UDim2.fromScale(1, .22), UDim2.fromScale(0, 0), 90}, {UDim2.fromScale(1, .22), UDim2.fromScale(0, .78), -90},
		{UDim2.fromScale(.16, 1), UDim2.fromScale(0, 0), 0}, {UDim2.fromScale(.16, 1), UDim2.fromScale(.84, 0), 180}} do
		local f = Instance.new("Frame")
		f.Size, f.Position = e[1], e[2]
		f.BackgroundColor3 = Color3.fromRGB(150, 12, 12)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.ZIndex = 40
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
		g.Parent = f
		f.Parent = overlay
		table.insert(edges, f)
	end
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(.5, .5)
	banner.Size = UDim2.fromOffset(520, 92)
	banner.BackgroundColor3 = Color3.fromRGB(8, 14, 17)
	banner.BackgroundTransparency = .2
	banner.BorderSizePixel = 0
	banner.ZIndex = 41
	banner.Parent = overlay
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = AMBER, 2
	stroke.Parent = banner
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size, title.Position = UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 10)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 34
	title.TextColor3 = AMBER
	title.ZIndex = 42
	title.Parent = banner
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size, hint.Position = UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 56)
	hint.Font = Enum.Font.Code
	hint.TextSize = 17
	hint.TextColor3 = Color3.fromRGB(214, 240, 232)
	hint.ZIndex = 42
	hint.Parent = banner
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DiveArrivalGrade"
	grade.Parent = Lighting
	local stingId = 0

	-- The angler gets no bearing: its model can still be parked when the snapshot arrives, and its groan is the directional cue.
	local function sting(kind, side, easy)
		if (lastArrival[kind] or -99) > os.clock() - 8 then return end
		lastArrival[kind] = os.clock()
		stingId += 1
		local id = stingId
		title.Text = if kind == "Angler" then "ANGLER APPROACHING" else "GIANT SQUID CLOSING"
		-- Instruction text is Easy-only, as in the GDD; other difficulties get the bearing alone.
		local fix = if not easy then nil elseif kind == "Angler" then "CUT THE ENGINE AND LET IT PASS" else "LAMP ON, AIM AT ITS BEARING"
		hint.Text = if side and fix then "BEARING " .. side .. "  •  " .. fix elseif side then "BEARING " .. side else fix or ""
		overlay.Visible = true
		banner.Position = UDim2.fromScale(.5, .08)
		banner.BackgroundTransparency, stroke.Transparency, title.TextTransparency, hint.TextTransparency = 1, 1, 1, 1
		local pop = TweenInfo.new(.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(banner, pop, {Position = UDim2.fromScale(.5, .2), BackgroundTransparency = .2}):Play()
		for _, o in {stroke, title, hint} do
			TweenService:Create(o, TweenInfo.new(.3), if o == stroke then {Transparency = 0} else {TextTransparency = 0}):Play()
		end
		for _, f in edges do
			f.BackgroundTransparency = 1
			TweenService:Create(f, TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true), {BackgroundTransparency = .35}):Play()
		end
		TweenService:Create(grade, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true, .1),
			{Brightness = -.22, TintColor = Color3.fromRGB(255, 205, 205)}):Play()
		play("growl")
		kick(.3)
		rumble = 1.8
		task.delay(3.4, function()
			if stingId ~= id then return end
			local out = TweenInfo.new(.6)
			TweenService:Create(banner, out, {BackgroundTransparency = 1}):Play()
			for _, o in {stroke, title, hint} do
				TweenService:Create(o, out, if o == stroke then {Transparency = 1} else {TextTransparency = 1}):Play()
			end
			task.delay(.65, function() if stingId == id then overlay.Visible = false end end)
		end)
	end

	-- Background music: plays from the lobby on, louder in a dive, ducked while the angler is near or a cinematic runs.
	local music = Instance.new("Sound")
	music.Name = "DiveMusic"
	music.Volume = 0
	music.Parent = SoundService
	local track = 1
	local musicMode = "Lobby"
	local function nextTrack()
		music.SoundId = "rbxassetid://" .. MUSIC[track]
		track = track % #MUSIC + 1
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	nextTrack()
	RunService.Heartbeat:Connect(function(dt)
		local goal = MUSIC_VOLUME[musicMode]
		if musicMode == "Dive" and (blocked() or (prev and (prev.shark or 0) > 0)) then goal = MUSIC_VOLUME.Duck end
		music.Volume += (goal - music.Volume) * math.min(1, dt * 1.5)
	end)

	-- Wet lab hull status monitor: every client fills it from its own snapshot, so all players see the same values.
	local readout
	local function gauge(key, n)
		-- Looked up lazily: with streaming on, the Wet lab may not be loaded yet (or may stream out and back).
		if not (readout and readout:IsDescendantOf(site)) then
			local monitor = site:FindFirstChild("Hull status monitor", true)
			readout = monitor and monitor:FindFirstChild("Readout", true)
			if not readout then return end
		end
		n = math.clamp(n or 0, 0, 100)
		local color = if n <= 20 then Color3.fromRGB(255, 84, 74) elseif n < 45 then AMBER else GREEN
		local value, bar = readout:FindFirstChild(key .. "Value", true), readout:FindFirstChild(key .. "Bar", true)
		if value then value.Text, value.TextColor3 = math.floor(n + .5) .. "%", color end
		if bar then bar.Size, bar.BackgroundColor3 = UDim2.fromScale(n / 100, 1), color end
	end

	-- Prompts that solve whatever is wrong right now. DiveClient draws these on top, in amber.
	local function requiredFor(p)
		local need = {}
		if p.alive == false then return need end
		if p.outside then
			if p.carryingArtifact then need.Return = true end
			return need
		end
		if (p.shark or 0) > 0 and p.engine then need.Engine = true end
		if api.restartEngine and not p.engine and (p.shark or 0) == 0 then need.Engine = true end
		if (p.squid or 0) > 0 and (not p.light or p.aim~=p.squidSide) then need.Light=true end
		for i, open in p.cracks or {} do
			if open then need["Repair" .. i] = true end
		end
		for i, severity in p.breaches or {} do
			if severity > 0 then need[if (p.planks or 0) > 0 then "Patch" .. i else "Planks"] = true end
		end
		if p.boarded and not p.hasExtinguisher then need.Extinguisher = true end
		if (p.swarm or 0) > 0 then need.Airlock = true end
		return need
	end

	function api.update(p)
		local was = prev or p
		local ship = p.outside ~= true
		musicMode = "Dive"
		gauge("Power", p.battery)
		gauge("Hull", p.hull)
		if was.engine ~= p.engine then
			local lever = partOf(find("ENGINE/EngineLever"))
			play(if p.engine then "engineOn" else "engineOff", lever)
			flash(lever, if p.engine then GREEN else AMBER)
			if ship then kick(if p.engine then .12 else .22) end
		end
		if (was.shark or 0) > 0 and (p.shark or 0) == 0 and not p.engine and (p.anglerStrikes or 0) == (was.anglerStrikes or 0) then
			api.restartEngine = true
		end
		if p.engine or (p.shark or 0) > 0 then api.restartEngine = false end
		if was.light ~= p.light then
			local lamp = partOf(find("OPTICS/Light"))
			play("click", lamp)
			flash(lamp, if p.light then Color3.fromRGB(255, 244, 214) else AMBER)
		end
		if was.aim ~= p.aim then play("aim", partOf(find("OPTICS/Light"))) end
		if was.sonarOn ~= p.sonarOn then
			local sonar = partOf(find("SONAR/SonarScreen"))
			play(if p.sonarOn then "sonarOn" else "sonarOff", sonar)
			flash(sonar, if p.sonarOn then GREEN else AMBER)
		end
		for i = 1, 3 do
			local crackNow, crackWas = (p.cracks or {})[i], (was.cracks or {})[i]
			local breachNow, breachWas = (p.breaches or {})[i] or 0, (was.breaches or {})[i] or 0
			local fracture = partOf(find("Section" .. i .. "/Fracture"))
			if prev and crackNow and not crackWas then play("crack", fracture) if ship then kick(.3) end end
			if prev and breachNow > breachWas then play("crack", fracture) if ship then kick(.85) end end
			if prev and ((crackWas and not crackNow) or (breachNow < breachWas)) then
				play(if breachNow > 0 then "hammer" else "sealed", fracture)
				flash(fracture, GREEN)
				if ship then kick(.15) end
				-- Covers the Welder trait too: its repair fires on the server mid-hold.
				if crackWas and not crackNow and arms.kind() == "plate" then arms.stop(true) end
			end
			setLeak(i, if breachNow > 0 then 1 + breachNow * .5 elseif crackNow then .6 else 0)
		end
		if prev and (p.planks or 0) > (was.planks or 0) then play("plank", partOf(find("Breach repair supplies"))) end
		local repairNow, repairWas = p.breachRepair, was.breachRepair
		if repairNow and repairWas and repairNow.id == repairWas.id and (repairNow.completed or 0) > (repairWas.completed or 0) then
			play("hammer", partOf(find("Section" .. repairNow.section .. "/Breach patch point")))
			kick(.1)
			arms.tap()
		end
		-- Plank patch arms live exactly as long as the server's repair challenge.
		if repairNow and (p.alive ~= false) and arms.kind() ~= "plank" then
			arms.start("plank")
		elseif not repairNow and arms.kind() == "plank" then
			local patched = false
			for i = 1, 3 do
				if ((p.breaches or {})[i] or 0) < ((was.breaches or {})[i] or 0) then patched = true end
			end
			arms.stop(patched)
		end
		if p.alive == false or p.outside then arms.stop(false, true) end
		if prev and ship and (was.hull or 0) - (p.hull or 0) >= 4 then kick(math.clamp(((was.hull or 0) - (p.hull or 0)) / 30, .25, .9)) end
		if prev and p.boarded and not was.boarded then kick(.7) end
		if prev and (was.shark or 0) == 0 and (p.shark or 0) > 0 then
			sting("Angler", nil, p.difficulty == "Easy")
		end
		if prev and (was.squid or 0) == 0 and (p.squid or 0) > 0 then sting("Squid", SIDES[p.squidSide], p.difficulty == "Easy") end
		local need = requiredFor(p)
		for action in need do
			if prev and not api.required[action] then play("newTask") break end
		end
		api.required = need
		prev = p
	end

	function api.reset()
		prev = nil
		api.required = {}
		api.restartEngine = false
		shake, rumble = 0, 0
		for i in leaks do setLeak(i, 0) end
		stingId += 1
		overlay.Visible = false
		arms.stop(false, true)
		musicMode = "Lobby"
		gauge("Power", 100)
		gauge("Hull", 100)
	end

	-- A cinematic takes the camera; drop whatever the arms hold.
	function api.stopArms()
		arms.stop(false, true)
	end

	-- Instant click when a station prompt fires; the state change sound follows with the next snapshot.
	PromptService.PromptTriggered:Connect(function(prompt)
		if prev and prompt:IsDescendantOf(site) then play("click", partOf(prompt.Parent)) end
		if arms.kind() == "plate" then arms.stop(true) end
	end)

	-- Crack repair: arms lift a replacement plate for the length of the hold; letting go cancels and removes them.
	PromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local action = prompt:GetAttribute("Action")
		if not prev or type(action) ~= "string" or not action:match("^Repair[1-3]$") or not prompt:IsDescendantOf(site) then return end
		local fracture = partOf(find("Section" .. action:sub(-1) .. "/Fracture"))
		arms.start("plate", prompt.HoldDuration, function() play("hammer", fracture) kick(.05) end)
	end)
	PromptService.PromptButtonHoldEnded:Connect(function()
		if arms.kind() == "plate" then arms.stop(false) end
	end)

	return api
end
