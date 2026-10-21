-- World Plan 1 (2026-10-20): installs the TEMP profile hook used by every Play test in this plan.
-- Run in Edit mode on Ye. It snapshots the tester's Profile.Data on load and exposes
-- ServerStorage.LMTestHook (BindableFunction) with "diff" (changed top-level keys) and "restore".
-- Same as the Lindenmoor kit test hook, except DataManager is found with WaitForChild, because after
-- Task 3 the hook is cloned into ServerScriptService by RenseiBoot. Delete LMTestHook_TEMP (in
-- ServerStorage.RenseiServer after Task 3) and ServerStorage.LMTestHook when the tests are done.
local S = Instance.new("Script")
S.Name = "LMTestHook_TEMP"
S.Source = [==[
if not game:GetService("RunService"):IsStudio() then return end -- never runs on a live server (RenseiServer is cloned into every server and becomes a Package)
-- TEMP: snapshot the tester's profile on load, restore on demand. Delete after.
local Players = game:GetService("Players")
local HS = game:GetService("HttpService")
local DM = require(game.ServerScriptService:WaitForChild("CharacterHandler"):WaitForChild("DataManager"))
local function copy(t) if type(t) ~= "table" then return t end local r = {} for k, v in pairs(t) do r[k] = copy(v) end return r end
local Snap = {}
local BF = Instance.new("BindableFunction")
BF.Name = "LMTestHook"
BF.OnInvoke = function(Op, Name)
	local P = Players:FindFirstChild(Name or "") or Players:GetPlayers()[1]
	local Prof = P and DM:GetProfile(P)
	if not Prof then return "no profile" end
	if Op == "diff" then
		local d = {}
		for k, v in pairs(Prof.Data) do
			local ok1, a = pcall(HS.JSONEncode, HS, v)
			local ok2, b = pcall(HS.JSONEncode, HS, Snap[P] and Snap[P][k])
			if not (ok1 and ok2 and a == b) then table.insert(d, k) end
		end
		return table.concat(d, ",")
	elseif Op == "restore" then
		for k in pairs(Prof.Data) do if Snap[P][k] == nil then Prof.Data[k] = nil end end
		for k, v in pairs(Snap[P]) do Prof.Data[k] = copy(v) end
		return "restored"
	end
end
BF.Parent = game.ServerStorage
local function Take(P)
	local Prof = DM:WaitProfile(P, 60)
	if Prof then Snap[P] = copy(Prof.Data) game.ServerStorage:SetAttribute("LMSnapTaken", P.Name) end
end
Players.PlayerAdded:Connect(Take)
for _, P in ipairs(Players:GetPlayers()) do task.spawn(Take, P) end
]==]
-- After Task 3 the hook lives in RenseiServer like every server script (RenseiBoot clones it in).
S.Parent = game.ServerStorage:FindFirstChild("RenseiServer") or game.ServerScriptService
return "hook installed in " .. S.Parent:GetFullName()
