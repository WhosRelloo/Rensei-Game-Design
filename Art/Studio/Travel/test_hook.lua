-- World Plan 1 (2026-10-20; updated Task 11, 2026-10-23, to the version every Play test in the plan used): installs the
-- TEMP profile hook. Run in Edit mode on the place you will Play (Ye or Foundry Yard). It goes into
-- ServerScriptService (RenseiServer is a Package, so it no longer goes there), is Studio-only, snapshots the tester's
-- Profile.Data on load (ServerStorage attribute LMSnapTaken = the player's name) and adds two BindableFunctions:
--   ServerStorage.LMTestHook:Invoke("diff" | "restore") -- "diff" compares JSON, so it lists keys whose tables merely
--                                                       -- iterate in another order, even straight after a restore;
--   ServerStorage.LMRunSuite:Invoke("Play_X")           -- runs RenseiTests.Play_X in the GAME VM (the execute_luau
--                                                       -- sandbox has its own require cache and sees no profiles).
-- After the tests: LMTestHook:Invoke("restore") from the Server datamodel, Stop, then delete LMTestHook_TEMP (in Edit).
local S = Instance.new("Script")
S.Name = "LMTestHook_TEMP"
S.Source = [==[
if not game:GetService("RunService"):IsStudio() then return end
-- TEMP (Lindenmoor kit play test, 2026-10-20): snapshot the tester's profile on load, restore on demand. Delete after.
local Players = game:GetService("Players")
local HS = game:GetService("HttpService")
local DM = require(game.ServerScriptService:WaitForChild("CharacterHandler", 60):WaitForChild("DataManager", 60)) -- waits for RenseiBoot's copy
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
local RS = Instance.new("BindableFunction") -- runs a test suite in the GAME VM (the sandbox has its own require cache)
RS.Name = "LMRunSuite"
RS.OnInvoke = function(Name)
	local TK = require(game.ServerStorage.RenseiTests.TestKit)
	local Ok, Res = pcall(function() return (TK.Run(require(game.ServerStorage.RenseiTests[Name]))) end)
	return Ok and Res or ("ERROR " .. tostring(Res))
end
RS.Parent = game.ServerStorage
local function Take(P)
	local Prof = DM:WaitProfile(P, 60)
	if Prof then Snap[P] = copy(Prof.Data) game.ServerStorage:SetAttribute("LMSnapTaken", P.Name) end
end
Players.PlayerAdded:Connect(Take)
for _, P in ipairs(Players:GetPlayers()) do task.spawn(Take, P) end
]==]
S.Parent = game.ServerScriptService
return "hook installed"
