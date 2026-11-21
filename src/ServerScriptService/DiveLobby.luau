-- Same-server crews, reserved dive deployment and end-of-dive accounting.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Profiles = require(script.Parent.DiveLobbyProfiles)
local Dive = require(script.Parent.DiveSimulation)
local studio = RunService:IsStudio() or game.GameId==0
local NetworkQueue = if studio then nil else require(script.Parent.DiveLobbyQueue)
local L = {}
local groups, lobbies, running, cooldown, joinCooldown = {}, {}, {}, {}, {}
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
local function lobbyDirectory()
	local rooms={}
	for id,group in lobbies do
		local host=group.members[1]
		if host and host.Parent==Players and not group.deploying and not running[host] then
			table.insert(rooms,{id=id,hostName=host.DisplayName,difficulty=group.difficulty,
				count=#group.members,capacity=group.capacity,locked=group.password~=nil})
		end
	end
	table.sort(rooms,function(a,b)
		if a.hostName==b.hostName then return a.id<b.id end
		return a.hostName<b.hostName
	end)
	return rooms
end

local function view(plr,rooms)
	if plr.Parent~=Players then return end
	local group=groups[plr]
	if not group then return end
	local roster={}
	for _,member in group.members do table.insert(roster,info(member)) end
	local money,equipped,traits,spinResult=Profiles.view(plr)
	feed:FireClient(plr,"Lobby",{
		difficulty=group.difficulty,party=roster,hostId=group.members[1].UserId,
		lobbyId=group.id,lobbies=rooms or lobbyDirectory(),capacity=group.capacity,locked=group.password~=nil,
		money=money,equipped=equipped,traits=traits,spinCost=Profiles.spinCost,spinResult=spinResult,
		deploying=group.deploying==true,studio=studio,reserved=game.PrivateServerId~="",
		busy=busy(plr),loading=not Profiles.ready(plr),
	})
end
function L.refresh()
	local rooms=lobbyDirectory()
	for _,plr in Players:GetPlayers() do view(plr,rooms) end
end

local function removeFromGroup(plr)
	local group=groups[plr]
	if not group then return end
	if group.members[1]==plr then
		if group.id then lobbies[group.id]=nil end
		for _,member in group.members do
			if member~=plr and member.Parent==Players then newGroup(member) end
		end
		table.clear(group.members)
	else
		local index=table.find(group.members,plr)
		if index then table.remove(group.members,index) end
	end
	groups[plr]=nil
end

local function validPassword(value)
	return typeof(value)=="string" and (#value==0 or (#value>=4 and #value<=24 and value:match("^[a-zA-Z0-9]+$")~=nil))
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
local function remoteDeploy(group)
	local members=table.clone(group.members)
	group.deploying=true
	L.refresh()
	task.spawn(function()
		local ok,err=NetworkQueue.private(members,group.difficulty)
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
local function register(plr)
	if groups[plr] then return end
	newGroup(plr)
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
		running[plr]=nil
		cooldown[plr],joinCooldown[plr],syncPending[plr]=nil,nil,nil
		Profiles.forget(plr)
		L.refresh()
	end)
	for _,plr in Players:GetPlayers() do register(plr) end
	if not studio then
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
	local host=group.members[1]==plr
	if action=="SpinTrait" then
		notice(plr,Profiles.spin(plr))
	elseif action=="Trait" and typeof(arg)=="string" then
		notice(plr,Profiles.choose(plr,arg))
	elseif action=="CreateLobby" then
		if group.id or #group.members~=1 or not Profiles.ready(plr) or typeof(arg)~="table" then return end
		if typeof(arg.difficulty)~="string" or not difficulties[arg.difficulty] then return end
		local capacity=arg.capacity
		if capacity~=2 and capacity~=3 and capacity~=4 then return end
		if not validPassword(arg.password) then
			notice(plr,"Use 4–24 letters or numbers for the lobby password, or leave it blank.")
			return
		end
		group.id=HttpService:GenerateGUID(false)
		group.difficulty,group.capacity=arg.difficulty,capacity
		group.password=if arg.password~="" then arg.password else nil
		lobbies[group.id]=group
	elseif action=="JoinLobby" then
		if group.id or #group.members~=1 or not Profiles.ready(plr) or typeof(arg)~="table"
			or typeof(arg.id)~="string" or #arg.id~=36 then return end
		local now=os.clock()
		if (joinCooldown[plr] or 0)>now then return end
		joinCooldown[plr]=now+.8
		local room=lobbies[arg.id]
		local leader=room and room.members[1]
		if not leader or leader.Parent~=Players or room.deploying or busy(leader) then
			notice(plr,"That lobby is no longer available.")
		elseif #room.members>=room.capacity then
			notice(plr,"That lobby is full.")
		elseif room.password and (not validPassword(arg.password) or room.password~=arg.password) then
			notice(plr,"Incorrect lobby password.")
		else
			table.insert(room.members,plr)
			groups[plr]=room
		end
	elseif action=="LeaveParty" and group.id then
		removeFromGroup(plr)
		newGroup(plr)
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
	elseif (action=="Launch" or action=="LaunchSolo") and host then
		if action=="LaunchSolo" then
			if group.id or #group.members~=1 or typeof(arg)~="string" or not difficulties[arg] then return end
			group.difficulty=arg
		elseif not group.id then return end
		if not crewReady(group) then notice(plr,"Waiting for crew profiles to finish loading.") return end
		if studio then
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
