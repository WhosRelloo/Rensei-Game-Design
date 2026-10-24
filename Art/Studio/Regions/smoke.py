"""The region import smoke test (Region Foundation final fix pass, 2026-10-24): a real Testbed import into Foundry Yard,
played, then undone. Foundry only, never Ye; never publish.

python -I Art/Studio/Regions/smoke.py [--work <dir>] [--steps snap,kit,dry,real,play,setup,restore,snap2]
                                      [--hook <hook.lua>] [--unhook <unhook.lua>] [--lock <name>]

Steps (all by default, in this order; each prints Studio's answer and stops the run on a failure):
  snap     Foundry's state before: World.Map children, every tag's count, MaterialService, ServerStorage (and the
           RenseiBackups folders), terrain cells and a voxel digest of the smoke's area -> <work>/before.txt
  kit      kit.py Testbed --place 109591196441030 --map-child TestbedSmoke --keep Foundry --offset 4000,0,4000
           --out <work>/kit (the committed Testbed import is not touched)
  dry      the chunk, then finish.lua with DryRun = true (expects "dry run ok", the keep report: move nothing, keep Foundry)
  real     the chunk, then finish.lua with Confirm = "Testbed" (the real swap: Map.TestbedSmoke beside Map.Foundry)
  play     installs Play_RegionSmoke in ServerStorage.RenseiTests, takes PlayLock, installs the save hook, starts Play,
           waits for LMSnapTaken, runs the suite in the game VM, restores the save, stops Play, removes the hook and the
           suite, clears PlayLock (the cleanup runs even when the suite fails)
  setup    adds two RenseiMarker parts to Map.TestbedSmoke (a TrainerSpot, which setup must skip, and a RoadPassage with
           Arrival = false, its attributes in region coordinates), runs setup.lua (bundle_setup.py --region Testbed
           --map-child TestbedSmoke --origin 4000,0,4000: the attributes are in region coordinates, moved by --offset),
           then the contract test on workspace.World.Map.TestbedSmoke
  restore  restore.lua (Map.TestbedSmoke and the kit's MaterialVariant go to RenseiBackups.Post-Region_Testbed_<date>,
           the terrain under the water box is pasted back), then removes that Post-Region backup (this test's own)
  snap2    Foundry's state after -> <work>/after.txt, compared line by line with before.txt
The save hook is the controller's (context.md): Play writes the owner's REAL save."""
import json, os, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
RBXC = os.path.join(REPO, "Art", "Tools", "rbxc.py")
PLACE = 109591196441030
MATCH = f"placeId: {PLACE}"
OFFSET = "4000,0,4000"
STEPS = ("snap", "kit", "dry", "real", "play", "setup", "restore", "snap2")
JOB = "C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender"

