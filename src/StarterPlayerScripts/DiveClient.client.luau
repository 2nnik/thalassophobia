local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PromptService=game:GetService("ProximityPromptService")
local InputService=game:GetService("UserInputService")
local SocialService=game:GetService("SocialService")
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
local function dockControls()
    local sequence=cinematics and cinematics:isPlaying()
    local patching=breach and breach:isActive()
    player.CameraMode=if mode=="Dive" then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
    screen.IgnoreGuiInset=mode~="Dive"
    if controls then
        if mode=="Dive" and not viewing and not sequence and not patching then controls:Enable() else controls:Disable() end
    end
    InputService.MouseIconEnabled=mode~="Dive" or viewing or patching
    if mode~="Dive" or patching then InputService.MouseBehavior=Enum.MouseBehavior.Default end
    PromptService.Enabled=mode=="Dive" and promptEligible and not sequence and not patching
end
cinematics=require(script.Parent:WaitForChild("DiveCinematics")).new(screen,dockControls)
local function send(action,arg)
    if action=="InviteFriends" then
        task.spawn(function()
            local ok,can=pcall(SocialService.CanSendGameInviteAsync,SocialService,player)
            if ok and can then
                local opened=pcall(SocialService.PromptGameInvite,SocialService,player)
                if opened then return end
            end
            instruments.notify("Roblox friend invites are unavailable for this session.")
        end)
        return
    end
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
local world=workspace:WaitForChild("Thalassa",12)
local distances={}
local outside=nil
local function filterPrompt(p)
    local action=p:GetAttribute("Action")
    if not action then return end
    if not distances[p] then distances[p]=p.MaxActivationDistance end
    local exterior=action:match("^Clean[1-4]$")~=nil or action=="Return"
    p.MaxActivationDistance=exterior==outside and distances[p] or 0
end
if world then
    for _,p in ipairs(world:GetDescendants()) do
        if p:IsA("ProximityPrompt") then filterPrompt(p) end
    end
    world.DescendantAdded:Connect(function(p)
        if p:IsA("ProximityPrompt") then task.defer(filterPrompt,p) end
    end)
end
local function applyOutside(value)
    if outside==value then return end
    outside=value
    for p in pairs(distances) do
        if p.Parent then filterPrompt(p) else distances[p]=nil end
    end
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
            terminal.lobby(payload)
            PromptService.Enabled=false
        end
    elseif kind=="Dive" and type(payload)=="table" then
        if payload.phase=="Results" or payload.phase=="Lobby" or mode=="Results" then return end
        received=true
        showDiveNotices=payload.difficulty=="Easy"
        if mode~="Dive" then
            mode="Dive"
            instruments.clearNotice()
            terminal.show(false)
            cinematics:play({kind="Wake",duration=2.7})
        end
        applyOutside(payload.outside==true)
        local camera=payload.cameraView==true and payload.alive~=false and not payload.outside and not payload.systemsOffline
        viewing=camera
        if cinematics:isPlaying() then breach:reset() else breach:update(payload) end
        promptEligible=payload.alive~=false and not camera and not payload.cleaning
        if not cinematics:isPlaying() then optics.update(payload) end
        exterior.update(payload)
        instruments.update(payload)
        dockControls()
    elseif kind=="Cinematic" and mode=="Dive" and type(payload)=="table" then
        viewing=false
        breach:reset()
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
player.CharacterAdded:Connect(function()
    task.defer(dockControls)
end)
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
