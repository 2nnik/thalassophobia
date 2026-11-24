-- A pressure-reef parasite with a ribbed shell and a fan of hooked swimming fins.
local Parasite = {}
Parasite.__index = Parasite
local rules = { Easy={4,9}, Normal={5,8}, Hard={7,7}, Nightmare={9,6} }
local letters = "XEDFGHBC"
local shell = Color3.fromRGB(48,84,83)
local underside = Color3.fromRGB(165,148,103)
local glow = Color3.fromRGB(102,218,190)

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
		crew={}, hunts={},rng=Random.new()},Parasite)
	for _,p in players do self.crew[p]={roll=6} end
	return self
end

function Parasite:clearLatch(p,m)
	if m.model then m.model:Destroy(); m.model=nil end
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
	self:clearLatch(p,m)
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
	m.model:PivotTo(root.CFrame*CFrame.new(0,1.35,-.65))
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
			m.model:PivotTo(head.CFrame*CFrame.new(0,0,-.65)*CFrame.Angles(math.rad(85),0,.06*math.sin(now*16)))
			if now>=m.deadline then self:clearLatch(p,m); hum.Health=0 end
		elseif m.hatch then
			if now>=m.hatch then
				m.hatch=nil
				m.roll=55
				local model=creature(self.site.Contacts,true)
				model:ScaleTo(.28)
				model:PivotTo(root.CFrame*CFrame.new(0,-.05,-.25))
				self.hunts[model]={host=p,born=now,health=3,bite=now+9}
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
		if age<4 and hostRoot then
			local t=math.min(1,age/1.6)
			model:ScaleTo(.28+.7*t)
			model:PivotTo(hostRoot.CFrame*CFrame.new(0,-.1,-.25-t*.95)*CFrame.Angles(-.45*t,.17*math.sin(age*12),0))
		else
			if not h.loose then model:ScaleTo(1.9); h.loose=true end
			local pos=model:GetPivot().Position
			local target,hum,dist=nil,nil,math.huge
			for p in self.crew do
				local r,human=body(p)
				if p.Parent and isAlive(p) and r and human and human.Health>0 then
					local d=(pos-r.Position).Magnitude
					if d<dist then target,hum,dist=r,human,d end
				end
			end
			if target then
				local aim=target.Position+Vector3.new(0,-1.3,0)
				local delta=aim-pos
				if delta.Magnitude>.1 then
					local nextPos=pos+delta.Unit*math.min(dt*8,delta.Magnitude*.85)
					model:PivotTo(CFrame.lookAt(nextPos,aim)*CFrame.Angles(0,0,.09*math.sin(age*9)))
				end
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
	table.clear(self.hunts)
	table.clear(self.crew)
end
return Parasite
