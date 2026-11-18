# Thalassophobia: build prompt

You are building **Thalassophobia**, a 1–4 player online co-op horror game. The players share a small submersible cage and descend to the ocean floor, retrieve an artifact, and ascend alive. They survive by keeping the cage's stations running and responding correctly to five kinds of sea monster. Mistakes get the whole crew killed.

## Platform and design decisions
- **Engine**: built in **Roblox Studio** (Luau). Use Roblox matchmaking/teleport services for queues, private servers for parties, and the built-in voice chat for communication. Game state is server-authoritative (server scripts own stations, battery, monsters, cracks; clients only send inputs).
- **Camera**: **first-person** only (lock the camera to first person).
- **Solo play** is allowed. With fewer players, monsters are **less active** (lower spawn rate and slower approach), scaling with player count.
- **Death payout**: if the crew dies they keep money **per depth reached**. Surviving with the artifact adds a bonus on top.
- **Monster overlap**: monsters can attack the cage **at the same time**. The spawn director may stack threats, so players have to prioritize.

## Core loop
1. **Lobby / matchmaking**: queue with other players, up to **4 players** per run (solo allowed). Friends can form a party. A host can pick the difficulty before the run.
2. **Descent**: the cage sinks. Threat frequency rises with depth. Players tend stations and react to monsters.
3. **Bottom**: the cage reaches the sea floor. One player (or the crew) picks up the **artifact**. This triggers the ascent.
4. **Ascent**: monsters are **much more active and aggressive** than on the way down. Power is already low and the cage is probably damaged.
5. **Results**: surviving with the artifact pays out money. Dying still pays out **money per depth reached**.
6. **Meta-progression**: spend money on **traits** (perks) that help in later runs. Traits are bought between runs and equipped before launch.

## The cage and its stations
The cage is a cramped, cage-like submersible with distinct sections that each hold a station. Players move around inside it and operate stations by interacting. A few stations must be tended all the time, so players have to split their attention.

- **Engine**: can be switched off and on. A running engine is loud.
- **Battery / power**: a global resource. Light, engine and other stations drain it. **If the battery hits zero, everyone dies.** Players must ration power, for example by turning the light off when not needed.
- **Light**: a controllable spotlight (aim and toggle). It drains battery while on.
- **Hull**: cracks appear over time and from impacts. They must be repaired at the crack's location.
- **Fire extinguisher(s)**: wall-mounted at set points in the cage.
- **Depth gauge / sonar**: shows depth and gives rough warning of incoming monsters.
- **Airlock / exit hatch**: lets one player leave the cage (see the swarm).

## The five monsters (four on the way down, plus one ascent-only)

### 1. The Leviathan Shark ("Engine Hunter")
- A very large shark-like creature that circles the cage and hunts by sound.
- **Counter**: when it is close, the engine must be **killed (shut off)** so the cage goes silent. Engine back on when it leaves.
- **Fail state**: if the engine is running while it is near, it attacks and the cage takes severe damage or the run ends.
- The player needs a clear warning cue (sonar blip, shadow, a low rumble) and a short reaction window.
- Tension: shutting the engine off stops propulsion and may affect other systems, and on the ascent it feeds the Pursuer.

### 2. The Giant Squid ("Light Pusher")
- A huge squid that approaches the cage from the dark and keeps creeping closer.
- **Counter**: a player must **aim the cage light at it** to push it back. Lighting it makes it retreat.
- **Fail state**: if it gets **too close**, the cage is crushed and everyone dies.
- The light drains **battery**, so players cannot keep it on all the time. This is the core power-versus-safety tension.
- It approaches in stages (far, near, very near, lethal), and the light only works if aimed at the right side.

