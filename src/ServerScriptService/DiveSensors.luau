-- Radar samples actual objects at each acoustic pulse. The client draws the last return.
local Sensors = {}
local RANGE = 315
local INTERVAL = 3.2
local site = workspace:WaitForChild("Thalassa")
local rocks = {}
for _,part in site.Ocean["Trench floor"]:GetChildren() do
	if part:IsA("BasePart") and part.Name == "Basalt outcrop" then table.insert(rocks,part) end
end
local targets = {
	{"Leviathan", "A", "ANGLER", "shark"},
	{"GiantSquid", "S", "SQUID", "squid"},
	{"CrackCrawler", "W", "WORMS", "crawler"},
	{"Pursuer", "P", "PURSUER", "pursuer"},
}
function Sensors.pulse(s, crew)
	if not s.sonarOn or s.knockbackSonar then s.echoes=nil return end
	if s.echoes and s.elapsed < s.nextPing then return end
	s.nextPing = s.elapsed + INTERVAL
	local center = site.ShipEnvelope.Position
	local echoes = {}
	local function echo(pos,kind,code,label,status)
		local delta = pos-center
		if delta.Magnitude>RANGE then return end
		table.insert(echoes,{x=math.round(delta.X),z=math.round(delta.Z),y=math.round(delta.Y),
			dist=math.round(delta.Magnitude),kind=kind,code=code,label=label,status=status})
	end
	for _,t in targets do
		local model=site.Contacts:FindFirstChild(t[1])
		if model and model:GetAttribute("Detectable") then
			local status = s[t[4]] > 0 and "APPROACH" or "ROAMING"
			if t[1]=="CrackCrawler" then status=s.boarded and "INSIDE" or "ON HULL" end
			echo(model:GetPivot().Position,"animal",t[2],t[3],status)
		end
	end
	for p,m in crew do
		if m.alive and m.outside and p.Character then echo(p.Character:GetPivot().Position,"diver","+","DIVER","EVA") end
	end
	if s.swarm>0 and s.cleanSites then
		for i=1,4 do
			local patch=site.BarnacleSites:FindFirstChild("Site"..i)
			if patch and patch.PrimaryPart and (s.cleanSites[i] or 0)<3 then
				echo(patch.PrimaryPart.Position,"patch","•",patch:GetAttribute("Label") or "HULL","FOULING")
			end
		end
	end
	for i=1,#rocks,3 do echo(rocks[i].Position,"terrain","","BASALT","") end
	s.echoes=echoes
	s.pingAt=workspace:GetServerTimeNow()
	return true
end
Sensors.range = RANGE
return Sensors
