# EVA wire, v1

The crew shares one suit. Send EVA input to `ReplicatedStorage.DiveNet.Action` as `(action, payload)`. All positions and directions are in world space. All times use `workspace:GetServerTimeNow()`. The server owns the avatar pose, oxygen, tether and patch progress.

| Action | Payload | Behavior |
| --- | --- | --- |
| Exit | `{}` | Use the interior Airlock prompt. The diver appears at AirlockExit. |
| Swim | `{direction = Vector3}` | Send a camera-relative input converted to a world vector at about 8 Hz while held. Include vertical input. Send zero on release. Input expires after 0.65 s. |
| Brace | `{site = "Keel"}` | Use a live colony's prompt. Valid IDs are Port, Starboard, Stern and Keel. The suit holds position until release. |
| Cut | `{challengeId = id, strikeTime = t, sequence = 1}` | Use the current dial ID. Timestamp the click/tap/button edge locally. Increment sequence for each attempt on this dial. |
| Cancel | `{}` | Release the brace immediately. Held swim input must resume sending. |
| Return | `{}` | Approach the exterior AirlockExit and use its prompt. Oxygen refills for the next outing. |

The 5 Hz `snapshot.eva` is shared by crewmates. Render personal EVA controls only when `eva.userId == LocalPlayer.UserId`. Idle state is `{mode = "Inside", predatorDanger = false}`. Active examples follow.

```lua
{mode = "Swimming", userId = 17, position = Vector3.new(16,133,20),
 oxygen = 51.4, oxygenMax = 55, predatorDanger = false}

{mode = "Braced", userId = 17, position = Vector3.new(0,125,0),
 oxygen = 38.1, oxygenMax = 55, predatorDanger = true, site = "Keel",
 challenge = {id = "GUID", startedAt = 190.5, period = 1.7, arcStart = 0.32, arcWidth = 0.23}}
```

The indicator advances clockwise in turns from 12 o'clock. Its phase is `((workspace:GetServerTimeNow() - challenge.startedAt) / challenge.period) % 1`. Draw the target from `arcStart` through `arcStart + arcWidth`. One attempt consumes that rotation, including a miss. The server accepts strikes up to 0.22 s old with 0.04 s of clock tolerance. Success adds one cut to `snapshot.dive.patches[site].cuts`. The third cut clears the colony and returns the diver to swimming. Cancel, return, death and diver swaps preserve cuts. A new infestation has new patch records.

Show an oxygen gauge and the predator warning on the diver's HUD. Voyage measures distance from the swimmer to the bodies of visible Angler, Squid and Pursuer actors. Proximity increases oxygen consumption and close contact drains health. The Oxygen trait increases starting oxygen. Keep water fog and the visible range local to the diver's view. A server Beam connects the suit to the external hatch.

The world builder should provide an outward-facing, noncollidable AirlockExit outside the hull with clearance for the avatar. With only an interior Airlock, the suit uses a point outside the nearest port, starboard or stern colony marker. Without any side markers it uses eight studs along the console's look direction. Each Sites marker belongs on the outside surface, visible to the approach from the corresponding face. Leave enough water between keel and seabed for the suit. The reference fixture uses a 52-stud hull, an 83-stud tether and a 1.55-stud swim collision radius.
