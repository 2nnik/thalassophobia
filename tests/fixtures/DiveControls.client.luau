-- Playable controls for integration testing until the presentation client is installed.
local players=game:GetService("Players")
local input=game:GetService("UserInputService")
local run=game:GetService("RunService")
local actions=game:GetService("ContextActionService")
local player=players.LocalPlayer
local net=game.ReplicatedStorage:WaitForChild("DiveNet")
local world=workspace:WaitForChild("DiveWorld")
local screen=Instance.new("ScreenGui")
screen.Name,screen.ResetOnSpawn,screen.Parent="DiveIntegration",false,player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0,1),UDim2.new(0,14,1,-14),UDim2.fromOffset(340,176)
panel.BackgroundColor3,panel.BackgroundTransparency,panel.Parent=Color3.fromRGB(12,27,32),.14,screen
local function label(parent,y,height)
	local t=Instance.new("TextLabel")
	t.Position,t.Size=UDim2.fromOffset(8,y),UDim2.new(1,-16,0,height)
	t.BackgroundTransparency,t.Font,t.TextSize,t.TextWrapped=1,Enum.Font.GothamMedium,15,true
	t.TextColor3,t.TextXAlignment,t.TextYAlignment=Color3.fromRGB(211,238,229),Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	t.Parent=parent
	return t
