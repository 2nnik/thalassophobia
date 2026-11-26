local Bloom={}
Bloom.__index=Bloom

local CHANCE=.34
local DISTANCE=460
local MAX_SECONDS=85
local QUIET_APPROACH=1050
local threats={"shark","squid","crawler","swarm","shoal","fault"}

function Bloom.new(rng)
	rng=rng or Random.new()
	local start=if rng:NextNumber()<CHANCE then rng:NextNumber(3400,8200) else nil
	return setmetatable({start=start},Bloom)
end

function Bloom:update(s,parasite)
	if s.jellyBloom then
		if s.depth>=self.finish or s.elapsed>=self.timeout or s.phase~="Descent" then
			s.jellyBloom=nil
		end
		return
	end
	if not self.start or s.phase~="Descent" or s.depth<self.start then return end
	if s.depth>self.start+QUIET_APPROACH then
		self.start=nil
		return
	end
	if not s.engine or s.boarded then return end
	for _,name in threats do
		if (s[name] or 0)>0 then return end
	end
	if parasite and parasite:isBusy() then return end
	self.start=nil
	s.jellyBloom=s.depth
	self.finish,self.timeout=s.depth+DISTANCE,s.elapsed+MAX_SECONDS
end

return Bloom
