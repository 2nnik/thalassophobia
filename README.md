# Thalassophobia

A 1-4 player co-op horror game for Roblox. You share a cage, sink to the ocean floor, grab an artifact and ride back
up while five sea monsters hunt you. Design: [`docs/game-prompt.md`](docs/game-prompt.md). Agents: [`AGENTS.md`](AGENTS.md).

## Play it in Studio (no Rojo)
1. `python3 tools/build.py`
2. Open `build/Thalassophobia.rbxlx` in Roblox Studio and press Play.

Config.Places are `0` by default, which starts a run directly (no lobby). To use the lobby and matchmaking, publish the
same file to two places (lobby and run) and put their ids in `src/shared/Config.lua`.

## Controls (prototype)
Walk to a station and use its prompt: engine switch (stern), light console (bow; aim with the camera), extinguishers on
the walls, refill (stern), claw (bow, at the bottom), hatch (airlock). Hold the prompt on a crack to repair it.
Left mouse sprays the extinguisher, or scrubs the swarm when you're outside.

## Status
| Part | State |
|---|---|
| Simulation: stations, 5 monsters, director, economy rules, traits | done, 35 passing tests |
| Roblox glue, procedural cage, HUD, sonar, silhouettes | written, **not run in Studio yet** |
| Lobby, matchmaking, DataStore | written, **needs a published experience to test** |
| Sound, real art, tutorial, tuning | not started |

## Checks
```bash
pip install lupa
python3 tools/check.py
```
