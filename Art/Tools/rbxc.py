"""Minimal stdio MCP client for the Roblox Studio MCP (StudioMCP.exe).
python rbxc.py studios                       -> connected Studio instances
python rbxc.py luau <name-substr> <Edit|Server|Client> @file.lua  -> execute_luau in the matching Studio
python rbxc.py list | schema <tool> | call <tool> <json-args or @file.json>
Runs its own StudioMCP.exe next to Claude Code's, so big generated Luau files go to Studio without passing through chat.
Match the Studio by place id (e.g. "placeId: 106992859583940" = Rensei/Ye); a name that matches 0 or 2+ Studios is refused.
"""
import json
import time, subprocess, sys, threading, queue

import glob, os
EXE = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe")), key=os.path.getmtime)[-1]

class Client:
    def __init__(self):
        self.p = subprocess.Popen([EXE], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        self.q = queue.Queue()
        threading.Thread(target=self._read, daemon=True).start()
        self.n = 0
        self.req("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "claude-code-script", "version": "1"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _read(self):
        for line in self.p.stdout:
            line = line.strip()
            if line:
                try:
                    self.q.put(json.loads(line))
                except ValueError:
                    pass

    def send(self, obj):
        self.p.stdin.write(json.dumps(obj) + "\n")
        self.p.stdin.flush()

    def req(self, method, params, timeout=300):
        self.n += 1
        my = self.n
        self.send({"jsonrpc": "2.0", "id": my, "method": method, "params": params})
        while True:
            msg = self.q.get(timeout=timeout)
            if msg.get("id") == my:
                return msg

    def close(self):
        try:
            self.p.kill()
        except Exception:
            pass

def main():
    c = Client()
    try:
        cmd = sys.argv[1]
        if cmd == "list":
            r = c.req("tools/list", {})
            for t in r["result"]["tools"]:
                print("-", t["name"], ":", (t.get("description") or "").split("\n")[0][:160])
        elif cmd == "schema":
            r = c.req("tools/list", {})
            for t in r["result"]["tools"]:
                if t["name"] == sys.argv[2]:
                    print(json.dumps(t, indent=1)[:6000])
        elif cmd == "studios":
            r = c.req("tools/call", {"name": "list_roblox_studios", "arguments": {}})
            print(r["result"]["content"][0]["text"])
        elif cmd == "luau":
            for attempt in range(10):  # Studio names can read null for a moment; retry before giving up
                r = c.req("tools/call", {"name": "list_roblox_studios", "arguments": {}})
                txt = r["result"]["content"][0]["text"]
                data = json.loads(txt)
                items = data if isinstance(data, list) else data.get("studios") or data.get("instances") or []
                hits = [i for i in items if sys.argv[2] in (i.get("name") or "")]
                if len(hits) == 1:
                    break
                time.sleep(2)
            if len(hits) != 1:
                print("studio match error:", [i.get("name") for i in items]); return
            src = sys.argv[4]
            code = open(src[1:], encoding="utf-8").read() if src.startswith("@") else src
            r = c.req("tools/call", {"name": "execute_luau", "arguments": {"code": code, "datamodel_type": sys.argv[3], "studio_id": hits[0]["id"]}}, timeout=600)
            res = r.get("result") or r.get("error")
            for part in (res.get("content") or []):
                if part.get("type") == "text":
                    print(part["text"][:30000])
            if res.get("isError"):
                print("(isError)")
        elif cmd in ("call", "code"):
            if cmd == "code":
                name = sys.argv[3] if len(sys.argv) > 3 else "execute_blender_code"
                src = sys.argv[2]
                code = open(src[1:], encoding="utf-8").read() if src.startswith("@") else src
                args = {"code": code}
            else:
                name = sys.argv[2]
                a = sys.argv[3] if len(sys.argv) > 3 else "{}"
                args = json.load(open(a[1:], encoding="utf-8")) if a.startswith("@") else json.loads(a)
            r = c.req("tools/call", {"name": name, "arguments": args})
            res = r.get("result") or r.get("error")
            if isinstance(res, dict) and "content" in res:
                for part in res["content"]:
                    if part.get("type") == "text":
                        print(part["text"][:30000])
                    else:
                        print("[", part.get("type"), "]")
                if res.get("isError"):
                    print("(isError)")
            else:
                print(json.dumps(res, indent=1)[:30000])
    finally:
        c.close()

if __name__ == "__main__":
    main()
