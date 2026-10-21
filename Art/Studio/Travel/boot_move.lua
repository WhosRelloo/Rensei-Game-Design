-- World Plan 1 Task 3 (2026-10-20), run once in Edit mode on Ye: moves every ServerScriptService child into
-- ServerStorage.RenseiServer and installs ServerScriptService.RenseiBoot (source: src/RenseiBoot.lua).
-- Back up first: RenseiBackups["Pre-WorldPlan1_2026-10-20"].SSS. Undo: move the RenseiServer children back, delete RenseiBoot.
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
assert(not SS:FindFirstChild("RenseiServer"), "already moved")
local Bundle = Instance.new("Folder")
Bundle.Name = "RenseiServer"
Bundle.Parent = SS
for _, C in ipairs(SSS:GetChildren()) do C.Parent = Bundle end
local Boot = Instance.new("Script")
Boot.Name = "RenseiBoot"
Boot.Source = [==[
-- RenseiBoot (World plan 1, 2026-10-20): every place ships the same server code as the Package
-- ServerStorage.RenseiServer; this copies it into ServerScriptService at server start, ModuleScripts first,
-- so every ServerScriptService.<Name> path in the code still works. Edit server code in RenseiServer, not here.
local SSS = game:GetService("ServerScriptService")
local Bundle = game:GetService("ServerStorage"):WaitForChild("RenseiServer")
local Later = {}
for _, C in ipairs(Bundle:GetChildren()) do
	if C:IsA("ModuleScript") or C:IsA("Folder") then C:Clone().Parent = SSS else table.insert(Later, C) end
end
for _, C in ipairs(Later) do C:Clone().Parent = SSS end
]==]
Boot.Parent = SSS
return ("moved %d; boot installed"):format(#Bundle:GetChildren())
