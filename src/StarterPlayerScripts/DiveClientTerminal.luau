local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local UI=require(script.Parent.DiveClientStyle)
local c=UI.c
local off=UDim2.fromOffset
local scale=UDim2.fromScale
local color=Color3.fromRGB
local function gradient(parent,colors,rotation,alpha)
    return UI.make("UIGradient",parent,{Color=ColorSequence.new(colors),Rotation=rotation or 0,
        Transparency=alpha or NumberSequence.new(0)})
end

-- A separate, client-only title scene keeps the lobby independent of the dive camera and lighting.
local function titleScene(parent)
    gradient(parent,{
        ColorSequenceKeypoint.new(0,color(17,74,83)),
        ColorSequenceKeypoint.new(.42,color(6,35,44)),
        ColorSequenceKeypoint.new(1,color(2,11,21)),
    },110)
    local viewport=UI.make("ViewportFrame",parent,{
        Name="UnderwaterScene",BackgroundTransparency=1,Size=scale(1,1),
        Ambient=color(39,81,92),LightColor=color(144,229,222),LightDirection=Vector3.new(-.6,-1,-.4),
        ImageColor3=color(163,212,213),
    })
    local world=UI.make("WorldModel",viewport)
    local camera=UI.make("Camera",viewport,{FieldOfView=43})
    viewport.CurrentCamera=camera
    local function solid(where,class,name,size,pose,shade,shape)
        local p=UI.make(class,where,{Name=name,Anchored=true,CanCollide=false,
            Size=size,CFrame=pose,Color=shade,CastShadow=false})
        if shape then p.Shape=shape end
        return p
    end
    local function oval(where,name,size,pose,shade)
        return solid(where,"Part",name,size,pose,shade,Enum.PartType.Ball)
    end
    local function bar(where,name,a,b,width,shade)
        return solid(where,"Part",name,Vector3.new(width,width,(a-b).Magnitude),
            CFrame.lookAt((a+b)*.5,b),shade)
    end
    local function v(x,y,z) return Vector3.new(x,y,z) end
    local rng=Random.new(180)
    for i=1,32 do
        local x=rng:NextNumber(-59,55)
        local z=rng:NextNumber(-55,40)
        local h=rng:NextNumber(1,4)+(math.abs(x)>28 and rng:NextNumber(2,11) or 0)
        local rock=solid(world,"WedgePart","Basalt",v(rng:NextNumber(5,18),h,rng:NextNumber(6,21)),
            CFrame.new(x,-8+h/3,z)*CFrame.Angles(rng:NextNumber(-.3,.3),rng:NextNumber(0,6),0),
            color(12+i%4*6,25+i%5*5,35+i%6*4))
        rock.Transparency=math.clamp((-z-8)/62,.06,.65)
    end
    local vessel=UI.make("Model",world,{Name="Kestrel survey bell"})
    local steel,rim,light=color(77,113,110),color(20,46,51),color(128,247,212)
    oval(vessel,"Pressure hull",v(7.4,6.4,18),CFrame.new(),steel)
    oval(vessel,"Forward window",v(6.25,5.2,4.5),CFrame.new(0,.18,-7.25),color(16,44,58))
    oval(vessel,"Window reflection",v(4.3,.28,2),CFrame.new(-.15,1.58,-8.5)*CFrame.Angles(.3,0,.14),color(117,204,201))
    for i=-2,2 do
        local z=i*2.45
        local radius=math.sqrt(1-(z/9)^2)
        for j=0,15 do
            local a,b=j*math.pi/8,(j+1)*math.pi/8
            bar(vessel,"Hull hoop",v(3.82*radius*math.cos(a),3.27*radius*math.sin(a),z),
                v(3.82*radius*math.cos(b),3.27*radius*math.sin(b),z),.23,rim)
        end
    end
    for _,s in ipairs({-1,1}) do
        oval(vessel,"Ballast tank",v(2.1,1.9,13),CFrame.new(3.8*s,-1.65,1),color(43,75,76))
        solid(vessel,"Part","Landing skid",v(.92,.43,12),CFrame.new(3.4*s,-3.85,0),rim)
        for _,z in ipairs({-3.65,3.65}) do
            bar(vessel,"Skid truss",v(2.4*s,-2.2,z),v(3.4*s,-3.85,z+.65),.31,rim)
        end
        oval(vessel,"Floodlight shroud",v(1.35,1.35,2.1),CFrame.new(2.7*s,-.78,-6.2),rim)
        oval(vessel,"Floodlight",v(.96,.96,.37),CFrame.new(2.7*s,-.78,-7.23),light)
        for i=-1,1 do
            oval(vessel,"Navigation lamp",v(.18,.18,.71),CFrame.new(3.66*s,.55,i*.85+1.25),light)
        end
    end
    local origin=CFrame.new(0,.7,-4)*CFrame.Angles(0,-1.25,-.10)
    vessel:PivotTo(origin)
    local dust=UI.frame(parent,Color3.new(),nil,nil,1)
    local particles={}
    for _=1,39 do
        local x,y=rng:NextNumber(),rng:NextNumber()
        local d=UI.frame(dust,color(156,213,206),scale(x,y),off(rng:NextInteger(1,3),rng:NextInteger(1,3)),rng:NextNumber(.38,.84))
        table.insert(particles,{d,x,y,rng:NextNumber(.007,.025)})
    end
    local shade=UI.frame(parent,Color3.new(1,1,1))
    gradient(shade,{ColorSequenceKeypoint.new(0,c.black),ColorSequenceKeypoint.new(1,color(3,19,25))},0,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.37,.13),
            NumberSequenceKeypoint.new(.70,.73),NumberSequenceKeypoint.new(1,.27),
        }))
    local t=0
    local step
    step=RunService.RenderStepped:Connect(function(dt)
        if not parent.Parent then step:Disconnect() return end
        if not parent.Visible then return end
        t+=dt
        local ratio=parent.AbsoluteSize.X/math.max(1,parent.AbsoluteSize.Y)
        local wide=ratio>1.28
        camera.CFrame=CFrame.lookAt(v(19+math.sin(t*.18)*.65,5,wide and 26 or 34),
            v(wide and -6.4 or -.2,wide and -.8 or 1.4,-4))
        vessel:PivotTo(origin*CFrame.new(0,math.sin(t*.62)*.38,0)*CFrame.Angles(0,math.sin(t*.23)*.09,math.sin(t*.36)*.025))
        for _,p in ipairs(particles) do
            p[1].Position=scale((p[2]+t*p[4]*.7)%1,(p[3]-t*p[4])%1)
        end
    end)