SNAP = r'''
local CS = game:GetService("CollectionService")
local Out = {}
local Map = workspace.World.Map
local L = {}
for _, C in ipairs(Map:GetChildren()) do table.insert(L, C.Name .. "(" .. #C:GetDescendants() .. ")") end
table.sort(L)
table.insert(Out, "Map=" .. table.concat(L, ","))
local T = {}
for _, Tag in ipairs(CS:GetAllTags()) do
	local N = #CS:GetTagged(Tag)
	if N > 0 then table.insert(T, Tag .. "=" .. N) end
end
table.sort(T)
table.insert(Out, "tags=" .. table.concat(T, ","))
local M = {}
for _, C in ipairs(game:GetService("MaterialService"):GetChildren()) do table.insert(M, C.ClassName .. ":" .. C.Name) end
table.sort(M)
table.insert(Out, "MaterialService=" .. table.concat(M, ","))
local S = {}
for _, C in ipairs(game.ServerStorage:GetChildren()) do table.insert(S, C.Name .. "(" .. #C:GetDescendants() .. ")") end
table.sort(S)
table.insert(Out, "ServerStorage=" .. table.concat(S, ","))
local B = game.ServerStorage:FindFirstChild("RenseiBackups")
local BL = {}
for _, C in ipairs(B and B:GetChildren() or {}) do table.insert(BL, C.Name .. "(" .. #C:GetDescendants() .. ")") end
table.sort(BL)
table.insert(Out, "RenseiBackups=" .. table.concat(BL, ","))
local Tests = {}
for _, C in ipairs(game.ServerStorage.RenseiTests:GetChildren()) do table.insert(Tests, C.Name) end
table.sort(Tests)
table.insert(Out, "RenseiTests=" .. table.concat(Tests, ","))
local Ter = workspace.Terrain
table.insert(Out, "terrain cells=" .. Ter:CountCells())
local R = Region3.new(Vector3.new(3840, -40, 3840), Vector3.new(4160, 80, 4160)):ExpandToGrid(4)
local Mats, Occ = Ter:ReadVoxels(R, 4)
local Sum, Water = 0, 0
for X = 1, Occ.Size.X do for Y = 1, Occ.Size.Y do for Z = 1, Occ.Size.Z do
	Sum += Occ[X][Y][Z]
	if Mats[X][Y][Z] == Enum.Material.Water then Water += 1 end
end end end
table.insert(Out, ("smoke-area voxels: occupancy %.3f, water %d"):format(Sum, Water))
table.insert(Out, "PlayLock=" .. tostring(game.ServerStorage:GetAttribute("PlayLock")) .. " LMSnapTaken=" .. tostring(game.ServerStorage:GetAttribute("LMSnapTaken")))
table.insert(Out, "hook=" .. tostring(game.ServerScriptService:FindFirstChild("LMTestHook_TEMP") ~= nil) .. " staging=" .. tostring(game.ServerStorage:FindFirstChild("RegionStaging") ~= nil))
return table.concat(Out, "\n")
'''

# the setup markers: region coordinates (the import is moved by OFFSET; setup's ORIGIN adds it back)
MARKERS = r'''
local CS = game:GetService("CollectionService")
local HS = game:GetService("HttpService")
local Root = workspace.World.Map:FindFirstChild("TestbedSmoke")
if not Root then return "markers refused: no World.Map.TestbedSmoke" end
local O = Vector3.new(%s)
local Old = Root:FindFirstChild("SmokeMarkers")
if Old then Old:Destroy() end
local F = Instance.new("Model")
F.Name = "SmokeMarkers"
local function Marker(Name, At, Attr)
	local P = Instance.new("Part")
	P.Name, P.Size, P.Anchored = Name, Vector3.new(2, 2, 2), true
	P.Transparency, P.CanCollide, P.CanQuery, P.CanTouch = 1, false, false, false
	P.CFrame = CFrame.new(O + At + Vector3.new(0, 1, 0))
	for K, V in pairs(Attr) do P:SetAttribute(K, V) end
	CS:AddTag(P, "RenseiMarker")
	P.Parent = F
end
Marker("TrainerSpot0", Vector3.new(-30, 4, -60), {Piece = "TrainerSpot", Trainer = "Calda", Element = "Flame"})
Marker("RoadPassage0", Vector3.new(-100, 4, -100), {Piece = "RoadPassage", Route = "SmokeRoad", To = "Foundry",
	RoadName = "The Smoke Road", Legs = HS:JSONEncode({{"line", -100, -100, 100, -100}}), Threshold = 150, RoadStart = 20,
	Encounters = "[60]", Half = 8, RoadY = 4, Seed = 1, Arrival = false, Name = "SmokeRoad"})
F.Parent = Root
return "markers: 2 RenseiMarker parts in " .. F:GetFullName()
'''

CLEANUP = r'''
local B = game.ServerStorage:FindFirstChild("RenseiBackups")
local Gone = {}
for _, C in ipairs(B and B:GetChildren() or {}) do
	if C.Name:sub(1, 19) == "Post-Region_Testbed" and C:GetAttribute("RegionKitRegion") == "Testbed"
		and C:GetAttribute("MapChild") == "TestbedSmoke" then
		table.insert(Gone, C.Name .. "(" .. #C:GetDescendants() .. ")")
		C:Destroy()
	end
end
return "cleanup: removed the smoke's own " .. (#Gone > 0 and table.concat(Gone, ", ") or "nothing")
'''


