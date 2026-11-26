local Rig={}
Rig.__index=Rig
local steel=Color3.fromRGB(36,58,65)
local amber=Color3.fromRGB(246,151,69)
local cyan=Color3.fromRGB(143,220,211)

local function part(parent,name,size,cf,color,material,shape)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Material,p.Shape=material or Enum.Material.Metal,shape or Enum.PartType.Block
	p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=false,false,false,false
	p.Anchored=true
	p.Parent=parent
	return p
end

local function sound(parent,name,id,volume,speed,range)
	local s=Instance.new("Sound")
	s.Name,s.SoundId,s.Volume,s.PlaybackSpeed=name,"rbxassetid://"..id,volume,speed
	s.RollOffMode,s.RollOffMinDistance,s.RollOffMaxDistance=Enum.RollOffMode.Linear,15,range
	s.Parent=parent
	return s
end

local function filter(sound,low,mid,high)
	local eq=Instance.new("EqualizerSoundEffect")
	eq.LowGain,eq.MidGain,eq.HighGain,eq.Parent=low,mid,high,sound
end

local function fish(parent)
	local model=Instance.new("Model")
	model.Name="The Knockback"
	local hide=Color3.fromRGB(75,102,103)
	local bone=Color3.fromRGB(180,209,196)
	local function oval(name,x,y,z,w,h,d,color,material)
		return part(model,name,Vector3.new(w,h,d),CFrame.new(x,y,z),color,material,Enum.PartType.Ball)
	end
	model.PrimaryPart=oval("Flattened body",0,0,0,10,3.8,17,hide,Enum.Material.Slate)
	oval("Ramming shield",0,.42,-6.2,12,3.3,6.5,bone,Enum.Material.Slate)
	oval("Pale lower jaw",0,-.86,-6,8.2,1.25,7.3,bone)
	oval("Tail stalk",0,0,8.1,2.4,1.4,8,hide)
	oval("Forked tail",0,.2,11.4,8,1.1,3.5,hide)
	for _,side in {-1,1} do
		local fin=oval("Knife fin",side*5.8,-.21,2.1,8.1,.54,6.4,hide)
		fin.CFrame*=CFrame.Angles(0,side*.54,side*.2)
		oval("Eye",side*4.5,.7,-7.55,.45,.36,.63,cyan,Enum.Material.Neon)
		for i=1,5 do
			local slit=oval("Gill seam",side*(4.27-i*.08),.70,-2.3+i*.65,.24,1.02,.25,bone)
			slit.CFrame*=CFrame.Angles(.35,0,side*.35)
		end
	end
	model.Parent=parent
	return model
end

