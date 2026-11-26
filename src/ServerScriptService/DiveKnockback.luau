local Knockback={}
Knockback.__index=Knockback

local quietSeconds=12
local firstRam={Easy=15,Normal=14,Hard=13,Nightmare=12}
local repeatRam={Easy=12,Normal=11,Hard=10,Nightmare=9}
local otherThreats={"shark","squid","crawler","swarm","shoal","fault","pursuer"}

function Knockback.new(rng)
	rng=rng or Random.new()
	local depth=if rng:NextNumber()<.40 then rng:NextNumber(4100,4650) else nil
	return setmetatable({depth=depth,stage="Idle"},Knockback)
end

function Knockback:update(s,parasite)
	local now=s.elapsed
	if s.jellyBloom or s.phase=="Results" then return end
	if self.stage=="Idle" then
		if not self.depth or s.phase~="Descent" or s.depth<self.depth then return end
		if s.depth>5250 then self.depth=nil; return end
		if not s.sonarOn or s.systemsOffline or s.boarded then return end
		for _,name in otherThreats do
			if (s[name] or 0)>0 then return end
		end
		if parasite and parasite:isBusy() then return end
		self.depth=nil
		self.stage,self.charges,self.lastPulse="Stalking",0,now-3.2
		self.quietUntil=now+quietSeconds
		s.knockbackActive=true
	elseif self.stage=="Stalking" and now>=self.quietUntil then
		self.stage,s.knockbackActive="Done",nil
	elseif self.stage=="Damaged" and now>=self.nextRam then
		self.rams+=1
		self.nextRam=now+(repeatRam[s.difficulty] or repeatRam.Normal)
		return if self.rams==1 then "FirstRam" else "Ram"
	elseif self.stage=="Retreat" and now>=self.clearAt then
		self.stage,s.knockbackActive="Reset",nil
		return "Clear"
	end
end

function Knockback:pulse(s)
	if self.stage~="Stalking" or s.jellyBloom then return end
	local now=s.elapsed
	-- Turning the console off and back on makes a real pulse. Limit lure gain
	-- to one per normal sweep so cycling cannot rush the warning sequence.
	self.quietUntil=now+quietSeconds
	if now-self.lastPulse<2.9 then return end
	self.lastPulse=now
	self.charges+=1
	if self.charges<4 then return "Knock",self.charges end
	self.stage,self.rams="Damaged",0
	self.nextRam=now+(firstRam[s.difficulty] or firstRam.Normal)
	s.knockbackSonar="Damaged"
	s.sonarOn,s.echoes,s.pingAt,s.nextPing=false,nil,nil,0
	return "Strike"
end

function Knockback:breaker(s)
	if self.stage=="Damaged" then
		self.stage,self.clearAt="Retreat",s.elapsed+3
		s.knockbackSonar="Isolated"
		return "Isolate"
	elseif self.stage=="Reset" then
		self.stage,s.knockbackSonar="Done",nil
		return "Reset"
	end
end

return Knockback
