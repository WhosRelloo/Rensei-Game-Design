-- client_check.lua (assassinations Task 6b, 2026-10-27): the CLIENT check of the ragdoll hook. ClientHandler calls
-- Modules.Managers.Ragdoll.Watch on every character it gets; when the server marks that character Ragdolled (a finished
-- grip), the client, which owns the character's physics, puts its own Humanoid in Physics. Play only, run from the Server:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Ragdoll/client_check.lua
-- It needs the Play protocol's hook (the save is snapshotted) like every Play check, though it writes nothing saved.
-- It NEVER ragdolls, grips or kills the player's character (the owner's real character): the client clones its own
-- character (Archivable on for the clone only, put back at once), strips the clone's scripts and stands it on a local
-- floor at y 3500 (above both maps: their tops are under y 430), then marks only the CLONE Ragdolled.
-- What it makes (Play copies, all removed before it returns): the RemoteEvent ReplicatedStorage.RagdollCheck_TEMP_Remote
-- (the client's answer comes back over it) and the LocalScript RagdollCheck_TEMP in the player's PlayerGui (plugin
-- security sets its Source), which removes its clone and floor itself.
-- Checks (TestKit's "PASS n / FAIL n" lines):
--   Watched: Ragdoll.IsWatched(the current character) -- ClientHandler hooked it.
--   CloneGoesLimp: a watched clone not marked stays out of Physics (control); marked Ragdolled, its Humanoid is in the
--     Physics state with PlatformStand within 0.5 s.
if not game:GetService("RunService"):IsRunning() then return "REFUSED: Play only" end

local CLIENT = [==[
-- RagdollCheck_TEMP (Play only; made by Art/Studio/Ragdoll/client_check.lua, gone at Stop): the client half.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remote = RS:WaitForChild("RagdollCheck_TEMP_Remote", 30)
local Player = Players.LocalPlayer
local Lines, Pass, Fail = {}, 0, 0
local function Check(Name, Fn)
	local Ok, Err = pcall(Fn)
	if Ok then Pass += 1 else Fail += 1 table.insert(Lines, "FAIL " .. Name .. ": " .. tostring(Err)) end
end
local Mod = RS.Modules.Managers:FindFirstChild("Ragdoll")
local Ragdoll = Mod and require(Mod)

Check("Watched", function()
	assert(Ragdoll and type(Ragdoll.IsWatched) == "function", "Ragdoll.IsWatched exists on the client")
	assert(Ragdoll.IsWatched(Player.Character), "ClientHandler watches the current character")
end)

Check("CloneGoesLimp", function()
	assert(Ragdoll and type(Ragdoll.Watch) == "function", "Ragdoll.Watch exists on the client")
	local C = Player.Character
	local At = C:GetPivot().Position
	local Was = C.Archivable
	C.Archivable = true
	local Ok, Rig = pcall(function() return C:Clone() end)
	C.Archivable = Was
	assert(Ok and Rig, "cloned the character: " .. tostring(Rig))
	local Floor = Instance.new("Part")
	Floor.Name = "RagdollCheck_TEMP_Floor"
	Floor.Anchored = true
	Floor.Size = Vector3.new(20, 1, 20)
	Floor.CFrame = CFrame.new(At.X, 3499.5, At.Z)
	Floor.Parent = workspace
	local Err
	local Fine = xpcall(function()
		for _, S in ipairs(Rig:GetDescendants()) do
			if S:IsA("LuaSourceContainer") then S:Destroy() end
		end
		Rig.Name = "RagdollCheck_TEMP_Rig"
		Rig:SetAttribute("Ragdolled", nil)
		Rig:PivotTo(CFrame.new(At.X, 3503, At.Z))
		Rig.Parent = workspace
		local H = Rig:FindFirstChildOfClass("Humanoid")
		assert(H, "the clone has a Humanoid")
		H.PlatformStand = false
		Ragdoll.Watch(Rig)
		task.wait(1) -- (it lands)
		assert(H:GetState() ~= Enum.HumanoidStateType.Physics and not H.PlatformStand,
			"control: not marked, not limp (" .. tostring(H:GetState()) .. ")")
		Rig:SetAttribute("Ragdolled", true)
		local T0 = os.clock()
		while H:GetState() ~= Enum.HumanoidStateType.Physics and os.clock() - T0 < 0.5 do task.wait() end
		assert(H:GetState() == Enum.HumanoidStateType.Physics, "marked Ragdolled: Physics (" .. tostring(H:GetState()) .. ")")
		assert(H.PlatformStand == true, "marked Ragdolled: PlatformStand")
	end, function(E) Err = E end)
	Rig:Destroy()
	Floor:Destroy()
	if not Fine then error(Err, 0) end
end)

table.insert(Lines, 1, string.format("PASS %d / FAIL %d", Pass, Fail))
Remote:FireServer(table.concat(Lines, "\n"))
]==]

local RS = game:GetService("ReplicatedStorage")
local P = game:GetService("Players"):GetPlayers()[1]
if not (P and P.Character) then return "no test player" end
if RS:FindFirstChild("RagdollCheck_TEMP_Remote") then return "REFUSED: a check is already running" end
local E = Instance.new("RemoteEvent")
E.Name = "RagdollCheck_TEMP_Remote"
E.Parent = RS
local Got
local Conn = E.OnServerEvent:Connect(function(From, Text) if From == P then Got = Text end end)
local L = Instance.new("LocalScript")
L.Name = "RagdollCheck_TEMP"
L.Source = CLIENT
L.Parent = P:WaitForChild("PlayerGui")
local T0 = os.clock()
while not Got and os.clock() - T0 < 30 do task.wait(0.1) end
Conn:Disconnect()
L:Destroy()
E:Destroy()
return Got or "no answer from the client in 30 s"
