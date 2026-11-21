-- Lobby, local crew invitations, difficulty, deployment and end-of-dive accounting.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Profiles = require(script.Parent.DiveLobbyProfiles)
local Dive = require(script.Parent.DiveSimulation)
local studio = RunService:IsStudio() or game.GameId==0
local NetworkQueue = if studio then nil else require(script.Parent.DiveLobbyQueue)
local L = {}
local groups, invitations, running, cooldown = {}, {}, {}, {}
local callbacks, feed
local syncPending = {}
local launching = false
local receiving = false
local difficulties = {Easy=.8,Normal=1,Hard=1.5,Nightmare=2}
local function newGroup(plr)
	local group={members={plr},difficulty="Normal"}
	groups[plr]=group
	return group
end
local function notice(plr,message)
	if plr and plr.Parent==Players then feed:FireClient(plr,"Notice",message) end
end
local function info(plr)
	return {id=plr.UserId,name=plr.DisplayName}
end
local function busy(plr)
	return receiving or running[plr] or (studio and (launching or callbacks.isBusy())) or false
end
local function view(plr)
	if plr.Parent~=Players then return end
	local group=groups[plr]
	if not group then return end
	local roster,available,invites={},{},{}
	for _,member in group.members do table.insert(roster,info(member)) end
	for _,other in Players:GetPlayers() do
		local crew=groups[other]
		if crew and other~=plr and crew~=group and #crew.members==1 and not crew.ticket and not crew.deploying and not running[other] then
			table.insert(available,info(other))
		end
	end
	for host,expires in invitations[plr] or {} do
		local crew=groups[host]
		if not crew or crew.members[1]~=host or expires<=os.time() or crew.deploying or crew.ticket or running[host] or #crew.members>=4 then
			invitations[plr][host]=nil
		else
			table.insert(invites,info(host))
		end
	end
	local money,equipped,traits,spinResult=Profiles.view(plr)
	feed:FireClient(plr,"Lobby",{
		difficulty=group.difficulty,party=roster,hostId=group.members[1].UserId,available=available,invites=invites,
		money=money,equipped=equipped,traits=traits,spinCost=Profiles.spinCost,spinResult=spinResult,
		queued=group.ticket~=nil,deploying=group.deploying==true,
		queueSeconds=if group.joined then math.max(0,os.time()-group.joined) else 0,
		studio=studio,reserved=game.PrivateServerId~="",busy=busy(plr),loading=not Profiles.ready(plr),
	})
end
function L.refresh()
	for _,plr in Players:GetPlayers() do view(plr) end
end
local function cancel(group)
	group.ticket=nil
	group.joined=nil
end
local function removeFromGroup(plr)
	local group=groups[plr]
	if not group then return end
	cancel(group)
	local index=table.find(group.members,plr)
	if index then table.remove(group.members,index) end
	groups[plr]=nil
end
local function crewReady(group)
	for _,plr in group.members do
		if plr.Parent~=Players or not Profiles.ready(plr) or busy(plr) then return false end
	end
	return true
end
local function beginLocal(roster,difficulty)
	if launching or callbacks.isBusy() or #roster==0 then return false end
	launching=true
	for _,p in roster do running[p]=true end
	local ok,started=pcall(callbacks.start,roster,difficulty)
	if not ok or not started then
		for _,p in roster do running[p]=nil end
		if not ok then warn("Dive start failed",started) end
	end
	launching=false
	return ok and started==true
end
local function remoteDeploy(group,code)
	local members=table.clone(group.members)
	cancel(group)
	group.deploying=true
	L.refresh()
	task.spawn(function()
		local ok,err
		if code then ok,err=NetworkQueue.send(members,code)
		else ok,err=NetworkQueue.private(members,group.difficulty) end
		if not ok then
			warn("Dive deployment failed",err)
			group.deploying=nil
			for _,p in members do notice(p,"Transfer failed. Your crew can launch again.") end
			L.refresh()
		else
			task.delay(35,function()
				if group.deploying and #group.members>0 then
					group.deploying=nil
					L.refresh()
				end
			end)
		end
	end)
