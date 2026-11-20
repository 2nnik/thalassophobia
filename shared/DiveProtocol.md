# Dive protocol v1
ReplicatedStorage.DiveNet contains RemoteEvents Action (client → server: action string, payload table) and Snapshot (server → individual client at 5 Hz, including lobby). Times are workspace:GetServerTimeNow() seconds. Client interpolates visual models, never publishes transforms. Roblox studs; fore -Z, starboard +X, up +Y. Ship stays fixed, depth is metres. Ship origin is Workspace.DiveWorld.ShipOrigin.CFrame. Ship deck near local Y=0. Physical access below keel is required.

Rooms Bridge, Machinery, Lab, DiveService. Workspace.DiveWorld folders Stations, Cameras, Sites contain anchored BaseParts named by ID. Stations Engine, Searchlight, Sonar, Camera, RepairPort, RepairStarboard, RepairStern, RepairKeel, Extinguisher, Refill, Airlock, Artifact. Cameras Fore, Starboard, Stern, Port facing outwards. Sites Port, Starboard, Stern, Keel. Add SpawnLobby and SpawnCrew BaseParts under DiveWorld. Claude owns reproducible world builder/visuals, Codex assembles in Studio. Keep paths accessible and interactable. Station activation via server-created ProximityPrompt; directional/continuous actions via Action. Camera desk interaction sets snapshot.camera for operator; CameraExit releases.

Lobby actions Solo, Public, Private, Invite, Join, Leave, Difficulty, Buy, Equip. Phases Lobby, Descent, Seabed, Ascent, Results. Dive actions Engine, Searchlight, Aim, Sonar, Repair, Collect, Refill, Spray, Recover, Exit, Swim, Brace, Cut, Cancel, Return, Camera, CameraExit. Actor IDs Angler, Squid, Crawler, Pursuer; colonies use site IDs. Server owns actor poses, sonar calculations, swimming restraints and run outcomes. Actual field details below will be supplemented with validated module examples.

Example envelopes (Luau shorthand):
```lua
{version=1,time=100,phase="Lobby",lobby={}}
{version=1,time=121,phase="Descent",dive={depth=65,hull=98,battery=94,actors={}},camera=false,eva={}}
{version=1,time=231,phase="Ascent",dive={patches={Keel={cuts=1}}},eva={}}
```

