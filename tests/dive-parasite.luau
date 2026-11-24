local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local clock=0
local random={NextNumber=function(_,lo,hi) return if lo then (lo+hi)/2 else .1 end}
local parasite=luau.load(fs.readFile("src/ServerScriptService/DiveParasite.luau"),{
	injectGlobals=true,environment={Color3=roblox.Color3,CFrame=roblox.CFrame,Random={new=function() return random end},
		workspace={GetServerTimeNow=function() return clock end}},
})()
local root={}
local hum={Health=100}
local p={Parent=true,Character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return hum end}}
local events={}
local remote={FireClient=function(_,_,event,...) table.insert(events,{event,...}) end}
local session=parasite.start({p},"Hard",{},remote)
local member=session.crew[p]
assert(session.rules[1]==7)
local function yes() return true end
local function no() return false end
session:step(10,5999,yes,yes)
session:step(10,6000,no,yes)
assert(member.roll==6)
local latches=0
session.latch=function(_,_,m,_,now)
	latches+=1
	m.sequence,m.index,m.deadline,m.started="XE",1,now+7,now
end
session:step(6,6000,yes,yes)
assert(latches==1)
session:input(p,"Key","B")
assert(member.index==1 and events[#events][2]==1)
session:input(p,"Key","X")
assert(member.index==2 and events[#events][2]==2)
clock=3
session:input(p,"Key","E")
assert(not member.sequence and not member.hatch and events[#events][1]=="LatchEnd")
session:latch(p,member,root,clock)
clock=6.01
session:input(p,"Key","X")
session:input(p,"Key","E")
assert(member.hatch==clock+90 and events[#events][1]=="LatchEnd")
session:step(1,6000,yes,no)
assert(not member.hatch)
session:latch(p,member,root,clock)
clock+=8
session:input(p,"Key","X")
assert(member.index==1)
session:destroy()
assert(next(session.crew)==nil)
print("Pressure parasite depth, timing, private incubation and cleanup passed")
