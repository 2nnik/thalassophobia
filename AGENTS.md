# Thalassophobia: instructions for coding agents (Claude Code, Codex, others)

Thalassophobia is a 1-4 player co-op horror game for **Roblox**. Players share a cage, descend, grab an artifact and
ascend while five sea monsters try to kill them. The full design is in `docs/game-prompt.md`. Read it first.

## Working agreement (applies to every agent)
- **Check the repo before every task**: this file, `README.md`, `docs/`, `notes/`, and the code you are about to touch.
- **Record what you do and what the user decides** in `notes/<YYYY-MM-DD>.md` (append, don't rewrite other agents' entries; start each entry with the agent name, e.g. `### Codex`). Commit it with the work.
- Two agents work in this repo. Pull before you start, keep commits small, and don't reformat files you aren't changing.

## No Rojo
The repo is the source of truth and there is no sync tool. Studio gets the project through a generated place file:
```bash
python3 tools/build.py     # writes build/Thalassophobia.rbxlx from src/ (open it in Roblox Studio)
python3 tools/check.py     # compile check + simulation tests + build (needs: pip install lupa)
```
Never edit `build/Thalassophobia.rbxlx` by hand. Edit `src/` and rebuild. Changes made inside Studio are NOT
saved back to the repo, so don't make code changes there. Rebuild and commit the `.rbxlx` along with source changes.

## Layout
- `src/shared/` -> ReplicatedStorage.Shared. `Config.lua` holds every tunable number; `Remotes.lua` creates remotes.
- `src/server/Sim/` -> **pure game simulation, no Roblox APIs** (Session, Director, Monsters/). This is where the rules live and the only code covered by tests.
- `src/server/Services/` -> Roblox glue: `RunController` (players, prompts, remotes), `CageBuilder`, `Economy` (DataStore), `Lobby` (matchmaking).
- `src/client/` -> HUD, input, monster silhouettes, lobby UI.
- File naming: `*.server.lua` = Script, `*.client.lua` = LocalScript, `*.lua` = ModuleScript, folders = Folder.
- `tests/` -> `sim_test.lua` run through `tests/run_tests.py` (Lua 5.4 via `lupa`, with a shim for `require(script.Parent.X)`).

## Rules for code
- **Server-authoritative**: clients only send input; the server validates and the Sim decides. Never trust remote arguments.
- Keep game rules in `Sim/` (testable). Keep Roblox API calls out of it. Pass config in, don't require `Shared` from `Sim`.
- Write Lua in the **Lua 5.1/5.4 + Luau common subset**: no type annotations, no `+=`, no `continue`, no `goto`. `tools/check.py` compiles files with plain Lua to enforce this.
- New tunables go in `Config.lua`, not inline.
- Add or update a test in `tests/sim_test.lua` for any change to `Sim/`. Run `python3 tools/check.py` before committing.
- Don't claim something works in Roblox unless it was run in Studio. Mark untested Roblox code as such.
