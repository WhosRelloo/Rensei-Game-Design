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
