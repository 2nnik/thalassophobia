-- Server-owned simulation. All positions and directions used by instruments come from these poses.
local Voyage = {}
Voyage.__index = Voyage

local T = {
    depth = 600, descent = 9, ascent = 6.4, acceleration = 3.2, coastSeconds = 6,
    drain = {idle = .12, engine = .19, sonar = .16, beam = .24},
    pulsePeriod = 2, sonarRange = 210, beamRange = 180, beamHalfAngle = 19,
    cuts = 3, repairSeconds = 2.1, anglerQuiet = 2.6, squidIllumination = 2.1,
    crawlerDamagePeriod = 5, pursuerStart = 110, pursuerLimit = 150,
    steadyClimbFraction = .78, pursuerGainFouled = .9, pursuerGainStalled = 3.2, pursuerRetreat = 2.4,
    difficulty = {
        Easy   = {rate=.80, window=1.25, drain=.80, damage=.75, pressure=.80},
        Normal = {rate=1,   window=1,    drain=1,   damage=1,   pressure=1},
        Hard   = {rate=1.24,window=.82,  drain=1.2, damage=1.2, pressure=1.25},
    },
    -- Independent intervals allow overlapping contacts. Times in seconds at normal difficulty with four crew.
    events = {
        Angler={first=17, period=44, window=13}, Squid={first=29,period=54,window=16},
        Crawler={first=38,period=49,window=17}, Colonies={first=21,period=70}, Fracture={first=15,period=26},
    },
}
Voyage.Tuning = T
local SITE = {'Port','Starboard','Stern','Keel'}
local ROOM = {Port='Machinery',Starboard='Lab',Stern='DiveService',Keel='Machinery'}
local OFFSETS = {Port=Vector3.new(-13,2,0), Starboard=Vector3.new(13,2,0), Stern=Vector3.new(0,2,26), Keel=Vector3.new(0,-2,0)}
local TAU = 2*math.pi
local function finite(x)
    return type(x) == 'number' and x == x and math.abs(x) < math.huge
end
local function moveToward(value,target,amount)
    return value + math.clamp(target-value,-amount,amount)
end
local function actor(origin, visible)
    return {pose=origin,state=visible and 'Roaming' or 'Dormant',visible=visible}
end
local function lightVector(self)
    local bearing, pitch = math.rad(self.bearing), math.rad(self.pitch)
    return Vector3.new(math.sin(bearing)*math.cos(pitch),math.sin(pitch),-math.cos(bearing)*math.cos(pitch))
end
local function placeAnimal(self, id)
    local track, a = self.tracks[id], self.actors[id]
    local theta = track.theta
    local y = 9 + 11*math.sin(theta*.9)
    if id=='Squid' then y = -3 + 15*math.sin(theta*1.2) end
    local pos = Vector3.new(math.sin(theta)*track.radius,y,-math.cos(theta)*track.radius)
    local heading = Vector3.new(math.cos(theta)*track.direction,0,math.sin(theta)*track.direction)
    a.pose = self.shipCFrame * CFrame.lookAt(pos,pos+heading)
end
function Voyage:setCrewCount(count)
    self.crewCount = math.clamp(math.floor(count or 1),1,4)
    self.eventRate = (.62+.38*(self.crewCount-1)/3)*self.level.rate
    self.windowFactor = (1.65-.65*(self.crewCount-1)/3)*self.level.window
end
function Voyage.new(difficulty,crewCount,traits,shipCFrame)
    local self = setmetatable({},Voyage)
    self.difficulty = T.difficulty[difficulty] and difficulty or 'Normal'
    self.level = T.difficulty[self.difficulty]
    self.traits, self.shipCFrame = traits or {},shipCFrame or CFrame.new()
    self:setCrewCount(crewCount)
    self.phase,self.depth,self.deepest,self.speed = 'Descent',0,0,0
    self.hull,self.battery,self.artifact,self.survived = 100,100,false,false
    self.elapsed,self.now,self.coastDrag = 0,0,0
    self.engine,self.sonar,self.searchlight = false,false,false
    self.bearing,self.pitch,self.sincePulse,self.pulseAt = 0,0,0,0
    self.pursuerGap,self.diverDanger,self.infestation = T.pursuerStart,0,0
    self.maxCharges = self.traits.Extinguisher and 5 or 3
    self.charges = self.maxCharges
    self.returns,self.patches,self.fractures,self.sites,self.features,self.repairs = {},{},{},{},{},{}
    self.features.Ridge = self.shipCFrame:PointToWorldSpace(Vector3.new(-48,-38,-62))
    self.features.Outcrop = self.shipCFrame:PointToWorldSpace(Vector3.new(33,-40,41))
    for _,site in ipairs(SITE) do
        self.sites[site] = self.shipCFrame:PointToWorldSpace(OFFSETS[site])
        self.fractures[site] = 0
    end
    self.actors,self.tracks = {},{}
    for _,id in ipairs({'Angler','Squid','Crawler','Pursuer'}) do self.actors[id] = actor(self.shipCFrame,id=='Angler' or id=='Squid') end
    for index,id in ipairs({'Angler','Squid'}) do
        self.tracks[id]={theta=(index==1 and .95 or -1.2)+math.random()*.9, radius=102+index*12,direction=index==1 and 1 or -1,progress=0}
        placeAnimal(self,id)
    end
    self.timers={}
    for id,event in pairs(T.events) do self.timers[id] = event.first end
    return self