end
local function localMatch()
	if launching or callbacks.isBusy() then return end
	local queue,seen={},{}
	for _,group in groups do
		if group.ticket and not seen[group] and crewReady(group) then
			seen[group]=true
			table.insert(queue,group)
		end
	end
	table.sort(queue,function(a,b)
		if a.joined==b.joined then return a.ticket<b.ticket end
		return a.joined<b.joined
	end)
	for _,leader in queue do
		local teams,crew={},{}
		for _,group in queue do
			if group.difficulty==leader.difficulty and #crew+#group.members<=4 then
				table.insert(teams,group)
				for _,p in group.members do table.insert(crew,p) end
			end
		end
		if #crew==4 or os.time()-leader.joined>=18 then
			for _,team in teams do cancel(team) end
			beginLocal(crew,leader.difficulty)
			L.refresh()
			break
		end
	end
end
local function snapshots()
	local result={}
	for _,group in groups do
		if group.ticket then
			local diff=group.difficulty
			result[diff]=result[diff] or {}
			if not result[diff][group.ticket] then
				local ids={}
				for _,p in group.members do table.insert(ids,p.UserId) end
				result[diff][group.ticket]={ids=ids,joined=group.joined}
			end
		end
	end
	return result
end
local function deliver(ticket,code)
	for _,group in groups do
		if group.ticket==ticket then remoteDeploy(group,code) return end
	end
end
local function register(plr)
	if groups[plr] then return end
	newGroup(plr)
	invitations[plr]={}
	task.spawn(Profiles.load,plr)
	L.refresh()
end
local function receive()
	-- Keep incoming reserved crews together until everyone arrives or the join window expires.
	local manifest
	for _=1,4 do
		local ok,result=pcall(NetworkQueue.manifest)
		if ok then manifest=result break end
		task.wait(2)
	end
	if manifest and typeof(manifest.ids)=="table" and difficulties[manifest.difficulty] then
		local roster={}
		local untilAt=os.clock()+25
		repeat
			table.clear(roster)
			for _,id in manifest.ids do
				local p=Players:GetPlayerByUserId(id)
				if p and Profiles.ready(p) then table.insert(roster,p) end
			end
			if #roster==#manifest.ids or os.clock()>=untilAt then break end
			task.wait(.25)
		until false
		if #roster>0 then
			local group={members=table.clone(roster),difficulty=manifest.difficulty}
			for _,p in roster do groups[p]=group end
			receiving=false
			beginLocal(roster,manifest.difficulty)
		end
	end
	receiving=false
	L.refresh()
end
function L.init(config)
	if callbacks then return end
	callbacks=config
	feed=game.ReplicatedStorage:WaitForChild("DiveNet"):WaitForChild("Feed")
	Profiles.init(view,notice)
	receiving=not studio and game.PrivateServerId~="" and game.PrivateServerOwnerId==0
	Players.PlayerAdded:Connect(register)
	Players.PlayerRemoving:Connect(function(plr)
		removeFromGroup(plr)
		invitations[plr]=nil
		for _,offers in invitations do offers[plr]=nil end
		running[plr]=nil
		cooldown[plr]=nil
		Profiles.forget(plr)
		L.refresh()
	end)
	for _,plr in Players:GetPlayers() do register(plr) end
	if not studio then
		NetworkQueue.run(snapshots,deliver)
		TeleportService.TeleportInitFailed:Connect(function(plr)
			local g=groups[plr]
			if g and g.deploying then
				g.deploying=nil
				notice(plr,"Transfer was interrupted. You can launch again.")
				L.refresh()
			end
		end)
		if receiving then task.spawn(receive) end
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if studio then localMatch() end
			for p,g in groups do
				if g.ticket then
					if os.time()-g.joined==45 then notice(p,"Dispatch is delayed. You can leave the queue and launch a private crew.") end
					view(p)
				end
			end
		end
	end)
