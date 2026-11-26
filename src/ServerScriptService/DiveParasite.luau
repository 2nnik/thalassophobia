-- A pressure-reef parasite with a ribbed shell and a fan of hooked swimming fins.
local Parasite = {}
Parasite.__index = Parasite
local rules = { Easy={4,9}, Normal={5,8}, Hard={7,7}, Nightmare={9,6} }
local letters = "XEDFGHBC"
local shell = Color3.fromRGB(48,84,83)
local underside = Color3.fromRGB(165,148,103)
local glow = Color3.fromRGB(102,218,190)
local clips = {Latch="115590488647349", Emergence="135649605245917", Move="135813245187045"}
local modelScale = {Limpet=.008, Skater=.0065}
local latchOffset = CFrame.new(0,-1.63,-.31)

local function play(model, name, looped)
	local controller=model:FindFirstChildWhichIsA("AnimationController",true)
	local animator=controller and controller:FindFirstChildOfClass("Animator")
	if not animator then return end
	local clip=Instance.new("Animation")
	clip.Name,clip.AnimationId,clip.Parent=name,"rbxassetid://"..clips[name],model
	local ok,track=pcall(animator.LoadAnimation,animator,clip)
	if not ok then warn("Rift creature animation "..name.." failed: "..tostring(track)); return end
	track.Looped=looped
	track.Priority=Enum.AnimationPriority.Action
	track:Play(.12)
	return track
end

local function bead(model,name,cf,size,color,lit)
	local part = Instance.new("Part")
	part.Name,part.Shape,part.Size,part.CFrame = name,Enum.PartType.Ball,size,cf
	part.Anchored,part.CanCollide,part.CanTouch = true,false,false
	part.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
	part.Color,part.Parent = color,model
	return part
end

local function limb(model,a,b,width,color)
	local middle = (a+b)*0.5
	bead(model,"Fin",CFrame.lookAt(middle,b),Vector3.new(width,width,(b-a).Magnitude+width*0.6),color)
end

local function creature(parent,adult)
	local kind=if adult then "Skater" else "Limpet"
	local templates=game:GetService("ServerStorage"):FindFirstChild("RiftCreatureRigs")
	local template=templates and templates:FindFirstChild("Rift "..kind)
	if template then
		local rig=template:Clone()
		rig:ScaleTo(modelScale[kind])
		for _,part in rig:GetDescendants() do
			if part:IsA("BasePart") then part.Anchored=part==rig.PrimaryPart end
		end
		rig.Parent=parent
		return rig
	end
	local model = Instance.new("Model")
	model.Name = if adult then "Rift Skater" else "Rift Limpet"
	local scale = if adult then 1.9 else 0.76
	model.PrimaryPart = bead(model,"Mantle",CFrame.new(),Vector3.new(1.05,.53,1.55),shell)
	for i=1,4 do
		local z=(i-2.5)*.32
		bead(model,"Shell ridge",CFrame.new(0,.17,z),Vector3.new(.99,.28,.16),underside)
		for _,sign in {-1,1} do
			local joint=Vector3.new(sign*(.78+.17*math.sin(i)),.17,z+.18)
			limb(model,Vector3.new(sign*.35,0,z),joint,.15,shell)
			limb(model,joint,Vector3.new(sign*1.03,-.34,z+.43),.09,underside)
		end
	end
	for _,sign in {-1,1} do
		bead(model,"Photophore",CFrame.new(sign*.31,.14,-.62),Vector3.new(.16,.12,.2),glow,true)
	end
	if adult then
		limb(model,Vector3.new(0,0,.55),Vector3.new(0,.35,1.45),.32,shell)
		limb(model,Vector3.new(0,.35,1.45),Vector3.new(0,.65,2.1),.14,underside)
	end
	model:ScaleTo(scale)
	model.Parent=parent
	return model
end

local function body(player)
	local char=player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

