local Lighting=game:GetService("Lighting")
local SoundService=game:GetService("SoundService")
local UI=require(script.Parent.DiveClientStyle)
local c=UI.c
local off=UDim2.fromOffset
local function sound(name,asset,speed,looped,bass,mid,treble)
    local s=UI.make("Sound",SoundService,{Name="Hydrophone"..name,SoundId="rbxasset://sounds/"..asset,
        PlaybackSpeed=speed,Looped=looped,Volume=0})
    UI.make("EqualizerSoundEffect",s,{LowGain=bass,MidGain=mid,HighGain=treble})
    return s
end
return function(gui)
    local frame=UI.frame(gui,c.black,nil,nil,1)
    frame.Name="DiveInstruments"
    frame.Visible=false
    local top=UI.frame(frame,c.sea,off(14,9),off(223,92),.13)
    UI.edge(top)
    local depth=UI.label(top,"000",32,c.white,UI.bold,off(12,5),off(86,41))
    UI.label(top,"M",15,c.soft,UI.mono,off(83,13),off(21,27))
    local phase=UI.label(top,"DESCENT",13,c.green,UI.mono,off(107,14),off(106,25),Enum.TextXAlignment.Right)
    local function gauge(parent,y,caption)
        UI.label(parent,caption,12,c.soft,UI.mono,off(12,y),off(48,18))
        local track=UI.frame(parent,c.grid,off(66,y+7),off(99,5))
        local bar=UI.frame(track,c.green)
        local value=UI.label(parent,"100%",13,c.white,UI.mono,off(165,y-1),off(46,20),Enum.TextXAlignment.Right)
        return function(n)
            n=math.clamp(n or 0,0,100)
            bar.Size=UDim2.fromScale(n/100,1)
            bar.BackgroundColor3=n<=20 and c.red or n<45 and c.orange or c.green
            value.Text=math.floor(n+.5).."%"
        end
    end
    local power=gauge(top,45,"POWER")
    local hull=gauge(top,68,"HULL")
    local panel=UI.frame(frame,c.sea,nil,nil,.15)
    UI.edge(panel)
    local rail=UI.frame(panel,c.orange,nil,UDim2.new(0,3,1,0))
    local signal=UI.label(panel,"",11,c.orange,UI.mono,off(12,4),UDim2.new(1,-24,0,18))
    local message=UI.label(panel,"",15,c.white,UI.bold,off(12,21),UDim2.new(1,-24,1,-25))
    message.TextWrapped=true
    message.TextTruncate=Enum.TextTruncate.None
    local strip=UI.frame(frame,c.sea,nil,off(227,65),.22)
    UI.edge(strip)
    local engine=UI.label(strip,"",13,c.white,UI.mono,off(10,6),off(208,20))
    local flood=UI.label(strip,"",13,c.soft,UI.mono,off(10,29),off(208,22))
    local status=UI.label(frame,"",14,c.orange,UI.bold,nil,nil,Enum.TextXAlignment.Center)
    status.BackgroundColor3=c.sea
    status.BackgroundTransparency=.12
    status.TextWrapped=true
    local toast=UI.label(gui,"",15,c.white,UI.bold,nil,nil,Enum.TextXAlignment.Center)
    toast.Name="TerminalNotice"
    toast.ZIndex=10
    toast.AnchorPoint=Vector2.new(.5,1)
    toast.Position=UDim2.new(.5,0,1,-16)
    toast.Size=UDim2.new(.8,0,0,42)
    UI.make("UISizeConstraint",toast,{MaxSize=Vector2.new(530,55)})
    toast.BackgroundColor3=c.raised
    toast.BackgroundTransparency=.02
    toast.TextWrapped=true
    toast.Visible=false
    local stamp=0
    local function notify(text)
        if type(text)~="string" or text=="" then return end
        stamp+=1
        local current=stamp
        toast.Visible=true
        toast.Text=text
        task.delay(3,function()
            if stamp==current then toast.Visible=false end
        end)
    end
    local noise=sound("Drive","action_falling.ogg",.37,true,6,-13,-35)
    UI.make("FlangeSoundEffect",noise,{Depth=.5,Mix=.55,Rate=.8})
    local sea=sound("Current","action_swim.mp3",.45,true,2,-19,-40)
    local ping=sound("Sonar","volume_slider.ogg",1.19,false,2,-5,-13)
    UI.make("EchoSoundEffect",ping,{Delay=.23,Feedback=.32,DryLevel=-2,WetLevel=-11})
    local impact=sound("Strain","impact_explosion_03.mp3",.52,false,5,-15,-40)
    local groan=sound("Hull","action_jump_land.mp3",.5,false,4,-12,-32)
    UI.make("ReverbSoundEffect",groan,{DecayTime=2,DryLevel=-4,WetLevel=-10})
    local distant=sound("DeepRumble","impact_water.mp3",.45,false,5,-11,-32)
    local scrape=sound("MetalScrape","impact_explosion_03.mp3",.59,false,0,-12,-23)
    UI.make("ReverbSoundEffect",distant,{DecayTime=3,DryLevel=-8,WetLevel=-12})
    UI.make("EchoSoundEffect",scrape,{Delay=.23,Feedback=.29,DryLevel=-7,WetLevel=-15})
    local calls={
        {field="shark", audio=sound("AnglerGroan","action_falling.ogg",.35,false,7,-12,-32), pitch=.35, volume=.19},
        {field="squid", audio=sound("SquidGurgle","impact_water.mp3",.84,false,1,-9,-16), pitch=.84, volume=.17},
        {field="crawler", audio=sound("CrawlerSkitter","action_footsteps_plastic.mp3",1.55,false,-9,-6,-13), pitch=1.55, volume=.11},
        {field="swarm", audio=sound("BarnacleTick","action_jump_land.mp3",1.32,false,-9,-5,-18), pitch=1.32, volume=.10},
        {field="pursuer", audio=sound("PursuerPulse","impact_explosion_03.mp3",.36,false,6,-22,-36), pitch=.36, volume=.18},
    }
    UI.make("FlangeSoundEffect",calls[1].audio,{Depth=.75,Mix=.55,Rate=.38})
    UI.make("EchoSoundEffect",calls[2].audio,{Delay=.11,Feedback=.32,DryLevel=-4,WetLevel=-12})
    UI.make("EchoSoundEffect",calls[4].audio,{Delay=.08,Feedback=.37,DryLevel=-4,WetLevel=-10})
    UI.make("ReverbSoundEffect",calls[5].audio,{DecayTime=3.4,DryLevel=-4,WetLevel=-13})
    local function loop(s,volume)
        s.Volume=volume
        if volume>0 and not s.IsPlaying then s:Play()
        elseif volume==0 and s.IsPlaying then s:Stop() end
    end
    local function play(s,volume,pitch)
        if pitch then s.PlaybackSpeed=pitch end
        s.Volume=volume
        s:Play()
    end
    local grade=UI.make("ColorCorrectionEffect",Lighting,{Name="DiveLocalGrade",Enabled=false})
    local blur=UI.make("DepthOfFieldEffect",Lighting,{Name="DiveTetherHaze",Enabled=false,FocusDistance=5,
        InFocusRadius=46,NearIntensity=0,FarIntensity=.24})
    local haze=UI.frame(frame,Color3.fromRGB(16,56,66),nil,nil,.83)
    haze.ZIndex=0
    haze.Visible=false
    local previous
    local nextContact=0
    local nextGroan=0
    local nextScare=nil
    local wasBoarded=false
    local rng=Random.new()
    local nextCall=0
    local bearings={"FORE","STARBOARD","AFT","PORT"}
    local function resize()
        local w=frame.AbsoluteSize.X
        local compact=w<670
        if compact then
            top.Position=off(7,4)
            panel.Position=off(7,105)
            panel.Size=off(math.min(math.max(w-14,180),335),70)
            strip.AnchorPoint=Vector2.new(1,0)
            strip.Position=UDim2.new(1,-7,0,4)
            strip.Size=off(math.max(118,math.min(w-242,197)),65)
            engine.Size=UDim2.new(1,-14,0,21)
            flood.Size=UDim2.new(1,-14,0,22)
            engine.TextSize=11
            flood.TextSize=11
        else
            top.Position=off(14,9)
            panel.AnchorPoint=Vector2.new(0,0)
            panel.Position=UDim2.new(1,-335,0,9)
            panel.Size=off(320,66)
            strip.AnchorPoint=Vector2.new(0,1)
            strip.Position=UDim2.new(0,14,1,-16)
            strip.Size=off(226,65)
            engine.Size=off(206,21)
            flood.Size=off(206,22)
            engine.TextSize=13
            flood.TextSize=13
        end
        status.AnchorPoint=Vector2.new(.5,0)
        status.Position=UDim2.new(.5,0,0,compact and 181 or 12)
        status.Size=off(math.min(300,math.max(145,w-590)),48)
    end
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    local function reset()
        previous=nil
        nextScare,wasBoarded=nil,false
        nextCall=0
        for _,call in calls do call.due=nil call.audio:Stop() end
        frame.Visible=false
        grade.Enabled=false
        blur.Enabled=false
        haze.Visible=false
        for _,s in ipairs({noise,sea,ping,impact,groan,distant,scrape}) do s:Stop() end
    end
    local function update(s)
        frame.Visible=not s.cameraView
        local at=math.max(0,math.floor((s.depth or 0)+.5))
        depth.Text=string.format("%03d",at)
        phase.Text=string.upper(s.phase=="Bottom" and "SEAFLOOR" or s.phase)
        power(s.battery)
        hull(s.hull)
        engine.Text=s.engine and "ENGINE   RUNNING" or (s.coast or 0)>.2 and "ENGINE   COASTING" or "ENGINE   SILENT"
        flood.Text="LIGHT    "..(s.light and (bearings[s.aim] or "FORE") or "OFF")
        local outside=s.outside
        local insideWarning=s.warning
        local sonar=s.sonar
        local hint=""
        if s.alive==false then hint="Your crew is still on the dive."
        elseif outside then hint=""
        elseif sonar and sonar~="" then hint=sonar
        elseif insideWarning and insideWarning~="" then hint=insideWarning
        elseif s.phase=="Bottom" then hint="Retrieve the artifact to begin ascent."
        elseif not previous or previous.phase~=s.phase then
            if s.phase=="Ascent" then notify("Artifact aboard. Keep the cage rising.") end
        end
        panel.Visible=hint~=""
        signal.Text=outside and "TETHER LINK" or sonar and sonar~="" and "SONAR RETURN" or "CAGE TELEMETRY"
        message.Text=hint
        local alert=insideWarning and insideWarning~=""
        signal.TextColor3=alert and c.orange or c.green
        rail.BackgroundColor3=signal.TextColor3
        if s.alive==false then status.Text="DIVER LOST"
        elseif outside then status.Text="OXYGEN   "..math.max(0,math.ceil(s.oxygen or 0)).." s"
        elseif s.systemsOffline then status.Text="CAMERAS / SONAR OFFLINE\nPLANKS   "..tostring(s.planks or 0).." / 3"
        elseif s.hasExtinguisher then status.Text=(s.extinguisherEquipped and "FOAM EQUIPPED   " or "FOAM STOWED   ")
            ..tostring(s.charges or 0).." / "..tostring(s.capacity or 3)
        elseif (s.planks or 0)>0 then status.Text="PLANKS   "..tostring(s.planks).." / 3"
        else status.Text="" end
        status.Visible=status.Text~=""
        grade.Enabled=true
        grade.Brightness=outside and -.045 or -.006
        grade.Contrast=outside and .07 or .025
        grade.Saturation=outside and -.30 or -.12
        grade.TintColor=outside and Color3.fromRGB(164,205,215) or Color3.fromRGB(236,248,247)
        blur.Enabled=outside==true
        haze.Visible=outside==true
        loop(noise,s.alive~=false and s.engine and (outside and .065 or .12) or 0)
        loop(sea,outside and .13 or 0)
        local now=os.clock()
        for _,call in calls do
            local intensity=s[call.field] or 0
            if intensity<=0 or s.alive==false then
                call.due=nil
            elseif not call.due then
                call.due=now+rng:NextNumber(2.5,6.5)
            elseif now>=call.due and now>=nextCall then
                local strength=(.78+math.min(intensity,1)*.35)*(outside and .8 or 1)
                play(call.audio,call.volume*strength,call.pitch*rng:NextNumber(.93,1.07))
                call.due=now+rng:NextNumber(11,24)
                nextCall=now+4
                nextScare=math.max(nextScare or now,now+4)
            end
        end
        if not nextScare then nextScare=now+rng:NextNumber(16,27) end
        if s.alive~=false and s.boarded and not wasBoarded and not outside then
            play(scrape,.17,.59)
            nextScare=now+rng:NextNumber(24,44)
        elseif s.alive~=false and at>20 and now>=nextScare then
            if outside or rng:NextNumber()<.65 then play(distant,outside and .13 or .15,rng:NextNumber(.39,.51))
            else play(scrape,.11,rng:NextNumber(.50,.66)) end
            nextScare=now+rng:NextNumber(23,47)
        end
        wasBoarded=s.boarded==true
        if previous and (s.hull or 100)<(previous.hull or 100)-4 then play(impact,.36) end
        local proximity=math.max(s.shark or 0,s.squid or 0,s.crawler or 0,s.pursuer or 0)
        if proximity>0 and now>nextContact and not outside then
            play(ping,.20,.8+proximity*.38)
            nextContact=now+math.max(2,7-4*proximity)
        end
        if now>nextGroan and at>100 and not outside and s.engine then
            play(groan,.14,.43+math.random()*.13)
            nextGroan=now+math.random(15,33)
        end
        previous=s
    end
    return {update=update,reset=reset,notify=notify}
end
