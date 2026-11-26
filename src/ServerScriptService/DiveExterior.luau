-- Exterior motion, diver restraint and shared hull-cleaning progress are owned by the server.
local Exterior = {}
local site, feed
local random = Random.new()
local TOTAL_SITES = 4
local CUTS = 3
local SWIM_SPEED = 13
Exterior.TETHER_LENGTH = 58
local nextId = 0

function Exterior.init(world, remote)
	site, feed = world, remote
end

local function notify(p, message)
	if p.Parent then feed:FireClient(p, "Notice", message) end
end

local function anchorPosition()
	local anchor = site:FindFirstChild("TetherAnchor", true)
	if anchor and anchor:IsA("Attachment") then return anchor.WorldPosition end
	if anchor and anchor:IsA("BasePart") then return anchor.Position end
	return site.OutsideSpawn.Position
end

local function claim(root)
	if root and root.Parent and not root.Anchored then
		local canSet = root:CanSetNetworkOwnership()
		if canSet then root:SetNetworkOwner(nil) end
	end
end

local function finite(v)
	return typeof(v) == "Vector3" and v.Magnitude < 1e5
end

local function limitVector(v)
	return v.Magnitude > 1 and v.Unit or v
end

local function braced(m)
	return m.cleaning or (m.breachRepair and m.breachRepair.kind=="Thruster")
end

local function setMotion(m)
	local swim = m.swim
	if not swim or not swim.root.Parent or braced(m) then return end
	local position = swim.root.Position
	local offset = position - swim.anchor
	local direction = swim.direction
	local distance = offset.Magnitude
	if distance > swim.radius - 5 then
		local normal = offset.Unit
		local outward = direction:Dot(normal)
		local tension=math.clamp((distance-(swim.radius-5))/5,0,1)
		if outward > 0 then direction -= normal * outward * tension end
		if distance > swim.radius then
			direction -= normal * math.min(1, (distance-swim.radius)*0.3)
		end
	end
	swim.velocity.VectorVelocity = limitVector(direction) * SWIM_SPEED
	local facing = swim.look
	local forward = Vector3.new(facing.X, 0, facing.Z)
	if forward.Magnitude > 0.01 then swim.heading = forward.Unit end
	local pitch = math.clamp(math.asin(math.clamp(facing.Y,-1,1)), -1.2, 1.2)
	local tilt = -0.63 * math.min(1, direction.Magnitude)
	swim.orientation.CFrame = CFrame.lookAt(Vector3.zero,swim.heading) * CFrame.Angles(pitch + tilt,0,0)
end

function Exterior.releaseBrace(m)
	local swim = m.swim
	if not swim or not swim.root.Parent then return end
	swim.root.Anchored = swim.wasAnchored
	swim.direction = Vector3.zero
	swim.velocity.VectorVelocity = Vector3.zero
	claim(swim.root)
end

function Exterior.brace(m)
	local swim=m.swim
	if not swim or not swim.root.Parent then return false end
	local root=swim.root
	swim.direction=Vector3.zero
	swim.velocity.VectorVelocity=Vector3.zero
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	root.Anchored=true
	return true
end

local function releaseGrip(m)
	m.cleaning=nil
	Exterior.releaseBrace(m)
end

function Exterior.stopSwim(p,m)
	if not m then return end
	local swim = m.swim
	if not swim then m.cleaning = nil return end
	if m.cleaning then releaseGrip(m) end
	m.swim = nil
	if swim.track then pcall(function() swim.track:Stop(0.16) swim.track:Destroy() end) end
	if swim.animation then swim.animation:Destroy() end
	swim.velocity:Destroy()
	swim.orientation:Destroy()
	swim.mount:Destroy()
	local root,h = swim.root,swim.humanoid
	if root.Parent then
		root.Anchored = swim.wasAnchored
		root.CanCollide = swim.originalCollide
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if not root.Anchored and root:CanSetNetworkOwnership() then root:SetNetworkOwnershipAuto() end
	end
	if h.Parent then
		h.WalkSpeed = swim.speed
		h.AutoRotate = swim.autoRotate
		h.EvaluateStateMachine = swim.stateMachine
		if h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end
end