def run(args, timeout=600):
    r = subprocess.run([sys.executable, "-I", RBXC] + args, capture_output=True, text=True, encoding="utf-8", timeout=timeout)
    return (r.stdout + r.stderr).strip()


def luau(work, name, code, ctx="Edit"):
    path = os.path.join(work, name)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(code)
    return run(["luau", MATCH, ctx, "@" + path])


def luau_file(path, ctx="Edit"):
    return run(["luau", MATCH, ctx, "@" + path])


def studio_id():
    d = json.loads(run(["studios"]))
    ids = [s["id"] for s in d["studios"] if MATCH in s["name"]]
    if len(ids) != 1:
        raise SystemExit(f"Foundry Studio not found exactly once: {d}")
    return ids[0]


def play(on):
    return run(["call", "start_stop_play", json.dumps({"is_start": on, "studio_id": studio_id()})])


def say(step, text):
    print(f"== {step}\n{text}\n", flush=True)


def need(step, text, prefix):
    say(step, text)
    if not text.startswith(prefix):
        raise SystemExit(f"smoke: step {step} failed (expected '{prefix}...')")


def main(argv):
    def opt(flag, default):
        return argv[argv.index(flag) + 1] if flag in argv else default
    work = os.path.abspath(opt("--work", tempfile.mkdtemp(prefix="region_smoke_")))
    os.makedirs(work, exist_ok=True)
    steps = opt("--steps", ",".join(STEPS)).split(",")
    hook, unhook = opt("--hook", f"{JOB}/hook.lua"), opt("--unhook", f"{JOB}/unhook.lua")
    lock = opt("--lock", "region-smoke")
    kitdir = os.path.join(work, "kit")
    imp = os.path.join(kitdir, "import")
    print("work folder:", work)
    for s in steps:
        if s not in STEPS:
            raise SystemExit(f"unknown step {s}; steps: {', '.join(STEPS)}")
    if "snap" in steps:
        out = luau(work, "snap.lua", SNAP)
        say("snap", out)
        open(os.path.join(work, "before.txt"), "w", encoding="utf-8").write(out)
    if "kit" in steps:
        sys.path.insert(0, HERE)
        import kit
        kit.main(["Testbed", "--place", str(PLACE), "--map-child", "TestbedSmoke", "--keep", "Foundry",
                  "--offset", OFFSET, "--out", kitdir])
    chunk = os.path.join(imp, "chunk_01.lua")
    finish = open(os.path.join(imp, "finish.lua"), encoding="utf-8").read() if os.path.exists(imp) else ""
    if "dry" in steps:
        need("dry chunk", luau_file(chunk), "chunk 1/1")
        need("dry", luau(work, "dry.lua", 'game.ServerStorage.RegionStaging:SetAttribute("DryRun", true)\n' + finish),
             "dry run ok")
    if "real" in steps:
        need("real chunk", luau_file(chunk), "chunk 1/1")
        need("real", luau(work, "real.lua", 'game.ServerStorage.RegionStaging:SetAttribute("Confirm", "Testbed")\n' + finish),
             "finish:")
    if "play" in steps:
        src = open(os.path.join(HERE, "Play_RegionSmoke.lua"), encoding="utf-8").read()
        if "]==]" in src:
            raise SystemExit("Play_RegionSmoke.lua contains ]==]")
        lock_code = ('local L = game.ServerStorage:GetAttribute("PlayLock")\n'
                     f'if L ~= nil and L ~= "{lock}" then return "locked by " .. tostring(L) end\n'
                     f'game.ServerStorage:SetAttribute("PlayLock", "{lock}")\n'
                     'local Old = game.ServerStorage.RenseiTests:FindFirstChild("Play_RegionSmoke")\n'
                     'if Old then Old:Destroy() end\n'
                     'local M = Instance.new("ModuleScript")\nM.Name = "Play_RegionSmoke"\n'
                     f'M.Source = [==[{src}]==]\nM.Parent = game.ServerStorage.RenseiTests\nreturn "locked; suite installed"')
        for _ in range(12):  # wait for another session's PlayLock (30 s at a time, about 6 minutes)
            out = luau(work, "lock.lua", lock_code)
            if out.startswith("locked;"):
                break
            say("play lock", out)
            time.sleep(30)
        else:
            raise SystemExit("smoke: PlayLock stayed taken")
        say("play lock", out)
        try:
            need("hook", luau_file(hook), "hook installed")
            say("play start", play(True))
            wait = ('local T0 = os.clock()\nrepeat task.wait(0.5) until game.ServerStorage:GetAttribute("LMSnapTaken") '
                    'or os.clock() - T0 > 60\nreturn "snap=" .. tostring(game.ServerStorage:GetAttribute("LMSnapTaken"))')
            out = ""
            for _ in range(10):
                out = luau(work, "wait.lua", wait, "Server")
                if out.startswith("snap=") and out != "snap=nil":
                    break
                time.sleep(3)
            say("save snapshot", out)
            if not out.startswith("snap=") or out == "snap=nil":
                raise SystemExit("smoke: the save hook took no snapshot; the suite was not run")
            res = luau(work, "suite.lua", 'local R = game.ServerStorage.LMRunSuite:Invoke("Play_RegionSmoke")\n'
                                          'return typeof(R) == "string" and R or tostring(R)', "Server")
            say("Play_RegionSmoke", res)
            open(os.path.join(work, "suite.txt"), "w", encoding="utf-8").write(res)
        finally:
            say("save restore", luau(work, "restore_save.lua", 'return tostring(game.ServerStorage.LMTestHook:Invoke("restore"))', "Server"))
            say("play stop", play(False))
            time.sleep(3)
            say("unhook", luau_file(unhook))
            say("unlock", luau(work, "unlock.lua", 'local M = game.ServerStorage.RenseiTests:FindFirstChild("Play_RegionSmoke")\n'
                                                  'if M then M:Destroy() end\n'
                                                  f'if game.ServerStorage:GetAttribute("PlayLock") == "{lock}" then '
                                                  'game.ServerStorage:SetAttribute("PlayLock", nil) end\n'
                                                  'return "suite removed; PlayLock=" .. tostring(game.ServerStorage:GetAttribute("PlayLock"))'))
    if "setup" in steps:
        need("setup markers", luau(work, "markers.lua", MARKERS % OFFSET.replace(",", ", ")), "markers:")
        bundle = os.path.join(work, "setup_bundle.lua")
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "bundle_setup.py"), "setup", bundle, "--region", "Testbed",
                        "--map-child", "TestbedSmoke", "--origin", OFFSET], check=True)
        need("setup", luau_file(bundle), "setup ok")
        check = os.path.join(work, "contract.lua")
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "bundle_setup.py"), "contract", check,
                        "workspace.World.Map.TestbedSmoke"], check=True)
        say("contract (TestbedSmoke, place-wide)", luau_file(check))
    if "restore" in steps:
        need("restore", luau_file(os.path.join(imp, "restore.lua")), "restore:")
        say("cleanup", luau(work, "cleanup.lua", CLEANUP))
    if "snap2" in steps:
        out = luau(work, "snap.lua", SNAP)
        open(os.path.join(work, "after.txt"), "w", encoding="utf-8").write(out)
        before_path = os.path.join(work, "before.txt")
        if os.path.exists(before_path):
            before = open(before_path, encoding="utf-8").read()
            diff = [f"  before: {a}\n  after:  {b}" for a, b in zip(before.splitlines(), out.splitlines()) if a != b]
            say("snap2", out + ("\nFoundry is exactly as before" if before == out else "\nCHANGED:\n" + "\n".join(diff)))
            if before != out:
                raise SystemExit("smoke: Foundry differs from before")
        else:
            say("snap2", out)


if __name__ == "__main__":
    main(sys.argv[1:])
