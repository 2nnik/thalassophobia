-- Expedition medical locker. Health and all supplies are owned by the server.
local Medical = {}
local V = Vector3.new
local steel = Color3.fromRGB(59,82,85)
local chalk = Color3.fromRGB(211,224,198)
local copper = Color3.fromRGB(197,98,52)
local mint = Color3.fromRGB(101,240,208)
local labels = {Axe="Rescue axe", Laser="Survey laser", Bandage="Pressure dressing"}
local rates = {Easy=2, Normal=1.5, Hard=1, Nightmare=.75}
local bonus = {Easy=2, Normal=1}
local function piece(parent,name,size,cf,color,base,material)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Material=material or Enum.Material.Metal
	p.CanCollide,p.CanTouch,p.CanQuery,p.Massless=false,false,false,true
	if base then
		local weld=Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent=base,p,p
	end
	p.Parent=parent
	return p
end
local function buildItem(parent,kind,cf,anchor)
	local handle=piece(parent,"Handle",if kind=="Bandage" then V(.62,.72,.60) else V(.23,1.12,.26),cf,if kind=="Bandage" then chalk else steel,anchor)
	local function detail(name,size,offset,color,material)
		return piece(parent,name,size,cf*offset,color,handle,material)
	end
	if kind=="Axe" then
		detail("Forged head",V(.83,.37,.19),CFrame.new(.22,.55,0),copper)
		detail("Cutting edge",V(.13,.57,.22),CFrame.new(.64,.54,0)*CFrame.Angles(0,0,.12),chalk)
	elseif kind=="Laser" then
		detail("Emitter",V(.40,.40,1.5),CFrame.new(0,.50,-.32),steel)
		detail("Lens",V(.23,.22,.10),CFrame.new(0,.5,-1.08),mint,Enum.Material.Neon)
	else
		detail("Seal",V(.66,.18,.64),CFrame.identity,mint)
	end
	return handle
