# New experience (from 2026-11-20)

2nnik switched the project to an existing place: "Untitled Experience", placeId 133428803360145, universeId 10777975725.
It already contains a complete Thalassophobia build, separate from the one in this repo's branches. Its scripts are not mirrored in `src/`; read and edit them in Studio over the MCP.

## What's in it
- Workspace.Thalassa (~3,300 parts): ship "Bell • KESTREL 04", "Pressure hull • Survey refit", Stations, Contacts (creatures), BarnacleSites, Ocean, Launch dock, DiveCamera1-4, WormWindow1-3, spawns (Lobby, Cage, Outside, InsideLock), TetherAnchor, ShipEnvelope, Dive stage.
- ReplicatedStorage.DiveNet: RemoteEvents `Feed` (server → client) and `Input` (client → server). This is a different protocol from shared/DiveProtocol.md.
- ServerScriptService: DiveController (Script), DiveSimulation, DiveWorld, DiveSensors, DiveExterior, DiveLobby, DiveLobbyProfiles (DataStore), DiveLobbyQueue (MemoryStore cross-server queue).
- StarterPlayerScripts: DiveClient (LocalScript), DiveClientStyle, DiveClientTerminal, DiveClientInstruments, DiveClientOptics, DiveExteriorClient.
- Lighting: Sky, SunRays, Atmosphere, 2x Bloom, DepthOfField.

## Ownership
See notes/messages.md (C10 onward) for the current split between Claude and Codex.
