local Lighting=game:GetService("Lighting")
local Bloom={}
local palettes={
	{Color3.fromRGB(236,119,210),Color3.fromRGB(255,178,223),Color3.fromRGB(159,98,236)},
	{Color3.fromRGB(79,172,235),Color3.fromRGB(160,238,255),Color3.fromRGB(125,123,255)},
	{Color3.fromRGB(153,131,245),Color3.fromRGB(220,194,255),Color3.fromRGB(87,148,246)},
}
local field,grade,glow
local actors,lamps,motes={},{},{}
local depth,entry,originDepth,nextDraw,lightLevel=0,nil,0,0,0

local function part(parent,name,position,size,color,material,ball)
	local p=Instance.new("Part")
	p.Name,p.CFrame,p.Size,p.Color=name,CFrame.new(position),size,color
	p.Material,p.Shape=material,if ball then Enum.PartType.Ball else Enum.PartType.Block
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
	p.Parent=parent
	return p
end

local function anchor(root,position)
	local a=Instance.new("Attachment")
	a.Position,a.Parent=position,root
	return a
end

local function strand(root,name,first,last,width,colors,curve)
	local beam=Instance.new("Beam")
	beam.Name,beam.Attachment0,beam.Attachment1=name,first,last
	beam.FaceCamera,beam.Segments=true,12
	beam.Width0,beam.Width1=width,width*.21
	beam.Color=ColorSequence.new(colors[2],colors[3])
	beam.CurveSize0,beam.CurveSize1=curve,curve*.6
	beam.Transparency=NumberSequence.new({
		NumberSequenceKeypoint.new(0,.17),NumberSequenceKeypoint.new(.64,.37),NumberSequenceKeypoint.new(1,1),
	})
	beam.LightEmission,beam.LightInfluence=1,0
	beam.Parent=root
	return beam
end

local function jelly(index,ring,altitude,colors,radius,offset)
	local model=Instance.new("Model")
	model.Name="Crown jelly "..index
	local core=part(model,"Crown pivot",Vector3.zero,Vector3.one,colors[1],Enum.Material.SmoothPlastic)
	core.Transparency=1
	model.PrimaryPart=core
	local records={}
	local function shell(name,y,width,height,color,material,alpha)
		local p=part(model,name,Vector3.new(0,y,0),Vector3.new(width,height,width),color,material,true)
		p.Transparency=1
		table.insert(records,{p,alpha})
		return p
	end
	local mantle=shell("Translucent mantle",2,radius*2,radius*.95,colors[1],Enum.Material.Glass,.38)
	local rim=shell("Luminous bell rim",-.9,radius*1.81,radius*.24,colors[2],Enum.Material.Neon,.64)
	shell("Inner bell",2.8,radius*1.43,radius*.44,colors[1],Enum.Material.ForceField,.35)
	shell("Central lantern",.35,radius*.63,radius*.46,colors[2],Enum.Material.Neon,.38)
	local fringes={}
	for i=1,16 do
		local angle=i*math.pi/8+.18*index
		local side=Vector3.new(math.cos(angle),0,math.sin(angle))
		local length=radius*(1.25+.43*math.sin(i*2.2+index))
		local first=anchor(core,side*(radius*.84)-Vector3.yAxis*1.6)
		first.Axis=(side*.56-Vector3.yAxis*.81).Unit
		local last=anchor(core,side*(radius*.58)-Vector3.yAxis*length)
		last.Axis=(-side*.29-Vector3.yAxis*.96).Unit
		local beam=strand(core,"Trailing cilium",first,last,radius*(if i%3==0 then .078 else .039),colors,length*.54)
		table.insert(fringes,{first=first,last=last,beam=beam,side=side,length=length,phase=i*.71})
	end
	for i=1,5 do
		local angle=i*math.pi*2/5
		local side=Vector3.new(math.cos(angle),0,math.sin(angle))
		local first=anchor(core,side*radius*.22)
		first.Axis=(side*.45-Vector3.yAxis*.89).Unit
		local last=anchor(core,side*radius*.36-Vector3.yAxis*radius*1.6)
		last.Axis=-Vector3.yAxis
		local beam=strand(core,"Flowing oral arm",first,last,radius*.16,colors,radius*.65)
		table.insert(fringes,{last=last,beam=beam,side=side*.65,length=radius*1.6,phase=i*1.25})
	end
	model.Parent=field
	table.insert(actors,{model=model,mantle=mantle,rim=rim,shells=records,fringes=fringes,radius=radius,
		angle=index*2.39996,ring=ring,altitude=altitude,offset=offset})
end

