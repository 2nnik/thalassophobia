local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local EVA = {}
EVA.__index = EVA

local Tuning = table.freeze({
	speed = 16,
	tetherLength = 83,
	bodyRadius = 1.55,
	airlockReach = 9,
	patchReach = 7,
	inputTimeout = 0.65,
	oxygen = 55,
	extendedOxygen = 82,
	dialPeriod = 1.7,
	arcWidth = 0.23,
	maxRewind = 0.22,
	clockTolerance = 0.04,
	contactThreshold = 0.70,
	contactDrain = 3,
})
EVA.Tuning = Tuning

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function resumeSwimming(session)
	session.site = nil
	session.patch = nil
	session.challenge = nil
	session.direction = Vector3.zero
end

local function living(session)
	return session.player.Character == session.character
		and session.root:IsDescendantOf(session.character)
		and session.humanoid.Health > 0
end

local function exteriorFrame(self)
	local exit = self.stations.AirlockExit
	if exit then return exit.CFrame end
	local hatch = self.stations.Airlock
	-- Older layouts may only have an interior console. The nearest side-site marker
	-- identifies an exterior hull surface even when the console faces down a corridor.
	local normals = {Port = -self.shipCFrame.RightVector, Starboard = self.shipCFrame.RightVector, Stern = -self.shipCFrame.LookVector}
	local closest, normal, shortest = nil, nil, math.huge
	for _, site in ipairs({"Port", "Starboard", "Stern"}) do
		local marker = self.sites[site]
		local distance = marker and (marker.Position - hatch.Position).Magnitude
		if distance and distance < shortest then
			closest, normal, shortest = marker, normals[site], distance
		end
	end
	if closest then
		local position = closest.Position + normal * (Tuning.bodyRadius + 2)
		return CFrame.lookAt(position, position + normal, self.shipCFrame.UpVector)
	end
	return hatch.CFrame * CFrame.new(0, 0, -8)
end

function EVA.new(shipCFrame, stations, sites)
	return setmetatable({
		shipCFrame = shipCFrame,
		stations = stations,
		sites = sites,
		random = Random.new(),
	}, EVA)
end

function EVA:_exit(player, now, voyage)
	if self.session then return false, "Airlock occupied" end
	local station = self.stations.Airlock
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not station or not root or not humanoid or humanoid.Health <= 0 or root.Anchored
		or (station.Position - root.Position).Magnitude > Tuning.airlockReach then
		return false, "Stand at the airlock"
	end

	local exit = exteriorFrame(self)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local oxygenMax = voyage.traits.Oxygen and Tuning.extendedOxygen or Tuning.oxygen
	local session = {
		player = player, character = character, root = root, humanoid = humanoid,
		returnPose = root.CFrame, autoRotate = humanoid.AutoRotate,
		anchor = exit.Position, position = exit.Position, direction = Vector3.zero, inputAt = now,
		oxygen = oxygenMax, oxygenMax = oxygenMax, danger = false,
		params = params,
	}
	self.session = session
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	root.CFrame = exit
	humanoid.AutoRotate = false

	local anchor = self.stations.AirlockExit or station
	local fixed = Instance.new("Attachment")
	fixed.Name = "EVATetherAnchor"
	fixed.Position = anchor.CFrame:PointToObjectSpace(exit.Position)
	fixed.Parent = anchor
	session.fixed = fixed
	local harness = Instance.new("Attachment")
	harness.Name = "EVATetherHarness"
	harness.Position = Vector3.new(0, 0, 0.8)
	harness.Parent = root
	session.harness = harness
	local tether = Instance.new("Beam")
	tether.Name = "EVATether"
	tether.Attachment0 = fixed
	tether.Attachment1 = harness
	tether.Width0 = 0.12
	tether.Width1 = 0.12
	tether.FaceCamera = true
	tether.Color = ColorSequence.new(Color3.fromRGB(218, 143, 60))
	tether.Parent = fixed

	session.died = humanoid.Died:Connect(function()
		if self.session == session then self:release(player) end
	end)
	session.removing = player.CharacterRemoving:Connect(function(removed)
		if self.session == session and removed == character then self:release(player) end
	end)
	return true
end

function EVA:release(player)
	local session = self.session
	if not session or (player and player ~= session.player) then return false end
	self.session = nil
	session.died:Disconnect()
	session.removing:Disconnect()
	session.fixed:Destroy()
	session.harness:Destroy()
	if session.root.Parent then
		if living(session) then session.root.CFrame = session.returnPose end
		session.root.AssemblyLinearVelocity = Vector3.zero
		session.root.AssemblyAngularVelocity = Vector3.zero
		session.root.Anchored = false
	end
	if session.humanoid.Parent then session.humanoid.AutoRotate = session.autoRotate end
	return true
end

local function reachable(self, session, site)
	local marker = self.sites[site]
	if not marker then return false end
	local direction = marker.Position - session.position
	if direction.Magnitude > Tuning.patchReach then return false end
	if direction.Magnitude < 0.1 then return true end
	local hit = Workspace:Raycast(session.position, direction, session.params)
	return not hit or hit.Instance == marker or hit.Distance >= direction.Magnitude - 0.5
end

