-- RenseiBoot (World plan 1, 2026-10-20): every place ships the same server code as the Package
-- ServerStorage.RenseiServer; this copies it into ServerScriptService at server start, ModuleScripts first,
-- so every ServerScriptService.<Name> path in the code still works. Edit server code in RenseiServer, not here.
-- The package's PackageLink is skipped (it can't be cloned), and each child is copied on its own, so one bad
-- child can never stop the rest from starting.
local SSS = game:GetService("ServerScriptService")
local Bundle = game:GetService("ServerStorage"):WaitForChild("RenseiServer")
local function Copy(C)
	local Ok, Err = pcall(function() C:Clone().Parent = SSS end)
	if not Ok then warn("[RenseiBoot] couldn't copy " .. C.Name .. ": " .. tostring(Err)) end
end
local Later = {}
for _, C in ipairs(Bundle:GetChildren()) do
	if C:IsA("PackageLink") then continue end
	if C:IsA("ModuleScript") or C:IsA("Folder") then Copy(C) else table.insert(Later, C) end
end
for _, C in ipairs(Later) do Copy(C) end

