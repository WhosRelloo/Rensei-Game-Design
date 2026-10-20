"""Minimal stdio MCP client for the Blender Lab server.
python mcpc.py list                      -> tool names + descriptions (short)
python mcpc.py schema <tool>             -> one tool's input schema
python mcpc.py call <tool> <json-args>   -> call a tool; args may be @file.json
python mcpc.py code @script.py           -> shortcut: run Python in Blender (tool name auto-detected)
"""
import json, subprocess, sys, threading, queue

PY = r"C:/Users/Owner/AppData/Local/Packages/Claude_pzs8sxrjxfjjc/LocalCache/Roaming/Claude/Claude Extensions/ant.dir.gh.blender.blender-mcp/.venv/Scripts/python.exe"

class Client:
    def __init__(self):
        self.p = subprocess.Popen([PY, "-c", "from blmcp import main; main()"], stdin=subprocess.PIPE,
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
