-- Entry point. The same build is published to two places: a lobby and the run place.
-- With Config.Places left at 0 (Studio testing) it just starts a run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent.Services

local isLobby = Config.Places.Lobby ~= 0 and game.PlaceId == Config.Places.Lobby
if isLobby then
	require(Services.Lobby).start()
else
	require(Services.RunController).start()
end
