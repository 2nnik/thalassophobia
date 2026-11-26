local Intercom={}
Intercom.__index=Intercom

local calls={
	{depth=0,id="91294398637751",label="OPENING"},
	{depth=500,id="97627395015655",label="500 M"},
	{depth=3000,id="95418885953543",label="3,000 M"},
}
local metal=Color3.fromRGB(27,51,55)
local amber=Color3.fromRGB(242,164,76)
local green=Color3.fromRGB(103,233,181)

function Intercom.start(site)
	local holder=Instance.new("Model")
	holder.Name="Surface Security intercom"
	local hull=site.HullMotion
	local origin=hull.CFrame*CFrame.new(-7.5,-.23,-20.64)
	local function part(name,size,offset,color,material)
		local p=Instance.new("Part")
		p.Name,p.Size,p.CFrame,p.Color=name,size,origin*CFrame.new(offset),color
		p.Material=material or Enum.Material.Metal
		p.CanCollide,p.CanTouch,p.Massless=false,false,true
		p.Parent=holder
		local weld=Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent=hull,p,p
		return p
	end
	local cabinet=part("Cabinet",Vector3.new(3.2,2,.37),Vector3.zero,metal)
	part("Speaker grille",Vector3.new(1.05,1.4,.10),Vector3.new(-.91,0,.24),Color3.fromRGB(10,21,26))
	for i=-3,3 do
		part("Grille slot",Vector3.new(.86,.045,.035),Vector3.new(-.91,i*.16,.30),metal)
	end
	local panel=part("Status screen",Vector3.new(1.58,.88,.12),Vector3.new(.61,.24,.24),Color3.fromRGB(7,22,25))
	local lamp=part("Call lamp",Vector3.new(.14,.14,.12),Vector3.new(1.25,-.53,.26),metal)
	part("Answer switch",Vector3.new(.65,.32,.19),Vector3.new(.48,-.54,.26),Color3.fromRGB(146,91,42))
	local gui=Instance.new("SurfaceGui")
	gui.Face,gui.CanvasSize,gui.LightInfluence=Enum.NormalId.Back,Vector2.new(250,132),0
	gui.Parent=panel
	local display=Instance.new("TextLabel")
	display.Size,display.BackgroundTransparency=UDim2.fromScale(1,1),1
	display.Font,display.TextSize,display.TextColor3=Enum.Font.Code,29,green
	display.Text,display.Parent="SURFACE SECURITY\nSTANDBY",gui
	local prompt=Instance.new("ProximityPrompt")
	prompt.Style=Enum.ProximityPromptStyle.Custom
	prompt.ActionText,prompt.ObjectText="Answer call","Surface Security"
	prompt.KeyboardKeyCode=Enum.KeyCode.E
	prompt.RequiresLineOfSight,prompt.MaxActivationDistance=false,9
	prompt:SetAttribute("Action","SecurityIntercom")
	prompt.Enabled,prompt.Parent=false,cabinet

	local voice=Instance.new("Sound")
	voice.Name,voice.Volume="Mercer",1.15
	voice.RollOffMode,voice.RollOffMinDistance,voice.RollOffMaxDistance=Enum.RollOffMode.Linear,16,60
	voice.Parent=cabinet
	for _,call in calls do
		local clip=Instance.new("Sound")
		clip.Name,clip.SoundId,clip.Parent=call.label,"rbxassetid://"..call.id,voice
	end
	local ring=Instance.new("Sound")
	ring.Name,ring.SoundId,ring.Volume="Call chime","rbxasset://sounds/electronicpingshort.wav",.5
	ring.RollOffMode,ring.RollOffMinDistance,ring.RollOffMaxDistance=Enum.RollOffMode.Linear,12,37
	ring.Parent=cabinet
	holder.Parent=site.Stations
	local self=setmetatable({holder=holder,voice=voice,ring=ring,display=display,lamp=lamp,
		prompt=prompt,nextCall=2,queue={}},Intercom)
	voice.Ended:Connect(function() self:complete() end)
	task.spawn(function()
		pcall(game:GetService("ContentProvider").PreloadAsync,game:GetService("ContentProvider"),voice:GetChildren())
	end)
	return self
end

function Intercom:refresh()
	local pending=if not self.playing then self.queue[1] else nil
	local state=if self.playing then "MERCER • "..self.playing.label elseif pending then "CALL • "..pending.label else "STANDBY"
	self.display.Text="SURFACE SECURITY\n"..state
	self.display.TextColor3=if pending then amber else green
	self.lamp.Color=if pending then amber elseif self.playing then green else metal
	self.lamp.Material=if pending or self.playing then Enum.Material.Neon else Enum.Material.Metal
	self.prompt.Enabled=pending~=nil
end

function Intercom:play(call)
	self.playing=call
	self.ring:Stop()
	self:refresh()
	self.voice.SoundId="rbxassetid://"..call.id
	self.voice:Play()
	-- Recover the answer button if a recording is unavailable on this server.
	task.delay(65,function()
		if self.holder.Parent and self.playing==call then
			self.voice:Stop()
			self:complete()
		end
	end)
end

function Intercom:complete()
	self.playing=nil
	self:refresh()
	if self.queue[1] then self.ring:Play() end
end

function Intercom:wake()
	if self.awake then return end
	self.awake=true
	self:play(calls[1])
end

function Intercom:update(depth)
	local queued=false
	while calls[self.nextCall] and depth>=calls[self.nextCall].depth do
		local idle=not self.playing and #self.queue==0
		table.insert(self.queue,calls[self.nextCall])
		self.nextCall+=1
		queued=true
		if idle then self.ring:Play() end
	end
	if queued then self:refresh() end
end

function Intercom:answer()
	if self.playing or not self.queue[1] then return end
	self:play(table.remove(self.queue,1))
end

function Intercom:destroy()
	self.holder:Destroy()
end

return Intercom
