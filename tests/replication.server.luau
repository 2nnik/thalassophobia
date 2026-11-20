-- Install temporarily under ServerScriptService, then run ExecuteMultiplayerTestAsync(2,"DiveReplication").
local test = game:GetService("StudioTestService")
if test:GetTestArgs() ~= "DiveReplication" then return end
local received,cleaned = {},{}
local report = Instance.new("RemoteEvent")
report.Name = "DiveQAReport"
report.OnServerEvent:Connect(function(player,kind,value)
	if kind=="error" then test:EndTest("FAIL: "..tostring(value)) return end
	if kind=="engine" then received[player.UserId]=value end
	if kind=="clean" then cleaned[player.UserId]=value end
	local count,total=0,0
	for id in pairs(received) do if cleaned[id] then count+=1 total+=cleaned[id] end end
	if count==2 and total==4 then test:EndTest("PASS: two clients observed engine/depth and completed 1+2 keel cuts across diver swap") end
end)
report.Parent = game.ReplicatedStorage
task.delay(120,function() test:EndTest("FAIL: missing client acknowledgment") end)
