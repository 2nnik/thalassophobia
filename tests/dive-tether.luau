local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local V,C=roblox.Vector3,roblox.CFrame
local external=luau.load(fs.readFile("src/ServerScriptService/DiveExterior.luau"),{
	injectGlobals=true,
	environment={Random={new=function() return {} end},Vector3=V,CFrame=C},
})()

local anchor={Position=V.zero,IsA=function(_,class) return class=="BasePart" end}
external.init({FindFirstChild=function() return anchor end},{})
local fields={CFrame=C.new(70,0,0),Parent=true,AssemblyLinearVelocity=V.new(13,0,4)}
local root=setmetatable(fields,{__index=function(t,k) if k=="Position" then return t.CFrame.Position end end})
local swim={root=root,radius=external.TETHER_LENGTH,direction=V.xAxis,look=V.xAxis,heading=V.xAxis,
	velocity={},orientation={}}
local diver={swim=swim,outside=true}
external.followShip(diver,V.zero)
assert(math.abs(root.Position.Magnitude-58)<.001,"the lifeline corrects overshoot even when the ship is stopped")
assert(root.AssemblyLinearVelocity==V.new(0,0,4),"radial velocity is removed without cancelling a sideways stroke")

anchor.Position=V.new(-10,-5,0)
external.followShip(diver,V.new(0,-5,0))
assert(math.abs((root.Position-anchor.Position).Magnitude-58)<.001,"range follows the moving ship anchor")
local out={}
external.snapshot({},diver,{},out)
assert(out.tetherRange==58 and out.tetherUsed<=58 and out.tetherUsed>57)

diver.cleaning={}
local old=root.Position
external.followShip(diver,V.new(0,-1,0))
assert(root.Position==old+V.new(0,-1,0),"a diver braced on a barnacle patch rides the hull")
print("PASS: hard lifeline limit, moving anchor, tangential swim and hull bracing")
