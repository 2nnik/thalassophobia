local fs = require("@lune/fs")
local luau = require("@lune/luau")

local now, nextRoom = 0, 0
local state, notices = {}, {}
local signals = {}
local players = {
	PlayerAdded = {Connect = function(_, fn) signals.added = fn end},
	PlayerRemoving = {Connect = function(_, fn) signals.removing = fn end},
}
local host = {UserId = 1, DisplayName = "Host", Parent = players}
local guest = {UserId = 2, DisplayName = "Guest", Parent = players}
local other = {UserId = 3, DisplayName = "Other", Parent = players}
function players:GetPlayers() return {host, guest, other} end
local feed = {FireClient = function(_, player, kind, value)
	if kind=="Lobby" then state[player]=value else notices[player]=value end
end}
local services = {
	Players = players,
	RunService = {IsStudio = function() return true end},
	HttpService = {GenerateGUID = function()
		nextRoom += 1
		return string.format("%036d", nextRoom)
	end},
}
local profiles = {init = function() end, load = function() end, forget = function() end,
	ready = function() return true end, view = function() return 0, nil, {} end}
local lobby = luau.load(fs.readFile("src/ServerScriptService/DiveLobby.luau"), {
	environment = {
		game = {PrivateServerId = "", GetService = function(_, name) return services[name] end,
			ReplicatedStorage = {WaitForChild = function() return {WaitForChild = function() return feed end} end}},
		script = {Parent = {DiveLobbyProfiles = "Profiles", DiveSimulation = "Dive"}},
		require = function(name) return if name=="Profiles" then profiles else {targetDepth=10000} end,
		task = {spawn = function(fn, ...) fn(...) end},
		os = {clock = function() return now end},
		typeof = type,
	},
	injectGlobals = true,
})()
local launches = {}
lobby.init({isBusy = function() return false end, start = function(roster, difficulty)
	table.insert(launches,{roster=roster,difficulty=difficulty})
	return true
end})
local function action(player, command, arg)
	now += 1
	lobby.input(player, command, arg)
end
action(host,"Queue")
assert(#launches==0 and #state[guest].lobbies==0)
action(host,"CreateLobby",{capacity=2,difficulty="Hard",password="Depth04"})
action(other,"CreateLobby",{capacity=3,difficulty="Easy",password=""})
local room=state[host].lobbyId
local openRoom=state[other].lobbyId
assert(room and openRoom and room~=openRoom and #state[guest].lobbies==2)
local protected=state[guest].lobbies[1]
assert(protected.id==room and protected.locked and protected.capacity==2 and protected.password==nil)
assert(state[host].password==nil and not state[other].locked)
action(guest,"JoinLobby",{id=room,password="wrong"})
assert(state[guest].lobbyId==nil and notices[guest]=="Incorrect lobby password.")
action(guest,"JoinLobby",{id=room,password="Depth04"})
assert(state[guest].lobbyId==room and #state[host].party==2 and #launches==0)
action(guest,"Launch")
assert(#launches==0)
action(host,"LeaveParty")
assert(not state[guest].lobbyId and #state[guest].lobbies==1)
action(guest,"JoinLobby",{id=openRoom})
assert(state[guest].lobbyId==openRoom and #state[other].party==2)
action(other,"Launch")
assert(#launches==1 and #launches[1].roster==2 and launches[1].difficulty=="Easy")
action(host,"LaunchSolo","Nightmare")
assert(#launches==2 and #launches[2].roster==1 and launches[2].difficulty=="Nightmare")
print("PASS: server-local room selection, passwords, membership, owner launch and solo difficulty")