end
function Medical.start(playerList,difficulty,site,onStrike)
	local self={}
	local allowed,tools,connections,bleeding,regen={},{},{},{},{}
	local dead=false
	local stock=math.ceil(#playerList*(rates[difficulty] or 1.5))+(bonus[difficulty] or 0)
	local function watch(character)
		local function disable(child)
			if child.Name=="Health" and child:IsA("Script") and child.Enabled then
				regen[child]=true
				child.Enabled=false
			end
		end
		table.insert(connections,character.ChildAdded:Connect(disable))
		for _,child in character:GetChildren() do disable(child) end
	end
	for _,p in playerList do
		allowed[p]=true
		p:SetAttribute("DiveBleeding",false)
		if p.Character then watch(p.Character) end
		table.insert(connections,p.CharacterAdded:Connect(function(character)
			if not allowed[p] then return end
			bleeding[p]=nil
			p:SetAttribute("DiveBleeding",false)
			watch(character)
		end))
	end
	local function vital(p)
		local char=p.Character
		local h=char and char:FindFirstChildOfClass("Humanoid")
		local root=char and char:FindFirstChild("HumanoidRootPart")
		if allowed[p] and root and h and h.Health>0 then return h,root end
	end
	local function equip(player,kind)
		local pack=player:FindFirstChildOfClass("Backpack")
		if not pack or pack:FindFirstChild(labels[kind]) or player.Character:FindFirstChild(labels[kind]) then return false end
		local tool=Instance.new("Tool")
		tool.Name,tool.CanBeDropped,tool.ToolTip=labels[kind],false,if kind=="Bandage" then "Aim at a crewmate or use on yourself" else labels[kind]
		tool:SetAttribute("DiveMedicalKind",kind)
		buildItem(tool,kind,CFrame.identity,nil)
		local aim=Instance.new("RemoteEvent")
		aim.Name,aim.Parent="Aim",tool
		local nextUse=0
		aim.OnServerEvent:Connect(function(sender,point)
			local h,root=vital(player)
			if dead or sender~=player or not h or tool.Parent~=player.Character or time()<nextUse or typeof(point)~="Vector3" then return end
			local origin=(player.Character:FindFirstChild("Head") or root).Position
			local delta=point-origin
			if not (delta.Magnitude<1e6 and delta.Magnitude>.001) then return end
			nextUse=time()+(if kind=="Laser" then .40 else .7)
			local params=RaycastParams.new()
			params.FilterType=Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances={player.Character,site.ShipEnvelope}
			local range=if kind=="Laser" then 90 else 9
			local direction=delta.Unit*range
			local hit=workspace:Raycast(origin,direction,params)
			if kind=="Bandage" then
				local target=player
				for mate in allowed do
					if hit and mate.Character and hit.Instance:IsDescendantOf(mate.Character) then target=mate;break end
				end
				local recipient=vital(target)
				if not recipient or (not bleeding[target] and recipient.Health>=recipient.MaxHealth) then return end
				bleeding[target]=nil
				target:SetAttribute("DiveBleeding",false)
				recipient.Health=math.min(recipient.MaxHealth,recipient.Health+45)
				tools[tool]=nil
				tool:Destroy()
			else
				if kind=="Laser" then
					local tip=tool:FindFirstChild("Lens")
					local from=if tip then tip.Position else origin
					local to=if hit then hit.Position else origin+direction
					if (to-from).Magnitude>.01 then
						local beam=piece(workspace,"Survey pulse",V(.09,.09,(to-from).Magnitude),CFrame.lookAt((to+from)/2,to),mint,nil,Enum.Material.Neon)
						beam.Anchored=true
						game:GetService("Debris"):AddItem(beam,.09)
					end
				end
				if hit then onStrike(player,kind,hit.Instance) end
			end
		end)
		tools[tool]=player
		tool.Parent=pack
		return true
	end
	local locker=Instance.new("Model")
	locker.Name,locker.Parent="Emergency locker",site.Stations
	local cf=site.HullMotion.CFrame*CFrame.new(-8,-2.4,12)
	local case=piece(locker,"Locker",V(6,4.7,.55),cf,steel,site.HullMotion)
	local medPrompt
	local function update()
		site:SetAttribute("DiveBandageStock",stock)
		if medPrompt then medPrompt.ObjectText="Medkit • "..stock.." dressings" end
	end
	for index,kind in {"Axe","Bandage","Laser"} do
		local handle=buildItem(locker,kind,cf*CFrame.new((index-2)*2,.1,-.56),case)
		local prompt=Instance.new("ProximityPrompt")
		prompt.Style=Enum.ProximityPromptStyle.Custom
		prompt.UIOffset=Vector2.new(0,(index-2)*61)
		prompt.ActionText,prompt.ObjectText="Take "..labels[kind],labels[kind]
		prompt.RequiresLineOfSight,prompt.MaxActivationDistance=false,7
		prompt.KeyboardKeyCode=({Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.R})[index]
		prompt.Parent=handle
		if kind=="Bandage" then medPrompt=prompt end
		prompt.Triggered:Connect(function(p)
			local _,root=vital(p)
			if dead or not root or (root.Position-handle.Position).Magnitude>8 or (kind=="Bandage" and stock<=0) then return end
			if equip(p,kind) and kind=="Bandage" then stock-=1;update() end
		end)
	end
	update()
	function self:wound(p)
		local h=vital(p)
		if not h or bleeding[p] then return end
		bleeding[p]=h
		h.Health=math.max(1,math.min(h.Health,60))
		p:SetAttribute("DiveBleeding",true)
	end
	task.spawn(function()
		while not dead do
			task.wait(2)
			if dead then break end
			for p,h in bleeding do
				if vital(p)==h then h:TakeDamage(2) else bleeding[p]=nil;p:SetAttribute("DiveBleeding",false) end
			end
		end
	end)
	function self:remove(player)
		allowed[player]=nil
		bleeding[player]=nil
		player:SetAttribute("DiveBleeding",nil)
		for t,owner in tools do
			if owner==player then tools[t]=nil;t:Destroy() end
		end
	end
	function self:destroy()
		dead=true
		for _,c in connections do c:Disconnect() end
		for t in tools do t:Destroy() end
		for s in regen do if s.Parent then s.Enabled=true end end
		for p in allowed do p:SetAttribute("DiveBleeding",nil) end
		site:SetAttribute("DiveBandageStock",nil)
		locker:Destroy()
	end
	return self
end
return Medical