local function build()
	originDepth=entry
	field=Instance.new("Folder")
	field.Name="Kestrel Jelly Bloom"
	field.Parent=workspace.CurrentCamera
	local random=Random.new(math.floor(entry))
	local radii={23,18,20,17,21,14,24,15,19,18,16,22}
	for i,radius in radii do
		local ring=if i<=5 then 46+i*4 else 72+i*4
		local y=if i<=5 then 4+(i%3)*7 else random:NextNumber(-25,37)
		jelly(i,ring,y,palettes[(i-1)%#palettes+1],radius,random:NextNumber(-3,3))
	end
	for i=1,4 do
		local node=part(field,"Hull spill "..i,Vector3.zero,Vector3.one,palettes[(i-1)%3+1][1],Enum.Material.SmoothPlastic)
		node.Transparency=1
		local light=Instance.new("PointLight")
		light.Color,light.Range,light.Brightness,light.Shadows=node.Color,31,0,false
		light.Parent=node
		table.insert(lamps,{node,light})
	end
	for i=1,44 do
		local color=palettes[(i-1)%3+1][2]
		local radius=random:NextNumber(.07,.26)
		local p=part(field,"Plankton",Vector3.zero,Vector3.one*radius,color,Enum.Material.Neon,true)
		p.Transparency=1
		motes[i]={p,random:NextNumber(23,91),random:NextNumber(-27,36),random:NextNumber(0,math.pi*2)}
	end
	grade=Instance.new("ColorCorrectionEffect")
	grade.Name,grade.Contrast,grade.Parent="Jelly bloom water tint",-.02,Lighting
	glow=Instance.new("BloomEffect")
	glow.Name,glow.Intensity,glow.Size,glow.Threshold,glow.Parent="Jelly bioluminescence",0,39,1.05,Lighting
end

function Bloom.update(s)
	depth,entry=s.depth or 0,s.jellyBloom
end

function Bloom.render(dt)
	lightLevel+=((if entry then 1 else 0)-lightLevel)*(1-math.exp(-dt*(if entry then .72 else .9)))
	if not field and not entry then return 0 end
	if not field then build() end
	if not entry and lightLevel<.015 then Bloom.reset() return 0 end
	local now=workspace:GetServerTimeNow()
	if now<nextDraw then return lightLevel end
	nextDraw=now+.033
	local site=workspace:FindFirstChild("Thalassa")
	local hull=site and site:FindFirstChild("HullMotion")
	if not hull then Bloom.reset() return 0 end
	local camera=workspace.CurrentCamera
	if field.Parent~=camera then field.Parent=camera end
	local basis=hull.CFrame
	local tide=math.clamp(depth-originDepth,0,460)*.036
	grade.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(229,207,255),lightLevel*.31)
	grade.Saturation=.11*lightLevel
	glow.Intensity=.34*lightLevel
	for i,a in actors do
		local angle=a.angle+.105*math.sin(now*.17+a.offset)
		local center=Vector3.new(math.cos(angle)*a.ring,a.altitude+math.sin(now*.36+a.offset)*4+tide-7,math.sin(angle)*a.ring)
		a.model:PivotTo(basis*CFrame.new(center)*CFrame.Angles(.10*math.sin(now*.43+i),angle,.10*math.cos(now*.43+i)))
		local pulse=1+.075*math.sin(now*1.38+a.offset)
		a.mantle.Size=Vector3.new(a.radius*2*pulse,a.radius*.95/pulse,a.radius*2*pulse)
		a.rim.Size=Vector3.new(a.radius*1.81*pulse,a.radius*.24,a.radius*1.81*pulse)
		for _,s in a.shells do s[1].Transparency=1-(1-s[2])*lightLevel end
		for _,f in a.fringes do
			local curl=math.sin(now*.8+f.phase+a.offset)
			f.last.Position=f.side*(a.radius*(.58+.23*curl))-Vector3.yAxis*(f.length*(1+.08*curl))
			f.beam.Enabled=lightLevel>.16
			f.beam.Brightness=lightLevel
		end
	end
	for i,l in lamps do
		local side=if i%2==0 then -1 else 1
		l[1].Position=basis:PointToWorldSpace(Vector3.new(side*17,3,if i<3 then -12 else 12))
		l[2].Brightness=lightLevel*(1.05+.29*math.sin(now*.8+i))
	end
	for i,m in motes do
		local a=m[4]+now*.045
		m[1].Position=basis:PointToWorldSpace(Vector3.new(math.cos(a)*m[2],m[3]+math.sin(now*.31+i)*3,math.sin(a)*m[2]))
		m[1].Transparency=1-lightLevel*(.46+.27*math.sin(now*1.8+i))
	end
	return lightLevel
end

function Bloom.reset()
	if field then field:Destroy();grade:Destroy();glow:Destroy() end
	field,grade,glow,entry=nil,nil,nil,nil
	lightLevel,nextDraw=0,0
	table.clear(actors)
	table.clear(lamps)
	table.clear(motes)
end

return Bloom