end
local function chart(parent)
    local f=UI.frame(parent,c.sea,off(22,99),off(352,369))
    f.ClipsDescendants=true
    UI.edge(f,c.grid)
    for x=0,352,32 do UI.frame(f,c.grid,off(x,0),off(1,369),.35) end
    for y=0,369,32 do UI.frame(f,c.grid,off(0,y),off(352,1),.35) end
    UI.label(f,"BATHYMETRIC SECTION",12,c.soft,UI.mono,off(16,12),off(222,20))
    -- Depth profile with a steep continental shelf and a trench cut.
    local ridge={141,145,150,148,156,159,176,181,199,206,235,251,259,277,294,292,304,302,290,276,269,252,243,236,230,219,203,196,191,177,174,160,152,148,143,139}
    for level=0,6 do
        local prev
        for i,h in ipairs(ridge) do
            local y=h+level*9+math.sin(i*.58+level*.8)*level*1.6
            if prev then UI.line(f,(i-2)*10.3,prev,(i-1)*10.3,y,level==0 and c.soft or c.line,level==0 and 2 or 1) end
            prev=y
        end
    end
    for y=60,264,10 do UI.frame(f,c.green,off(169,y),off(1,5)) end
    UI.frame(f,c.green,off(31,57),off(285,1),.35)
    for i,label in ipairs({"0 M","2,500 M","5,000 M","7,500 M","10,000 M"}) do
        local y=55+(i-1)*55
        UI.frame(f,c.soft,off(4,y+2),off(5,1))
        UI.label(f,label,10,c.soft,UI.mono,off(11,y-7),off(62,18))
    end
    UI.line(f,159,74,169,64,c.green,2)
    UI.line(f,179,74,169,64,c.green,2)
    local cage=UI.frame(f,c.panel,off(154,74),off(30,17))
    UI.edge(cage,c.green)
    for i=1,3 do UI.frame(cage,c.green,off(i*7,1),off(1,15)) end
    local target=UI.frame(f,c.orange,off(166,277),off(7,7))
    target.Rotation=45
    UI.label(f,"ARTIFACT",11,c.orange,UI.mono,off(181,268),off(78,22))
    UI.frame(f,c.line,off(15,333),off(322,1))
    UI.label(f,"TARGET DEPTH",12,c.soft,UI.mono,off(15,341),off(145,20))
    UI.label(f,"10,000 M",15,c.white,UI.mono,off(220,340),off(114,23),Enum.TextXAlignment.Right)
    return f
