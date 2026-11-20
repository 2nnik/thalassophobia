# Running the shared dive

The integrated source is on `studio-sync-and-notes`. Open **Super cool game** (place ID `82753323748432`) in Studio. Play, choose a difficulty, and select Solo. Public queues admit crews of up to four. Private launches the current party.

The server builds the ship on Play. Walk to a station to use its proximity prompt. Start the engine in Machinery, watch the camera or sonar from the bridge, and recover the artifact in the lab at 600 m. Cut the engine during an angler approach. Aim the searchlight at the squid. Clear fouling below the hull to improve ascent speed under Pursuer pressure.

## Installing a checkout

With Studio in Edit mode, sync source using the Studio MCP. Copy the direct children of `src/ServerScriptService` and `src/ReplicatedStorage` to the matching services. A plain `.luau` file is a ModuleScript and a `.server.luau` file is a Script. Map `src/StarterPlayerScripts/DiveClient/init.client.luau` to a LocalScript named DiveClient under StarterPlayer.StarterPlayerScripts. Its six sibling modules become children of that LocalScript. Keep the temporary DiveControlsFixture disabled when DiveClient is installed. Preserve unrelated scripts and objects. The game creates DiveNet and DiveWorld at runtime.

## Verification

From the repo root, run `lune run tests/voyage.luau` and `lune run tests/lobby.luau`. The latter uses mocked network and storage services. Run the source of `tests/EVA.spec.luau` in Studio to exercise the physical fixture, including movement beneath the keel, brace/cancel, replay handling, a diver swap and release on death.

For a two-client Studio run, temporarily install the two replication test scripts in the services named in their headers. Start a two-player StudioTestService session with argument `DiveReplication`. The test queues both players, changes the engine from one client, then requires separate observations from both clients. Remove the test scripts after the session.

Published-client checks require separate Roblox accounts and the published experience. Test cross-server party admission and failed transfers, persistence across servers, and eligible-player voice there.
