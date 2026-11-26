local Players = game:GetService("Players")
local Actions = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local UI = require(script.Parent.DiveClientStyle)

local Client = {}
local alphabet = "XEDFGHBC"
local gamepadKeys = {"DPadUp","DPadRight","DPadDown","DPadLeft","ButtonX","ButtonY","ButtonB","ButtonA"}
local gamepadLabels = {"↑","→","↓","←","X","Y","B","A"}
local binding = "KestrelLatchSequence"
local cameraBinding = "KestrelEmergenceView"
local off = UDim2.fromOffset
local c = UI.c

function Client.start(remote,onActiveChanged)
    local player = Players.LocalPlayer
    local gui = UI.make("ScreenGui", player:WaitForChild("PlayerGui"), {
        Name="DiveVitals", ResetOnSpawn=false, Enabled=false, DisplayOrder=11,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    })
    local vitals = UI.frame(gui,c.sea,UDim2.new(0,14,1,-94),off(146,38),.15)
    vitals.AnchorPoint=Vector2.new(0,1)
    UI.edge(vitals)
    local reading = UI.label(vitals,"",13,c.white,UI.mono,off(9,0),off(128,25))
    local healthTrack = UI.frame(vitals,c.line,off(9,26),off(128,4))
    local healthBar = UI.frame(healthTrack,c.green)
    local function placeVitals()
        local camera=workspace.CurrentCamera
        local compact=camera and camera.ViewportSize.X<670
        vitals.Position=if compact then UDim2.new(0,7,.59,0) else UDim2.new(0,14,1,-94)
    end
    local viewportConnection
    local function watchViewport()
        if viewportConnection then viewportConnection:Disconnect() end
        local camera=workspace.CurrentCamera
        if camera then viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeVitals) end
        placeVitals()
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
    watchViewport()
    local card = UI.frame(gui,c.sea,UDim2.fromScale(.5,.56),UDim2.new(.88,0,0,182),.03)
    card.AnchorPoint = Vector2.new(.5,.5)
    UI.make("UISizeConstraint",card,{MaxSize=Vector2.new(520,182)})
    UI.edge(card,c.orange)
    card.Visible = false
    UI.label(card,"BREAK THE GRIP",18,c.orange,UI.bold,off(12,6),off(210,27))
    local clock = UI.label(card,"",15,c.white,UI.mono,UDim2.new(1,-89,0,6),off(76,27),Enum.TextXAlignment.Right)
    local timer = UI.frame(card,c.orange,off(0,0),UDim2.new(1,0,0,2))
    local hint = UI.label(card,"",13,c.soft,UI.body,off(12,36),UDim2.new(1,-24,0,20))
    local row = UI.frame(card,c.sea,off(10,63),UDim2.new(1,-20,0,40),1)
    local pad = UI.frame(card,c.sea,off(10,113),UDim2.new(1,-20,0,60),1)
    local sequence, nextIndex, deadline, duration = "",1,0,1
    local function clearView()
        Run:UnbindFromRenderStep(cameraBinding)
    end
    local function ease(t)
        t=math.clamp(t,0,1)
        return t*t*(3-2*t)
    end
    local function showEmergence(startedAt)
        if not gui.Enabled then return end
        local initialCamera=workspace.CurrentCamera
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not root or not initialCamera or initialCamera.CameraType==Enum.CameraType.Scriptable then return end
        local initialView=root.CFrame:ToObjectSpace(initialCamera.CFrame)
        clearView()
        Run:BindToRenderStep(cameraBinding,Enum.RenderPriority.Camera.Value+1,function()
            local camera=workspace.CurrentCamera
            local elapsed=workspace:GetServerTimeNow()-startedAt
            if not gui.Enabled or player.Character~=character or not root.Parent or camera~=initialCamera
                or camera.CameraType==Enum.CameraType.Scriptable or elapsed>=2.9 then
                clearView()
                return
            end
            -- Follow the avatar root, avoiding the small movements of the animated head.
            local stable=root.CFrame*initialView
            local target=(root.CFrame*CFrame.new(0,.1,-1.25)).Position
            local look=CFrame.lookAt(stable.Position,target)
            local blendIn=ease(elapsed/.65)
            local blendOut=ease((elapsed-1.78)/1.12)
            camera.CFrame=stable:Lerp(look,blendIn*(1-blendOut))
        end)
    end
    local boundKeys, letters, symbols = {},{},{}
    local function key(letter)
        if gui.Enabled and card.Visible and workspace:GetServerTimeNow() < deadline then
            remote:FireServer("Key",letter)
        end
    end
    for i=1,#alphabet do
        local letter = alphabet:sub(i,i)
        for _,code in {Enum.KeyCode[letter],Enum.KeyCode[gamepadKeys[i]]} do
            table.insert(boundKeys,code)
            letters[code]=letter
        end
        symbols[letter]=gamepadLabels[i]
        local button = UI.button(pad,letter,"Key"..letter,c.raised,c.white,function() key(letter) end)
        button.Position=UDim2.fromScale((i-1)%4/4,math.floor((i-1)/4)/2)
        button.Size=UDim2.new(.25,-3,.5,-3)
        button.Selectable=false
    end
    local function repaint()
        local isPad=Input:GetLastInputType().Name:match("^Gamepad")~=nil
        pad.Visible=Input.TouchEnabled and not isPad
        card.Size=UDim2.new(.88,0,0,pad.Visible and 182 or 114)
        hint.Text=if isPad then "Press the controller sequence in order" elseif pad.Visible then "Tap the keys in order" else "Type the keys in order"
        for i,cell in row:GetChildren() do
            local index=tonumber(cell.Name)
            local letter=sequence:sub(index,index)
            cell.Text=if isPad then symbols[letter] else letter
            cell.BackgroundColor3=if index==nextIndex then c.orange elseif index<nextIndex then c.raised else c.panel
            cell.TextColor3=if index==nextIndex then c.black elseif index<nextIndex then c.green else c.white
        end
    end
    local function finish()
        local wasVisible=card.Visible
        if wasVisible then Actions:UnbindAction(binding) end
        card.Visible=false
        row:ClearAllChildren()
        if wasVisible and onActiveChanged then onActiveChanged() end
    end
    remote.OnClientEvent:Connect(function(kind,value,expires)
        if kind=="Emergence" then showEmergence(value) return end
        if kind=="LatchEnd" then finish() return end
        if kind=="LatchProgress" and card.Visible then nextIndex=value repaint() return end
        if kind~="Latch" then return end
        finish()
        sequence,nextIndex,deadline=value,1,expires
        duration=math.max(.01,deadline-workspace:GetServerTimeNow())
        for i=1,#sequence do
            local cell=UI.label(row,"",19,c.white,UI.mono,UDim2.fromScale((i-1)/#sequence,0),UDim2.new(1/#sequence,-3,1,0),Enum.TextXAlignment.Center)
            cell.Name=tostring(i)
            cell.BackgroundTransparency=0
        end
        card.Visible=true
        if onActiveChanged then onActiveChanged() end
        repaint()
        Actions:BindActionAtPriority(binding,function(_,state,object)
            if state==Enum.UserInputState.Begin then key(letters[object.KeyCode]) end
            return Enum.ContextActionResult.Sink
        end,false,4000,table.unpack(boundKeys))
    end)
    Input.LastInputTypeChanged:Connect(function() if card.Visible then repaint() end end)
    local observed, tool, activation, added, removed, healthChanged, maxChanged
    local function refreshHealth()
        if not observed then vitals.Visible=false return end
        vitals.Visible=observed.Health>0
        local bleeding=player:GetAttribute("DiveBleeding")
        reading.Text=(if bleeding then "BLEEDING  " else "HEALTH  ")..math.ceil(observed.Health)
        reading.TextColor3=if bleeding then c.red else c.white
        healthBar.Size=UDim2.fromScale(math.clamp(observed.Health/math.max(1,observed.MaxHealth),0,1),1)
        healthBar.BackgroundColor3=if player:GetAttribute("DiveBleeding") or observed.Health<=30 then c.red else c.green
        if observed.Health<=0 then finish() end
    end
    local function watch(character)
        clearView()
        finish()
        for _,connection in {activation,added,removed,healthChanged,maxChanged} do connection:Disconnect() end
        observed,tool,activation,added,removed,healthChanged,maxChanged=nil,nil,nil,nil,nil,nil,nil
        refreshHealth()
        local function childAdded(child)
            if child:IsA("Humanoid") then
                observed=child
                healthChanged=child.HealthChanged:Connect(refreshHealth)
                maxChanged=child:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
                refreshHealth()
            elseif child:IsA("Tool") and child:GetAttribute("DiveMedicalKind") then
                if activation then activation:Disconnect() end
                tool=child
                activation=child.Activated:Connect(function()
                    local camera=workspace.CurrentCamera
                    local aim=child:FindFirstChild("Aim")
                    if not (gui.Enabled and not card.Visible and camera and aim and child.Parent==character) then return end
                    local ray=camera:ViewportPointToRay(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
                    local params=RaycastParams.new()
                    params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={character}
                    local hit=workspace:Raycast(ray.Origin,ray.Direction*150,params)
                    aim:FireServer(if hit then hit.Position else ray.Origin+ray.Direction*150)
                end)
            end
        end
        added=character.ChildAdded:Connect(childAdded)
        removed=character.ChildRemoved:Connect(function(child)
            if child==tool and activation then activation:Disconnect() activation,tool=nil,nil end
        end)
        for _,child in character:GetChildren() do childAdded(child) end
    end
    player.CharacterAdded:Connect(watch)
    if player.Character then watch(player.Character) end
    player:GetAttributeChangedSignal("DiveBleeding"):Connect(refreshHealth)
    Run.RenderStepped:Connect(function()
        if not card.Visible then return end
        local remaining=math.max(0,deadline-workspace:GetServerTimeNow())
        timer.Size=UDim2.new(math.clamp(remaining/duration,0,1),0,0,2)
        clock.Text=string.format("%.1f s",remaining)
    end)
    return {isActive=function() return card.Visible end,setDiveActive=function(_,active)
        gui.Enabled=active
        if not active then finish(); clearView() end
    end}
end

return Client
