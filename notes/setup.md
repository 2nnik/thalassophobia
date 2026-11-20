# Setup

## Studio connection
- No Rojo. Removed on 2026-11-20. Files here do **not** sync to Studio automatically.
- VS Code (Claude Code) talks to Studio through the Roblox Studio MCP, configured in `/.mcp.json`.
  It runs `%LOCALAPPDATA%\Roblox\mcp.bat`, which Studio's quick connect created.
- Studio must be open with the place loaded for the MCP to work.
- Claude Desktop also starts its own StudioMCP. If the two clash, close Claude Desktop.
- Codex does not read `.mcp.json`. Each Codex user adds the server to their own `~/.codex/config.toml`:
  ```toml
  [mcp_servers.Roblox_Studio]
  command = "cmd.exe"
  args = ["/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]
  ```
  (Or use Studio's quick connect for Codex, if it offers it.)

## Shared memory
- `AGENTS.md` is the shared instruction file (Codex reads it; `CLAUDE.md` just imports it).
- Notes live in `notes/` and are shared through git: commit and push after updating them, pull before starting.

## Place
- "Super cool game", placeId 82753323748432, universeId 10777977430 (saved to the cloud).

## Folder → Studio mapping
| Folder | Studio location |
|---|---|
| `src/ServerScriptService/` | ServerScriptService (server Scripts) |
| `src/StarterPlayerScripts/` | StarterPlayer > StarterPlayerScripts (LocalScripts) |
| `src/ReplicatedStorage/` | ReplicatedStorage (ModuleScripts shared by both sides) |

File suffixes: `.server.luau` = Script, `.client.luau` = LocalScript, plain `.luau` = ModuleScript.
A script with children becomes a folder: its own code goes in `init.server.luau` (or `init.client.luau` / `init.luau`),
children sit beside it. Example: `src/ServerScriptService/Server/` = the `Server` Script plus its child `FriendSyncCheck`.

## Syncing
- Studio (Team Create) is the live copy. Nothing syncs automatically in either direction.
- To update files from Studio, ask the agent to "pull scripts from Studio into src" (it reads them over the MCP).
- To push files into Studio, ask the agent to write the script into the matching Studio location.
