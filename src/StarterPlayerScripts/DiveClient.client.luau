local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PromptService=game:GetService("ProximityPromptService")
local InputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local net=ReplicatedStorage:WaitForChild("DiveNet")
local input=net:WaitForChild("Input")
local feed=net:WaitForChild("Feed")
local screen=Instance.new("ScreenGui")
screen.Name="Thalassophobia"
screen.ResetOnSpawn=false
screen.DisplayOrder=9
screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
screen.Parent=player:WaitForChild("PlayerGui")
local arrival=Instance.new("ScreenGui")
arrival.Name="DiveArrival"
arrival.IgnoreGuiInset=true
arrival.ResetOnSpawn=false
arrival.DisplayOrder=screen.DisplayOrder+1
arrival.Parent=screen.Parent
local transfer=Instance.new("Frame")
transfer.Name="Transfer"
transfer.Size=UDim2.fromScale(1,1)
transfer.BorderSizePixel=0
transfer.BackgroundColor3=Color3.fromRGB(5,8,10)
transfer.Parent=arrival
local transferText=Instance.new("TextLabel")
transferText.AnchorPoint=Vector2.new(.5,1)
transferText.Position=UDim2.fromScale(.5,.91)
transferText.Size=UDim2.new(1,0,0,35)
transferText.BackgroundTransparency=1
transferText.Font=Enum.Font.Code
transferText.TextColor3=Color3.fromRGB(205,213,211)
transferText.TextSize=15
transferText.Text=""
transferText.Parent=transfer
local instruments=require(script.Parent:WaitForChild("DiveClientInstruments"))(screen)
local optics=require(script.Parent:WaitForChild("DiveClientOptics"))(net,screen)
local exterior=require(script.Parent:WaitForChild("DiveExteriorClient"))
exterior.init(net,screen)
local viewing=false
local mode="Lobby"
local pendingLobby=nil
local controls=nil
local received=false
local terminal
local cinematics
local breach
local promptEligible=false
local showDiveNotices=false
local intakeId=nil
local parasiteUI
local crewAlive=false
local function dockControls()
    local sequence=intakeId~=nil or (cinematics and cinematics:isPlaying())
    if parasiteUI then parasiteUI:setDiveActive(mode=="Dive" and crewAlive and not sequence) end
    local patching=(breach and breach:isActive()) or (parasiteUI and parasiteUI:isActive())
    player.CameraMode=if mode=="Dive" then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
    local camera=workspace.CurrentCamera
    if mode=="Dive" and not viewing and not sequence and camera and camera.CameraType==Enum.CameraType.Scriptable then
        local character=player.Character
        if character then camera.CameraSubject=character:FindFirstChildOfClass("Humanoid") end
        camera.CameraType=Enum.CameraType.Custom
    end
    screen.IgnoreGuiInset=mode~="Dive"
    if controls then
        if mode=="Dive" and not viewing and not sequence and not patching then controls:Enable() else controls:Disable() end
    end
    InputService.MouseIconEnabled=mode~="Dive" or viewing or patching
    if mode~="Dive" or patching then InputService.MouseBehavior=Enum.MouseBehavior.Default end
    PromptService.Enabled=mode=="Dive" and promptEligible and not viewing and not sequence and not patching
end
parasiteUI=require(script.Parent:WaitForChild("DiveParasiteClient")).start(net:WaitForChild("Parasite"),dockControls)
cinematics=require(script.Parent:WaitForChild("DiveCinematics")).new(screen,dockControls)
local function send(action,arg)
    if action=="DismissResults" then
        mode="Lobby"
        cinematics:reset()
        dockControls()
        if pendingLobby then terminal.lobby(pendingLobby) end
    end
    input:FireServer(action,arg)
