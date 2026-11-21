# Thalassa Feed and Input

Snapshot of the interface in place `133428803360145` at the VS Code cutover. Changes to payloads need coordinated server and client edits.

Both remotes are under `ReplicatedStorage.DiveNet`. The client calls `Input:FireServer(action, arg)`. Server responses use `Feed:FireClient(player, kind, payload)`.

| Feed kind | Payload and owner |
| --- | --- |
| Lobby | `DiveLobby` sends difficulty, party, hostId, available players, invites, money, equipped trait, traits, queued, deploying, queueSeconds, studio, reserved, busy and loading. |
| Dive | `DiveController` sends shared phase, depth, battery, hull, propulsion, light, damage and threat state. It adds private crew state such as outside, oxygen, extinguisher and cameraView. `DiveExterior` adds the cleaning and swimming fields. With sonar active inside the ship, the payload also carries echoes and pingAt. |
| Results | `DiveController` sends the run receipt. `DismissResults` clears the receipt and asks the lobby for fresh state. |
| Notice | A string for player-facing feedback. |
| Cinematic | `DiveController` sends a presentation cue with kind, duration, startedAt and optionally section/position. WormGrab holds only the targeted crewmate. WormRescue and WormDeath replace that cue. Angler, Squid and Flood play before Results. The client owns the wake-up sequence on the first Dive snapshot. |

The server sends Dive updates about four times per second during a run, with additional updates for interactions. The `Sync` action requests the current view. Lobby actions include `Launch`, `Queue`, `CancelQueue`, `PublicLobby`, `LeaveParty`, `Invite` and `Accept` with a numeric user ID, and `Difficulty` with a string argument.

The red extinguisher rack equips a physical Tool. `hasExtinguisher` reports possession and `extinguisherEquipped` reports whether it is in hand. The server validates boarder state, charges, range and line of sight before a discharge. The swim before the Flood or Squid finisher is a client-controlled presentation segment after the run is lost.

`SpinTrait` spends `Lobby.spinCost` earned credits. The server samples using the catalog weights, then persists the balance and unlock together. `Lobby.spinResult` carries a unique `id`, `trait`, `duplicate` and `refund` for the reveal. `Trait` with an owned trait ID toggles equip.

Dive actions include `CloseCamera`, `SwimMove` with direction and look vectors, `CleanStrike` with challenge id and strike time, and `CleanCancel`. Many station interactions originate from server-side ProximityPrompts. Review `DiveController`, `DiveExterior`, and `DiveLobby` for validation and exact fields before changing the interface.
