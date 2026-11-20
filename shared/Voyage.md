# Voyage payloads · protocol v1

`DiveRuntime` publishes `dive = voyage:snapshot()` during Descent, Seabed and Ascent. Depth, deepest depth and speed use metres and metres/second. World poses, contact ranges and the Pursuer gap use Roblox studs. The stationary ship's local axes are +X starboard, +Y up and −Z fore. A bearing of 0° points fore and 90° starboard. Positive pitch is up.

| Snapshot field | Meaning |
| --- | --- |
| `phase`, `difficulty`, `depth`, `deepest`, `speed` | Current phase, difficulty, depth, retained maximum depth and unsigned vertical speed. |
| `engine`, `artifact`, `hull`, `battery` | Engine switch, recovered flag and 0–100 hull/battery percentages. Speed can stay positive after shutdown. |
| `searchlight`, `bearing`, `pitch`, `beamDirection` | Exterior beam switch, ship-relative angles in degrees and current unit direction in world coordinates. |
| `sonar`, `pulseAt`, `returns` | Pulse switch, server timestamp of latest pulse and map of echoes at that instant. Clearing sonar clears the display. Use ship centre as the origin blip. |
| `actors[id]` | `{pose: CFrame, state: string, visible: boolean}`. `pose` is the same centre transform used for external models, sonar and diver danger. Models face local -Z. `deadline` on an approaching animal or active crawler uses server time in seconds. |
| `patches[site]`, `infestation` | `nil` before first wave. Each entry carries `position`, `cuts` (0–3) and `active`. Green cuts persist until a later wave replaces all four entries. `infestation` increases on replacement. |
| `fractures[site]` | Severity 0–3 per site. A completed seal takes a few seconds and clears that site. |
| `pursuerGap`, `diverDanger` | Gap below the ship in studs and severity of swimmer exposure from 0 to 1. Evaluate Pursuer warnings during ascent. |
| `extinguisherHolder`, `charges`, `maxCharges` | Holder UserId when carried and charge count. A refill requires the holder at the refill station. |
| `reason`, `survived` | Terminal reason e.g. `Surfaced`, `Hull collapse`, `Battery depleted` or `Pursuer`; simulation's surface success flag. Runtime computes individual outcomes. |

`Angler` and `Squid` roam between encounters. Their `Approach` state requires quiet or a sustained correctly aimed beam, respectively. `Passing` means their approach has ended. `Crawler` becomes `Attached` at `site` in `room`. Seal the named fracture, or spray it from inside that room after `Boarded`. Its hidden state is `Dormant`. `Pursuer` is hidden until artifact recovery. It alternates between `Closing` and `FallingBack`. Show both an angler warning and Pursuer gap whenever they overlap.

Each sonar echo is keyed by actor ID, colony site, `Diver` or terrain feature name. It contains `{kind, pose, position, bearing, range, elevation}`. `elevation` is vertical separation in studs. Echo positions remain fixed until the next pulse. The ship's centre and scale are constant. Example of a diver directly to starboard at the ship's height:

```luau
returns.Diver = {
    kind = "Diver", position = ship:PointToWorldSpace(Vector3.new(20,0,0)),
    pose = CFrame.new(ship:PointToWorldSpace(Vector3.new(20,0,0))),
    bearing = 90, range = 20, elevation = 0,
}
```

Client station actions use `Engine`, `Searchlight`, `Sonar` with `{enabled=true|false}`, `Aim` with `{bearing=degrees,pitch=degrees}`, `Repair` with `{site="Port"|"Starboard"|"Stern"|"Keel"}`, and `Collect`, `Refill`, `Spray`, `Recover` with `{}`. The server derives the caller and spray room. Repeated switch commands set the given state. `Recover` succeeds once at the seabed.

`Voyage.new(difficulty, crewCount, traits, shipCFrame)` receives a set of equipped crew traits. Set `voyage.sites[site]` from each world marker's Position before the run. `features` is a map of world-space feature centres at maximum depth; near the bottom the simulated floor moves up at 3.57 studs per metre. `step(dt, serverNow, outsideDiverPosition?)` advances all systems. `cut(site)` commits one validated strike. `setCrewCount(n)` rescales subsequent events. `release(userId)` drops a departing holder's extinguisher. Editable constants and difficulty multipliers are at the top of `src/ServerScriptService/Voyage.luau`.

To run the headless voyage checks from the repository root with Lune 0.11.1:

```powershell
lune run tests/voyage.luau
```