function Rig.start(site)
	local root=Instance.new("Model")
	root.Name="Sonar isolation breaker"
	local hull=site.HullMotion
	local base=hull.CFrame*CFrame.new(21.7,-.35,-20.25)
	local function mount(name,size,cf,color,material)
		local p=part(root,name,size,base*cf,color,material)
		p.Massless,p.Anchored=true,false
		local weld=Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent=hull,p,p
		return p
	end
	local box=mount("Breaker box",Vector3.new(2.18,1.95,.4),CFrame.identity,steel)
	local face=mount("Engraved plate",Vector3.new(1.94,1.20,.08),CFrame.new(0,.28,.24),Color3.fromRGB(12,21,26))
	mount("Isolation lever",Vector3.new(.32,.57,.31),CFrame.new(0,-.48,.32),amber)
	local pilot=mount("Fault lamp",Vector3.new(.18,.18,.10),CFrame.new(.81,-.50,.24),cyan,Enum.Material.Neon)
	local gui=Instance.new("SurfaceGui")
	gui.Face,gui.CanvasSize,gui.LightInfluence,gui.Parent=Enum.NormalId.Back,Vector2.new(240,145),0,face
	local legend=Instance.new("TextLabel")
	legend.BackgroundTransparency,legend.Size=1,UDim2.fromScale(1,1)
	legend.TextColor3,legend.Font,legend.TextSize=cyan,Enum.Font.Code,27
	legend.Text,legend.Parent="SONAR BREAKER\nCIRCUIT READY",gui
	local prompt=Instance.new("ProximityPrompt")
	prompt.Style=Enum.ProximityPromptStyle.Custom
	prompt.ObjectText,prompt.ActionText="Sonar breaker","Isolate sonar"
	prompt.RequiresLineOfSight,prompt.MaxActivationDistance=false,10
	prompt.KeyboardKeyCode,prompt.HoldDuration=Enum.KeyCode.E,.22
	prompt:SetAttribute("Action","KnockbackBreaker")
	prompt.Enabled,prompt.Parent=false,box
	local head=mount("Transducer impact",Vector3.one,CFrame.new(4,-2.8,10),steel)
	head.Transparency=1
	local under=mount("Keel audio",Vector3.one,CFrame.new(-13,-4.7,8),steel)
	under.Transparency=1
	local knock=sound(under,"Knockback double knock",9117022316,.46,.66,66)
	filter(knock,4,-4,-12)
	local impact=sound(head,"Transducer / hull impact",9125668193,1.03,.64,78)
	local whine=sound(box,"Damaged sonar head",9125767459,.55,1.78,45)
	filter(whine,-23,-5,4)
	whine.Looped=true
	root.Parent=site.Stations
	return setmetatable({site=site,root=root,prompt=prompt,legend=legend,pilot=pilot,
		knock=knock,impact=impact,whine=whine},Rig)
end

function Rig:cue(kind,count)
	if kind=="Knock" then
		self.knock.Volume=.33+.11*count
		task.delay(.27,function()
			if not self.root.Parent then return end
			self.knock:Play()
			task.wait(.34)
			if self.root.Parent then self.knock:Stop(); self.knock:Play() end
		end)
	elseif kind=="Strike" then
		self.impact:Play()
		self.whine:Play()
		self.pilot.Color=amber
		self.legend.Text="SONAR BREAKER\nHEAD FAILURE"
		self.prompt.Enabled=true
		self.actor=fish(self.site)
		self.passage=workspace:GetServerTimeNow()
		self:move()
	elseif kind=="FirstRam" or kind=="Ram" then
		self.impact:Stop(); self.impact:Play()
	elseif kind=="Isolate" then
		self.whine:Stop()
		self.legend.Text="SONAR BREAKER\nISOLATED"
		self.prompt.Enabled=false
		if self.actor then self.actor:Destroy(); self.actor=nil end
	elseif kind=="Clear" then
		self.legend.Text="SONAR BREAKER\nRESET AVAILABLE"
		self.prompt.ActionText="Reset sonar"
		self.prompt.Enabled=true
	elseif kind=="Reset" then
		self.pilot.Color=cyan
		self.legend.Text="SONAR BREAKER\nCIRCUIT READY"
		self.prompt.Enabled=false
	end
end

function Rig:move()
	if not self.actor then return end
	local time=workspace:GetServerTimeNow()-self.passage
	if time>10 then self.actor:Destroy(); self.actor=nil; return end
	local z=-24+time*4.9
	local x=37+9*math.sin(math.pi*math.clamp(time/10,0,1))
	local cf=self.site.HullMotion.CFrame
	local pos=cf:PointToWorldSpace(Vector3.new(x,-1.6+math.sin(time)*1.9,z))
	local direction=cf:VectorToWorldSpace(Vector3.new(math.cos(time*.31)*.42,.09*math.cos(time),1))
	self.actor:PivotTo(CFrame.lookAt(pos,pos+direction)*CFrame.Angles(0,0,.14*math.sin(time*.86)))
end

function Rig:destroy()
	if self.actor then self.actor:Destroy() end
	self.root:Destroy()
end

return Rig