function Parasite.start(players,difficulty,site,remote)
	local self=setmetatable({rules=rules[difficulty] or rules.Normal, site=site,remote=remote,
		crew={}, hunts={},released={},rng=Random.new()},Parasite)
	for _,p in players do self.crew[p]={roll=6} end
	return self
end

function Parasite:clearLatch(p,m,escaped)
	if m.model then
		if escaped and m.track and m.track.Length>1.85 then
			m.track.TimePosition=1.85
			m.track:AdjustSpeed(1.65)
			local released=m.model
			self.released[released]=true
			task.delay(.8,function() self.released[released]=nil; released:Destroy() end)
		else
			m.model:Destroy()
		end
		m.model,m.track=nil,nil
	end
	if m.sequence and p.Parent then self.remote:FireClient(p,"LatchEnd") end
	m.sequence=nil
	m.index=nil
end

function Parasite:input(p,action,key)
	local m=self.crew[p]
	if action~="Key" or not m or not m.sequence or type(key)~="string" or #key~=1 then return end
	local now=workspace:GetServerTimeNow()
	if now>=m.deadline then return end
	if key==m.sequence:sub(m.index,m.index) then m.index+=1 end
	if m.index<=#m.sequence then
		self.remote:FireClient(p,"LatchProgress",m.index)
		return
	end
	if now-m.started>3 then m.hatch=now+self.rng:NextNumber(60,120) end
	self:clearLatch(p,m,true)
	m.roll=35
end