function EVA:_brace(session, site, now, voyage)
	if session.challenge then return false, "Already braced" end
	if type(site) ~= "string" then return false, "Choose a colony" end
	local patch = voyage.patches[site]
	if not patch or not patch.active or not reachable(self, session, site) then
		return false, "Approach an attached colony"
	end
	session.direction = Vector3.zero
	session.site = site
	session.patch = patch
	session.challenge = {
		id = HttpService:GenerateGUID(false),
		startedAt = now,
		period = Tuning.dialPeriod,
		arcStart = self.random:NextNumber(0.15, 0.92 - Tuning.arcWidth),
		arcWidth = Tuning.arcWidth,
	}
	session.lastSequence = 0
	session.lastCycle = -1
	return true
end

function EVA:_cut(session, payload, now, voyage)
	local challenge = session.challenge
	if not challenge or payload.challengeId ~= challenge.id then return false, "Expired dial" end
	if session.patch ~= voyage.patches[session.site] or session.patch.active == false
		or not reachable(self, session, session.site) then
		resumeSwimming(session)
		return false, "Colony unavailable"
	end
	local strike = payload.strikeTime
	local sequence = payload.sequence
	if not finite(sequence) or sequence <= session.lastSequence or sequence % 1 ~= 0
		or not finite(strike) or strike < challenge.startedAt
		or strike < now - Tuning.maxRewind or strike > now + Tuning.clockTolerance then
		return false, "Stale strike"
	end
	local turns = (math.min(strike, now) - challenge.startedAt) / challenge.period
	local cycle = math.floor(turns)
	if cycle <= session.lastCycle then return false, "Wait for the next rotation" end
	session.lastSequence = sequence
	session.lastCycle = cycle
	local phase = turns - cycle
	if phase < challenge.arcStart or phase > challenge.arcStart + challenge.arcWidth then
		return false, "Miss"
	end
	if not voyage:cut(session.site) then
		resumeSwimming(session)
		return false, "Colony unavailable"
	end
	if not session.patch.active then resumeSwimming(session) end
	return true
end

function EVA:action(player, action, payload, now, voyage)
	if action == "Exit" then return self:_exit(player, now, voyage) end
	local session = self.session
	if not session or player ~= session.player then return false, "Diver only" end
	if not living(session) or session.oxygen <= 0 then
		self:release(player)
		return false, "No active diver"
	end
	if type(payload) ~= "table" then return false, "Missing input" end
	if action == "Return" then
		if (session.position - session.anchor).Magnitude > Tuning.airlockReach then
			return false, "Return to the external hatch"
		end
		return self:release(player)
	elseif action == "Cancel" then
		resumeSwimming(session)
		return true
	elseif action == "Brace" then
		return self:_brace(session, payload.site, now, voyage)
	elseif action == "Cut" then
		return self:_cut(session, payload, now, voyage)
	elseif action == "Swim" then
		if session.challenge then return false, "Release the brace to swim" end
		local direction = payload.direction
		if typeof(direction) ~= "Vector3" or not finite(direction.Magnitude) then return false, "Invalid direction" end
		session.direction = direction / math.max(1, direction.Magnitude)
		session.inputAt = now
		return true
	end
	return false, "Unknown EVA action"
end

local function swim(session, dt)
	local anchor = session.anchor
	local displacement = session.direction * (Tuning.speed * dt)
	local offset = session.position + displacement - anchor
	if offset.Magnitude > Tuning.tetherLength then
		displacement = anchor + offset.Unit * Tuning.tetherLength - session.position
	end
	if displacement.Magnitude < 0.001 then return end
	local hit = Workspace:Spherecast(session.position, Tuning.bodyRadius, displacement, session.params)
	if hit then
		displacement = displacement.Unit * math.max(0, hit.Distance - 0.05)
	end
	session.position += displacement
	local horizontal = Vector3.new(session.direction.X, 0, session.direction.Z)
	if horizontal.Magnitude > 0.05 then
		session.root.CFrame = CFrame.lookAt(session.position, session.position + horizontal)
	else
		session.root.CFrame = CFrame.new(session.position) * session.root.CFrame.Rotation
	end
end

function EVA:step(dt, now, voyage)
	local session = self.session
	if not session then return end
	if not living(session) then self:release(session.player) return end
	if session.challenge then
		if session.patch ~= voyage.patches[session.site] or session.patch.active == false then
			resumeSwimming(session)
		end
	elseif now - session.inputAt <= Tuning.inputTimeout then
		swim(session, math.min(dt, Tuning.inputTimeout))
	end

	-- Voyage measures distance to the length of each visible animal in its own pose.
	local exposure = voyage.diverDanger or 0
	session.danger = exposure > 0
	local drain = 1 + Tuning.contactDrain * exposure
	session.oxygen = math.max(0, session.oxygen - dt * drain)
	if session.oxygen <= 0 then
		local humanoid = session.humanoid
		self:release(session.player)
		humanoid.Health = 0
	elseif exposure >= Tuning.contactThreshold then
		session.humanoid:TakeDamage(dt * 8)
	end
end

function EVA:position()
	return self.session and self.session.position or nil
end

function EVA:snapshot()
	local session = self.session
	if not session then return {mode = "Inside", predatorDanger = false} end
	return {
		userId = session.player.UserId, mode = session.challenge and "Braced" or "Swimming",
		position = session.position, oxygen = session.oxygen, oxygenMax = session.oxygenMax,
		predatorDanger = session.danger, site = session.site, challenge = session.challenge,
	}
end

return EVA
