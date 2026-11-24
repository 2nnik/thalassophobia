# Thalassa Feed and Input

Snapshot of the interface in place `133428803360145` at the VS Code cutover. Changes to payloads need coordinated server and client edits.

Both remotes are under `ReplicatedStorage.DiveNet`. The client calls `Input:FireServer(action, arg)`. Server responses use `Feed:FireClient(player, kind, payload)`.

| Feed kind | Payload and owner |
| --- | --- |
| Lobby | `DiveLobby` sends difficulty, party, hostId, lobbyId, capacity, locked, the same-server lobbies directory, money, equipped trait, traits, deploying, studio, reserved, busy and loading. Directory entries contain id, hostName, difficulty, count, capacity and locked. Passwords stay on the server. |
| Dive | `DiveController` sends shared phase, depth, battery, hull, propulsion, light, damage and threat state. It adds private crew state such as outside, oxygen, extinguisher and cameraView. `DiveExterior` adds the cleaning and swimming fields. With sonar active inside the ship, the payload also carries echoes and pingAt. |
| Results | `DiveController` sends the run receipt. `DismissResults` clears the receipt and asks the lobby for fresh state. |
| Notice | A string for player-facing feedback. |
| Cinematic | `DiveController` sends a presentation cue with kind, duration, startedAt and optionally section/position. WormGrab holds only the targeted crewmate. WormRescue and WormDeath replace that cue. Angler, Squid and Flood play before Results. The client owns the wake-up sequence on the first Dive snapshot. |

The server sends Dive updates about four times per second during a run, with additional updates for interactions. `Sync` requests the current view. `CreateLobby` takes a difficulty, capacity and password string (blank for an open room). `JoinLobby` takes an id with a password when required. `Launch` departs with the listed lobby, `LaunchSolo` takes a difficulty string, `LeaveParty` exits or closes a lobby, and `PublicLobby` returns a reserved crew to the public dock.

The red extinguisher rack equips a physical Tool. `hasExtinguisher` reports possession and `extinguisherEquipped` reports whether it is in hand. `SprayCrawler` takes a unit aim vector from the equipped player. The server checks charges, cooldown, range, and line of sight, and only a burst on target releases a victim. The swim before the Flood or Squid finisher is a client-controlled presentation segment after the run is lost.

Predator breaches are tracked by section in `Dive.breaches`. Any open breach sets `systemsOffline`, closes camera sessions, and disables the sonar. The searchlight remains available. `planks` is the player's carried supply. At a leak, `breachRepair` provides the challenge ID, section, completed count, normalized circle positions, synchronized target times and timing window. `BreachHit` takes the matching ID, target index and synchronized strike time. `BreachCancel` takes no payload. Misses and cancellations leave the plank available.

`SpinTrait` spends `Lobby.spinCost` earned credits. The server samples using the catalog weights, then persists the balance and unlock together. `Lobby.spinResult` carries a unique `id`, `trait`, `duplicate` and `refund` for the reveal. `Trait` with an owned trait ID toggles equip.

The optics stations open via a server-validated prompt or click. The private Dive snapshot indicates `cameraView` or `searchlightView`. Camera selection is local, while `AimSearchlight` changes the shared beam for players with an active searchlight session. It takes an integer 1–4 for bow, starboard, stern or port and powers the beam, or `false` to switch it off. `CloseOptics` leaves either station.

Dive actions also include `SwimMove` with direction and look vectors, `CleanStrike` with challenge id and strike time, and `CleanCancel`. Many station interactions originate from server-side ProximityPrompts. Review `DiveController`, `DiveExterior`, and `DiveLobby` for validation and exact fields before changing the interface.