function Exterior.startSwim(p,m,s)
	if m.swim then Exterior.stopSwim(p,m) end
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health <= 0 then return false end
	local anchor = anchorPosition()
	local swim = {root=root, humanoid=h, wasAnchored=root.Anchored, originalCollide=root.CanCollide,
		speed=h.WalkSpeed, autoRotate=h.AutoRotate, stateMachine=h.EvaluateStateMachine,
		anchor=anchor, radius=Exterior.TETHER_LENGTH, direction=Vector3.zero, look=root.CFrame.LookVector,
		heading=Vector3.new(0,0,-1), lastPacket=0, lastInput=0}
	m.swim = swim
	claim(root)
	h.WalkSpeed = 0
	h.AutoRotate = false
	h.EvaluateStateMachine = false
	h:ChangeState(Enum.HumanoidStateType.Physics)
	root.CanCollide = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local mount = Instance.new("Attachment")
	mount.Name = "DiverBuoyancy"
	mount.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SwimVelocity"
	velocity.Attachment0 = mount
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = math.max(6000,root.AssemblyMass*(workspace.Gravity+200))
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "SwimAttitude"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = mount
	orientation.MaxTorque = 1e6
	orientation.Responsiveness = 12
	orientation.CFrame = root.CFrame.Rotation
	orientation.Parent = root
	swim.mount, swim.velocity, swim.orientation = mount,velocity,orientation
	-- Use the avatar's configured swimming animation when its Animate script supplies one.
	local animate = character:FindFirstChild("Animate")
	local source = animate and animate:FindFirstChild("swim")
	local clip = source and source:FindFirstChildWhichIsA("Animation",true)
	if not clip and h.RigType == Enum.HumanoidRigType.R15 then
		-- Stock Roblox R15 swimming stroke for avatars without a locomotion override.
		clip = Instance.new("Animation")
		clip.AnimationId = "rbxassetid://507784897"
		swim.animation = clip
	end
	local animator = h:FindFirstChildOfClass("Animator")
	if animator and clip then
		local ok,track=pcall(function() return animator:LoadAnimation(clip) end)
		if ok then
			swim.track=track
			track.Looped=true
			track.Priority=Enum.AnimationPriority.Action
			track:Play(.25,1,.55)
		end
	end
	return true
end

local function getPatch(index)
	local folder = site:FindFirstChild("BarnacleSites")
	local model = folder and folder:FindFirstChild("Site"..index)
	return model, model and (model.PrimaryPart or model:FindFirstChild("Target"))
end

local function colonized(s,index)
	local cuts=s.cleanSites and s.cleanSites[index]
	return cuts~=nil and cuts>=0 and cuts<CUTS
end

local function needleAngle(c,time)
	return (c.startAngle+c.sign*(time-c.started)/c.period*360)%360
end

local function issueChallenge(s,m,index,label,feedback,previous,now)
	nextId += 1
	local difficulty = s.difficulty
	local period = difficulty=="Nightmare" and 1.6 or difficulty=="Hard" and 1.77 or difficulty=="Easy" and 2.42 or 2.08
	local arc = difficulty=="Nightmare" and 43 or difficulty=="Hard" and 51 or difficulty=="Easy" and 78 or 64
	local sign = if previous then -previous.sign elseif random:NextInteger(0,1)==0 then 1 else -1
	local started = now or (workspace:GetServerTimeNow()+.14)
	local startAngle = if previous then needleAngle(previous,started) else random:NextInteger(0,359)
	m.cleaning = {
		id=nextId,index=index,label=label,feedback=feedback or "",
		started=started,
		center=(startAngle + sign*random:NextInteger(96,265))%360,
		startAngle=startAngle, sign=sign, period=period, arc=arc
	}
end

function Exterior.beginClean(p,m,s,index)
	if not m or not m.outside or not m.alive or not m.swim or braced(m) or s.swarm<=0 then return false end
	if type(index)~="number" or index%1~=0 or index<1 or index>TOTAL_SITES then return false end
	if not colonized(s,index) then return false end
	local model,target=getPatch(index)
	local root=m.swim.root
	if not target or not root.Parent or (root.Position-target.Position).Magnitude>9.75 then return false end
	local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true)
	if not prompt or not prompt.Enabled then return false end
	if not Exterior.brace(m) then return false end
	issueChallenge(s,m,index,model:GetAttribute("Label") or model.Name)
	return true
end

