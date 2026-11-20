local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local UI=require(script.Parent.DiveClientStyle)
local c=UI.c
local off=UDim2.fromOffset
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
    for i,label in ipairs({"000 M","200 M","400 M","600 M"}) do
        local y=55+(i-1)*73
        UI.frame(f,c.soft,off(4,y+2),off(5,1))
        UI.label(f,label,10,c.soft,UI.mono,off(11,y-7),off(48,18))
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
    UI.label(f,"600 M",15,c.white,UI.mono,off(220,340),off(114,23),Enum.TextXAlignment.Right)
    return f
end
return function(gui,send)
    local backdrop=UI.frame(gui,c.black,nil,nil,.10)
    backdrop.Name="CrewTerminal"
    local shell=UI.frame(backdrop,c.surface)
    shell.AnchorPoint=Vector2.new(.5,.5)
    shell.Position=UDim2.fromScale(.5,.5)
    UI.edge(shell,c.line)
    local zoom=UI.make("UIScale",shell,{Scale=1})
    UI.frame(shell,c.green,off(0,0),off(50,4))
    local name=UI.label(shell,"THALASSOPHOBIA",36,c.white,UI.bold,off(21,15),off(488,47))
    local subtitle=UI.label(shell,"SUBMERSIBLE OPERATIONS",13,c.green,UI.mono,off(23,61),off(345,21))
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
    local tab="DIVE"
    local state={}
    local report=nil
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
        title("Crew outfitter")
        para("Equip one trait for the next dive. Purchases last between runs.",37)
        for _,t in ipairs(state.traits or {}) do
            local caption=t.equipped and "Unequip" or t.owned and "Equip" or tostring(t.price).." CR"
            entry(t.name,t.description,caption,"Trait"..t.id,function() send("Trait",t.id) end)
        end
    end
    local function dive()
        if state.loading or not state.hostId then
            title("Connecting to dock")
            return
        end
        title("Artifact recovery")
        para("Descend to 600 m, recover the artifact, and bring the cage back to the surface.",42)
        local level=state.difficulty or "Normal"
        label("DIVE DIFFICULTY")
        if isHost() and not state.queued and not state.deploying then
            local options={}
            for _,diff in ipairs({"Easy","Normal","Hard"}) do
                table.insert(options,{diff,"Difficulty"..diff,function() send("Difficulty",diff) end,
                    level==diff and c.soft or c.raised,level==diff and c.black or c.white})
            end
            buttonRow(options,36)
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
        entry("Leviathan angler","Cut the engine at the heavy-contact warning. Wait for the angler to pass, then restart.")
        entry("Giant squid","Turn the floodlight toward the squid's bearing. Hold the beam there until it retreats, then switch it off.")
        entry("Crack crawler","Watch for worms on the windows. Seal their fracture before they enter. For a boarder, refill at the extinguisher rack and spray in its section.")
        entry("Hull swarm","Check sonar for close predators before going outside. Swim to the hull patches, including the keel. Time three cuts per patch. Cancel and resume any time.")
        entry("Pursuer · ascent only","The cage coasts briefly after shutdown. Restart once the angler passes. Low power and hull damage reduce thrust.")
        entry("Seafloor pickup","Use the salvage station at 600 m to bring the artifact aboard and begin the ascent.")
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
    local render
    for idx,key in ipairs({"DIVE","CREW","TRAITS","GUIDE"}) do
        local b=UI.button(nav,key,"Tab"..key,c.panel,c.soft,function()
            tab=key
            content.CanvasPosition=Vector2.zero
            render()
        end)
        b.Size=UDim2.new(.25,-4,1,0)
        b.Position=UDim2.new((idx-1)*.25,0,0,0)
        b.Font=UI.mono
        b.TextSize=15
        navItems[key]=b
    end
    local keys={"DIVE","CREW","TRAITS","GUIDE"}
    for i,key in ipairs(keys) do
        navItems[key].NextSelectionLeft=navItems[keys[(i-2)%#keys+1]]
        navItems[key].NextSelectionRight=navItems[keys[i%#keys+1]]
    end
    render=function()
        local focused=GuiService.SelectedObject
        local selected=focused and focused:IsDescendantOf(content) and focused.Name or nil
        local scroll=content.CanvasPosition
        for _,child in ipairs(content:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        order=0
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
            GuiService.SelectedObject=report and content:FindFirstChild("DismissResults",true) or navItems[tab]
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