end
function L.input(plr,action,arg)
	local group=groups[plr]
	if not group or type(action)~="string" then return end
	if action=="Sync" then
		if (cooldown[plr] or 0)<=os.clock() then
			view(plr)
			cooldown[plr]=os.clock()+.13
		else
			if not syncPending[plr] then
				syncPending[plr]=true
				task.delay(.15,function()
					syncPending[plr]=nil
					if groups[plr] then view(plr) end
				end)
			end
		end
		return
	end
	if (cooldown[plr] or 0)>os.clock() then return end
	cooldown[plr]=os.clock()+.13
	if busy(plr) or group.deploying then return end
	if (action=="Invite" or action=="Accept") and (typeof(arg)~="number" or arg~=arg or math.abs(arg)>9007199254740991 or arg%1~=0) then return end
	local host=group.members[1]==plr
	if action=="CancelQueue" and host then
		cancel(group)
	elseif group.ticket then return
	elseif action=="SpinTrait" then
		notice(plr,Profiles.spin(plr))
	elseif action=="Trait" and typeof(arg)=="string" then
		notice(plr,Profiles.choose(plr,arg))
	elseif action=="Difficulty" and host and typeof(arg)=="string" and difficulties[arg] then
		group.difficulty=arg
	elseif action=="LeaveParty" and #group.members>1 then
		removeFromGroup(plr)
		newGroup(plr)
	elseif action=="Invite" and host and #group.members<4 and typeof(arg)=="number" then
		local other=Players:GetPlayerByUserId(arg)
		local otherGroup=groups[other]
		if otherGroup and otherGroup~=group and #otherGroup.members==1 and not otherGroup.ticket and not otherGroup.deploying and not busy(other) then
			invitations[other][plr]=os.time()+60
			notice(other,plr.DisplayName.." invited you to a dive crew.")
			notice(plr,"Invitation sent to "..other.DisplayName..".")
		end
	elseif action=="Accept" and #group.members==1 and typeof(arg)=="number" then
		local leader=Players:GetPlayerByUserId(arg)
		local crew=groups[leader]
		if crew and crew.members[1]==leader and (invitations[plr][leader] or 0)>os.time() and #crew.members<4 and not crew.ticket and not crew.deploying and not busy(leader) then
			removeFromGroup(plr)
			table.insert(crew.members,plr)
			groups[plr]=crew
			table.clear(invitations[plr])
		end
	elseif action=="PublicLobby" and host and not studio and game.PrivateServerId~="" then
		if not crewReady(group) then notice(plr,"Waiting for the crew to be ready.") return end
		local members=table.clone(group.members)
		group.deploying=true
		L.refresh()
		task.spawn(function()
			local ok=pcall(TeleportService.TeleportAsync,TeleportService,game.PlaceId,members)
			if not ok then
				group.deploying=nil
				for _,member in members do notice(member,"Dock transfer failed. Try again.") end
				L.refresh()
			else
				task.delay(35,function() group.deploying=nil L.refresh() end)
			end
		end)
	elseif (action=="Launch" or action=="Queue") and host then
		if not crewReady(group) then notice(plr,"Waiting for crew profiles to finish loading.") return end
		if action=="Queue" then
			group.ticket=HttpService:GenerateGUID(false)
			group.joined=os.time()
		elseif studio then
			if not beginLocal(table.clone(group.members),group.difficulty) then notice(plr,"The cage is occupied.") end
		else
			remoteDeploy(group)
		end
	else return end
	L.refresh()
end
function L.finish(members,depth,artifact,survived,difficulty)
	local payouts={}
	local progress=math.clamp((tonumber(depth) or 0)/Dive.targetDepth,0,1)
	local base=progress*100+(if artifact then 35 else 0)+(if survived then 80 else 0)
	local amount=math.floor(base*(if survived then 1 else .75)*(difficulties[difficulty] or 1))
	for _,p in members do
		payouts[p.UserId]=amount
		running[p]=nil
		Profiles.award(p,amount)
	end
	task.defer(L.refresh)
	return payouts
end
L.trait=Profiles.trait
return L