local function strike(p,m,s,arg)
	local c=m.cleaning
	if not c or typeof(arg)~="table" or arg.id~=c.id or not m.swim then return end
	if s.swarm<=0 or not colonized(s,c.index) then releaseGrip(m) return end
	local _,target=getPatch(c.index)
	if not target or (m.swim.root.Position-target.Position).Magnitude>10 then releaseGrip(m) return end
	local now=workspace:GetServerTimeNow()
	local time=arg.time
	if typeof(time)~="number" or time~=time or time<c.started or time>now+0.10 then return end
	local allowance=math.clamp(p:GetNetworkPing()+0.115,0.14,0.38)
	if time<now-allowance or now<c.started then return end
	local angle=needleAngle(c,time)
	local errorAngle=math.abs((angle-c.center+180)%360-180)
	if errorAngle>c.arc/2 then
		issueChallenge(s,m,c.index,c.label,"MISSED",c,now)
		return
	end
	s.cleanSites[c.index]=math.min(CUTS,s.cleanSites[c.index]+1)
	local cleared=s.cleanSites[c.index]==CUTS
	if p.Parent then feed:FireClient(p,"CleanFeedback",if cleared then "Cleared" else "Cut") end
	if not cleared then
		issueChallenge(s,m,c.index,c.label,"GOOD CUT",c,now)
		return
	end
	releaseGrip(m)
	local remaining=0
	for i=1,TOTAL_SITES do if colonized(s,i) then remaining+=1 end end
	if remaining==0 then
		s.swarm,s.foulingCandidates=0,nil
		s.nextFoulingAt=s.elapsed+18
		s.warning="Hull clear. All growth removed."
		s.warningUntil=s.elapsed+5
	else
		notify(p,c.label.." cleared. "..remaining.." active hull patches left.")
	end
end

function Exterior.input(p,m,s,action,arg)
	if action~="SwimMove" and action~="CleanStrike" and action~="CleanCancel" then return false end
	if not m or not s or not m.alive or not m.outside or not m.swim then return true end
	if action=="CleanCancel" then
		if m.cleaning then releaseGrip(m) end
	elseif action=="CleanStrike" then
		strike(p,m,s,arg)
	elseif not braced(m) and typeof(arg)=="table" and finite(arg.direction) and finite(arg.look) then
		local swim=m.swim
		local now=os.clock()
		if now-swim.lastPacket >= 0.07 then
			swim.lastPacket,swim.lastInput=now,now
			swim.direction=limitVector(arg.direction)
			if arg.look.Magnitude>0.3 then swim.look=arg.look.Unit end
			setMotion(m)
		end
	end
	return true
end

function Exterior.tick(p,m,s,dt)
	local swim=m.swim
	if not swim or not swim.root.Parent then return end
	if braced(m) then
		if m.cleaning and (s.swarm<=0 or not colonized(s,m.cleaning.index)) then releaseGrip(m) end
		return
	end
	if os.clock()-swim.lastInput>0.6 then swim.direction=Vector3.zero end
	if swim.track then swim.track:AdjustSpeed(0.42 + 0.55*swim.direction.Magnitude) end
	setMotion(m)
end

function Exterior.snapshot(p,m,s,out)
	out.cleanSites=s.cleanSites
	if m.outside then
		out.cleaning=m.cleaning
		out.tetherRange=m.swim and m.swim.radius
		local swim=m.swim
		if swim and swim.root.Parent then
			out.tetherUsed=math.min(swim.radius, (swim.root.Position-swim.anchor).Magnitude)
		end
	end
end

function Exterior.followShip(m,delta)
	local swim=m.swim
	if not swim or not swim.root.Parent then return end
	swim.anchor=anchorPosition()
	-- A diver holding the hull travels with it. Free swimmers keep their
	-- position in the water until they move or the lifeline pulls them.
	if braced(m) then
		if delta.Y~=0 then swim.root.CFrame+=delta end
		return
	end
	local root=swim.root
	local offset=root.Position-swim.anchor
	local distance=offset.Magnitude
	if distance<=swim.radius then return end
	local normal=offset.Unit
	root.CFrame+=normal*(swim.radius-distance)
	local velocity=root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity=velocity-normal*math.max(0,velocity:Dot(normal))
	setMotion(m)
end

return Exterior
