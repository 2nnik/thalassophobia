# Log

## 2026-11-20
- Removed Rojo (config, build files) and stopped the Rojo servers.
- Connected VS Code to Studio via the Roblox Studio MCP (`.mcp.json`).
- Added `src/ServerScriptService/Test.server.luau`, pushed it to Studio as ServerScriptService.Test, and play-tested it: it prints on start, player join and spawn.
- Renamed `src/` folders to match Studio services.
- Added `notes/` as shared memory and `AGENTS.md` so Claude Code and Codex both read it.
- Friend (Popularvino, via Codex + Team Create) edited `ServerScriptService.Server` and added `Server.FriendSyncCheck`.
  Pulled both into `src/ServerScriptService/Server/`.
