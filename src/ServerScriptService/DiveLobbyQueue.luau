-- Cross-server queue. Whole parties are claimed in one atomic map transaction.
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Queue = {}
local board = MemoryStoreService:GetHashMap("Thalassophobia_Queue_1")
local manifests = MemoryStoreService:GetHashMap("Thalassophobia_Crews_1")
local difficulties = {"Easy","Normal","Hard"}
local server = game.JobId
local interval = 5
local grace = 18
local function reserve(ids,difficulty)
	local code,privateId = TeleportService:ReserveServerAsync(game.PlaceId)
	manifests:SetAsync(privateId,{ids=ids,difficulty=difficulty},300)
	return code
end
function Queue.send(players,code)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	local ok,err=pcall(TeleportService.TeleportAsync,TeleportService,game.PlaceId,players,options)
	options:Destroy()
	return ok,err
end
function Queue.private(players,difficulty)
	local ids={}
	for _,plr in players do table.insert(ids,plr.UserId) end
	local ok,code=pcall(reserve,ids,difficulty)
	if not ok then return false,code end
	return Queue.send(players,code)
end
function Queue.manifest()
	if game.PrivateServerId=="" or game.PrivateServerOwnerId~=0 then return nil end
	return manifests:GetAsync(game.PrivateServerId)
end

local function prune(state,now)
	state=state or {tickets={},matches={}}
	for id,ticket in state.tickets do
		if ticket.expires<=now then state.tickets[id]=nil end
	end
	for id,match in state.matches do
		if match.expires<=now then state.matches[id]=nil end
	end
	return state
end
local function choose(tickets,now)
	local sorted={}
	for id,ticket in tickets do
		table.insert(sorted,{id=id,t=ticket})
	end
	table.sort(sorted,function(a,b)
		if a.t.joined == b.t.joined then return a.id<b.id end
		return a.t.joined<b.t.joined
	end)
	local crew,ids={},{}
	for _,row in sorted do
		if #ids+#row.t.ids<=4 then
			table.insert(crew,row.id)
			for _,id in row.t.ids do table.insert(ids,id) end
			if #ids==4 then break end
		end
	end
	if #crew==0 then return nil end
	local first=tickets[crew[1]]
	if first.server~=server or (#ids<4 and now-first.joined<grace) then return nil end
	return crew,ids
end

local function tickLevel(diff,localTickets,deliver)
	local now=os.time()
	local state=board:UpdateAsync(diff,function(previous)
		local s=prune(previous,now)
		for id,t in s.tickets do
			if t.server==server and not localTickets[id] then s.tickets[id]=nil end
		end
		for id,t in localTickets do
			if not s.matches[id] then
				s.tickets[id]={server=server,ids=t.ids,joined=t.joined,expires=now+30}
			end
		end
		return s
	end,180)
	if not state then return end
	local crew,ids=choose(state.tickets,now)
	if crew then
		local code=reserve(ids,diff)
		state=board:UpdateAsync(diff,function(previous)
			local s=prune(previous,os.time())
			for _,id in crew do
				if not s.tickets[id] then return s end
			end
			for _,id in crew do
				s.tickets[id]=nil
				s.matches[id]={code=code,expires=os.time()+90}
			end
			return s
		end,180)
	end
	for id,ticket in localTickets do
		local assigned=state and state.matches[id]
		if assigned then deliver(id,assigned.code) end
	end
end
function Queue.run(snapshot,deliver)
	task.spawn(function()
		local activeLast={}
		while true do
			local tickets=snapshot()
			for _,diff in difficulties do
				local localTickets=tickets[diff] or {}
				if next(localTickets) or activeLast[diff] then
					local ok,err=pcall(tickLevel,diff,localTickets,deliver)
					if not ok then warn("Dive queue unavailable",err) end
				end
				activeLast[diff]=next(localTickets)~=nil
			end
			task.wait(interval)
		end
	end)
end
return Queue
