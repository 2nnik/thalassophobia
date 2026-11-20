-- Client displays the server's synchronized cutter and sends only movement intent and input times.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local Client={}
local net, controls, screen
local overlay,card,dial,pivot,headline,progress,feedback,travel,rise,down,cancel,help,scale
local active,challenge=false,nil
local ticks,travelPoints={},{}
local heldRise,heldDown=false,false
local riseTouch,downTouch
local pending,lastSend=nil,0
local color={
	paper=Color3.fromRGB(226,241,234),steel=Color3.fromRGB(43,70,74),dark=Color3.fromRGB(12,29,33),
	panel=Color3.fromRGB(17,40,44),foam=Color3.fromRGB(105,237,198),muted=Color3.fromRGB(147,178,177),
	amber=Color3.fromRGB(252,186,94)
}
local function make(class,parent,props)
	local v=Instance.new(class)
	for key,val in props do v[key]=val end
	v.Parent=parent
	return v
end
local function frame(parent,pos,size,col,z)
	return make("Frame",parent,{Position=pos,Size=size,BorderSizePixel=0,BackgroundColor3=col,ZIndex=z})
end
local function label(parent,text,pos,size,font,textSize,col,z)
	return make("TextLabel",parent,{Text=text,Position=pos,Size=size,Font=font,TextSize=textSize,
		TextColor3=col,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=z})
end
local function button(parent,text,pos,size)
	local b=make("TextButton",parent,{Text=text,Position=pos,Size=size,BackgroundColor3=color.steel,TextColor3=color.paper,
		Font=Enum.Font.Code,TextSize=14,AutoButtonColor=true,BorderSizePixel=0,ZIndex=27})
	return b
end
local function round(obj)
	make("UICorner",obj,{CornerRadius=UDim.new(1,0)})
end

local function hit()
	local c=challenge
	if not active or not c or pending==c.id then return end
	local now=workspace:GetServerTimeNow()
	if now<c.started then return end
	-- At most one attempt per server-issued sweep. Retry if a packet missed the server's timing window.
	pending=c.id
	net.Input:FireServer("CleanStrike",{id=c.id,time=now})
	task.delay(.72,function() if pending==c.id then pending=nil end end)
end
local function cancelGrip()
	if active and challenge then net.Input:FireServer("CleanCancel") end
