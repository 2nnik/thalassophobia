-- From the repository: lune run tests/voyage.luau
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local roblox = require('@lune/roblox')
local path = 'src/ServerScriptService/Voyage.luau'
assert(fs.isFile(path), 'authoritative voyage module missing')
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local Voyage = luau.load(fs.readFile(path), {environment={Vector3=Vector3, CFrame=CFrame}, injectGlobals=true})()
local function new(difficulty, crew, traits)
    local sim = Voyage.new(difficulty or 'Normal', crew or 1, traits or {}, CFrame.new(40, 30, -70) * CFrame.Angles(0, 0.33, 0))
    local now = 4000
    local function advance(seconds, diver)
        for _=1, math.round(seconds * 10) do
            now += 0.1
            sim:step(0.1, now, diver)
        end
        return sim:snapshot()
    end
    local function act(name, payload)
        return sim:action(name, payload or {}, now)
    end
    return sim, advance, act
end

local sim, advance, act = new('Easy')
assert(sim.phase == 'Descent' and not act('Recover'))
assert(act('Engine', {enabled=true}))
advance(4)
assert(sim.depth > 0 and sim.speed > 0)
assert(act('Engine', {enabled=false}))
local coastStart = sim.depth
advance(2)
assert(sim.depth > coastStart and sim.speed > 0)
advance(10)
assert(sim.speed == 0)
assert(act('Engine', {enabled=true}))
local contacts = {}
local function operate()
    local s = sim:snapshot()
    if s.actors.Angler.state == 'Approach' then act('Engine', {enabled=false}) else act('Engine', {enabled=true}) end
    local squid = s.actors.Squid
    if squid.state == 'Approach' then
        local target = sim.shipCFrame:PointToObjectSpace(squid.pose.Position)
        act('Aim', {bearing=math.deg(math.atan2(target.X, -target.Z)),pitch=math.deg(math.asin(target.Y/target.Magnitude))})
        act('Searchlight', {enabled=true})
    else act('Searchlight', {enabled=false}) end
    for site, crack in pairs(s.fractures) do
        if crack > 0 then act('Repair',{site=site}) end
    end
    if s.actors.Crawler.state == 'Boarded' then
        act('Collect', {userId=17})
        act('Spray', {room=s.actors.Crawler.room,userId=17})
    end
    for site, patch in pairs(s.patches) do
        if patch.active then
            contacts[site] = true
            assert(sim:cut(site))
        end
    end
end
for _=1,400 do
    operate()
    advance(0.5)
    if sim.phase == 'Seabed' then break end
end
assert(sim.phase == 'Seabed' and sim.depth == 600, sim.reason or sim.phase)
assert(act('Recover') and not act('Recover'))
assert(sim.phase == 'Ascent' and sim.artifact)
for _=1,500 do
    operate()
    advance(0.5)
    if sim.phase == 'Results' then break end
end
assert(sim.survived and sim.depth == 0, sim.reason or sim.phase)
for _, site in ipairs({'Port','Starboard','Stern','Keel'}) do assert(contacts[site],site) end
assert(not act('Engine',{enabled=true}))
local sonar, ping, toggle = new()
assert(toggle('Sonar',{enabled=true}))
local diver = sonar.shipCFrame:PointToWorldSpace(Vector3.new(20,0,0))
local snapshot = ping(3, diver)
assert(snapshot.returns.Diver and math.abs(snapshot.returns.Diver.range-20) < 0.01)
assert(math.abs(snapshot.returns.Diver.bearing - 90)<0.01)
assert((snapshot.returns.Angler.position - snapshot.returns.Angler.pose.Position).Magnitude < 0.01)
assert(toggle('Sonar',{enabled=false}))
assert(next(sonar:snapshot().returns)==nil)
print('PASS solo surface, shared patches, recover idempotency, shutdown coast, true sonar bearings')

-- Stage the next random event without skipping the approach, prompt, counter, damage or exit logic.
local function isolate(simulation)
    for id in pairs(simulation.timers) do simulation.timers[id]=1e5 end
end
local function nextContact(simulation,advanceTime,id)
    simulation.timers[id]=0
    advanceTime(.1)
    return simulation.actors[id]