### 3. The Crack Crawler ("Boarder")
- A creature that squeezes in through **unrepaired hull cracks** and enters the cage.
- **Prevention**: repair cracks before it arrives.
- **Counter once inside**: a player must **spray it with a fire extinguisher** in the section of the cage it is in, which makes it leave. The player has to be in the right section, and the extinguisher is limited (it runs out and has to be refilled or swapped).
- **Fail state**: if it is not driven out in time, it kills a player or damages stations.
- This forces a split of the crew: some fixing cracks, some guarding.

### 4. The Hull Swarm ("Barnacle Cloud")
- A swarm of small creatures that sticks to the outside of the cage and gradually damages or blinds it (for example blocking light or draining power).
- **Counter**: one player must **leave the cage through the airlock** and clear the swarm by hand. This is the riskiest job in the game.
- The player outside is on a **tether** with **limited oxygen** and a **short view distance**.
- **Risk**: leaving at the wrong time, while another monster is near, means that player **dies**. The crew inside must call out when it is safe to go, for example by watching sonar and the other monsters.
- It needs cooperation: the outside player cannot see everything, and the inside crew cannot reach the swarm.

### 5. The Pursuer ("Stillness Hunter", ascent only)
- Appears **only during the ascent**, never on the descent.
- It hunts the cage whenever the cage is **not moving upward**. Each second the cage is stopped or drifting, a hidden "catch-up" meter fills and the creature closes in visibly (sonar, shadow, sound).
- **If the cage stays stopped too long, it catches the cage and the run ends.**
- Resuming upward movement makes it fall back and the meter drain, so players cannot simply stop to fix everything. They must repair, fight other monsters and manage power **while still rising**.
- This creates a conflict with the shark: killing the engine to hide from the shark halts ascent and feeds the Pursuer. Players need a short, risky coasting window rather than a full stop. Tune this so it is hard but fair.
- It interacts with all the other stations, since being slow from damage or low battery also fills its meter.

## Difficulty settings
At least **Easy / Normal / Hard** (and optionally Nightmare). Difficulty scales:
- monster frequency and speed
- length of reaction windows
- battery drain rate and crack frequency
- how much more active everything is on the ascent
- the money reward multiplier

## Progression and traits
- Currency is earned per run, with bonuses for depth, for retrieving the artifact, for surviving, and for harder difficulties.
- **Traits** are purchased between runs. Examples:
  - longer battery life
  - a bigger light radius
  - a faster hull repair
  - a quieter engine
  - a larger extinguisher
  - more oxygen outside
- Some strong traits carry a **drawback** (for example a bigger battery that makes the light flicker, or a quieter engine that has less thrust).
- Traits should be helpful but never remove the need for teamwork. Avoid anything that makes a monster harmless.

## Multiplayer requirements
- Online matchmaking and private lobbies for 1–4 players.
- The game state (stations, battery, monsters, cracks) is **server-authoritative** and synced between players.
- Player voice (proximity or party voice) is strongly encouraged, since communication is the heart of the game.
- Handle players disconnecting mid-run without ending the session.

## Artifact
Picking up the artifact makes the cage **heavier and louder** (slower rise, more noise), so the ascent plays differently from the descent and not just harder.

## Tone and feel
Claustrophobic, dark, and tense, in the vein of a horror game about thalassophobia (fear of the deep ocean). Sparse HUD, strong sound design (creaking hull, muffled sonar pings, silence when the engine is off), dim lighting, and slow, dread-building pacing broken by sudden panic. The monsters should be seen mostly as silhouettes and shapes in the dark.

## Deliverables for the first milestone
1. A playable single-cage prototype for up to 4 players with the descent, bottom pickup and ascent.
2. All five station types working (engine, battery, light, hull/cracks, extinguisher), plus the airlock.
3. All five monsters implemented with their counters and fail states, including simultaneous attacks and the ascent-only Pursuer.
4. A basic lobby (Roblox matchmaking, 1-4 players), a difficulty selector, solo scaling, and a post-run results screen with money per depth.
5. A simple money system and a small shop with a handful of traits.

## Open questions
None blocking. Details such as exact numbers, art style and the shop's trait list can be tuned during prototyping.