end
local status=label(panel,8,50)
local detail=label(panel,58,42)
local bar=Instance.new("Frame")
bar.Size,bar.Position,bar.BackgroundTransparency,bar.Parent=UDim2.new(1,-12,0,72),UDim2.fromOffset(6,100),1,panel
local grid=Instance.new("UIGridLayout")
grid.CellSize,grid.CellPadding,grid.SortOrder,grid.Parent=UDim2.fromOffset(103,30),UDim2.fromOffset(5,4),Enum.SortOrder.LayoutOrder,bar
local state={}
local function send(name,payload) net.Action:FireServer(name,payload or {}) end
local buttons={}
local function setButtons(specs)
	for i=1,math.max(#buttons,#specs) do
		local b=buttons[i]
		if not b and specs[i] then
			b=Instance.new("TextButton")
			b.Font,b.TextSize,b.TextColor3,b.BackgroundColor3=Enum.Font.GothamMedium,13,Color3.new(1,1,1),Color3.fromRGB(41,81,85)
			b.LayoutOrder,b.Parent=i,bar
			b.Activated:Connect(function() if buttons[i].Visible and buttons[i]:GetAttribute("Label") then local f=state.buttons[i] if f then f[2]() end end end)
			buttons[i]=b
		end
		if b then
			b.Visible=specs[i]~=nil
			if specs[i] then b.Text=specs[i][1] b:SetAttribute("Label",b.Text) end
		end
	end
	state.buttons=specs
end
local cameraIndex,sequence,climb=1,0,0
local feeds={"Fore","Starboard","Stern","Port"}
local lastCamera=false
local function cut()
	local e=state.eva
	if e and e.challenge then
		sequence+=1
		send("Cut",{challengeId=e.challenge.id,strikeTime=workspace:GetServerTimeNow(),sequence=sequence})
	end
end
local cursor=false
local function menu(_,phase)
	if phase==Enum.UserInputState.Begin then cursor=not cursor end
	return Enum.ContextActionResult.Pass
end
actions:BindAction("DiveCursor",menu,false,Enum.KeyCode.Tab,Enum.KeyCode.ButtonSelect)
local function shortcut(_,phase,k)
	if phase~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if k.KeyCode==Enum.KeyCode.X or k.KeyCode==Enum.KeyCode.ButtonX then
		if state.eva and state.eva.userId==player.UserId and state.eva.challenge then cut() else send("Spray") end
	else send("Cancel") if state.camera then send("CameraExit") end end
	return Enum.ContextActionResult.Pass
end
actions:BindAction("DiveShortcut",shortcut,false,Enum.KeyCode.X,Enum.KeyCode.C,Enum.KeyCode.ButtonX,Enum.KeyCode.ButtonB)
local function elevation(_,phase,k)
	if phase==Enum.UserInputState.Begin then climb=if k.KeyCode==Enum.KeyCode.Space or k.KeyCode==Enum.KeyCode.ButtonA then 1 else -1
	elseif phase==Enum.UserInputState.End then climb=0 end
	return Enum.ContextActionResult.Pass
end
actions:BindAction("DiveElevation",elevation,false,Enum.KeyCode.Space,Enum.KeyCode.LeftControl,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonL2)
local function aim()
	local h=workspace.CurrentCamera.CFrame.LookVector
	local d=world.ShipOrigin.CFrame:VectorToObjectSpace(h)
	send("Aim",{bearing=math.deg(math.atan2(d.X,-d.Z)),pitch=math.deg(math.asin(d.Y))})
end
local function button(t,n,a,p) table.insert(t,{n,function() send(a,p) end}) end
local function refresh(s)
	local specs={}
	local e,d,l=s.eva,s.dive,s.lobby or {}
	if s.phase=="Lobby" then
		status.Text=("THALASSOPHOBIA   /   DIVE DOCK\n%s     •     %s credits"):format(l.difficulty or "Normal",l.credits or 0)
		detail.Text=s.notice or l.notice or "Choose a launch mode."
		for _,n in ipairs({"Solo","Public","Private"}) do button(specs,n,n) end
		for _,n in ipairs({"Easy","Normal","Hard"}) do button(specs,n,"Difficulty",{difficulty=n}) end
	elseif s.phase=="Results" then
		status.Text="DIVE REPORT"
		local r=s.result or {}
		detail.Text=("%s     •     %d m"):format(r.reason or "",math.floor(r.deepest or 0))
	elseif d then
		status.Text=("%s   %d m   |   Hull %d%%   Battery %d%%\nEngine %s   •   %.1f m/s"):format(s.phase,math.floor(d.depth),math.floor(d.hull),math.floor(d.battery),d.engine and "on" or "off",d.speed)
		local messages={}
		for id,a in pairs(d.actors or {}) do if a.visible and a.state~="Roam" and a.state~="Roaming" then table.insert(messages,id.." "..a.state) end end
		if d.pursuerGap and s.phase=="Ascent" then table.insert(messages,"Pursuer "..math.floor(d.pursuerGap).." m") end
		detail.Text=s.notice or table.concat(messages,"   ")
		if s.camera then
			table.insert(specs,{"◀ Feed",function() cameraIndex=(cameraIndex-2)%4+1 end})
			table.insert(specs,{"Feed ▶",function() cameraIndex=cameraIndex%4+1 end})
			button(specs,"Exit camera","CameraExit")
		elseif e and e.userId==player.UserId then
			if e.challenge then table.insert(specs,{"Cut [X]",cut}) button(specs,"Release [C]","Cancel")
			else
				table.insert(specs,{"Swim up",function() climb=1 task.delay(.55,function() climb=0 end) end})
				table.insert(specs,{"Swim down",function() climb=-1 task.delay(.55,function() climb=0 end) end})
				button(specs,"Return","Return")
			end
			if not e.challenge then detail.Text=("Tethered   •   O₂ %d s%s"):format(math.ceil(e.oxygen),e.predatorDanger and "   •   Predator nearby" or "") end
		else
			table.insert(specs,{"Aim beam",aim})
			button(specs,"Spray [X]","Spray")
		end
	end
	setButtons(specs)
end
net.Snapshot.OnClientEvent:Connect(function(s)
	for k in pairs(state) do if k~="buttons" then state[k]=nil end end
	for k,v in pairs(s) do state[k]=v end
	refresh(state)
end)
local elapsed=0
run:BindToRenderStep("DiveFixtureControls",Enum.RenderPriority.Camera.Value+1,function(dt)
	local cam=workspace.CurrentCamera
	if state.camera then
		cam.CameraType=Enum.CameraType.Scriptable
		cam.CFrame=world.Cameras[feeds[cameraIndex]].CFrame
	elseif lastCamera then cam.CameraType=Enum.CameraType.Custom end
	lastCamera=state.camera
	if state.camera or cursor then input.MouseBehavior=Enum.MouseBehavior.Default end
	local e=state.eva
	if e and e.userId==player.UserId then
		if e.challenge then
			local c=e.challenge
			local angle=((workspace:GetServerTimeNow()-c.startedAt)/c.period)%1
			local good=(angle-c.arcStart)%1<=c.arcWidth
			detail.Text=("%s   %03d°   •   %s"):format(e.site,angle*360,good and "CUT NOW" or "wait for arc")
		else
			elapsed+=dt
			if elapsed>=.1 then
				elapsed=0
				local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local dir=humanoid and humanoid.MoveDirection or Vector3.zero
				if dir.Magnitude>.01 then
					local flat=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
					if flat.Magnitude>.01 then dir+=Vector3.new(0,dir:Dot(flat.Unit)*cam.CFrame.LookVector.Y,0) end
				end
				send("Swim",{direction=dir+Vector3.yAxis*climb})
			end
		end
	end
end)
