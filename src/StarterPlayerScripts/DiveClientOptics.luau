local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local Context = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UI = require(script.Parent.DiveClientStyle)

return function(net, screen)
	local site=workspace:WaitForChild("Thalassa")
	local hull=site:WaitForChild("ShipEnvelope")
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
	display.ZIndex=20
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
	local subject=label(top,"Signal","",UDim2.new(.47,-20,1,0),UDim2.fromScale(.53,0),14,pale)
	subject.TextXAlignment=Enum.TextXAlignment.Right
	local cross=label(display,"Reticle","+",size(26,28),UDim2.fromScale(.5,.5),21,soft)
	cross.AnchorPoint=Vector2.new(.5,.5)
	cross.TextXAlignment=Enum.TextXAlignment.Center
	local panel=frame(display,"KestrelMap",dark,size(358,286))
	panel.BackgroundTransparency=.06
	stroke(panel,soft,.34)
	local panelScale=make("UIScale",panel,{Scale=1})
	local panelTitle=label(panel,"ConsoleName","",size(242,28),size(13,5),14,green)
	local function button(name,text,x,y,width,height)
		local b=make("TextButton",panel,{Name=name,Text=text,TextColor3=pale,TextSize=14,Font=Enum.Font.Code,
			Size=size(width,height),Position=size(x,y),BackgroundColor3=Color3.fromRGB(20,51,54),
			BorderSizePixel=0,Modal=true})
		stroke(b,soft,.44)
		return b
	end
	local leave=button("Exit","EXIT  Q",266,7,80,29)
	local power=button("BeamOff","BEAM OFF",233,244,113,30)
	local status=label(panel,"BearingStatus","",size(206,31),size(13,244),13,soft)
	local map=frame(panel,"HullSchematic",Color3.fromRGB(9,31,35),size(332,196),size(13,42))
	map.ClipsDescendants=true
	stroke(map,soft,.65)
	for x=9,329,16 do frame(map,"Vertical grid",soft,size(1,196),size(x,0)).BackgroundTransparency=.9 end
	for y=10,196,16 do frame(map,"Horizontal grid",soft,size(332,1),size(0,y)).BackgroundTransparency=.9 end
	local function polyline(points,color,width)
		for i=2,#points do
			local a,b=points[i-1],points[i]
			UI.line(map,a[1],a[2],b[1],b[2],color,width)
		end
	end
	-- Bow faces the top. The stern narrows between its two steering planes.
	local outline={{166,37},{152,40},{133,50},{120,66},{112,82},{111,117},{117,132},
		{103,151},{125,145},{145,156},{166,162},{187,156},{207,145},{229,151},
		{215,132},{221,117},{220,82},{212,66},{199,50},{180,40},{166,37}}
	polyline(outline,green,1.65)
	polyline({{123,64},{209,64}},soft,1)
	polyline({{112,94},{151,94},{151,109},{220,109}},soft,1)
	polyline({{121,132},{211,132}},soft,1)
	label(map,"Bridge","BRIDGE",size(74,14),size(141,71),11,pale)
	label(map,"Airlock","LOCK",size(42,14),size(181,116),10,soft)
	label(map,"Engine","ENGINE",size(70,14),size(140,137),11,pale)
	local routes={
		{{166,37},{166,28}},
		{{221,105},{263,105}},
		{{166,162},{166,172}},
		{{111,105},{68,105}},
	}
	for _,route in routes do polyline(route,soft,1.5) end
	local names={"BOW","STBD","STERN","PORT"}
	local positions={{145,45},{274,130},{145,205},{14,130}}
	local nodes={}
	for i,xy in positions do
		nodes[i]=button("Bearing"..i,"",xy[1],xy[2],68,32)
	end
	local grade=make("ColorCorrectionEffect",Lighting,{Name="HullCameraGain",Enabled=false,Brightness=.055,
		Contrast=.15,Saturation=-.8,TintColor=Color3.fromRGB(201,232,223)})
	-- The camera softens the rendered scene while its overlay and controls stay sharp.
	local lens=make("BlurEffect",Lighting,{Name="HullCameraSoftFocus",Enabled=false,Size=3})
	local mode
	local slot=1
	local previousFOV=70
	local previousMouse
	local deskMount
	local displayedSlot
	local syncUntil=0
	local nextNoise=0
	local function marker(i) return site:FindFirstChild("DiveCamera"..i,true) end
	local function tintMap(bearing,lit,powered)
		local color=if mode=="Light" then amber else green
		for i,b in nodes do
			local selected=i==bearing
			b.Text=string.format("%02d %s",i,names[i])
			b.BackgroundColor3=if selected and lit then color elseif selected then Color3.fromRGB(51,60,56) else Color3.fromRGB(20,51,54)
			b.TextColor3=if selected and lit then dark else pale
			b.UIStroke.Color=if selected then color else soft
		end
		status.Text=if mode=="Camera" then "FEED  "..names[bearing]
			elseif not powered then "POWER UNAVAILABLE"
			elseif lit then "BEAM  "..names[bearing] else "BEAM STANDBY"
		power.Visible=mode=="Light"
	end
	local function selectBearing(i)
		if not i then return end
		if mode=="Light" then
			net.Input:FireServer("AimSearchlight",i)
		elseif mode=="Camera" then
			slot=i
			tintMap(slot,true,true)
		end
	end
	for i,b in nodes do b.Activated:Connect(function() selectBearing(i) end) end
	power.Activated:Connect(function()
		if mode=="Light" then net.Input:FireServer("AimSearchlight",false) end
	end)
	local function quit() net.Input:FireServer("CloseOptics") end
	leave.Activated:Connect(quit)
	local keyOrder={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four}
	local function view(nextMode)
		if nextMode==mode then return end
		local wasOpen=mode~=nil
		mode=nextMode
		local cameraFeed=mode=="Camera"
		display.Visible=mode~=nil
		grade.Enabled=cameraFeed
		lens.Enabled=cameraFeed
		signalLayer.Visible=cameraFeed
		top.Visible=cameraFeed
		cross.Visible=cameraFeed
		display.BackgroundTransparency=if cameraFeed then 1 else .26
		local cam=workspace.CurrentCamera
		if mode then
			panelTitle.Text=if cameraFeed then "KESTREL 04  /  CCTV" else "KESTREL 04  /  SEARCHLIGHT"
			displayedSlot=nil
			nextNoise=0
			if cam then
				if not wasOpen then previousFOV=cam.FieldOfView end
				deskMount=if cameraFeed then nil else hull.CFrame:ToObjectSpace(cam.CFrame)
				cam.CameraType=Enum.CameraType.Scriptable
				cam.FieldOfView=if cameraFeed then 78 else previousFOV
			end
			if not wasOpen then previousMouse=UserInput.MouseBehavior end
			UserInput.MouseBehavior=Enum.MouseBehavior.Default
			Context:BindActionAtPriority("OpticsSelect",function(_,state,input)
				if state==Enum.UserInputState.Begin then selectBearing(table.find(keyOrder,input.KeyCode)) end
				return Enum.ContextActionResult.Sink
			end,false,3000,table.unpack(keyOrder))
			Context:BindActionAtPriority("OpticsClose",function(_,state)
				if state==Enum.UserInputState.Begin then quit() end
				return Enum.ContextActionResult.Sink
			end,false,3000,Enum.KeyCode.Q,Enum.KeyCode.ButtonB)
			if UserInput:GetLastInputType().Name:find("Gamepad",1,true) then GuiService.SelectedObject=nodes[slot] end
		else
			Context:UnbindAction("OpticsSelect")
			Context:UnbindAction("OpticsClose")
			if previousMouse then UserInput.MouseBehavior=previousMouse end
			if cam then
				cam.CameraType=Enum.CameraType.Custom
				cam.FieldOfView=previousFOV
				local char=Players.LocalPlayer.Character
				if char then cam.CameraSubject=char:FindFirstChildOfClass("Humanoid") end
			end
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(display) then GuiService.SelectedObject=nil end
		end
	end
	local function updateSignal(now)
		if displayedSlot~=slot then
			displayedSlot=slot
			syncUntil=now+.27
			nextNoise=0
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
		if not cam then return end
		local compact=cam.ViewportSize.X<720
		if scope.Visible then
			scopeScale.Scale=compact and .72 or .95
			scope.Position=UDim2.new(1,-10,1,compact and -88 or -12)
			local ratio=math.clamp((workspace:GetServerTimeNow()-(lastPulse or 0))/2.15,.003,1)
			wave.Size=UDim2.fromScale(ratio,ratio)
			waveStroke.Transparency=math.min(1,.1+ratio*.9)
		end
		if not mode then return end
		panelScale.Scale=math.min(1.15,(cam.ViewportSize.X-26)/358,(cam.ViewportSize.Y-70)/286)
		local cameraFeed=mode=="Camera"
		panel.AnchorPoint=if cameraFeed then Vector2.new(1,1) else Vector2.new(.5,.5)
		panel.Position=if cameraFeed then UDim2.new(1,-18,1,-18) else UDim2.fromScale(.5,.5)
		UserInput.MouseBehavior=Enum.MouseBehavior.Default
		if not cameraFeed then
			if deskMount then
				cam.CFrame=hull.CFrame*deskMount
				cam.Focus=cam.CFrame*CFrame.new(0,0,-4)
			end
			return
		end
		local m=marker(slot)
		if not m then title.Text="VIDEO  /  ACQUIRING" return end
		local now=os.clock()
		local acquiring=updateSignal(now)
		local mount=m:GetAttribute("HullMount")
		local pose=if mount then hull.CFrame*mount else m.CFrame
		-- Interference runs on its own clock. The camera pose follows the hull every frame.
		cam.CameraType=Enum.CameraType.Scriptable
		cam.CFrame=pose
		cam.Focus=pose*CFrame.new(0,0,-70)
		title.Text=string.format("CAM %02d  /  %s",slot,string.upper(m:GetAttribute("Label") or "HULL"))
		subject.Text=if acquiring then "SYNCING" else "LIVE"
	end)
	return {
		update=function(s)
			local inside=s.alive~=false and not s.outside
			view(if inside and s.cameraView then "Camera" elseif inside and s.searchlightView then "Light" else nil)
			if mode then tintMap(if mode=="Camera" then slot else s.aim or 1,mode=="Camera" or s.light,(s.battery or 0)>0) end
			scope.Visible=s.sonarOn==true and inside and not mode
			if scope.Visible and s.pingAt and s.pingAt~=lastPulse then draw(s) end
			if not scope.Visible then lastPulse=nil end
		end,
		reset=function() view(nil) scope.Visible=false lastPulse=nil end,
	}
end
