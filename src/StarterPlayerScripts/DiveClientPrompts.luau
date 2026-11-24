local Prompts=game:GetService("ProximityPromptService")
local Input=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UI=require(script.Parent.DiveClientStyle)
local c=UI.c
local off=UDim2.fromOffset

return function(playerGui,world)
	local cards={}
	local pressed={}
	local layer=UI.make("ScreenGui",playerGui,{Name="KestrelInteractions",ResetOnSpawn=false,
		ScreenInsets=Enum.ScreenInsets.None,DisplayOrder=12})
	local function hide(prompt)
		local card=cards[prompt]
		if not card then return end
		cards[prompt]=nil
		if card.pointer then
			pressed[card.pointer]=nil
			if prompt.Parent then prompt:InputHoldEnd() end
		end
		if card.tween then card.tween:Cancel() end
		card.face:Destroy()
	end

	Input.InputEnded:Connect(function(input)
		local prompt=pressed[input]
		if not prompt then return end
		pressed[input]=nil
		local card=cards[prompt]
		if card then card.pointer=nil end
		prompt:InputHoldEnd()
	end)
	Prompts.PromptHidden:Connect(hide)
	Prompts:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not Prompts.Enabled then
			for prompt in cards do hide(prompt) end
		end
	end)
	world.DescendantRemoving:Connect(function(instance)
		if cards[instance] then hide(instance) end
	end)
	RunService:BindToRenderStep("ThalassaInteractionCards",Enum.RenderPriority.Camera.Value+8,function()
		local camera=workspace.CurrentCamera
		if not camera then return end
		for prompt,card in cards do
			local reference=card.adornee
			local p=if reference:IsA("Attachment") then reference.WorldPosition else reference.Position
			local point,onScreen=camera:WorldToViewportPoint(p+Vector3.yAxis*.8)
			card.face.Position=off(point.X+prompt.UIOffset.X,point.Y+prompt.UIOffset.Y)
			card.face.Visible=onScreen
		end
	end)
	Prompts.PromptShown:Connect(function(prompt,inputType)
		if prompt.Style~=Enum.ProximityPromptStyle.Custom or not prompt:IsDescendantOf(world) then return end
		local adornee=prompt.Parent
		if not (adornee:IsA("Attachment") or adornee:IsA("BasePart")) then return end
		hide(prompt)
		local action=prompt:GetAttribute("Action") or ""
		local accent=if action=="Artifact" or action=="Return" or action:match("^Patch") then c.orange else c.green
		local touch=inputType==Enum.ProximityPromptInputType.Touch
		local key=if inputType==Enum.ProximityPromptInputType.Gamepad then prompt.GamepadKeyCode.Name:gsub("^Button","")
			elseif touch then "TAP" else Input:GetStringForKeyCode(prompt.KeyboardKeyCode)
		if key=="" then key=prompt.KeyboardKeyCode.Name end
		local holding=prompt.HoldDuration>0
		if touch and holding then key="HOLD" end
		local face=UI.make("TextButton",layer,{Name="StationAction",Size=off(216,59),AnchorPoint=Vector2.new(.5,.75),Visible=false,
			Text="",BackgroundColor3=c.black,BackgroundTransparency=.08,AutoButtonColor=false,
			Active=prompt.ClickablePrompt or touch,Selectable=false,BorderSizePixel=0})
		UI.edge(face,c.line)
		UI.frame(face,accent,off(0,0),off(3,59))
		local badge=UI.frame(face,c.raised,off(10,8),off(51,43))
		UI.edge(badge,accent)
		local keyLabel=UI.label(badge,key,if #key>4 then 11 else 15,accent,UI.mono,nil,nil,Enum.TextXAlignment.Center)
		keyLabel.TextTruncate=Enum.TextTruncate.None
		local caption=UI.label(face,string.upper(prompt.ActionText),13,c.white,UI.mono,off(71,9),off(137,24))
		caption.TextTruncate=Enum.TextTruncate.None
		caption.TextScaled=true
		UI.make("UITextSizeConstraint",caption,{MinTextSize=9,MaxTextSize=13})
		local detail=if holding and not touch then "HOLD TO CONFIRM" else string.upper(prompt.ObjectText)
		UI.label(face,detail,10,c.soft,UI.mono,off(71,30),off(137,15))
		local track=UI.frame(face,c.grid,off(71,50),off(137,2))
		track.Visible=holding
		local fill=UI.frame(track,accent,nil,UDim2.fromScale(0,1))
		cards[prompt]={face=face,fill=fill,adornee=adornee}
		if face.Active then
			face.InputBegan:Connect(function(input)
				local card=cards[prompt]
				local kind=input.UserInputType
				if not card or card.pointer or (kind~=Enum.UserInputType.Touch and kind~=Enum.UserInputType.MouseButton1) then return end
				card.pointer=input
				pressed[input]=prompt
				prompt:InputHoldBegin()
			end)
		end
	end)
	Prompts.PromptButtonHoldBegan:Connect(function(prompt)
		local card=cards[prompt]
		if not card or prompt.HoldDuration<=0 then return end
		if card.tween then card.tween:Cancel() end
		card.fill.Size=UDim2.fromScale(0,1)
		card.tween=TweenService:Create(card.fill,TweenInfo.new(prompt.HoldDuration,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(1,1)})
		card.tween:Play()
	end)
	Prompts.PromptButtonHoldEnded:Connect(function(prompt)
		local card=cards[prompt]
		if not card then return end
		if card.tween then card.tween:Cancel() end
		card.fill.Size=UDim2.fromScale(0,1)
	end)
end
