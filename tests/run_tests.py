"""Runs the pure-Lua simulation tests. Needs: pip install lupa"""
import os, sys
from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT = root
harness = lua.execute(open(os.path.join(root, "tests", "harness.lua")).read())
test = lua.eval("function(src, H) return load(src, '@sim_test.lua')(H) end")
try:
    test(open(os.path.join(root, "tests", "sim_test.lua")).read(), harness)
except Exception as e:
    print(e)
    sys.exit(1)
