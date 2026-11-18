-- Sends raw input to the server. The server decides whether it does anything.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Input = {}

function Input.start()
	local camera = workspace.CurrentCamera
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then return end
		acc = 0
		local look = camera.CFrame.LookVector
		-- bearing 0 = -Z, matching the server's spotlight and the monster visuals
		Remotes.LightAim:FireServer(math.deg(math.atan2(-look.X, -look.Z)) % 360)
	end)

	local function set(on)
		Remotes.Spray:FireServer(on)
		Remotes.Scrub:FireServer(on) -- the server applies whichever one makes sense (extinguisher inside, scrubbing outside)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then set(true) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then set(false) end
	end)
end

return Input
