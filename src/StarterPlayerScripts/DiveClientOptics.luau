local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local Context = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

return function(net, screen)
	local site=workspace:WaitForChild("Thalassa")
	local function make(class,parent,props)
		local o=Instance.new(class)
		for key,value in props do o[key]=value end
		o.Parent=parent
		return o
	end
	local pale=Color3.fromRGB(204,243,227)
	local soft=Color3.fromRGB(111,164,155)
	local amber=Color3.fromRGB(255,184,106)
	local green=Color3.fromRGB(111,238,192)
	local dark=Color3.fromRGB(6,23,29)
	local function frame(parent,name,color,size,pos)
		return make("Frame",parent,{Name=name,BorderSizePixel=0,BackgroundColor3=color,Size=size,Position=pos or UDim2.new()})
	end
	local function label(parent,name,value,size,pos,fontSize,color)
		return make("TextLabel",parent,{Name=name,Text=value,TextColor3=color or pale,TextSize=fontSize or 14,
			Font=Enum.Font.Code,Size=size,Position=pos or UDim2.new(),BorderSizePixel=0,BackgroundTransparency=1,
			TextXAlignment=Enum.TextXAlignment.Left})
	end
	local function stroke(obj,color,alpha)
		return make("UIStroke",obj,{Color=color,Transparency=alpha or 0,Thickness=1})
	end
	local function ring(parent,name,ratio,color)
		local r=frame(parent,name,color,UDim2.fromScale(ratio,ratio),UDim2.fromScale(.5,.5))
		r.AnchorPoint=Vector2.new(.5,.5)
		r.BackgroundTransparency=1
		make("UICorner",r,{CornerRadius=UDim.new(.5,0)})
		return r,stroke(r,color,.35)
	end
	local size=UDim2.fromOffset
	local scope=frame(screen,"ActiveSonar",dark,size(198,249),UDim2.new(1,-12,1,-12))
	scope.AnchorPoint=Vector2.new(1,1)
	scope.BackgroundTransparency=.12
	scope.Visible=false
	stroke(scope,soft,.5)
	local scopeScale=make("UIScale",scope,{Scale=1})
	label(scope,"Header","ACTIVE SONAR",size(130,20),size(10,4),15,green)
	local range=label(scope,"Range","190 st",size(57,20),size(130,4),12,soft)
	range.TextXAlignment=Enum.TextXAlignment.Right
	local plot=frame(scope,"Scan",Color3.fromRGB(8,35,39),size(142,142),size(28,26))
	make("UICorner",plot,{CornerRadius=UDim.new(.5,0)})
	for _,r in {1,.66,.33} do ring(plot,"RangeRing",r,soft) end
	frame(plot,"Longitude",soft,UDim2.new(0,1,1,0),UDim2.new(.5,0,0,0)).BackgroundTransparency=.74
	frame(plot,"Latitude",soft,UDim2.new(1,0,0,1),UDim2.new(0,.5,0,0)).BackgroundTransparency=.74
	local shape=frame(plot,"OwnVessel",green,UDim2.fromScale(50/380,44/380),UDim2.fromScale(.5,.5))
	shape.AnchorPoint=Vector2.new(.5,.5)
	shape.BackgroundTransparency=.8
	stroke(shape,green,.22)
	local wave,waveStroke=ring(plot,"OutgoingPulse",.02,green)
	local marks=frame(plot,"Returns",dark,UDim2.fromScale(1,1))
	marks.BackgroundTransparency=1
	local heading=label(plot,"Heading","F",size(12,12),UDim2.new(.5,-6,0,0),10,soft)
	heading.TextXAlignment=Enum.TextXAlignment.Center
	local contactsText=label(scope,"Contacts","",size(184,72),size(8,172),12,pale)
	contactsText.TextYAlignment=Enum.TextYAlignment.Top
	contactsText.TextWrapped=true
	local scanSound=make("Sound",scope,{Name="Transducer",SoundId="rbxasset://sounds/volume_slider.ogg",Volume=.16,PlaybackSpeed=1.38})
	make("EchoSoundEffect",scanSound,{Delay=.16,Feedback=.23,WetLevel=-13})
	local lastPulse
	local function draw(s)
		lastPulse=s.pingAt
		marks:ClearAllChildren()
		local lines={}
		
		for _,e in s.echoes or {} do
			local pos=UDim2.fromScale(.5+e.x/(2*s.sonarRange),.5+e.z/(2*s.sonarRange))
			if e.kind=="animal" then
				local mark=label(marks,"Contact",e.code,size(16,16),pos,14,amber)
				mark.AnchorPoint=Vector2.new(.5,.5)
				mark.TextXAlignment=Enum.TextXAlignment.Center
				mark.TextStrokeTransparency=.25
				table.insert(lines,string.format("%s  %-7s %3d  %s",e.code,e.label,e.dist,e.status=="APPROACH" and "CLOSE" or e.status=="ROAMING" and "OUT" or e.status))
			else
				local color=e.kind=="terrain" and soft or (e.kind=="patch" and amber or green)
				local blip=frame(marks,"Echo",color,size(e.kind=="terrain" and 2 or 4,e.kind=="terrain" and 2 or 4),pos)
				blip.AnchorPoint=Vector2.new(.5,.5)
			end
		end
		contactsText.Text=#lines>0 and table.concat(lines,"\n") or "No biological returns"
		range.Text=tostring(s.sonarRange).." st"
		scanSound:Play()
	end

	local display=frame(screen,"ExteriorVideo",dark,UDim2.fromScale(1,1))
	display.BackgroundTransparency=1
	display.Visible=false
	local signalLayer=frame(display,"VideoArtifacts",dark,UDim2.fromScale(1,1))
	signalLayer.BackgroundTransparency=1
	signalLayer.ClipsDescendants=true
	local transmission=frame(signalLayer,"SignalLock",Color3.fromRGB(15,26,29),UDim2.fromScale(1,1))
	transmission.BackgroundTransparency=1
	for i=0,115 do
		local line=frame(signalLayer,"Scanline",Color3.fromRGB(1,8,10),UDim2.new(1,0,0,1),UDim2.fromScale(0,i/116))
		line.BackgroundTransparency=i%3==0 and .68 or .78
	end
	local rng=Random.new()
	local noise={}
	for i=1,46 do
		local fleck=frame(signalLayer,"Static",i%3==0 and dark or pale,UDim2.fromOffset(4,1))
		fleck.BackgroundTransparency=1
		noise[i]=fleck
	end
	local border=frame(display,"VideoMask",dark,UDim2.new(1,-14,1,-14),UDim2.fromOffset(7,7))
	border.BackgroundTransparency=1
	stroke(border,soft,.55)
	local top=frame(display,"CameraInfo",dark,UDim2.new(1,-20,0,40),size(10,10))
	top.BackgroundTransparency=.06
	stroke(top,soft,.6)
	local title=label(top,"Feed","",UDim2.new(.53,0,1,0),size(12,0),17,green)
	local subject=label(top,"Target","",UDim2.new(.47,-20,1,0),UDim2.fromScale(.53,0),14,pale)
	subject.TextXAlignment=Enum.TextXAlignment.Right
	local cross=label(display,"Reticle","+",size(26,28),UDim2.fromScale(.5,.5),21,soft)
	cross.AnchorPoint=Vector2.new(.5,.5)
	cross.TextXAlignment=Enum.TextXAlignment.Center
	local bar=frame(display,"CameraControls",dark,size(380,44),UDim2.new(.5,0,1,-9))
	bar.AnchorPoint=Vector2.new(.5,1)
	local barScale=make("UIScale",bar,{Scale=1})
	local function btn(text,x,width)
		local b=make("TextButton",bar,{Name=text,Text=text,TextColor3=pale,TextSize=14,Font=Enum.Font.Code,
			Size=size(width,34),Position=size(x,5),BackgroundColor3=Color3.fromRGB(22,54,57),BorderSizePixel=0,Modal=true})
		return b
	end
	local back=btn("‹ PREV",5,69)
	local nextCam=btn("NEXT ›",78,69)
	local track=btn("TRACK CONTACT",151,131)
	local leave=btn("EXIT  Q",286,89)
	local grade=make("ColorCorrectionEffect",Lighting,{Name="HullCameraGain",Enabled=false,Brightness=.055,
		Contrast=.15,Saturation=-.8,TintColor=Color3.fromRGB(201,232,223)})
	-- The camera softens the rendered scene while its overlay and controls stay sharp.
	local lens=make("BlurEffect",Lighting,{Name="HullCameraSoftFocus",Enabled=false,Size=3})
	local viewing=false
	local slot=1
	local target
	local previousFOV=70
	local displayedSlot
	local syncUntil=0
	local nextNoise=0
	local nextFrame=0
	local bindings={"CameraPrev","CameraNext","CameraTrack","CameraLeave"}
	local ids={"Leviathan","GiantSquid","CrackCrawler","Pursuer"}
	local function marker(i) return site:FindFirstChild("DiveCamera"..i,true) end
	local function detected(id)
		local contacts=site:FindFirstChild("Contacts")
		local model=contacts and id and contacts:FindFirstChild(id)
		if model and model:GetAttribute("Detectable") then return model end
	end
	local function bestCamera(pos)
		local bestScore,best=-2,1
		for i=1,4 do
			local m=marker(i)
			if m then
				local v=pos-m.Position
				local score=v.Magnitude>.1 and m.CFrame.LookVector:Dot(v.Unit) or -2
				if score>bestScore then bestScore,best=score,i end
			end
		end
		return best
	end
	local function nextTarget()
		local start=table.find(ids,target) or 0
		target=nil
		for j=1,#ids do
			local id=ids[(start+j-1)%#ids+1]
			local model=detected(id)
			if model then target=id slot=bestCamera(model:GetPivot().Position) return end
		end
	end
	local function cycle(delta) target=nil slot=(slot-1+delta)%4+1 end
	local function quit() net.Input:FireServer("CloseCamera") end
	back.Activated:Connect(function() cycle(-1) end)
	nextCam.Activated:Connect(function() cycle(1) end)
	track.Activated:Connect(nextTarget)
	leave.Activated:Connect(quit)
	local commands={function() cycle(-1) end,function() cycle(1) end,nextTarget,quit}
	local keys={{Enum.KeyCode.A,Enum.KeyCode.ButtonL1},{Enum.KeyCode.D,Enum.KeyCode.ButtonR1},
		{Enum.KeyCode.T,Enum.KeyCode.ButtonX},{Enum.KeyCode.Q,Enum.KeyCode.ButtonB}}
	local function view(on)
		if on==viewing then return end
		viewing=on
		display.Visible=on
		grade.Enabled=on
		lens.Enabled=on
		local cam=workspace.CurrentCamera
		if on then
			slot=1 target=nil nextTarget()
			displayedSlot=nil
			nextNoise,nextFrame=0,0
			previousFOV=cam.FieldOfView
			cam.CameraType=Enum.CameraType.Scriptable
			cam.FieldOfView=78
			for i,name in bindings do
				Context:BindActionAtPriority(name,function(_,state)
					if state==Enum.UserInputState.Begin then commands[i]() end
					return Enum.ContextActionResult.Sink
				end,false,3000,table.unpack(keys[i]))
			end
		else
			for _,name in bindings do Context:UnbindAction(name) end
			cam.CameraType=Enum.CameraType.Custom
			cam.FieldOfView=previousFOV
			local char=Players.LocalPlayer.Character
			if char then cam.CameraSubject=char:FindFirstChildOfClass("Humanoid") end
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(display) then GuiService.SelectedObject=nil end
		end
	end
	local function updateSignal(now)
		if displayedSlot~=slot then
			displayedSlot=slot
			syncUntil=now+.27
			nextNoise,nextFrame=0,0
		end
		local tuning=math.clamp((syncUntil-now)/.27,0,1)
		transmission.BackgroundTransparency=1-.65*tuning
		if now<nextNoise then return tuning>0 end
		nextNoise=now+1/14
		for i,fleck in noise do
			-- Short monochrome streaks imply interference without a full-screen flash.
			local streak=i%9==0
			local width=if streak then rng:NextNumber(.018,.065) else 0
			fleck.Size=UDim2.new(width,if streak then 0 else rng:NextInteger(2,12),0,rng:NextInteger(1,2))
			fleck.Position=UDim2.fromScale(rng:NextNumber(),rng:NextNumber())
			fleck.BackgroundTransparency=rng:NextNumber(.77,.97)-tuning*.29
		end
		return tuning>0
	end
	RunService:BindToRenderStep("ThalassaExteriorOptics",Enum.RenderPriority.Camera.Value+2,function()
		local cam=workspace.CurrentCamera
		local compact=cam.ViewportSize.X<720
		if scope.Visible then
			scopeScale.Scale=compact and .72 or .95
			scope.Position=UDim2.new(1,-10,1,compact and -88 or -12)
			local ratio=math.clamp((workspace:GetServerTimeNow()-(lastPulse or 0))/2.15,.003,1)
			wave.Size=UDim2.fromScale(ratio,ratio)
			waveStroke.Transparency=math.min(1,.1+ratio*.9)
		end
		if not viewing then return end
		barScale.Scale=math.min(1,(cam.ViewportSize.X-14)/380)
		if target and not detected(target) then nextTarget() end
		local animal=detected(target)
		local m=marker(slot)
		if not m then title.Text="VIDEO  /  ACQUIRING" return end
		local pos=animal and animal:GetPivot().Position
		if pos and m.CFrame.LookVector:Dot((pos-m.Position).Unit)<.24 then
			slot=bestCamera(pos)
			m=marker(slot) or m
		end
		local now=os.clock()
		local acquiring=updateSignal(now)
		if now>=nextFrame then
			-- Low-bandwidth feed cadence affects the image, never the UI.
			nextFrame=now+1/18
			cam.CameraType=Enum.CameraType.Scriptable
			cam.CFrame=pos and CFrame.lookAt(m.Position,pos) or m.CFrame
			cam.Focus=CFrame.new(pos or m.Position+m.CFrame.LookVector*70)
		end
		title.Text=string.format("CAM %02d  /  %s",slot,string.upper(m:GetAttribute("Label") or "HULL"))
		subject.Text=if acquiring then "SYNCING" elseif animal then string.upper(animal:GetAttribute("ContactLabel") or animal.Name) else "LIVE  /  FIXED"
	end)
	return {
		update=function(s)
			view(s.cameraView==true and s.alive~=false and not s.outside)
			scope.Visible=s.sonarOn==true and s.alive~=false and not s.outside
			if scope.Visible and s.pingAt and s.pingAt~=lastPulse then draw(s) end
			if not scope.Visible then lastPulse=nil end
		end,
		reset=function() view(false) scope.Visible=false lastPulse=nil end,
	}
end
