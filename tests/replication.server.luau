-- Install temporarily under ServerScriptService, then run ExecuteMultiplayerTestAsync(2,"DiveReplication").
local test = game:GetService("StudioTestService")
if test:GetTestArgs() ~= "DiveReplication" then return end
local received = {}
local report = Instance.new("RemoteEvent")
report.Name = "DiveQAReport"
report.OnServerEvent:Connect(function(player,depth)
	received[player.UserId] = depth
	local count = 0
	for _ in pairs(received) do count += 1 end
	if count == 2 then test:EndTest("PASS: both clients observed engine and depth") end
end)
report.Parent = game.ReplicatedStorage
task.delay(90,function() test:EndTest("FAIL: missing client acknowledgment") end)
