-- Profile transactions are committed per operation, including an idempotent run receipt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local localMode = RunService:IsStudio() or game.GameId == 0
local store = if localMode then nil else DataStoreService:GetDataStore("Thalassophobia_Profile_1")
local Profiles = {}
Profiles.spinCost = 50
local duplicateRefund = 20
local rng = Random.new()
local cache, locked, pending, loading = {}, {}, {}, {}
local updateClient, notifyFailure
local catalog = {
	{id="Battery", name="Reserve cells", description="The cage uses 15% less power.", weight=10},
	{id="Optics", name="Focusing lens", description="The spotlight repels the squid faster.", weight=20},
	{id="Welder", name="Hull welder", description="Seal a damaged hull panel faster.", weight=17},
	{id="Baffle", name="Engine baffle", description="Gain angler reaction time at the cost of thrust.", weight=13},
	{id="Tank", name="Reserve cylinder", description="Carry a larger extinguisher charge.", weight=22},
	{id="Diver", name="Rebreather", description="Stay outside longer on each excursion.", weight=18},
}
local byId = {}
local totalWeight = 0
for _, item in catalog do
	byId[item.id] = item
	totalWeight += item.weight
end

local function normalize(raw)
	local data = if typeof(raw) == "table" then raw else {}
	data.money = math.max(0, math.floor(tonumber(data.money) or 0))
	data.owned = if typeof(data.owned) == "table" then data.owned else {}
	data.equipped = if byId[data.equipped] and data.owned[data.equipped] then data.equipped else ""
	data.receipts = if typeof(data.receipts) == "table" then data.receipts else {}
	return data
end

local function notify(plr)
	if plr.Parent and updateClient then updateClient(plr) end
end

local function transact(plr, receipt, mutate)
	local id = plr.UserId
	while locked[id] do task.wait(.1) end
	locked[id] = true
	local function write(raw)
		local data = normalize(raw)
		if not table.find(data.receipts,receipt) then
			mutate(data)
			table.insert(data.receipts, receipt)
			if #data.receipts > 128 then table.remove(data.receipts,1) end
		end
		return data
	end
	local ok, data
	if localMode then
		ok, data = true, write(cache[id])
	else
		ok, data = pcall(function()
			return store:UpdateAsync("u"..id, write)
		end)
	end
	if ok then cache[id] = data end
	locked[id] = nil
	return ok
end

function Profiles.init(changed, notice)
	updateClient, notifyFailure = changed, notice
	game:BindToClose(function()
		local deadline = os.clock()+25
		while (next(pending) or next(locked)) and os.clock()<deadline do task.wait(.15) end
	end)
end
function Profiles.load(plr)
	local id=plr.UserId
	if loading[id] or cache[id] then return end
	loading[id]=true
	local retry=0
	repeat
		local ok,raw=true,nil
		if store then ok,raw=pcall(function() return store:GetAsync("u"..id) end) end
		if ok then
			cache[id]=normalize(raw)
		else
			retry+=1
			if notifyFailure and (retry==1 or retry%6==0) then
				notifyFailure(plr,"Your credit ledger is unavailable. Reconnecting before deployment.")
			end
			task.wait(math.min(12,2^math.min(retry,4)))
		end
	until cache[id] or not plr.Parent
	loading[id]=nil
	notify(plr)
end
function Profiles.ready(plr)
	return cache[plr.UserId] ~= nil and not locked[plr.UserId] and not pending[plr.UserId]
end
function Profiles.trait(plr)
	local data=cache[plr.UserId]
	return if data then data.equipped else ""
end
function Profiles.view(plr)
	local data=cache[plr.UserId] or normalize(nil)
	local rows={}
	for _,item in catalog do
		local row=table.clone(item)
		row.owned=data.owned[row.id]==true
		row.equipped=data.equipped==row.id
		table.insert(rows,row)
	end
	return data.money,data.equipped,rows,data.spinResult
end
function Profiles.choose(plr,id)
	local item=byId[id]
	if not item or not Profiles.ready(plr) then return "Loadout is busy." end
	local response=""
	local ok=transact(plr,HttpService:GenerateGUID(false),function(data)
		if not data.owned[id] then
			response="Unlock this trait at the spin station."
			return
		end
		data.equipped=if data.equipped==id then "" else id
		response=if data.equipped=="" then "Trait unequipped." else item.name.." equipped."
	end)
	return if ok then response else "Could not save your loadout. Try again."
end
function Profiles.spin(plr)
	if not Profiles.ready(plr) then return "Loadout is busy." end
	-- Pick once for the transaction so UpdateAsync retries cannot reroll.
	local roll = rng:NextInteger(1,totalWeight)
	local selected
	for _,item in catalog do
		roll -= item.weight
		if roll <= 0 then selected=item break end
	end
	local receipt = HttpService:GenerateGUID(false)
	local ok = transact(plr,receipt,function(data)
		if data.money < Profiles.spinCost then return end
		local duplicate = data.owned[selected.id] == true
		local refund = if duplicate then duplicateRefund else 0
		data.money -= Profiles.spinCost - refund
		data.owned[selected.id] = true
		data.spinResult = {id=receipt,trait=selected.id,duplicate=duplicate,refund=refund}
	end)
	if not ok then return "Could not save your spin. Try again." end
	local result = cache[plr.UserId].spinResult
	if not result or result.id ~= receipt then return "A spin costs "..Profiles.spinCost.." earned credits." end
	return if result.duplicate then selected.name.." duplicate. +"..result.refund.." credits returned."
		else selected.name.." unlocked."
end
function Profiles.award(plr,amount)
	if amount<=0 then return end
	local id=plr.UserId
	local receipt=HttpService:GenerateGUID(false)
	pending[id]=(pending[id] or 0)+1
	task.spawn(function()
		local delaySeconds=1
		while not transact(plr,receipt,function(data) data.money+=amount end) do
			if delaySeconds==1 and notifyFailure then notifyFailure(plr,"Award save delayed. Reconnecting to your credit ledger.") end
			task.wait(delaySeconds)
			delaySeconds=math.min(8,delaySeconds*2)
		end
		pending[id]-=1
		if pending[id]==0 then pending[id]=nil end
		notify(plr)
	end)
end
function Profiles.forget(plr)
	if localMode then return end
	task.spawn(function()
		while locked[plr.UserId] or pending[plr.UserId] or loading[plr.UserId] do task.wait(.5) end
		if not Players:GetPlayerByUserId(plr.UserId) then cache[plr.UserId]=nil end
	end)
end
return Profiles