end
return function(gui,send)
    local backdrop=UI.frame(gui,c.black)
    backdrop.Name="CrewTerminal"
    titleScene(backdrop)
    local home=UI.frame(backdrop,c.black,nil,nil,1)
    local hero=UI.frame(home,c.black,nil,off(520,495),1)
    local heroZoom=UI.make("UIScale",hero,{Scale=1})
    UI.frame(hero,c.green,off(0,8),off(26,2))
    UI.label(hero,"KESTREL 04  /  SURVEY BELL",14,c.green,UI.mono,off(39,-3),off(370,26))
    local heroTitle=UI.label(hero,"THALASSO\nPHOBIA",81,c.white,Enum.Font.GothamBlack,off(-3,22),off(520,180))
    heroTitle.LineHeight=.77
    local heroBrief=UI.label(hero,"Artifact recovery  •  10,000 m",17,c.soft,UI.body,off(0,192),off(390,28))
    local heroStatus=UI.label(hero,"",14,c.orange,UI.mono,off(0,462),off(510,30))
    local heroButtons={}
    local function heroButton(value,detail,id,top,callback,primary)
        local b=UI.button(hero,"",id,primary and c.green or c.black,c.white,callback)
        b.Position,b.Size=off(0,top),off(340,49)
        b.BackgroundTransparency=primary and .03 or .30
        local foreground=primary and c.black or c.white
        if not primary then UI.edge(b,c.grid) end
        UI.frame(b,primary and c.black or c.green,off(0,0),off(2,49),primary and .7 or .1)
        local caption=UI.label(b,value,18,foreground,UI.bold,off(14,3),off(280,26))
        local sub=UI.label(b,detail,12,primary and c.surface or c.soft,UI.mono,off(14,25),off(286,20))
        UI.label(b,"›",24,foreground,UI.body,off(302,5),off(26,36),Enum.TextXAlignment.Right)
        table.insert(heroButtons,b)
        return b,caption,sub
    end
    local homeWallet=UI.label(home,"",14,c.soft,UI.mono,nil,nil,Enum.TextXAlignment.Right)
    local shell=UI.frame(backdrop,c.surface)
    shell.AnchorPoint=Vector2.new(.5,.5)
    shell.Position=UDim2.fromScale(.5,.5)
    UI.edge(shell,c.line)
    local zoom=UI.make("UIScale",shell,{Scale=1})
    UI.frame(shell,c.green,off(0,0),off(50,4))
    local name=UI.label(shell,"DIVE TERMINAL",35,c.white,Enum.Font.GothamBlack,off(21,15),off(488,47))
    local subtitle=UI.label(shell,"KESTREL 04",13,c.green,UI.mono,off(23,61),off(345,21))
    local wallet=UI.label(shell,"",13,c.soft,UI.mono,nil,nil,Enum.TextXAlignment.Right)
    local divider=UI.frame(shell,c.line,off(0,88),UDim2.new(1,0,0,1))
    local left=chart(shell)
    local nav=UI.frame(shell,c.surface,nil,nil,1)
    local content=UI.make("ScrollingFrame",shell,{Name="TerminalContent",BorderSizePixel=0,BackgroundTransparency=1,
        ScrollBarThickness=4,ScrollBarImageColor3=c.line,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,VerticalScrollBarInset=Enum.ScrollBarInset.Always})
    UI.make("UIPadding",content,{PaddingBottom=UDim.new(0,5),PaddingRight=UDim.new(0,6),PaddingLeft=UDim.new(0,2),PaddingTop=UDim.new(0,2)})
    local layout=UI.make("UIListLayout",content,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
    local footer=UI.label(shell,"",12,c.soft,UI.mono,off(23,477),off(852,26))
    local modal=UI.make("TextButton",backdrop,{Text="",BackgroundTransparency=1,Size=off(1,1),Modal=true,Selectable=false,
        AutoButtonColor=false,Active=true})
    local tab="HOME"
    local state={}
    local report=nil
    local spinUntil=0
    local spinStarted=0
    local spinResultId
    local spinPreview
    local selectedResult
    local render
    local navItems={}
    local order=0
    local function row(height)
        order+=1
        local f=UI.frame(content,c.surface,nil,UDim2.new(1,0,0,height),1)
        f.LayoutOrder=order
        return f
    end
    local function title(text)
        UI.label(row(30),text,22,c.white,UI.bold)
    end
    local function para(text,height)
        local t=UI.label(row(height or 40),text,15,c.soft)
        t.TextWrapped=true
        t.TextTruncate=Enum.TextTruncate.None
    end
    local function label(text)
        UI.label(row(18),text,12,c.green,UI.mono)
    end
    local function buttonRow(items,height)
        local f=row(height or 42)
        for i,v in ipairs(items) do
            local b=UI.button(f,v[1],v[2],v[4] or c.raised,v[5] or c.white,v[3])
            b.Position=UDim2.new((i-1)/#items,i==1 and 0 or 3,0,0)
            b.Size=UDim2.new(1/#items,#items==1 and 0 or -4,1,0)
        end
    end
    local function entry(nameText,detail,caption,id,onClick)
        local f=row(60)
        f.BackgroundTransparency=0
        f.BackgroundColor3=c.panel
        f.Name="Entry_"..nameText
        f.Selectable=caption==nil
        local pad=caption and 116 or 16
        UI.label(f,nameText,15,c.white,UI.bold,off(10,5),UDim2.new(1,-pad,0,22))
        local d=UI.label(f,detail,12,c.soft,UI.body,off(10,27),UDim2.new(1,-pad,0,30))
        d.TextWrapped=true
        d.TextTruncate=Enum.TextTruncate.None
        if caption then
            local b=UI.button(f,caption,id,c.raised,c.green,onClick)
            b.Position=UDim2.new(1,-99,0,10)
            b.Size=off(90,40)
            b.TextSize=13
        end
    end
    local function isHost()
        return state.hostId==Players.LocalPlayer.UserId
    end
    local function crew()
        local party=state.party or {}
        if state.loading then para("Connecting to the crew terminal…") return end
        title("Crew manifest")
        for _,p in ipairs(party) do
            entry(p.name,p.id==state.hostId and "Dive leader" or "Crew member")
        end
        if not state.studio and not state.reserved and isHost() and #party<4 and not state.queued and not state.deploying then
            buttonRow({{"Invite Roblox friends","InviteFriends",function() send("InviteFriends") end}})
        end
        if state.reserved and not state.busy and not state.queued and not state.deploying then
            buttonRow({{"Return to public dock","PublicLobby",function() send("PublicLobby") end}})
        end
        if #party>1 and not state.deploying and not state.queued then
            buttonRow({{"Leave party","LeaveParty",function() send("LeaveParty") end}})
        end
        for _,p in ipairs(state.invites or {}) do
            entry(p.name,"Party invitation","Join","Accept"..p.id,function() send("Accept",p.id) end)
        end
        if isHost() and #party<4 and not state.deploying and not state.queued then
            local available=state.available or {}
            if #available>0 then
                label("AT THE DOCK")
                for _,p in ipairs(available) do
                    entry(p.name,"Available crew","Invite","Invite"..p.id,function() send("Invite",p.id) end)
                end
            else
                para("Other players at this dock appear here. Use the public queue to find more crew.",42)
            end
        end
    end
    local function gear()
        title("Trait station")
        local cost=state.spinCost
        local busy=os.clock()<spinUntil
        local display=row(84)
        display.BackgroundTransparency=0
        display.BackgroundColor3=c.panel
        UI.edge(display,c.line)
        UI.frame(display,c.green,off(0,0),off(4,84))
        local result
        for _,trait in ipairs(state.traits or {}) do
            if selectedResult and trait.id==selectedResult.trait then result=trait break end
        end
        local status=if busy then "SCANNING LOADOUT…" elseif result then "LAST SPIN" else "TRAIT DRAW"
        UI.label(display,status,11,c.green,UI.mono,off(13,5),UDim2.new(1,-26,0,20))
        spinPreview=UI.label(display,if result then result.name else "Awaiting spin",25,c.white,UI.bold,
            off(13,24),UDim2.new(1,-26,0,34))
        local caption=if result and selectedResult.duplicate then "Already owned  •  +"..selectedResult.refund.." CR returned"
            elseif result then "Unlocked in your loadout" else "Equip one unlocked trait per dive"
        UI.label(display,caption,12,c.soft,UI.mono,off(13,58),UDim2.new(1,-26,0,18))
        if type(cost)=="number" then
            local ready=not busy and not state.loading and not state.deploying and not state.queued and not state.busy
            if ready and (state.money or 0)>=cost then
                buttonRow({{"Spin  ·  "..cost.." CR","SpinTrait",function()
                    if os.clock()<spinUntil then return end
                    spinStarted=os.clock()
                    spinUntil=spinStarted+6
                    send("SpinTrait")
                    render()
                    task.delay(6,function()
                        if spinUntil>0 and os.clock()>=spinUntil then spinUntil=0 render() end
                    end)
                end,c.green,c.black}})
            else
                para(if busy then "Selecting a trait…" elseif (state.money or 0)<cost
                    then "Earn credits on dives. A spin costs "..cost.." CR."
                    else "Spins are available at the dock when the crew is idle.",42)
            end
        elseif state.loading then
            para("Loading your credit ledger…")
        end
        label("TRAITS & ODDS")
        for _,t in ipairs(state.traits or {}) do
            local caption=t.owned and (t.equipped and "Unequip" or "Equip") or nil
            local odds=type(t.weight)=="number" and string.format("  ·  %d%%",t.weight) or ""
            local suffix=if t.equipped then "  ·  EQUIPPED" elseif not t.owned then "  ·  LOCKED" else ""
            entry(t.name..odds..suffix,t.description,caption,"Trait"..t.id,function() send("Trait",t.id) end)
        end
    end
    local function dive()
        if state.loading or not state.hostId then
            title("Connecting to dock")
            return
        end
        title("Artifact recovery")
        para("Descend to 10,000 m, recover the artifact, and surface. Allow about 15 minutes down and 7 minutes up under power.",60)
        local level=state.difficulty or "Normal"
        label("DIVE DIFFICULTY")
        if isHost() and not state.queued and not state.deploying then
            local options={}
            for _,diff in ipairs({"Easy","Normal","Hard","Nightmare"}) do
                table.insert(options,{diff,"Difficulty"..diff,function() send("Difficulty",diff) end,
                    level==diff and c.soft or c.raised,level==diff and c.black or c.white})
            end
            buttonRow(options,36)
            if level=="Nightmare" then
                para("A single angler hit or squid grab sinks the cage. Worms and barnacles appear more often.",38)
            end
        else
            para(level,22)
        end
        local party=state.party or {}
        local members={}
        for _,p in ipairs(party) do table.insert(members,p.name) end
        label("CREW  "..#party.." / 4")
        para(table.concat(members,"   /   "),24)
        if state.deploying then
            para("Preparing departure…",32)
        elseif state.queued then
            para("Searching for crew  ·  "..tostring(state.queueSeconds or 0).." s",28)
            if isHost() then buttonRow({{"Cancel queue","CancelQueue",function() send("CancelQueue") end}}) end
        elseif state.busy then
            para("Cage in use. Stand by at the dock.",32)
        elseif isHost() then
            buttonRow({{#party>1 and "Launch crew" or "Launch solo","Launch",function() send("Launch") end,c.green,c.black},
                {"Public queue","Queue",function() send("Queue") end}})
        else
            para("Waiting for your dive leader to launch.",32)
        end
    end
    local function guide()
        title("Emergency procedures")
        entry("Bridge sonar","Toggle the transducer for a live chart of animal echoes, divers, fouling and nearby seabed. Each pulse uses battery.")
        entry("Exterior video","Use the bridge camera desk to view four hull cameras. Track a contact or switch to a fixed feed.")
        entry("Leviathan angler · 500 m","Cut the engine at the heavy-contact warning. Wait for the angler to pass, then restart.")
        entry("Giant squid · 1,250 m","Turn the floodlight toward the squid's bearing. Hold the beam there until it retreats, then switch it off.")
        entry("Hull breach","Take planks from the amber rack by the bridge. Fit one at a leak and click each circle when its outer ring meets it. The sonar and cameras return after all breaches are sealed. The searchlight stays available.")
        entry("Worms · 2,000 m","Seal the cracked window before the worms get in. Equip the red wall extinguisher between the bridge consoles, then get close and spray the boarder.")
        entry("Barnacles · 3,000 m","Check sonar for close predators before going outside. Swim to the hull patches, including the keel. Time three cuts per patch. Cancel and resume any time.")
        entry("Pursuer · recovery and ascent","It wakes when you lift the artifact. Get it through the airlock and keep the engine running. Hull damage and low power reduce thrust.")
        entry("Seafloor pickup · 10,000 m","Leave through the starboard airlock. Follow the beacon down, recover the artifact, and swim back to the outer latch.")
    end
    local function results()
        title(report.survived and "Recovered at surface" or "Contact lost")
        para(tostring(report.reason or ""),42)
        entry("Deepest point",tostring(math.floor(report.depth or 0)).." m   /   "..tostring(report.difficulty or "Normal"))
        entry("Artifact",report.artifact and "Recovered from the seafloor" or "At the seafloor")
        entry("Crew payout","+"..tostring(report.money or 0).." credits")
        buttonRow({{"Return to dock","DismissResults",function() send("DismissResults") end,c.green,c.black}})
    end
    local pages={DIVE=dive,CREW=crew,TRAITS=gear,GUIDE=guide}
    local function open(key)
        if tab==key then return end
        tab=key
        content.CanvasPosition=Vector2.zero
        render()
        if UIS.PreferredInput==Enum.PreferredInput.Gamepad then
            GuiService.SelectedObject=if key=="HOME" then heroButtons[1] else navItems[key]
        end
    end
    local _,launchCaption,launchSub=heroButton("Solo dive","Choose difficulty","HomeLaunch",231,function()
        open("DIVE")
    end,true)
    local _,queueCaption,queueSub=heroButton("Public queue","Find a crew","HomeQueue",288,function()
        if isHost() and not state.loading and not state.deploying and not state.queued and not state.busy then
            send("Queue")
        end
        open("DIVE")
    end)
    heroButton("Trait station","Spin for a loadout upgrade","HomeTraits",345,function() open("TRAITS") end)
    heroButton("Dive setup","Difficulty, crew and procedures","HomeSetup",402,function() open("DIVE") end)
    for i,b in ipairs(heroButtons) do
        b.NextSelectionUp=heroButtons[i-1]
        b.NextSelectionDown=heroButtons[i+1]
    end
    local keys={"HOME","DIVE","CREW","TRAITS","GUIDE"}
    for idx,key in ipairs(keys) do
        local b=UI.button(nav,key,"Tab"..key,c.panel,c.soft,function() open(key) end)
        b.Size=UDim2.new(1/#keys,-4,1,0)
        b.Position=UDim2.new((idx-1)/#keys,0,0,0)
        b.Font=UI.mono
        b.TextSize=15
        navItems[key]=b
    end
    for i,key in ipairs(keys) do
        navItems[key].NextSelectionLeft=navItems[keys[(i-2)%#keys+1]]
        navItems[key].NextSelectionRight=navItems[keys[i%#keys+1]]
    end
    render=function()
        local onHome=tab=="HOME" and not report
        home.Visible,shell.Visible=onHome,not onHome
        homeWallet.Text=state.money and string.format("%d  CR",state.money) or ""
        local party=state.party or {}
        launchCaption.Text=#party>1 and "Crew dive" or "Solo dive"
        launchSub.Text=if state.hostId and not isHost() then "Your dive leader launches the crew" else "Choose difficulty  /  "..(state.difficulty or "Normal")
        queueCaption.Text=state.queued and "View queue" or "Public queue"
        queueSub.Text=state.queued and "Searching for crew…" or "Find a crew"
        heroStatus.Text=if state.loading or not state.hostId then "CONNECTING TO DOCK"
            elseif state.deploying then "PREPARING DEPARTURE"
            elseif state.busy then "CAGE IN USE" else ""
        if onHome then
            if backdrop.Visible and UIS.PreferredInput==Enum.PreferredInput.Gamepad then
                local selected=GuiService.SelectedObject
                if not selected or not selected:IsDescendantOf(home) then GuiService.SelectedObject=heroButtons[1] end
            end
            return
        end
        local focused=GuiService.SelectedObject
        local selected=focused and focused:IsDescendantOf(content) and focused.Name or nil
        local scroll=content.CanvasPosition
        for _,child in ipairs(content:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        order=0
        spinPreview=nil
        wallet.Text=state.money and string.format("%d  CR",state.money) or ""
        for key,btn in pairs(navItems) do
            btn.BackgroundColor3=(key==tab and not report) and c.soft or c.panel
            btn.TextColor3=(key==tab and not report) and c.black or c.soft
        end
        nav.Visible=report==nil
        if report then
            results()
        else
            pages[tab]()
        end
        if report then
            footer.Text="DIVE OPERATIONS   /   RECOVERY REPORT"
        else
            footer.Text=state.studio and "LOCAL DOCK   /   STUDIO SESSION" or "DIVE OPERATIONS   /   SURFACE DOCK"
        end
        content.CanvasPosition=scroll
        -- Anchor gamepad navigation even when network snapshots recreate the controls.
        local first=nil
        for _,f in ipairs(content:GetChildren()) do
            if f:IsA("GuiObject") then
                local target=f.Selectable and f or f:FindFirstChildWhichIsA("TextButton",true)
                if target and not first then first=target end
            end
        end
        for _,btn in pairs(navItems) do btn.NextSelectionDown=first end
        if first and not report then first.NextSelectionUp=navItems[tab] end
        if backdrop.Visible and UIS.PreferredInput==Enum.PreferredInput.Gamepad then
            if report then
                GuiService.SelectedObject=content:FindFirstChild("DismissResults",true)
            elseif selected then
                GuiService.SelectedObject=content:FindFirstChild(selected,true) or first or navItems[tab]
            elseif not GuiService.SelectedObject or not GuiService.SelectedObject:IsDescendantOf(backdrop) then
                GuiService.SelectedObject=navItems[tab]
            end
        end
    end
    local function resize()
        local v=backdrop.AbsoluteSize
        if v.X<1 or v.Y<1 then return end
        local narrow=v.X/v.Y<1.36
        heroZoom.Scale=if narrow then math.min(1,(v.X-36)/360,(v.Y-42)/515)
            else math.min(1.28,v.X/1240,v.Y/625)
        hero.Position=if narrow then off(18,math.max(25,(v.Y-495*heroZoom.Scale)*.65))
            else off(v.X*.078,math.max(24,(v.Y-495*heroZoom.Scale)*.5))
        homeWallet.Position=UDim2.new(1,-140,0,12)
        homeWallet.Size=off(118,24)
        heroTitle.Size=off(narrow and 380 or 520,180)
        heroTitle.TextSize=narrow and 74 or 81
        heroBrief.Size=off(narrow and 350 or 390,28)
        local w,h=narrow and 424 or 900,narrow and 582 or 508
        shell.Size=off(w,h)
        zoom.Scale=math.min(1.23,(v.X-12)/w,(v.Y-12)/h)
        name.TextSize=narrow and 29 or 36
        name.Size=off(narrow and 412 or 510,47)
        left.Visible=not narrow
        wallet.Position=off(w-149,narrow and 59 or 26)
        wallet.Size=off(126,22)
        local x=narrow and 20 or 414
        nav.Position=off(x,99)
        nav.Size=off(w-x-21,34)
        content.Position=off(x,145)
        content.Size=off(w-x-19,h-190)
        footer.Position=off(22,h-35)
        footer.Size=off(w-44,28)
    end
    backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    UIS.LastInputTypeChanged:Connect(function()
        if backdrop.Visible and UIS.PreferredInput==Enum.PreferredInput.Gamepad and not GuiService.SelectedObject then
            GuiService.SelectedObject=if report then content:FindFirstChild("DismissResults",true)
                elseif tab=="HOME" then heroButtons[1] else navItems[tab]
        end
    end)
    local spinStep
    spinStep=RunService.RenderStepped:Connect(function()
        if not backdrop.Parent then spinStep:Disconnect() return end
        local choices=state.traits
        if backdrop.Visible and tab=="TRAITS" and not report and spinPreview and spinPreview.Parent
            and os.clock()<spinUntil and choices and #choices>0 then
            local index=math.floor((os.clock()-spinStarted)*10)%#choices+1
            spinPreview.Text=choices[index].name
        end
    end)
    resize()
    render()
    return {
        show=function(visible)
            backdrop.Visible=visible
            if not visible then GuiService.SelectedObject=nil end
        end,
        lobby=function(s)
            state=s
            report=nil
            backdrop.Visible=true
            local result=s.spinResult
            if type(result)=="table" and result.id~=spinResultId then
                spinResultId=result.id
                selectedResult=result
                if os.clock()<spinUntil then
                    spinUntil=math.max(spinStarted+1.2,os.clock()+.18)
                    task.delay(spinUntil-os.clock(),function()
                        if spinUntil>0 and os.clock()>=spinUntil then spinUntil=0 render() end
                    end)
                end
            end
            render()
        end,
        results=function(s)
            report=s
            content.CanvasPosition=Vector2.zero
            backdrop.Visible=true
            render()
        end
    }
end