function Parasite:latch(p,m,root,now)
	m.sequence=""
	for _=1,self.rules[1] do
		local i=self.rng:NextInteger(1,#letters)
		m.sequence..=letters:sub(i,i)
	end
	m.index,m.started,m.deadline=1,now,now+self.rules[2]
	m.model=creature(self.site.Contacts,false)
	m.track=play(m.model,"Latch",false)
	local head=p.Character:FindFirstChild("Head") or root
	m.model:PivotTo(if m.track then head.CFrame*latchOffset else root.CFrame*CFrame.new(0,1.35,-.65))
	self.remote:FireClient(p,"Latch",m.sequence,m.deadline)
end

function Parasite:step(dt,depth,isOutside,isAlive,wound)
	local now=workspace:GetServerTimeNow()
	for p,m in self.crew do
		local root,hum=body(p)
		if not p.Parent or not root or not hum or hum.Health<=0 or not isAlive(p) then
			self:clearLatch(p,m)
			m.hatch=nil
			continue
		end
		if m.sequence then
			local head=p.Character:FindFirstChild("Head") or root
			if m.track then
				m.model:PivotTo(head.CFrame*latchOffset)
				if m.track.Speed>0 and m.track.TimePosition>=1.72 then
					m.track.TimePosition=1.72
					m.track:AdjustSpeed(0)
				end
			else
				m.model:PivotTo(head.CFrame*CFrame.new(0,0,-.65)*CFrame.Angles(math.rad(85),0,.06*math.sin(now*16)))
			end
			if now>=m.deadline then self:clearLatch(p,m); hum.Health=0 end
		elseif m.hatch then
			if now>=m.hatch then
				m.hatch=nil
				m.roll=55
				local model=creature(self.site.Contacts,true)
				model:PivotTo(root.CFrame*CFrame.new(0,-.05,-.25))
				local track=play(model,"Emergence",false)
				if track then track:AdjustSpeed(1.25) end
				local hidden={}
				if track then
					for _,part in model:GetDescendants() do
						if part:IsA("MeshPart") then
							hidden[part]={part.Transparency,part.CanQuery}
							part.Transparency,part.CanQuery=1,false
						end
					end
				else
					model:ScaleTo(.28)
				end
				self.hunts[model]={host=p,born=now,health=3,bite=now+9,track=track,hidden=hidden}
				self.remote:FireClient(p,"Emergence",now)
				if wound then wound(p) end
			end
		elseif depth>=6000 and isOutside(p) then
			m.roll-=dt
			if m.roll<=0 then
				m.roll=10
				if self.rng:NextNumber()<.24 then self:latch(p,m,root,now) end
			end
		end
	end
	for model,h in self.hunts do
		local hostRoot=body(h.host)
		local age=now-h.born
		if age>=1.10 and h.hidden then
			for part,original in h.hidden do part.Transparency,part.CanQuery=original[1],original[2] end
			h.hidden=nil
		end
		if age<4 and hostRoot then
			if h.track then
				model:PivotTo(hostRoot.CFrame*CFrame.new(0,-.28,-.53))
			else
				local t=math.min(1,age/1.6)
				model:ScaleTo(.28+.7*t)
				model:PivotTo(hostRoot.CFrame*CFrame.new(0,-.1,-.25-t*.95)*CFrame.Angles(-.45*t,.17*math.sin(age*12),0))
			end
		else
			if not h.loose then
				if h.track then
					local head=model:FindFirstChild("Segment_00",true)
					local pose=model:GetPivot()
					if head then model:PivotTo(CFrame.new(head.TransformedWorldCFrame.Position)*pose.Rotation) end
					h.track:Stop(.16)
					h.track=play(model,"Move",true)
				else
					model:ScaleTo(1.9)
				end
				h.loose=true
			end
			local pose=model:GetPivot()
			local pos=pose.Position
			local target,hum,dist=nil,nil,math.huge
			for p in self.crew do
				local r,human=body(p)
				if p.Parent and isAlive(p) and r and human and human.Health>0 then
					local d=(pos-r.Position).Magnitude
					if d<dist then target,hum,dist=r,human,d end
				end
			end
			if target then
				local delta=target.Position-pos
				local flat=Vector3.new(delta.X,0,delta.Z)
				local nextPos=pos+Vector3.new(0,math.clamp(delta.Y,-dt*2,dt*2),0)
				local facing=pose.Rotation
				if flat.Magnitude>2.7 then
					nextPos+=flat.Unit*math.min(dt*7,flat.Magnitude-2.7)
					facing=facing:Lerp(CFrame.lookAt(Vector3.zero,flat),1-math.exp(-dt*5))
				end
				model:PivotTo(CFrame.new(nextPos)*facing)
				if dist<4 and now>=h.bite then hum:TakeDamage(12); h.bite=now+3 end
			end
		end
	end
end

function Parasite:strike(p,kind,target)
	local root,hum=body(p)
	if not self.crew[p] or not root or not hum or hum.Health<=0 or typeof(target)~="Instance" or not target:IsA("BasePart") then return false end
	local model=target.Parent
	local hunt=self.hunts[model]
	if not hunt then return false end
	local now=workspace:GetServerTimeNow()
	local axe=kind=="Axe"
	if (axe and now-hunt.born>=4) or (not axe and (kind~="Laser" or now-hunt.born<4)) then return false end
	local head=p.Character:FindFirstChild("Head") or root
	local delta=target.Position-head.Position
	if delta.Magnitude>(if axe then 10 else 85) then return false end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances=if not hunt.loose and hunt.host.Character then {p.Character,hunt.host.Character} else {p.Character}
	local hit=workspace:Raycast(head.Position,delta,params)
	if hit and not hit.Instance:IsDescendantOf(model) then return false end
	local m=self.crew[p]
	if now<(m.nextStrike or 0) then return false end
	m.nextStrike=now+.32
	hunt.health-=if axe then 3 else 1
	if hunt.health<=0 then self.hunts[model]=nil; model:Destroy() end
	return true
end

function Parasite:destroy()
	for p,m in self.crew do self:clearLatch(p,m) end
	for model in self.hunts do model:Destroy() end
	for model in self.released do model:Destroy() end
	table.clear(self.hunts)
	table.clear(self.crew)
	table.clear(self.released)
end
return Parasite
