-- Creates (server) or waits for (client) all RemoteEvents under ReplicatedStorage.Remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "State", "Events", "LightAim", "Spray", "Scrub", "LobbyAction", "LobbyState" }

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
