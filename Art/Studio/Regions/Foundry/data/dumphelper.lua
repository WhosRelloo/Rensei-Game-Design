-- dumphelper.lua (Foundry data plan, Ruling 19): the save check for every hooked Play session in this plan.
-- It installs a TEMP Script, LMQuestDump_TEMP, in ServerScriptService. In Play that Script adds the BindableFunction
-- ServerStorage.LMQuestDump, which returns a canonical dump of a player's Data.Quests: recursive, keys sorted, as one
-- string. The dump has to run in the game VM, because the execute_luau sandbox has its own require cache and can't
-- see DataManager's profiles.
--
-- How to use it (Global Constraints, the Play protocol):
--   1. In Edit, after hook.lua (step 2), install it in the playing place:
--        python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua
--      It returns "dump helper installed".
--   2. In Play (Server), once ServerStorage.LMSnapTaken is set and before any suite runs, take the dump:
--        return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()   -- (optional arg: a player name)
--      Save it to the scratch folder as quests_<task>_1.txt. A dump over ~25,000 characters goes into a StringValue
--      in ServerStorage instead; read it back in 25,000-character chunks, then delete the value.
--   3. After LMTestHook:Invoke("restore") returns "restored", dump again (quests_<task>_2.txt). It must equal the
--      first dump character for character. If it differs: stop, keep Play running and report both dumps.
--   4. After Stop, in Edit, with unhook.lua (step 7), remove the helper:
--        for _, p in ipairs({game.ServerScriptService, game.ServerStorage}) do
--        	for _, c in ipairs(p:GetChildren()) do
--        		if c.Name == "LMQuestDump_TEMP" or c.Name == "LMQuestDump" then c:Destroy() end
--        	end
--        end
--      Then clear PlayLock as usual.
-- Studio only: the Script does nothing outside Studio. Never publish a place with LMQuestDump_TEMP in it.
if game:GetService("RunService"):IsRunning() then return "REFUSED: install in Edit, before Play" end
if game.ServerScriptService:FindFirstChild("LMQuestDump_TEMP") then return "dump helper already installed" end
local S = Instance.new("Script")
S.Name = "LMQuestDump_TEMP"
S.Source = [==[
if not game:GetService("RunService"):IsStudio() then return end
-- TEMP (Foundry data plan, the Play protocol's save check): canonical dump of a player's Data.Quests. Delete after.
local Players = game:GetService("Players")
local DM = require(game.ServerScriptService:WaitForChild("CharacterHandler", 60):WaitForChild("DataManager", 60))
local function Key(K) return type(K) == "string" and string.format("%q", K) or (type(K) .. ":" .. tostring(K)) end
local function Dump(V)
	if type(V) == "table" then
		local Keys = {}
		for K in pairs(V) do table.insert(Keys, K) end
		table.sort(Keys, function(A, B) return Key(A) < Key(B) end)
		local Out = {}
		for _, K in ipairs(Keys) do table.insert(Out, "[" .. Key(K) .. "]=" .. Dump(V[K])) end
		return "{" .. table.concat(Out, ",") .. "}"
	elseif type(V) == "string" then return string.format("%q", V)
	elseif type(V) == "number" then return string.format("%.17g", V)
	else return type(V) .. ":" .. tostring(V) end
end
local BF = Instance.new("BindableFunction")
BF.Name = "LMQuestDump"
BF.OnInvoke = function(Name)
	local P = Players:FindFirstChild(Name or "") or Players:GetPlayers()[1]
	local Prof = P and DM:GetProfile(P)
	if not Prof then return "no profile" end
	return Dump(Prof.Data.Quests)
end
BF.Parent = game.ServerStorage
]==]
S.Parent = game.ServerScriptService
return "dump helper installed"
