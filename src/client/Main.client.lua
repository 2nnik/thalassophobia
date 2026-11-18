local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson -- first-person only

local isLobby = Config.Places.Lobby ~= 0 and game.PlaceId == Config.Places.Lobby
if isLobby then
	require(script.Parent.LobbyUI).start()
else
	require(script.Parent.HUD).start()
	require(script.Parent.Visuals).start()
	require(script.Parent.Input).start()
end
