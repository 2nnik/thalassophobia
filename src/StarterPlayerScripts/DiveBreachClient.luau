local ContextActions = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local UI = require(script.Parent.DiveClientStyle)

local BreachClient = {}
local c = UI.c
local center = Enum.TextXAlignment.Center
local lookAhead = 1.05
local hitAction = "ThalassaRepairStrike"
local cancelAction = "ThalassaRepairCancel"

local function circle(object)
	UI.make("UICorner",object,{CornerRadius=UDim.new(1,0)})
end

local function targetPosition(target)
	return UDim2.fromScale(.12 + .76 * math.clamp(target.x,0,1),.13 + .74 * math.clamp(target.y,0,1))
end

function BreachClient.new(gui,send,onOwnershipChanged)
	local layer=UI.make("ScreenGui",gui.Parent,{
		Name="HullRepair",DisplayOrder=gui.DisplayOrder+16,ResetOnSpawn=false,Enabled=false,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
	})
	local shade=UI.frame(layer,c.black,nil,nil,.24)
	UI.make("TextButton",layer,{Name="RepairCursor",Size=UDim2.fromOffset(1,1),
		Text="",BackgroundTransparency=1,Modal=true,Selectable=false,AutoButtonColor=false})
	local plate=UI.frame(shade,c.sea,UDim2.fromScale(.5,.13),UDim2.new(.8,0,0,95),.12)
	plate.AnchorPoint=Vector2.new(.5,.5)
	UI.make("UISizeConstraint",plate,{MinSize=Vector2.new(238,95),MaxSize=Vector2.new(490,95)})
	UI.edge(plate)
	UI.frame(plate,c.orange,UDim2.fromOffset(0,0),UDim2.fromOffset(38,3))
	local title=UI.label(plate,"Seal the breach",22,c.white,UI.bold,UDim2.fromOffset(9,7),UDim2.new(1,-18,0,29),center)
	local progress=UI.label(plate,"",13,c.orange,UI.mono,UDim2.fromOffset(9,37),UDim2.new(1,-18,0,18),center)
	local track=UI.frame(plate,c.grid,UDim2.fromOffset(18,65),UDim2.new(1,-36,0,3))
	local bar=UI.frame(track,c.green,nil,UDim2.fromScale(1,1))
	local feedback=UI.label(plate,"",13,c.soft,UI.bold,UDim2.fromOffset(9,72),UDim2.new(1,-18,0,19),center)
	local pad=UI.frame(shade,c.panel,UDim2.fromScale(.5,.53),UDim2.fromScale(.83,.57),.87)
	pad.AnchorPoint=Vector2.new(.5,.5)
	UI.edge(pad,c.grid)
	local hint=UI.label(shade,"",14,c.white,UI.body,UDim2.fromScale(.5,.84),UDim2.new(.86,0,0,25),center)
	hint.AnchorPoint=Vector2.new(.5,0)
	local challenge, tickConnection
	local buttons={}
	local peerProgress=1
	local planks=0
	local pendingIndex=nil
	local pendingUntil=0
	local started=0
	local temporaryText,temporaryUntil
	local cancelText

	local function flash(text)
		temporaryText,temporaryUntil=text,workspace:GetServerTimeNow()+.65
	end

	local function requestCancel()
		if challenge then send("BreachCancel") end
	end
	local cancel=UI.button(shade,"Cancel repair","CancelHullRepair",c.panel,c.white,requestCancel)
	cancel.AnchorPoint=Vector2.new(.5,1)
	cancel.Position,cancel.Size=UDim2.fromScale(.5,.975),UDim2.fromOffset(164,40)
	UI.edge(cancel)

	local function strike(index)
		if not challenge or index~=peerProgress then return end
		local target=challenge.targets[index]
		if not target then return end
		local now=workspace:GetServerTimeNow()
		if pendingIndex==index and now<pendingUntil then return end
		local offset=now-target.at
		if offset < -challenge.window then flash("Early  ·  wait for the ring") return end
		if offset > challenge.window then flash("Missed") return end
		pendingIndex,pendingUntil=index,now+.38
		flash("Checking timing…")
		send("BreachHit",{id=challenge.id,index=index,time=now})
	end

	local function bindControls()
		local priority=Enum.ContextActionPriority.High.Value+10
		ContextActions:BindActionAtPriority(hitAction,function(_,state)
			if state==Enum.UserInputState.Begin then strike(peerProgress) end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.ButtonA)
		ContextActions:BindActionAtPriority(cancelAction,function(_,state)
			if state==Enum.UserInputState.Begin then requestCancel() end
			return Enum.ContextActionResult.Sink
		end,false,priority,Enum.KeyCode.Q,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
	end

	local function paint()
		if not challenge then return end
		local now=workspace:GetServerTimeNow()
		local targets=challenge.targets
		local deadline=challenge.expiresAt or (targets[#targets].at+challenge.window)
		local remaining=math.max(0,deadline-now)
		bar.Size=UDim2.fromScale(math.clamp(remaining/math.max(deadline-started,.01),0,1),1)
		progress.Text=("%d / %d  •  %d plank%s  •  %.1fs"):format(
			math.min(peerProgress-1,#targets),#targets,planks,planks==1 and "" or "s",remaining)
		local gamepad=Input.PreferredInput==Enum.PreferredInput.Gamepad
		local touch=Input.PreferredInput==Enum.PreferredInput.Touch
		hint.Text=if gamepad then "Press A as the ring meets the active circle"
			elseif touch then "Tap each circle as its ring meets the edge"
			else "Click each circle as its ring meets the edge"
		local label=if gamepad then "Cancel repair  [B]" elseif touch then "Cancel repair" else "Cancel repair  [Q]"
		if cancelText~=label then cancel.Text=label cancelText=label end

		local active=targets[peerProgress]
		local default=if not active then "Securing plank…"
			elseif now>active.at+challenge.window then "Timing missed"
			elseif math.abs(now-active.at)<=challenge.window then "NOW"
			else "Wait for the ring"
		feedback.Text=if temporaryUntil and now<temporaryUntil then temporaryText else default
		feedback.TextColor3=default=="NOW" and c.green or default=="Timing missed" and c.red or c.soft

		local diameter=math.clamp(math.min(pad.AbsoluteSize.X/7,pad.AbsoluteSize.Y/4.1),46,72)
		for index,entry in buttons do
			local target=targets[index]
			local offset=now-target.at
			local complete=index<peerProgress
			local current=index==peerProgress
			local timing=current and math.abs(offset)<=challenge.window
			local reveal=offset>=-lookAhead and offset<=challenge.window+.25
			entry.group.Visible=reveal or (complete and offset<.62)
			if not entry.group.Visible then continue end
			entry.button.Size=UDim2.fromOffset(diameter,diameter)
			entry.button.Interactable=current and not complete
			local ringScale=1+math.clamp(-offset/lookAhead,0,1)*.95
			local ringSize=diameter*ringScale
			entry.ring.Size=UDim2.fromOffset(ringSize,ringSize)
			entry.ring.Visible=current and not complete and offset<=challenge.window
			entry.button.BackgroundColor3=if timing then c.green elseif complete then c.raised else c.panel
			entry.button.BackgroundTransparency=if current or complete then .10 else .45
			entry.button.TextColor3=if timing then c.black elseif complete then c.green else c.white
			entry.button.Text=if complete then "✓" elseif offset>challenge.window then "×" else tostring(index)
			entry.outline.Color=if offset>challenge.window and not complete then c.red elseif timing or complete then c.green else c.line
			entry.ringOutline.Color=timing and c.green or c.orange
		end
	end

	local function clear()
		if not challenge then return end
		challenge=nil
		layer.Enabled=false
		if tickConnection then tickConnection:Disconnect() tickConnection=nil end
		ContextActions:UnbindAction(hitAction)
		ContextActions:UnbindAction(cancelAction)
		for _,entry in buttons do entry.group:Destroy() end
		table.clear(buttons)
		pendingIndex,pendingUntil=nil,0
		temporaryText,temporaryUntil=nil,nil
		if onOwnershipChanged then onOwnershipChanged(false) end
	end

	local self={}
	function self:isActive() return challenge~=nil end
	function self:reset() clear() end

	function self:update(snapshot)
		local nextChallenge=snapshot and snapshot.breachRepair
		if type(nextChallenge)~="table" or type(nextChallenge.targets)~="table" or #nextChallenge.targets==0 then
			clear()
			return
		end
		planks=snapshot.planks or 0
		local nextIndex=math.floor(nextChallenge.nextIndex or ((nextChallenge.completed or 0)+1))
		if challenge and nextChallenge.id==challenge.id then
			if nextIndex>peerProgress then
				peerProgress=nextIndex
				pendingIndex=nil
				flash("Fastener set")
			end
			challenge=nextChallenge
			return
		end
		clear()
		challenge=nextChallenge
		peerProgress=math.clamp(nextIndex,1,#challenge.targets+1)
		started=workspace:GetServerTimeNow()
		title.Text=string.format("Seal breach  %02d",challenge.section)
		for index,target in challenge.targets do
			local anchor=UI.frame(pad,c.black,targetPosition(target),UDim2.fromOffset(0,0),1)
			local ring=UI.frame(anchor,c.black,nil,nil,1)
			ring.AnchorPoint=Vector2.new(.5,.5)
			circle(ring)
			local ringOutline=UI.edge(ring,c.orange)
			ringOutline.Thickness=3
			local button=UI.button(anchor,tostring(index),"RepairTarget"..index,c.panel,c.white,function() strike(index) end)
			button.AnchorPoint=Vector2.new(.5,.5)
			button.AutoButtonColor=false
			button.Selectable=false
			button.TextSize=19
			circle(button)
			local outline=UI.edge(button,c.line)
			outline.Thickness=2
			buttons[index]={group=anchor,ring=ring,ringOutline=ringOutline,button=button,outline=outline}
		end
		bindControls()
		layer.Enabled=true
		paint()
		tickConnection=RunService.Heartbeat:Connect(paint)
		if onOwnershipChanged then onOwnershipChanged(true) end
	end
	return self
end

return BreachClient
