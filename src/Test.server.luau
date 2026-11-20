-- Server-side test: confirms the server script runs and sees players join.
local Players = game:GetService("Players")

print("[Test] Server script running")

Players.PlayerAdded:Connect(function(player)
	print(("[Test] %s joined (UserId %d)"):format(player.Name, player.UserId))

	player.CharacterAdded:Connect(function(character)
		print(("[Test] %s spawned at %s"):format(player.Name, tostring(character:GetPivot().Position)))
	end)
end)
