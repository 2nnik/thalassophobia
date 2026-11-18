#!/usr/bin/env python3
"""Checks everything that can be checked without Roblox Studio:
  1. every .lua file compiles (the code is kept to the Lua/Luau common subset on purpose)
  2. the simulation tests pass (tests/sim_test.lua)
  3. the place file builds and is well-formed XML
Needs: pip install lupa
"""
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build  # noqa: E402

lua = LuaRuntime()
compile_fn = lua.eval("function(src, name) local f, err = load(src, name) if not f then return err end end")
bad = 0
count = 0
for base in ("src", "tests"):
    for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
        for name in files:
            if name.endswith(".lua"):
                path = os.path.join(dirpath, name)
                with open(path, encoding="utf-8") as f:
                    err = compile_fn(f.read(), "@" + os.path.relpath(path, ROOT))
                count += 1
                if err:
                    bad += 1
                    print("SYNTAX", err)
print("compiled %d lua files, %d errors" % (count, bad))

tests = subprocess.run([sys.executable, os.path.join(ROOT, "tests", "run_tests.py")], capture_output=True, text=True)
print(tests.stdout.strip().splitlines()[-1] if tests.stdout.strip() else tests.stderr)
if tests.returncode:
    print(tests.stdout)
    bad += 1

ET.parse(build.build())
print("place file builds and parses")
sys.exit(1 if bad else 0)
