local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local clock=100
local random={
	NextInteger=function(_,a,b) return math.floor((a+b)/2) end,
}
local exterior=luau.load(fs.readFile("src/ServerScriptService/DiveExterior.luau"),{
	injectGlobals=true,
	environment={Random={new=function() return random end},Vector3=roblox.Vector3,
		workspace={GetServerTimeNow=function() return clock end}},
})()
local zero=roblox.Vector3.zero
local root={Position=zero,Parent=true,CanSetNetworkOwnership=function() return false end}
local target={Position=zero,FindFirstChildWhichIsA=function() return {Enabled=true} end}
local model={Name="Site1",PrimaryPart=target,GetAttribute=function() return "Bow patch" end}
local events={}
exterior.init({FindFirstChild=function()
	return {FindFirstChild=function() return model end}
end},{FireClient=function(_,_,name,payload) table.insert(events,{name,payload}) end})
local p={Parent=true,GetNetworkPing=function() return .08 end}
local m={alive=true,outside=true,swim={root=root,velocity={},wasAnchored=false}}
local s={difficulty="Normal",swarm=.1,elapsed=0}
assert(exterior.beginClean(p,m,s,1))
local function angle(c,t)
	return (c.startAngle+c.sign*math.max(0,t-c.started)*360/c.period)%360
end
local function strike(good)
	local c=m.cleaning
	local at=(c.center-c.startAngle)*c.sign
	if not good then at+=180 end
	local pressedAt=c.started+(at%360)*c.period/360
	clock=pressedAt+.07
	exterior.input(p,m,s,"CleanStrike",{id=c.id,time=pressedAt})
	return c
end
local first=strike(false)
local second=m.cleaning
assert(second.feedback=="MISSED" and second.sign==-first.sign)
assert(math.abs((angle(second,clock)-angle(first,clock)+180)%360-180)<1e-6,"reversal cannot jump the needle")
assert(#events==0 and s.cleanSites[1]==0,"a miss must not sound like a cut")
first=strike(true)
second=m.cleaning
assert(second.sign==-first.sign and s.cleanSites[1]==1 and second.feedback=="GOOD CUT")
assert(math.abs((angle(second,clock)-angle(first,clock)+180)%360-180)<1e-6)
assert(events[1][1]=="CleanFeedback" and events[1][2]=="Cut")
strike(true)
strike(true)
assert(not m.cleaning and s.cleanSites[1]==3 and not root.Anchored)
assert(events[3][1]=="CleanFeedback" and events[3][2]=="Cleared","the final cut needs its own sound")
print("PASS: barnacle cutter reverses in place and confirms only accepted cuts")