end
local confrontation, run, station=new('Normal',4)
isolate(confrontation)
station('Engine',{enabled=true})
run(74)
assert(confrontation.phase=='Seabed' and station('Recover'))
run(4)
local angler=nextContact(confrontation,run,'Angler')
assert(angler.state=='Approach')
local gap,hull,depth=confrontation.pursuerGap,confrontation.hull,confrontation.depth
station('Engine',{enabled=false})
run(2.7)
assert(angler.state=='Passing' and confrontation.hull==hull and confrontation.depth<depth)
assert(confrontation.pursuerGap>=gap, 'shutdown coast should give angler a safe response window')
run(65)
assert(confrontation.phase=='Results' and confrontation.reason=='Pursuer' and not confrontation.survived)
local failed,wait,operateFailed=new('Normal',4)
isolate(failed)
operateFailed('Engine',{enabled=true})
nextContact(failed,wait,'Angler')
wait(15)
assert(failed.hull<80 and failed.actors.Angler.state=='Passing')
local squid,slide,turn=new()
isolate(squid)
local contact=nextContact(squid,slide,'Squid')
local function aimAt(direction)
    turn('Aim',{bearing=math.deg(math.atan2(direction.X,-direction.Z)),pitch=math.deg(math.asin(direction.Y/direction.Magnitude))})
end
local toSquid=squid.shipCFrame:PointToObjectSpace(contact.pose.Position)
aimAt(-toSquid)
turn('Searchlight',{enabled=true})
slide(3)
assert(contact.state=='Approach')
aimAt(squid.shipCFrame:PointToObjectSpace(contact.pose.Position))
slide(2.3)
assert(contact.state=='Passing' and squid.hull==100)
local habitat,seconds,tool=new()
isolate(habitat)
local crawler=nextContact(habitat,seconds,'Crawler')
local site=crawler.site
assert(crawler.state=='Attached' and (crawler.pose.Position-habitat.sites[site]).Magnitude<0.001)
assert(tool('Repair',{site=site}))
seconds(2.3)
assert(crawler.state=='Dormant' and habitat.fractures[site]==0)
crawler=nextContact(habitat,seconds,'Crawler')
seconds(30)
assert(crawler.state=='Boarded')
assert(tool('Collect',{userId=1}) and not tool('Collect',{userId=2}))
assert(not tool('Spray',{userId=2,room=crawler.room}) and not tool('Spray',{userId=1,room='Bridge'}))
assert(tool('Spray',{userId=1,room=crawler.room}) and habitat.charges==2 and not crawler.visible)
assert(not tool('Refill',{userId=2}) and tool('Refill',{userId=1}) and habitat.charges==3)
habitat:release(1)
assert(tool('Collect',{userId=2}))
nextContact(habitat,seconds,'Colonies')
local first=habitat.patches.Keel
assert(habitat:cut('Keel') and first.cuts==1)
nextContact(habitat,seconds,'Colonies')
assert(habitat.patches.Keel==first and first.cuts==1)
for _,siteId in ipairs({'Keel','Port','Starboard','Stern'}) do
    while habitat:cut(siteId) do end
    assert(habitat.patches[siteId].cuts==3 and not habitat.patches[siteId].active)
end
nextContact(habitat,seconds,'Colonies')
assert(habitat.patches.Keel~=first and habitat.patches.Keel.cuts==0)
local pingSim,clock,togglePing=new()
isolate(pingSim)
nextContact(pingSim,clock,'Colonies')
togglePing('Sonar',{enabled=true})
local trueEcho=clock(.1,pingSim.actors.Angler.pose.Position)
assert(trueEcho.diverDanger>.98 and (trueEcho.returns.Angler.position-trueEcho.actors.Angler.pose.Position).Magnitude<0.001)
assert(trueEcho.returns.Keel and trueEcho.returns.Keel.kind=='Colony' and not trueEcho.returns.Ridge)
local battery,clockBattery,consume=new()
isolate(battery)
consume('Searchlight',{enabled=true})
consume('Sonar',{enabled=true})
clockBattery(260)
assert(battery.reason=='Battery depleted' and not battery.survived)
local distressed,climb,gear=new('Normal',4)
isolate(distressed)
gear('Engine',{enabled=true})
climb(74)
assert(gear('Recover'))
nextContact(distressed,climb,'Colonies')
climb(12)
assert(distressed.actors.Pursuer.state=='Closing','heavy fouling should slow ascent enough for the Pursuer to gain')
for _,id in ipairs({'Port','Stern'}) do for _=1,3 do assert(distressed:cut(id)) end end
climb(3)
assert(distressed.actors.Pursuer.state=='FallingBack')
print('PASS angler counter/strike, simultaneous Pursuer/coast, stalled and fouled pursuit, directional squid, crawler seal/boarding/spray, colony renewal, live actor sonar, predator proximity, dead battery')