end
function Voyage:finish(reason)
    if self.phase == 'Results' then return false end
    self.phase,self.reason,self.survived = 'Results',reason,reason=='Surfaced'
    self.engine,self.speed,self.searchlight,self.sonar = false,0,false,false
    return true
end
function Voyage:release(userId)
    if self.extinguisherHolder == userId then self.extinguisherHolder = nil end
end
function Voyage:cut(site)
    local patch = self.patches[site]
    if self.phase=='Results' or not patch or not patch.active then return false end
    patch.cuts += 1
    patch.active = patch.cuts < T.cuts
    return true
end
local function hideCrawler(self)
    local crawler = self.actors.Crawler
    crawler.state,crawler.visible,crawler.site,crawler.room,crawler.deadline = 'Dormant',false,nil,nil,nil
end
function Voyage:action(name,p,now)
    if self.phase=='Results' or type(p)~='table' or not finite(now) then return false,'Unavailable' end
    if name=='Engine' or name=='Searchlight' or name=='Sonar' then
        if type(p.enabled)~='boolean' then return false,'Expected enabled' end
        if name=='Engine' then
            if not p.enabled and self.engine then self.coastDrag = self.speed / T.coastSeconds end
            self.engine=p.enabled
        elseif name=='Sonar' then
            if p.enabled and not self.sonar then self.sincePulse = T.pulsePeriod end
            if not p.enabled then self.returns = {} end
            self.sonar=p.enabled
        else self.searchlight=p.enabled end
    elseif name=='Aim' then
        if not finite(p.bearing) or not finite(p.pitch) then return false,'Invalid aim' end
        self.bearing,self.pitch=p.bearing%360,math.clamp(p.pitch,-75,75)
    elseif name=='Recover' then
        if self.phase~='Seabed' then return false,'Requires seabed' end
        self.phase,self.artifact,self.speed = 'Ascent',true,0
        self.actors.Pursuer.visible,self.actors.Pursuer.state = true,'Closing'
        self.actors.Pursuer.pose=self.shipCFrame*CFrame.new(0,-self.pursuerGap,0)*CFrame.Angles(math.pi/2,0,0)
    elseif name=='Repair' then
        if not self.fractures[p.site] or self.fractures[p.site]<=0 or self.repairs[p.site] then return false,'No available fracture' end
        self.repairs[p.site]=self.elapsed+T.repairSeconds*(self.traits.Repair and .52 or 1)
    elseif name=='Collect' then
        if not finite(p.userId) or (self.extinguisherHolder and self.extinguisherHolder~=p.userId) then return false,'Unavailable' end
        self.extinguisherHolder=p.userId
    elseif name=='Refill' then
        if not finite(p.userId) or self.extinguisherHolder~=p.userId or self.charges==self.maxCharges then return false,'Requires used extinguisher' end
        self.charges=self.maxCharges
    elseif name=='Spray' then
        local crawler=self.actors.Crawler
        if not finite(p.userId) or self.extinguisherHolder~=p.userId or self.charges<=0 then return false,'Requires charged extinguisher' end
        if crawler.state~='Boarded' or p.room~=crawler.room then return false,'Crawler absent from room' end
        self.charges-=1
        hideCrawler(self)
    else return false,'Unknown action' end
    return true
