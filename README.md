# Thalassa live place

This VS Code checkout mirrors scripts from Roblox Studio place `133428803360145` in experience `10777975725`. Open this folder as your VS Code workspace. The earlier prototype is separately checked out.

`studio-place.json` maps the exported files to instances. The server entry point is DiveController and the client entry point is DiveClient. The network uses DiveNet.Input and DiveNet.Feed. The ship, launch dock, ocean, contacts and station markers are authored under Workspace.Thalassa. The geometry and other place assets remain in Roblox Studio. The source mirror does not run automatic sync.

Before updating Studio, confirm the place ID and coordinate with the other agent. Compare the live edit-mode source to the Git copy before writing a shared script. Keep lobby, render, simulation and station contracts from this place. The agent mailbox remains notes/messages.md on studio-sync-and-notes.
