local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local random={}
local roll=0
function random:NextNumber(lo,hi)
	roll+=1
	return if math.floor((roll-1)/2)%2==0 then lo else hi
end
local repairs=luau.load(fs.readFile("src/ServerScriptService/DiveBreach.luau"),{
	injectGlobals=true,
	environment={
		Random={new=function() return random end},
		Vector2=roblox.Vector2,
		game={GetService=function() return {GenerateGUID=function() return "challenge" end} end},
		workspace={GetServerTimeNow=function() return 100 end},
	},
})()
for _,difficulty in {"Easy","Normal","Hard","Nightmare"} do
	local hull=repairs.newChallenge(difficulty,1)
	local engine=repairs.newChallenge(difficulty,2,"Thruster")
	assert(hull.kind==nil and engine.kind=="Thruster" and engine.section==2)
	assert(#hull.targets==#engine.targets and hull.window==engine.window)
	local gap=engine.targets[2].at-engine.targets[1].at
	local oldGap=hull.targets[2].at-hull.targets[1].at
	assert(math.abs(gap-oldGap*.83)<.001)
	local first=engine.targets[1].at
	assert(repairs.hit(engine,{id=engine.id,index=2,time=first},first,.08)=="Ignore")
	assert(repairs.hit(engine,{id=engine.id,index=1,time=first},first-engine.window,.08)=="Ignore")
	assert(repairs.hit(engine,{id=engine.id,index=1,time=first-engine.window-.02},first-engine.window-.02,.08)=="Miss")
	for i,target in engine.targets do
		local expected=if i==#engine.targets then "Complete" else "Hit"
		assert(repairs.hit(engine,{id=engine.id,index=i,time=target.at},target.at,.08)==expected)
	end
end
print("PASS: faster thruster circles, original hull pacing, timed validation and completion")
