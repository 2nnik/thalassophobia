local Lighting=game:GetService("Lighting")
local SoundService=game:GetService("SoundService")
local UI=require(script.Parent.DiveClientStyle)
local c=UI.c
local off=UDim2.fromOffset
local function sound(name,asset,speed,looped,bass,mid,treble)
    local soundId=if type(asset)=="number" then "rbxassetid://"..asset else "rbxasset://sounds/"..asset
    local s=UI.make("Sound",SoundService,{Name="Hydrophone"..name,SoundId=soundId,
        PlaybackSpeed=speed,Looped=looped,Volume=0})
    UI.make("EqualizerSoundEffect",s,{LowGain=bass,MidGain=mid,HighGain=treble})
    return s
end
return function(gui)
    local frame=UI.frame(gui,c.black,nil,nil,1)
    frame.Name="DiveInstruments"
    frame.Visible=false
    -- Power and hull live on the Wet lab "Hull status monitor" (DiveClientFeedback fills it), not on the HUD.
    local top=UI.frame(frame,c.sea,off(14,9),off(223,48),.13)
    UI.edge(top)
    local depth=UI.label(top,"",30,c.white,UI.bold,off(12,5),off(116,41))
    depth.RichText=true
    local phase=UI.label(top,"DESCENT",13,c.green,UI.mono,off(129,14),off(84,25),Enum.TextXAlignment.Right)
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
    local function clearNotice()
        stamp+=1
        toast.Visible=false
    end
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
    local pressure=sound("PressureBed","action_falling.ogg",.71,true,8,2,-17)
    UI.make("FlangeSoundEffect",pressure,{Depth=.6,Mix=.35,Rate=.22})
    local sea=sound("Current","action_swim.mp3",.45,true,2,-14,-31)
    local ping=sound("Sonar","volume_slider.ogg",1.19,false,2,-5,-13)
    UI.make("EchoSoundEffect",ping,{Delay=.23,Feedback=.32,DryLevel=-2,WetLevel=-11})
    local impact=sound("Strain","impact_explosion_03.mp3",.52,false,5,-15,-40)
    local groan=sound("Hull","action_jump_land.mp3",.5,false,4,-12,-32)
    UI.make("ReverbSoundEffect",groan,{DecayTime=2,DryLevel=-4,WetLevel=-10})
    local cable=sound("TetherCreak","action_footsteps_plastic.mp3",.38,false,-7,1,-15)
    UI.make("EchoSoundEffect",cable,{Delay=.17,Feedback=.3,DryLevel=-5,WetLevel=-12})
    local bulkhead=sound("BulkheadRing","action_jump_land.mp3",.83,false,2,4,-10)
    UI.make("ReverbSoundEffect",bulkhead,{DecayTime=1.7,DryLevel=-3,WetLevel=-8})
    local driveShift=sound("DriveShift","action_get_up.mp3",.55,false,7,-2,-12)
    local distant=sound("DeepRumble","impact_water.mp3",.45,false,5,-11,-32)
    local scrape=sound("MetalScrape","impact_explosion_03.mp3",.59,false,0,-12,-23)
    local leak=sound("WaterIngress","action_swim.mp3",.78,true,0,-7,-14)
    local splash=sound("BreachSplash","impact_water.mp3",.83,false,2,-6,-17)
    local bell=sound("StationBell","volume_slider.ogg",.66,false,0,-4,-13)
    local recoveryAlarm=sound("RecoveryAlarm","volume_slider.ogg",.76,false,0,-2,-8)
    UI.make("EchoSoundEffect",recoveryAlarm,{Delay=.28,Feedback=.58,DryLevel=0,WetLevel=-5})
    UI.make("ReverbSoundEffect",distant,{DecayTime=3,DryLevel=-8,WetLevel=-12})
    UI.make("EchoSoundEffect",scrape,{Delay=.23,Feedback=.29,DryLevel=-7,WetLevel=-15})
    local angler=sound("AnglerGroan",9113980319,.77,false,3,-1,-17)
    UI.make("FlangeSoundEffect",angler,{Depth=.23,Mix=.19,Rate=.28})
    UI.make("ReverbSoundEffect",angler,{DecayTime=3.6,DryLevel=-1,WetLevel=-8})
    local anglerSource=UI.make("Part",workspace,{Name="LocalAnglerHydrophone",Anchored=true,CanCollide=false,
        CanTouch=false,CanQuery=false,CastShadow=false,Transparency=1,Size=Vector3.one})
    local anglerEcho=sound("AnglerBearing",9113980319,.69,false,2,-2,-17)
    anglerEcho.RollOffMinDistance,anglerEcho.RollOffMaxDistance=8,28
    anglerEcho.Parent=anglerSource
    UI.make("EchoSoundEffect",anglerEcho,{Delay=.38,Feedback=.25,DryLevel=-5,WetLevel=-10})
    local wormScrape=sound("WormOutside","action_footsteps_plastic.mp3",1.35,false,-5,1,-8)
    local wormAlarm=sound("WormWindowAlarm","volume_slider.ogg",.95,false,-2,0,-7)
    local wormIngress=sound("WormIngress","impact_water.mp3",.84,false,0,-1,-13)
    UI.make("EchoSoundEffect",wormScrape,{Delay=.15,Feedback=.48,DryLevel=0,WetLevel=-6})
    UI.make("EchoSoundEffect",wormAlarm,{Delay=.25,Feedback=.57,DryLevel=0,WetLevel=-5})
    local calls={
        {field="squid", audio=sound("SquidGurgle","impact_water.mp3",.88,false,1,-5,-13), pitch=.88, volume=.26},
        {field="swarm", audio=sound("BarnacleTick","action_jump_land.mp3",1.32,false,-9,-1,-12), pitch=1.32, volume=.24},
        {field="pursuer", audio=sound("PursuerPulse","impact_explosion_03.mp3",.36,false,6,-15,-28), pitch=.36, volume=.27},
    }
    UI.make("EchoSoundEffect",calls[1].audio,{Delay=.11,Feedback=.32,DryLevel=-4,WetLevel=-12})
    UI.make("EchoSoundEffect",calls[2].audio,{Delay=.08,Feedback=.37,DryLevel=-4,WetLevel=-10})
    UI.make("ReverbSoundEffect",calls[3].audio,{DecayTime=3.4,DryLevel=-4,WetLevel=-13})
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
    local nextAnglerCue=0
    local nextContact=0
    local nextGroan=0
    local nextScare=nil
    local nextWormCue=0
    local previousLeaks=0
    local rng=Random.new()
    local nextCall=0
    local bearings={"FORE","STARBOARD","AFT","PORT"}
    local function aimAnglerAudio()
        local camera=workspace.CurrentCamera
        local world=workspace:FindFirstChild("Thalassa")
        local contacts=world and world:FindFirstChild("Contacts")
        local fish=contacts and contacts:FindFirstChild("Leviathan")
        if not camera or not fish then return end
        local origin=camera.CFrame.Position
        local offset=fish:GetPivot().Position-origin
        if offset.Magnitude>.01 then anglerSource.Position=origin+offset.Unit*7.5 end
    end
    local function resize()
        local w=frame.AbsoluteSize.X
        local compact=w<670
        if compact then
            top.Position=off(7,4)
            panel.Position=off(7,60)
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
        status.Position=UDim2.new(.5,0,0,compact and 136 or 12)
        status.Size=off(math.min(300,math.max(145,w-590)),48)
    end
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    local function reset()
        previous=nil
        nextScare=nil
        nextCall,nextContact,nextGroan,previousLeaks,nextAnglerCue,nextWormCue=0,0,0,0,0,0
        clearNotice()
        for _,call in calls do call.due=nil call.audio:Stop() end
        frame.Visible=false
        grade.Enabled=false
        blur.Enabled=false
        haze.Visible=false
        for _,s in {noise,pressure,sea,ping,impact,groan,cable,bulkhead,driveShift,distant,scrape,leak,splash,bell,
            recoveryAlarm,angler,anglerEcho,wormScrape,wormAlarm,wormIngress} do s:Stop() end
    end
    local function update(s)
        frame.Visible=not (s.cameraView or s.searchlightView)
        local at=math.max(0,math.floor((s.depth or 0)+.5))
        depth.Text=string.format('%03d <font size="14">M</font>',at)
        phase.Text=string.upper(s.phase=="Bottom" and "SEAFLOOR" or s.phase)
        engine.Text=s.engine and "ENGINE   RUNNING" or (s.coast or 0)>.2 and "ENGINE   COASTING" or "ENGINE   SILENT"
        flood.Text="LIGHT    "..(s.light and (bearings[s.aim] or "FORE") or "OFF")
        local outside=s.outside
        local tutorial=s.difficulty=="Easy"
        local insideWarning=tutorial and s.warning
        local sonar=s.sonar
        local hint=""
        if s.alive==false then hint=tutorial and "Your crew is still on the dive." or ""
        elseif outside then hint=""
        elseif sonar and sonar~="" then hint=sonar
        elseif insideWarning and insideWarning~="" then hint=insideWarning
        elseif tutorial and s.phase=="Bottom" then hint="Take the airlock and follow the salvage beacon."
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
        local darkness=math.sqrt(math.clamp(at/math.max(1,s.maxDepth or 10000),0,1))
        grade.Brightness=outside and (-.012-.035*darkness) or -.006
        grade.Contrast=outside and .07 or .025
        grade.Saturation=outside and -.30 or -.12
        grade.TintColor=outside and Color3.fromRGB(207,235,235):Lerp(Color3.fromRGB(160,200,215),darkness)
            or Color3.fromRGB(236,248,247)
        blur.Enabled=outside==true
        haze.Visible=outside==true
        local now=os.clock()
        local proximity=s.shark or 0
        local before=previous and previous.shark or 0
        local anglerPresent=s.alive~=false and proximity>0
        local ambience=anglerPresent and .38 or 1
        loop(noise,s.alive~=false and s.engine and (outside and .27 or .7)*ambience or 0)
        loop(pressure,s.alive~=false and (.27+.52*darkness)*ambience or 0)
        loop(sea,outside and .20*ambience or 0)
        if anglerPresent then
            aimAnglerAudio()
            local gettingClose=before<.43 and proximity>=.43
            if before==0 or gettingClose or now>=nextAnglerCue then
                local gain=(.59+.23*proximity)*(outside and .88 or 1)
                play(angler,gain,.8-.09*proximity)
                play(anglerEcho,gain*.30,.72-.05*proximity)
                nextAnglerCue=now+(proximity>=.43 and 5.7 or 7.2)
                nextScare=now+8
            end
        else
            nextAnglerCue=0
        end
        local leaks=0
        for _,crack in s.cracks or {} do if crack then leaks+=1 end end
        for _,severity in s.breaches or {} do leaks+=severity*2 end
        local inside=not outside and s.alive~=false
        loop(leak,inside and math.min(.44,leaks*.08) or 0)
        if inside and leaks>previousLeaks then play(splash,.44) end
        if inside and previous and s.engine~=previous.engine then
            play(driveShift,.38,s.engine and .72 or .51)
        end
        previousLeaks=leaks
        if previous and previous.phase~=s.phase and (s.phase=="Bottom" or s.phase=="Ascent") then
            play(bell,.22,s.phase=="Bottom" and .66 or 1)
            if tutorial and s.phase=="Ascent" then notify("Artifact aboard. Keep the cage rising.") end
        end
        if s.alive~=false and s.phase=="Bottom" and (s.pursuer or 0)>0 then
            local last=previous and previous.pursuer or 0
            if last==0 or (last<.68 and s.pursuer>=.68) then
                play(recoveryAlarm,.33,last==0 and .76 or 1.02)
            end
        end
        for _,call in calls do
            local intensity=s[call.field] or 0
            local before=previous and previous[call.field] or 0
            local approach=intensity>0 and before<=0
            if intensity<=0 or s.alive==false then
                call.due=nil
            elseif approach then
                play(call.audio,call.volume*(anglerPresent and .72 or 1.25)*(outside and .85 or 1),call.pitch)
                call.due=now+rng:NextNumber(11,24)
                nextCall=now+4
            elseif not call.due then
                call.due=now+rng:NextNumber(2.5,6.5)
            elseif now>=call.due and now>=nextCall and not anglerPresent then
                local strength=(.78+math.min(intensity,1)*.35)*(outside and .8 or 1)
                play(call.audio,call.volume*strength,call.pitch*rng:NextNumber(.93,1.07))
                call.due=now+rng:NextNumber(11,24)
                nextCall=now+4
                nextScare=math.max(nextScare or now,now+4)
            end
        end
        local crawlerActive=s.alive~=false and (s.crawler or 0)>0
        if crawlerActive then
            local wasOutside=previous and (previous.crawler or 0)>0 and not previous.boarded
            if s.boarded and not (previous and previous.boarded) then
                play(wormIngress,outside and .40 or .56)
                nextScare=now+6
            elseif not s.boarded then
                local urgent=s.crawlerEntryWarning and s.cracks and s.cracks[s.crawlerSection]
                local wasUrgent=previous and previous.crawlerEntryWarning
                if urgent and not wasUrgent then
                    play(wormAlarm,outside and .42 or .60)
                    nextWormCue=now+1.9
                    nextScare=now+5
                elseif not wasOutside or now>=nextWormCue then
                    play(wormScrape,outside and .43 or .58,urgent and 1.6 or 1.35)
                    nextWormCue=now+(urgent and 1.55 or 3.6)
                    nextScare=now+4
                end
            end
        end
        if not nextScare then nextScare=now+rng:NextNumber(7,14) end
        if s.alive~=false and at>20 and now>=nextScare and not anglerPresent then
            if outside then
                if rng:NextNumber()<.46 then play(cable,.24,rng:NextNumber(.35,.51))
                else play(distant,.27,rng:NextNumber(.45,.61)) end
            else
                local roll=rng:NextNumber()
                if roll<.34 then play(distant,.22,rng:NextNumber(.40,.57))
                elseif roll<.61 then play(bulkhead,.36,rng:NextNumber(.70,.99))
                else play(scrape,.16,rng:NextNumber(.48,.67)) end
            end
            nextScare=now+rng:NextNumber(8,16)
        end
        if previous and (s.hull or 100)<(previous.hull or 100)-4 then play(impact,.55) end
        local otherThreat=math.max(s.squid or 0,s.crawler or 0,s.pursuer or 0)
        if otherThreat>0 and now>nextContact and not outside and not anglerPresent then
            play(ping,.29,.8+otherThreat*.38)
            nextContact=now+math.max(2,7-4*otherThreat)
        end
        if now>nextGroan and at>100 and not outside and s.engine then
            if not anglerPresent then play(groan,.27,.43+math.random()*.13) end
            nextGroan=now+math.random(13,26)
        end
        previous=s
    end
    return {update=update,reset=reset,notify=notify,clearNotice=clearNotice}
end