end
local function startEvent(self,id)
    if id=='Angler' or id=='Squid' then
        local a,tr=self.actors[id],self.tracks[id]
        if a.state~='Roaming' or (id=='Angler' and not self.engine) then return end
        tr.progress,tr.remaining=0,T.events[id].window*self.windowFactor
        tr.fullWindow=tr.remaining
        a.state,a.deadline='Approach',self.now+tr.remaining
    elseif id=='Colonies' then
        for _,patch in pairs(self.patches) do if patch.active then return end end
        self.infestation+=1
        self.patches={}
        for _,site in ipairs(SITE) do self.patches[site]={active=true,cuts=0,position=self.sites[site]} end
    elseif id=='Crawler' then
        local a=self.actors.Crawler
        if a.visible then return end
        local site=SITE[math.random(1,3)]
        a.state,a.visible,a.site,a.room='Attached',true,site,ROOM[site]
        a.pose=CFrame.lookAt(self.sites[site],self.shipCFrame.Position,self.shipCFrame.UpVector)
        a.deadline=self.now+T.events.Crawler.window*self.windowFactor
        -- The selected window develops a new fracture. One completed seal blocks this entry.
        self.fractures[site]=math.max(self.fractures[site],1)
    else
        local site=SITE[math.random(1,#SITE)]
        self.fractures[site]=math.min(3,self.fractures[site]+1)
    end
end
local function updateAnimal(self,id,dt)
    local a,tr=self.actors[id],self.tracks[id]
    local baseRadius = id=='Angler' and 114 or 126
    local orbitSpeed = id=='Angler' and .024 or .020
    if a.state=='Approach' then
        tr.remaining-=dt
        local fraction=math.clamp(tr.remaining/tr.fullWindow,0,1)
        tr.radius=moveToward(tr.radius,45+(baseRadius-45)*fraction,dt*10)
        orbitSpeed*=.7
    else
        tr.radius=moveToward(tr.radius,baseRadius+(a.state=='Passing' and 14 or 0),dt*4)
    end
    tr.theta+=dt*orbitSpeed*tr.direction
    placeAnimal(self,id)
    if a.state=='Approach' then
        local countered=not self.engine
        if id=='Squid' then
            local target=self.shipCFrame:PointToObjectSpace(a.pose.Position)
            local optics=self.traits.Optics and 1.35 or 1
            countered=self.searchlight and target.Magnitude <= T.beamRange*optics and lightVector(self):Dot(target.Unit)>=math.cos(math.rad(T.beamHalfAngle*optics))
        end
        tr.progress=countered and tr.progress+dt or 0
        if tr.progress >= (id=='Angler' and T.anglerQuiet or T.squidIllumination) or tr.remaining<=0 then
            if not countered or tr.progress < (id=='Angler' and T.anglerQuiet or T.squidIllumination) then
                self.hull -= (id=='Angler' and 31 or 24)*self.level.damage
            end
            a.state,a.deadline='Passing',nil
            tr.remaining=9
        end
    elseif a.state=='Passing' then
        tr.remaining-=dt
        if tr.remaining<=0 then a.state='Roaming' end
    end
end
local function pulse(self,diver)
    local returns={}
    local function plot(id,kind,pose)
        local offset=self.shipCFrame:PointToObjectSpace(pose.Position)
        if offset.Magnitude > T.sonarRange then return end
        returns[id]={kind=kind,position=pose.Position,pose=pose,bearing=math.deg(math.atan2(offset.X,-offset.Z))%360,range=offset.Magnitude,elevation=offset.Y}
    end
    for id,a in pairs(self.actors) do if a.visible and a.state~='Boarded' then plot(id,id,a.pose) end end
    for site,p in pairs(self.patches) do if p.active then plot(site,'Colony',CFrame.new(self.sites[site])) end end
    if diver then plot('Diver','Diver',CFrame.new(diver)) end
    for id,position in pairs(self.features) do
        local distanceAboveFloor=(T.depth-self.depth)*3.57
        plot(id,'Terrain',CFrame.new(position-self.shipCFrame.UpVector*distanceAboveFloor))
    end
    self.returns,self.pulseAt=returns,self.now
end
local function tickSim(self,dt,now,diver)
    self.elapsed+=dt
    self.now=now
    for id,event in pairs(T.events) do
        local rate=self.eventRate
        if self.artifact then rate*=1.23 end
        if id=='Angler' and self.traits.QuietEngine then rate*=.73 end
        self.timers[id]-=dt*rate
        if self.timers[id]<=0 then
            startEvent(self,id)
            self.timers[id]=event.period*(.88+.24*math.random())
        end
    end
    local crackTotal=0
    for _,site in ipairs(SITE) do
        if self.repairs[site] and self.elapsed>=self.repairs[site] then
            self.fractures[site],self.repairs[site]=0,nil
            if self.actors.Crawler.state=='Attached' and self.actors.Crawler.site==site then hideCrawler(self) end
        end
        crackTotal+=self.fractures[site]
    end
    local colonies=0
    for _,p in pairs(self.patches) do if p.active then colonies+=1 end end
    local fullSpeed=(self.artifact and T.ascent or T.descent)*(self.traits.QuietEngine and .90 or 1)
    local target=self.engine and fullSpeed*(1-colonies*.085) or 0
    if self.phase=='Seabed' then self.speed=0 else
        self.speed=moveToward(self.speed,target,dt*(self.engine and T.acceleration or self.coastDrag))
        self.depth=math.clamp(self.depth+(self.artifact and -1 or 1)*self.speed*dt,0,T.depth)
        self.deepest=math.max(self.deepest,self.depth)
        if self.depth>=T.depth and self.phase=='Descent' then self.phase,self.speed='Seabed',0 end
    end
    local drain=T.drain.idle+(self.engine and T.drain.engine or 0)+(self.sonar and T.drain.sonar or 0)+(self.searchlight and T.drain.beam or 0)+colonies*.017
    self.battery=math.max(0,self.battery-dt*drain*self.level.drain*(self.traits.Battery and .74 or 1))
    self.hull-=dt*crackTotal*.12*self.level.damage
    updateAnimal(self,'Angler',dt)
    updateAnimal(self,'Squid',dt)
    local crawler=self.actors.Crawler
    if crawler.state=='Attached' and now>=crawler.deadline then
        crawler.state,crawler.deadline='Boarded',now+T.crawlerDamagePeriod
        crawler.pose=self.shipCFrame*CFrame.new(0,2,({Machinery=6.5,Lab=-6.5,DiveService=19.5})[crawler.room])
    elseif crawler.state=='Boarded' and now>=crawler.deadline then
        self.battery=math.max(0,self.battery-2*self.level.damage)
        self.hull-=1.5*self.level.damage
        crawler.deadline=now+T.crawlerDamagePeriod
    end
    if self.phase=='Ascent' then
        -- A coasting cage still makes headway. Four fouled faces drag even a powered cage
        -- below its steady climb rate, giving the exterior cleaning job a visible payoff.
        local climbing=self.speed>=fullSpeed*(self.engine and T.steadyClimbFraction or .55)
        local gain = self.speed > fullSpeed*.45 and T.pursuerGainFouled or T.pursuerGainStalled
        self.pursuerGap=math.clamp(self.pursuerGap+dt*(climbing and T.pursuerRetreat or -gain*self.level.pressure),0,T.pursuerLimit)
        local pursuer=self.actors.Pursuer
        pursuer.state=climbing and 'FallingBack' or 'Closing'
        pursuer.pose=self.shipCFrame*CFrame.new(0,-(self.pursuerGap+8),4)*CFrame.Angles(math.pi/2,0,0)
    end
    self.diverDanger=0
    if diver then
        for _,id in ipairs({'Angler','Squid','Pursuer'}) do
            local a=self.actors[id]
            if a.visible then
                local relative=a.pose:PointToObjectSpace(diver)
                local halfLength=id=='Pursuer' and 20 or 54
                local nearest=Vector3.new(0,0,math.clamp(relative.Z,-halfLength,halfLength))
                self.diverDanger=math.max(self.diverDanger,math.clamp(1-(relative-nearest).Magnitude/36,0,1))
            end
        end
    end
    if self.sonar then
        self.sincePulse+=dt
        if self.sincePulse>=T.pulsePeriod then self.sincePulse=0; pulse(self,diver) end
    end
    self.hull=math.max(0,self.hull)
    if self.hull<=0 then self:finish('Hull collapse')
    elseif self.battery<=0 then self:finish('Battery depleted')
    elseif self.phase=='Ascent' and self.pursuerGap<=0 then self:finish('Pursuer')
    elseif self.phase=='Ascent' and self.depth<=0 then self:finish('Surfaced') end
end
function Voyage:step(dt,now,diverPosition)
    if not finite(dt) or dt<=0 or not finite(now) then return end
    while dt>.000001 and self.phase~='Results' do
        local span=math.min(.25,dt)
        tickSim(self,span,now-dt+span,diverPosition)
        dt-=span
    end
end
function Voyage:snapshot()
    return {
        phase=self.phase,difficulty=self.difficulty,depth=self.depth,deepest=self.deepest,speed=self.speed,
        engine=self.engine,battery=self.battery,hull=self.hull,artifact=self.artifact,survived=self.survived,reason=self.reason,
        sonar=self.sonar,returns=self.returns,pulseAt=self.pulseAt,searchlight=self.searchlight,bearing=self.bearing,pitch=self.pitch,
        beamDirection=self.shipCFrame:VectorToWorldSpace(lightVector(self)),actors=self.actors,patches=self.patches,fractures=self.fractures,
        infestation=self.infestation,pursuerGap=self.pursuerGap,diverDanger=self.diverDanger,
        extinguisherHolder=self.extinguisherHolder,charges=self.charges,maxCharges=self.maxCharges,
    }
end
return Voyage
