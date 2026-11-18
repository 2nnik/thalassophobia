#!/usr/bin/env python3
"""Builds build/Thalassophobia.rbxlx from src/ (no Rojo, no dependencies; Python 3 only).

Open the .rbxlx in Roblox Studio. Mapping:
  src/shared -> ReplicatedStorage.Shared
  src/server -> ServerScriptService.Server
  src/client -> StarterPlayer.StarterPlayerScripts.Client
  *.server.lua -> Script, *.client.lua -> LocalScript, *.lua -> ModuleScript, folders -> Folder

The repository is the source of truth. Edit files in src/, rebuild, reopen in Studio.
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "Thalassophobia.rbxlx")

_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%d" % _ref[0]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", source=None):
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        props += '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, ref(), props, children)


def script_class(filename):
    if filename.endswith(".server.lua"):
        return "Script", filename[: -len(".server.lua")]
    if filename.endswith(".client.lua"):
        return "LocalScript", filename[: -len(".client.lua")]
    if filename.endswith(".lua"):
        return "ModuleScript", filename[: -len(".lua")]
    return None, None


def folder_xml(path, name):
    kids = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            kids.append(folder_xml(full, entry))
        else:
            cls, base = script_class(entry)
            if cls:
                with open(full, encoding="utf-8") as f:
                    kids.append(item(cls, base, source=f.read()))
    return item("Folder", name, "".join(kids))


def build():
    shared = folder_xml(os.path.join(ROOT, "src", "shared"), "Shared")
    server = folder_xml(os.path.join(ROOT, "src", "server"), "Server")
    client = folder_xml(os.path.join(ROOT, "src", "client"), "Client")
    services = [
        item("Workspace", "Workspace"),
        item("ReplicatedStorage", "ReplicatedStorage", shared),
        item("ServerScriptService", "ServerScriptService", server),
        item("StarterPlayer", "StarterPlayer", item("StarterPlayerScripts", "StarterPlayerScripts", client)),
    ]
    xml = '<?xml version="1.0" encoding="utf-8"?>\n<roblox version="4">%s</roblox>\n' % "".join(services)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    return OUT


if __name__ == "__main__":
    print("wrote", os.path.relpath(build(), ROOT))
    sys.exit(0)