end
local function bindSwim(enable)
	for _,name in {"DiveRise","DiveSink","DiveCut","DiveRelease"} do CAS:UnbindAction(name) end
	heldRise,heldDown=false,false
	riseTouch,downTouch=nil,nil
	if not enable then return end
	local priority=Enum.ContextActionPriority.High.Value+15
	if challenge then
		CAS:BindActionAtPriority("DiveCut",function(_,state)
			if state==Enum.UserInputState.Begin then hit() end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
		CAS:BindActionAtPriority("DiveRelease",function(_,state)
			if state==Enum.UserInputState.Begin then cancelGrip() end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.Q,Enum.KeyCode.ButtonB)
	else
		local function vertical(name,state)
			local isHeld=state~=Enum.UserInputState.End and state~=Enum.UserInputState.Cancel
			if name=="DiveRise" then heldRise=isHeld else heldDown=isHeld end
			return Enum.ContextActionResult.Sink
		end
		CAS:BindActionAtPriority("DiveRise",vertical,false,priority,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
		CAS:BindActionAtPriority("DiveSink",vertical,false,priority,Enum.KeyCode.C,Enum.KeyCode.LeftControl,Enum.KeyCode.ButtonB)
	end
end

local function refreshBindings(oldActive,oldChallenge)
	if oldActive~=active or oldChallenge~=(challenge~=nil) then bindSwim(active) end
	overlay.Visible=challenge~=nil
	travel.Visible=active and not challenge
	local touch=UIS.PreferredInput==Enum.PreferredInput.Touch
	rise.Visible=travel.Visible and touch
	down.Visible=rise.Visible
end
local function populate(c,s)
	headline.Text=string.upper(c.label).."   /   HULL CLEANING"
	for index,tick in ticks do
		local angle=(index-1)*5
		local inBand=math.abs((angle-c.center+180)%360-180)<=c.arc/2
		tick.BackgroundColor3=inBand and color.foam or color.steel
		tick.Size=UDim2.fromOffset(inBand and 4 or 2,inBand and 13 or 7)
	end
	progress.Text=string.format("%d / 3",s.cleanSites and s.cleanSites[c.index] or 0)
	feedback.Text=c.feedback~="" and c.feedback or "SET THE CUTTER"
	feedback.TextColor3=c.feedback=="MISSED" and color.amber or color.foam
end

local function travelStatus(s)
	local completed=0
	if s.cleanSites and s.swarm>0 then
		for _,count in s.cleanSites do if count>=3 then completed+=1 end end
	end
	local text
	if UIS.PreferredInput==Enum.PreferredInput.Touch then
		text="Swim where you look  ·  Hold ↑ or ↓"
	elseif UIS.PreferredInput==Enum.PreferredInput.Gamepad then
		text="Swim where you look  ·  A rise  /  B dive"
	else
		text="Swim where you look  ·  Space rise  /  C dive"
	end
	if s.swarm and s.swarm>0 and s.cleanSites then
		local origin=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local near,distance=nil,math.huge
		for i,point in travelPoints do
			if origin and point.Parent and (s.cleanSites[i] or 0)<3 then
				local d=(origin.Position-point.Position).Magnitude
				if d<distance then near,distance=point.Parent,d end
			end
		end
		text=string.format("HULL   %d/4",completed)..(near and "   •   "..string.upper(near:GetAttribute("Label") or near.Name).."   "..math.round(distance).." st" or "").."\n"..text
	end
	travel.Text=text
end

function Client.init(network,rootGui)
	net,screen=network,rootGui
	task.spawn(function()
		local playerScripts=Players.LocalPlayer:WaitForChild("PlayerScripts")
		local module=playerScripts:WaitForChild("PlayerModule",10)
		if module then local ok,result=pcall(function() return require(module):GetControls() end) if ok then controls=result end end
	end)
	local holder=make("Frame",screen,{Name="ExteriorOperations",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=23})
	overlay=frame(holder,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(1,11,14),24)
	overlay.Name="CutterView"
	overlay.BackgroundTransparency=.35
	overlay.Visible=false
	card=frame(overlay,UDim2.fromScale(.5,.5),UDim2.fromOffset(390,338),color.dark,25)
	card.AnchorPoint=Vector2.new(.5,.5)
	make("UIStroke",card,{Color=color.steel,Thickness=1})
	scale=make("UIScale",card,{Scale=1})
	local function resize()
		local size=holder.AbsoluteSize
		if size.X>0 and size.Y>0 then scale.Scale=math.min(1.08,(size.X-20)/390,(size.Y-24)/338) end
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	headline=label(card,"",UDim2.fromOffset(10,8),UDim2.fromOffset(370,24),Enum.Font.Code,14,color.foam,26)
	help=label(card,"Strike when the needle crosses the green arc",UDim2.fromOffset(9,34),UDim2.fromOffset(372,21),Enum.Font.Gotham,15,color.paper,26)
	dial=make("TextButton",card,{Name="Strike",Text="",Size=UDim2.fromOffset(210,210),Position=UDim2.fromOffset(90,59),
		BackgroundColor3=color.panel,BorderSizePixel=0,Modal=true,AutoButtonColor=false,Selectable=false,ZIndex=26})
	round(dial)
	for i=1,72 do
		local angle=math.rad((i-1)*5)
		local tick=frame(dial,UDim2.fromOffset(105+math.sin(angle)*94,105-math.cos(angle)*94),UDim2.fromOffset(2,7),color.steel,27)
		tick.AnchorPoint=Vector2.new(.5,.5)
		tick.Rotation=(i-1)*5
		ticks[i]=tick
	end
	pivot=frame(dial,UDim2.fromScale(.5,.5),UDim2.fromOffset(184,184),color.panel,28)
	pivot.AnchorPoint=Vector2.new(.5,.5)
	pivot.BackgroundTransparency=1
	local needle=frame(pivot,UDim2.fromScale(.5,0),UDim2.fromOffset(4,57),color.amber,29)
	needle.AnchorPoint=Vector2.new(.5,0)
	local hub=frame(dial,UDim2.fromScale(.5,.5),UDim2.fromOffset(75,75),color.dark,29)
	hub.AnchorPoint=Vector2.new(.5,.5)
	round(hub)
	progress=label(hub,"0 / 3",UDim2.fromOffset(0,16),UDim2.fromOffset(75,25),Enum.Font.Code,20,color.paper,30)
	label(hub,"CUTS",UDim2.fromOffset(0,38),UDim2.fromOffset(75,16),Enum.Font.Code,11,color.muted,30)
	feedback=label(card,"",UDim2.fromOffset(0,271),UDim2.fromOffset(390,19),Enum.Font.Code,13,color.foam,27)
	local stroke=button(card,"STRIKE",UDim2.fromOffset(24,297),UDim2.fromOffset(179,30))
	stroke.Name="StrikeControl"
	cancel=button(card,"RELEASE",UDim2.fromOffset(212,297),UDim2.fromOffset(154,30))
	cancel.Name="ReleaseControl"
	local function pressed(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then hit() end
	end
	dial.InputBegan:Connect(pressed)
	stroke.InputBegan:Connect(pressed)
	cancel.Activated:Connect(cancelGrip)
	local function deviceText()
		local gamepad=UIS.PreferredInput==Enum.PreferredInput.Gamepad
		local touch=UIS.PreferredInput==Enum.PreferredInput.Touch
		stroke.Text=touch and "TAP TO STRIKE" or gamepad and "STRIKE  •  A" or "STRIKE  •  SPACE"
		cancel.Text=touch and "RELEASE" or gamepad and "RELEASE  •  B" or "RELEASE  •  Q"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(deviceText)
	deviceText()
	travel=label(holder,"",UDim2.new(.5,0,1,-12),UDim2.new(.94,0,0,44),Enum.Font.Code,13,color.paper,24)
	travel.AnchorPoint=Vector2.new(.5,1)
	travel.TextStrokeTransparency=.35
	travel.Visible=false
	rise=button(holder,"↑",UDim2.new(1,-65,.54,0),UDim2.fromOffset(47,43))
	down=button(holder,"↓",UDim2.new(1,-65,.54,49),UDim2.fromOffset(47,43))
	rise.TextSize,down.TextSize=24,24
	rise.Visible,down.Visible=false,false
	rise.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then riseTouch=input end end)
	down.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then downTouch=input end end)
	UIS.InputEnded:Connect(function(input)
		if input==riseTouch then riseTouch=nil end
		if input==downTouch then downTouch=nil end
	end)
	local world=workspace:FindFirstChild("Thalassa")
	local function register(item)
		if item:IsA("BasePart") and item.Name=="Target" and item.Parent and item.Parent.Parent and item.Parent.Parent.Name=="BarnacleSites" then
			local index=tonumber(item.Parent.Name:match("^Site(%d+)$"))
			if index then travelPoints[index]=item end
		end
	end
	if world then for _,item in world:GetDescendants() do register(item) end end
	workspace.DescendantAdded:Connect(register)
	RunService.RenderStepped:Connect(function()
		if not active then return end
		if challenge then
			local t=math.max(0,workspace:GetServerTimeNow()-challenge.started)
			pivot.Rotation=(challenge.startAngle+challenge.sign*t*360/challenge.period)%360
			return
		end
		local now=os.clock()
		if now-lastSend<0.13 then return end
		lastSend=now
		local camera=workspace.CurrentCamera
		if not camera then return end
		local move=Vector3.zero
		local vertical=0
		if not UIS:GetFocusedTextBox() and not GuiService.MenuIsOpen then
			if controls then
				move=controls:GetMoveVector()
			else
				local function key(k) return UIS:IsKeyDown(k) and 1 or 0 end
				move=Vector3.new(key(Enum.KeyCode.D)-key(Enum.KeyCode.A),0,key(Enum.KeyCode.S)-key(Enum.KeyCode.W))
			end
			vertical=((heldRise or riseTouch) and 1 or 0)-((heldDown or downTouch) and 1 or 0)
		end
		local cf=camera.CFrame
		local direction=cf.RightVector*move.X - cf.LookVector*move.Z + Vector3.yAxis*vertical
		if direction.Magnitude>1 then direction=direction.Unit end
		net.Input:FireServer("SwimMove",{direction=direction,look=cf.LookVector})
	end)
end

function Client.update(s)
	local oldActive,oldChallenge=active,challenge~=nil
	local previousId=challenge and challenge.id
	active=s.outside==true and s.alive~=false
	challenge=active and s.cleaning or nil
	if challenge and previousId~=challenge.id then
		pending=nil
		populate(challenge,s)
	end
	refreshBindings(oldActive,oldChallenge)
	if active and not challenge then travelStatus(s) end
end

function Client.reset()
	if not overlay then return end
	local oldActive,oldChallenge=active,challenge~=nil
	active,challenge,pending=false,nil,nil
	refreshBindings(oldActive,oldChallenge)
end

return Client