end
breach=require(script.Parent:WaitForChild("DiveBreachClient")).new(screen,send,dockControls)
terminal=require(script.Parent:WaitForChild("DiveClientTerminal"))(screen,send)
terminal.show(false)
local function beginIntake(id)
    intakeId=id
    terminal.show(false)
    screen.Enabled=false
    transfer.BackgroundTransparency=0
    transferText.Text=""
    arrival.Enabled=true
    dockControls()
    task.spawn(function()
        while intakeId==id do
            local character=player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            if game:IsLoaded() and workspace.CurrentCamera and root and root:FindFirstChild("DiveWakeHold")
                and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChild("Head") then break end
            RunService.Heartbeat:Wait()
        end
        if intakeId~=id then return end
        input:FireServer("IntakeStarted",id)
        cinematics:play({kind="Intake",onComplete=function()
            if intakeId~=id then return end
            transfer.BackgroundTransparency=1
            transferText.Text="Waiting for crew"
            arrival.Enabled=true
            input:FireServer("IntakeFinished",id)
        end})
        if intakeId==id then arrival.Enabled=false end
    end)
end
local feedback=require(script.Parent:WaitForChild("DiveClientFeedback"))(screen,function()
    return intakeId~=nil or cinematics:isPlaying() or viewing or breach:isActive()
end)
local world=workspace:WaitForChild("Thalassa",12)
if world then require(script.Parent:WaitForChild("DiveClientPrompts"))(screen.Parent,world) end
local outlines=Instance.new("Folder")
outlines.Name="LocalInteractionOutlines"
outlines.Parent=workspace
local interactions={}
-- One Highlight per adorned part: a disabled second Highlight on the same part hides the enabled one
-- (Repair and Patch both outline the section's Pressure plate).
local outlineFor={}
local outside=nil
local equipped
local aimingGui=Instance.new("ScreenGui")
aimingGui.Name="ExtinguisherAim"
aimingGui.ResetOnSpawn=false
aimingGui.ScreenInsets=Enum.ScreenInsets.None
aimingGui.DisplayOrder=screen.DisplayOrder
aimingGui.Enabled=false
aimingGui.Parent=screen.Parent
local aimDot=Instance.new("Frame")
aimDot.Name="NozzleAim"
aimDot.AnchorPoint=Vector2.new(.5,.5)
aimDot.Position=UDim2.fromScale(.5,.5)
aimDot.Size=UDim2.fromOffset(5,5)
aimDot.BackgroundColor3=Color3.fromRGB(202,249,235)
aimDot.BackgroundTransparency=.18
aimDot.BorderSizePixel=0
aimDot.Parent=aimingGui
local rounding=Instance.new("UICorner")
rounding.CornerRadius=UDim.new(.5,0)
rounding.Parent=aimDot
local function filterPrompt(prompt,point)
    prompt.MaxActivationDistance=if point.outside==outside then point.distance else 0
end
local function registerPrompt(prompt)
    if interactions[prompt] or not prompt:IsDescendantOf(world) then return end
    local action=prompt:GetAttribute("Action")
    local base=prompt:FindFirstAncestorWhichIsA("BasePart")
    if type(action)~="string" or not base then return end
    prompt.Style=Enum.ProximityPromptStyle.Custom
    local clean=action:match("^Clean[1-4]$")~=nil
    local outsideOnly=clean or action=="Return" or action=="Artifact"
    local target=base
    if clean or action=="Planks" then
        target=base.Parent
    elseif action:match("^Patch[1-3]$") then
        target=base.Parent:FindFirstChild("Pressure plate") or base
    end
    local color=if action=="Artifact" or action=="Return" then Color3.fromRGB(246,196,98)
        elseif outsideOnly then Color3.fromRGB(123,237,225) else Color3.fromRGB(155,221,220)
    local shared=outlineFor[target]
    if not shared then
        local outline=Instance.new("Highlight")
        outline.Name="InteractionOutline"
        outline.Adornee=target
        outline.DepthMode=Enum.HighlightDepthMode.Occluded
        outline.Enabled=false
        outline.FillColor,outline.OutlineColor=color,color
        outline.FillTransparency,outline.OutlineTransparency=.93,.19
        outline.Parent=outlines
        shared={outline=outline,color=color,users=0}
        outlineFor[target]=shared
    end
    shared.users+=1
    local point={base=base,target=target,distance=prompt.MaxActivationDistance,outside=outsideOnly,shared=shared,action=action}
    interactions[prompt]=point
    filterPrompt(prompt,point)
end
if world then
    for _,p in ipairs(world:GetDescendants()) do
        if p:IsA("ProximityPrompt") then registerPrompt(p) end
    end
    world.DescendantAdded:Connect(function(object)
        if object:IsA("ProximityPrompt") then task.defer(registerPrompt,object) end
    end)
    world.DescendantRemoving:Connect(function(object)
        local point=interactions[object]
        if not point then return end
        interactions[object]=nil
        point.shared.users-=1
        if point.shared.users<=0 then
            point.shared.outline:Destroy()
            outlineFor[point.target]=nil
        end
    end)
end
local function applyOutside(value)
    if outside==value then return end
    outside=value
    for prompt,point in pairs(interactions) do filterPrompt(prompt,point) end
end
local ray=RaycastParams.new()
ray.RespectCanCollide=true
ray.IgnoreWater=true
local nextHighlightUpdate=0
RunService.Heartbeat:Connect(function()
    local now=os.clock()
    if now<nextHighlightUpdate then return end
    nextHighlightUpdate=now+.1
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local camera=workspace.CurrentCamera
    local canHighlight=PromptService.Enabled and root~=nil and camera~=nil
    aimingGui.Enabled=canHighlight and outside==false and equipped~=nil
    if canHighlight then ray.FilterDescendantsInstances={character} end
    local pulse=.5+.5*math.sin(now*6)
    local wanted={}
    for prompt,point in pairs(interactions) do
        local visible=false
        local live=canHighlight and prompt.Enabled and point.outside==outside
        -- Required prompts (feedback.required) show through walls in amber until the job is done.
        local must=live and feedback.required[point.action]==true
        if must then
            visible=true
        elseif live then
            local parent=prompt.Parent
            local position=if parent:IsA("Attachment") then parent.WorldPosition else point.base.Position
            local maxDistance=if outside then math.min(23,point.distance*2.6) else point.distance+2.5
            if (position-root.Position).Magnitude<=maxDistance then
                local offset=position-camera.CFrame.Position
                local hit=workspace:Raycast(camera.CFrame.Position,offset,ray)
                visible=not hit or hit.Instance==point.target or hit.Instance:IsDescendantOf(point.target)
                    or (hit.Position-position).Magnitude<.65
            end
        end
        local w=wanted[point.shared] or {}
        wanted[point.shared]=w
        w.must=w.must or must
        w.visible=w.visible or visible
    end
    for shared,w in wanted do
        local outline,must=shared.outline,w.must==true
        if shared.required~=must then
            shared.required=must
            local color=if must then Color3.fromRGB(255,176,74) else shared.color
            outline.DepthMode=if must then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
            outline.FillColor,outline.OutlineColor=color,color
            outline.FillTransparency,outline.OutlineTransparency=.93,if must then 0 else .19
        end
        if must then outline.FillTransparency=.62+.3*pulse end
        if outline.Enabled~=w.visible then outline.Enabled=w.visible end
    end
end)
local toolConnection
local characterConnections={}
local function observeCharacter(character)
    for _,connection in characterConnections do connection:Disconnect() end
    table.clear(characterConnections)
    if toolConnection then toolConnection:Disconnect() toolConnection=nil end
    equipped=nil
    local function equippedTool(tool)
        if not tool:IsA("Tool") or tool:GetAttribute("DiveExtinguisher")~=true then return end
        if toolConnection then toolConnection:Disconnect() end
        equipped=tool
        toolConnection=tool.Activated:Connect(function()
            local camera=workspace.CurrentCamera
            if camera and mode=="Dive" and PromptService.Enabled and outside==false and tool.Parent==character then
                input:FireServer("SprayCrawler",camera.CFrame.LookVector)
            end
        end)
    end
    table.insert(characterConnections,character.ChildAdded:Connect(equippedTool))
    table.insert(characterConnections,character.ChildRemoved:Connect(function(child)
        if child==equipped and toolConnection then
            toolConnection:Disconnect()
            toolConnection,equipped=nil,nil
        end
    end))
    for _,child in character:GetChildren() do equippedTool(child) end
end
PromptService.Enabled=false
dockControls()
feed.OnClientEvent:Connect(function(kind,payload)
    if kind=="Notice" then
        if mode=="Lobby" or (mode=="Dive" and showDiveNotices) then instruments.notify(payload) end
    elseif kind=="Lobby" and type(payload)=="table" then
        received=true
        pendingLobby=payload
        if mode=="Lobby" then
            breach:reset()
            cinematics:reset()
            instruments.reset()
            optics.reset()
            exterior.reset()
            if payload.receiving then
                terminal.show(false)
                transfer.BackgroundTransparency=0
                transferText.Text="Waiting for crew"
                arrival.Enabled=true
            else
                arrival.Enabled=false
                terminal.lobby(payload)
            end
            feedback.reset()
            PromptService.Enabled=false
        end
    elseif kind=="Dive" and type(payload)=="table" then
        if payload.phase=="Results" or payload.phase=="Lobby" or (mode=="Results" and not payload.intakeId) then return end
        received=true
        crewAlive=payload.alive~=false
        showDiveNotices=payload.difficulty=="Easy"
        if mode~="Dive" then
            mode="Dive"
            instruments.clearNotice()
            terminal.show(false)
        end
        if payload.intakeId then
            if intakeId~=payload.intakeId then beginIntake(payload.intakeId) end
            return
        end
        if intakeId then
            intakeId=nil
            cinematics:reset()
        end
        arrival.Enabled=false
        screen.Enabled=true
        feedback.update(payload)
        applyOutside(payload.outside==true)
        viewing=(payload.cameraView==true or payload.searchlightView==true) and payload.alive~=false and not payload.outside and not cinematics:isPlaying()
        if cinematics:isPlaying() then breach:reset() else breach:update(payload) end
        promptEligible=payload.alive~=false and not payload.cleaning
        if not cinematics:isPlaying() then optics.update(payload) end
        exterior.update(payload)
        instruments.update(payload)
        dockControls()
    elseif kind=="Cinematic" and mode=="Dive" and type(payload)=="table" then
        viewing=false
        breach:reset()
        feedback.stopArms()
        optics.reset()
        if payload.kind=="Angler" or payload.kind=="Squid" or payload.kind=="Flood" then
            exterior.reset()
            instruments.reset()
        end
        cinematics:play(payload)
        dockControls()
    elseif kind=="Results" and type(payload)=="table" then
        received=true
        mode="Results"
        intakeId=nil
        arrival.Enabled=false
        screen.Enabled=true
        feedback.reset()
        breach:reset()
        cinematics:reset()
        viewing=false
        optics.reset()
        exterior.reset()
        PromptService.Enabled=false
        instruments.reset()
        terminal.results(payload)
        dockControls()
    end
end)
player.CharacterAdded:Connect(function(character)
    observeCharacter(character)
    task.defer(dockControls)
end)
if player.Character then observeCharacter(player.Character) end
task.spawn(function()
    local module=player.PlayerScripts:WaitForChild("PlayerModule",15)
    if module then
        local ok,result=pcall(function() return require(module):GetControls() end)
        if ok then controls=result dockControls() end
    end
end)
task.spawn(function()
    repeat
        input:FireServer("Sync")
        task.wait(2)
    until received or not screen.Parent
end)
