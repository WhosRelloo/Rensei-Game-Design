"""Build a Luau script that backs up and replaces Tutorial's AppearanceService + Customization with Ye's sources."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))


def src(name):
    b = open(os.path.join(HERE, name + ".lua"), "rb").read().replace(b"\r", b"")
    return b.decode("utf-8")


app, cus = src("appearance"), src("custom")
assert len(app.encode()) == 9542 and len(cus.encode()) == 19208, (len(app.encode()), len(cus.encode()))
for s in (app, cus):
    assert "]=====]" not in s
lua = f'''local SS = game:GetService("ServerStorage")
local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups"
Backups.Parent = SS
local B = Backups:FindFirstChild("Pre-HairSync_2026-10-20") or Instance.new("Folder")
B.Name = "Pre-HairSync_2026-10-20"
B.Parent = Backups
local function Replace(Old, Source)
	if not B:FindFirstChild(Old.Name) then
		local C = Old:Clone()
		C.Parent = B
	end
	local New = Instance.new("ModuleScript")
	New.Name = Old.Name
	New.Source = Source
	local Parent = Old.Parent
	Old:Destroy()
	New.Parent = Parent
	return #New.Source
end
local A = Replace(game.ServerScriptService.AppearanceService, [=====[{app}]=====])
local C = Replace(game.ReplicatedStorage.Modules.Data.Rensei.Customization, [=====[{cus}]=====])
return "AppearanceService " .. A .. " Customization " .. C
'''
open(os.path.join(HERE, "push.lua"), "w", encoding="utf-8", newline="\n").write(lua)
print("ok", len(lua))
