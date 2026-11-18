-- Monster silhouettes seen through the fog, placed from the server snapshot. Purely cosmetic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Visuals = {}
local SCALE = 0.6 -- studs per sim metre

local function dark(size, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.Shape = size, shape or Enum.PartType.Block
	p.Color, p.Material = Color3.fromRGB(4, 8, 10), Enum.Material.SmoothPlastic
	p.Parent = workspace
	return p
end

function Visuals.start()
	local parts, targets, swarm = {}, {}, {}
	local cage = workspace:WaitForChild("Cage")
	local origin = cage:GetPivot().Position

	for i = 1, 40 do
		local p = dark(Vector3.new(0.6, 0.6, 0.6), Enum.PartType.Ball)
		p.Transparency = 1
		swarm[i] = { part = p, offset = Vector3.new((math.random() - 0.5) * 14, (math.random() - 0.5) * 10, (math.random() - 0.5) * 40) }
	end

	local function place(kind, state)
		local dir = Vector3.new(-math.sin(math.rad(state.bearing or 0)), 0, -math.cos(math.rad(state.bearing or 0)))
		local dist = (state.dist or 50) * SCALE
		if kind == "Shark" then
			return CFrame.new(origin + dir * dist + Vector3.new(0, 4, 0), origin + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(90), 0)
		elseif kind == "Pursuer" then
			return CFrame.new(origin + Vector3.new(0, -dist - 10, 0))
		end
		return CFrame.new(origin + dir * dist + Vector3.new(0, 2, 0))
	end

	Remotes.State.OnClientEvent:Connect(function(snap)
		local seen = {}
		for _, m in ipairs(snap.monsters) do
			if m.kind == "Swarm" then
				for _, s in ipairs(swarm) do s.part.Transparency = 1 - m.coverage * 0.95 end
			elseif m.kind ~= "Crawler" then
				seen[m.kind] = true
				if not parts[m.kind] then
					local size = ({ Shark = Vector3.new(7, 4, 24), Squid = Vector3.new(28, 28, 28), Pursuer = Vector3.new(20, 8, 20) })[m.kind]
					parts[m.kind] = dark(size, m.kind == "Squid" and Enum.PartType.Ball or Enum.PartType.Block)
				end
				targets[m.kind] = place(m.kind, m)
			end
		end
		local hasSwarm = false
		for _, m in ipairs(snap.monsters) do if m.kind == "Swarm" then hasSwarm = true end end
		if not hasSwarm then for _, s in ipairs(swarm) do s.part.Transparency = 1 end end
		for kind, part in pairs(parts) do
			if not seen[kind] then part:Destroy(); parts[kind], targets[kind] = nil, nil end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		for kind, part in pairs(parts) do
			if targets[kind] then part.CFrame = part.CFrame:Lerp(targets[kind], math.min(1, dt * 4)) end
		end
		for _, s in ipairs(swarm) do s.part.Position = origin + s.offset end
	end)
end

return Visuals
