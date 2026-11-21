local Rack = {}
local red = Color3.fromRGB(193,42,37)
local steel = Color3.fromRGB(42,53,55)

local function part(parent,name,size,cf,color,anchored)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Anchored,p.Massless=anchored,true
	p.CanCollide,p.CanTouch,p.CanQuery=false,false,false
	p.Material=Enum.Material.Metal
	p.Parent=parent
	return p
end

local function cylinder(parent,frame,anchored)
	local can=part(parent,"Handle",Vector3.new(1.62,.64,.64),frame*CFrame.Angles(0,0,math.pi/2),red,anchored)
	can.Shape=Enum.PartType.Cylinder
	local valve=part(parent,"Brass valve",Vector3.new(.35,.33,.36),frame*CFrame.new(0,.89,0),Color3.fromRGB(198,154,76),anchored)
	local grip=part(parent,"Pressure lever",Vector3.new(.46,.09,.30),frame*CFrame.new(0,1.08,0),steel,anchored)
	local tip=part(parent,"Foam nozzle",Vector3.new(.17,.16,.40),frame*CFrame.new(.23,.76,.18),steel,anchored)
	local band=part(parent,"White label",Vector3.new(.39,.32,.05),frame*CFrame.new(0,.04,.314),Color3.fromRGB(228,224,198),anchored)
	if not anchored then
		for _,item in {valve,grip,tip,band} do
			local w=Instance.new("WeldConstraint")
			w.Part0,w.Part1=can,item
			w.Parent=item
		end
	end
	return can
end

function Rack.install(stations)
	local lifeSupport=stations:FindFirstChild("LIFE SUPPORT")
	local oldCylinder=lifeSupport and lifeSupport:FindFirstChild("Portable extinguisher")
	if oldCylinder then
		for _,item in oldCylinder:GetDescendants() do
			if item:IsA("ProximityPrompt") and item:GetAttribute("Action")=="Extinguisher" then item.Enabled=false item:SetAttribute("Action",nil) end
		end
		oldCylinder.Transparency=1
		for _,name in {"Cylinder strap","Handle"} do
			local item=lifeSupport:FindFirstChild(name)
			if item and item:IsA("BasePart") then item.Transparency=1 end
		end
	end
	local mount=Instance.new("Model")
	mount.Name="Fire extinguisher rack"
	local frame=CFrame.new(4.62,123.1,-9.04)
	local board=part(mount,"Red mounting plate",Vector3.new(1.55,2.8,.2),frame*CFrame.new(0,.18,-.43),red,true)
	local panel=Instance.new("SurfaceGui")
	panel.Face=Enum.NormalId.Back
	panel.CanvasSize=Vector2.new(190,340)
	panel.LightInfluence=.25
	panel.Parent=board
	local label=Instance.new("TextLabel")
	label.Size=UDim2.fromScale(1,.19)
	label.BackgroundTransparency=1
	label.Text="EXTINGUISHER"
	label.TextScaled=true
	label.Font=Enum.Font.GothamBold
	label.TextColor3=Color3.fromRGB(255,240,220)
	label.Parent=panel
	local can=cylinder(mount,frame,true)
	local pickup=Instance.new("ProximityPrompt")
	pickup.ObjectText,pickup.ActionText="Wall extinguisher","Equip / refill"
	pickup.RequiresLineOfSight=false
	pickup.MaxActivationDistance,pickup.HoldDuration=7,.18
	pickup:SetAttribute("Action","Extinguisher")
	pickup.Parent=can
	mount.Parent=stations
	return mount
end

function Rack.makeTool()
	local tool=Instance.new("Tool")
	tool.Name,tool.ToolTip,tool.CanBeDropped="Fire Extinguisher","Aim at the crawler and discharge foam",false
	tool.Grip=CFrame.new(0,-.34,0)*CFrame.Angles(0,0,-math.pi/2)
	cylinder(tool,CFrame.identity,false)
	return tool
end

return Rack
