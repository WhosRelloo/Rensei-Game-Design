local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Framework = Modules.Framework
local SkillModules = Modules.Skills

local BlockManager = require(Modules.Managers.BlockManager)
local ResourceManager = require(Modules.Managers.ResourceManager)
local Tuning = require(Modules.Data.Rensei.TuningConfig)
local DataManager = require(script.DataManager)
local ProgressionService = require(game:GetService("ServerScriptService"):WaitForChild("ProgressionService"))
local AnimManager = require(Modules.Managers.AnimationManager)
local MovementState = require(Modules.Managers.MovementState)
local WCS = require(Framework.WCS)
local WCSCharacter = WCS.Character

local Server = WCS.CreateServer()
Server:RegisterDirectory(SkillModules)
Server:Start()
-- EnemyService waits for this before creating enemy characters (WCS refuses them earlier)
script:SetAttribute("WCSStarted", true)

local Skills = {}

-- loop through movesetmodules and require them
for _,Module in pairs(SkillModules:GetDescendants()) do
	if Module:IsA("ModuleScript") then
		Skills[Module.Name] = require(Module)
	end
end

DataManager:Initiate()

Players.PlayerAdded:Connect(function(Player)
	local Combo = Instance.new("NumberValue")
	Combo.Name = "Combo"
	Combo.Parent = Player
	
	Player.CharacterRemoving:Connect(function(Character)
	end)
	Player.CharacterAdded:Connect(function(Character)
		repeat Character.Parent = workspace.World.Live task.wait(0.1) until Character.Parent == workspace.World.Live
		
		local CharacterState = WCSCharacter.new(Character)
		BlockManager.Initiate(Character)
		-- the server-owned traversal state ends on stun / knock / grip / carry / death (MovementState)
		MovementState.Track(Character, CharacterState)
		
		coroutine.wrap(function()
			-- (bounded: a player who leaves, or whose save never loads, doesn't leave this waiting forever)
			local Profile = DataManager:WaitProfile(Player, 60)
			if not Profile then return end
			
			local ProfileData = Profile.Data
			Skills["Fist"].new(CharacterState)
			Skills["Block"].new(CharacterState)
			Skills["Heavy"].new(CharacterState)
			Skills["Flashstep"].new(CharacterState)
			
			ProgressionService.ApplyCharacter(Player)
			-- the equipped weapon (inventory, not the hotbar) comes back on every spawn
			require(game:GetService("ServerScriptService").LoadoutService).Restore(Player)
			-- the look chosen in character creation (AppearanceService; default look until then)
			require(game:GetService("ServerScriptService").AppearanceService).ApplyIdentity(Character, ProfileData.Identity)
			DataManager:SendData(Player)
			
			local Humanoid = Character:WaitForChild("Humanoid")
			
			Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			end)
			
			Humanoid.Died:Once(function()
				CharacterState:Destroy()
			end)
			
		
		end)()
		
		
	end)
	
	Player.ChildRemoved:Connect(function(Character)
		Character:Destroy()
	end)
end)

Players.PlayerRemoving:Connect(function(Player)
	Player:Destroy()
end)

-- The client may only request the self-states its own movement code needs, with bounded
-- durations. Previously any state (IFrame, SuperArmor...) could be started for any duration,
-- and {"Stun", false} cancelled whatever Stun was active -- including combat hitstun.
local ClientStates = {
	Attacking = {MaxDuration = 0.3},
	-- Dash (Q): i-frames only if the server can charge the stamina (TuningConfig.Dash).
	-- (the Mastery skill tree: Acrobat lengthens the i-frames, Quick Step shortens the interval)
	IFrame = {MaxDuration = Tuning.Dash.IFrames, MinInterval = Tuning.Dash.Cooldown, Stamina = Tuning.Dash.Stamina,
		ExtraMax = "DashIFrames", IntervalMod = "DashCooldown"},
	Stun = {Toggle = true}, -- crouch hold
}
local SkillMods = require(Modules.Managers.SkillMods)
local LastClientState = {} -- [Player] = {[StateName] = os.clock()}
local CrouchStuns = require(Modules.Managers.AttackRunner).CrouchStuns -- [CharacterState] = the Stun crouch started

Players.PlayerRemoving:Connect(function(Player)
	LastClientState[Player] = nil
end)

ReplicatedStorage.Remotes.StateRemote.OnServerEvent:Connect(function(Player,States)
	if type(States) ~= "table" or #States > 2 then return end
	local Character = Player.Character
	local CharacterState = Character and WCSCharacter.GetCharacterFromInstance(Character)
	if not CharacterState then return end
	local Times = LastClientState[Player] or {}
	LastClientState[Player] = Times

	for _,StateInfo in ipairs(States) do
		if type(StateInfo) ~= "table" then continue end
		local StateName = StateInfo[1]
		local Duration = StateInfo[2]
		local Rule = type(StateName) == "string" and ClientStates[StateName]
		if not Rule or not Skills[StateName] then continue end

		if Rule.Toggle then
			if Duration == true then
				if not CrouchStuns[CharacterState] then
					local Status = Skills[StateName].new(CharacterState)
					Status:Start()
					CrouchStuns[CharacterState] = Status
				end
			elseif Duration == false then
				-- Only ever stop the Stun that crouching started.
				local Status = CrouchStuns[CharacterState]
				CrouchStuns[CharacterState] = nil
				if Status then Status:Stop() end
			end
		elseif typeof(Duration) == "number" and Duration == Duration and Duration > 0 then
			local Now = os.clock()
			local MinInterval = Rule.MinInterval and Rule.MinInterval * (Rule.IntervalMod and SkillMods.Mult(Character, Rule.IntervalMod) or 1)
			local MaxDuration = Rule.MaxDuration + (Rule.ExtraMax and SkillMods.Get(Character, Rule.ExtraMax) or 0)
			if MinInterval and Times[StateName] and Now - Times[StateName] < MinInterval then
				continue
			end
			if Rule.Stamina and not ResourceManager.Spend(Character, "Stamina", Rule.Stamina) then
				continue
			end
			Times[StateName] = Now
			Skills[StateName].new(CharacterState):Start(math.min(Duration, MaxDuration))
		end
	end
end)

for _,Dummy in pairs(workspace.World.Live:GetChildren()) do
	-- training dummies only: players and EnemyService enemies set themselves up
	if Dummy:GetAttribute("EnemyType") or Players:GetPlayerFromCharacter(Dummy) then continue end
	local CharacterState = WCSCharacter.new(Dummy)

	local Humanoid = Dummy:WaitForChild("Humanoid")
	Humanoid.MaxHealth = math.huge
	Humanoid.Health = math.huge
	
	BlockManager.Initiate(Dummy)

	if Dummy.Name == "Blocking" then
		Skills["Blocking"].new(CharacterState):Start()
		AnimManager.Play(Dummy,"BlockIdle",{Looped = true})
		
		task.spawn(function()
			while true do
				task.wait()
				if not CharacterState:HasStatusEffects({Skills["Blocking"]}) then
					repeat task.wait() until not CharacterState:HasStatusEffects({Skills["Stun"]})
					BlockManager.Negate(Dummy,-100)
					AnimManager.StopAllAnims(Dummy)
					AnimManager.Play(Dummy,"BlockIdle")

					Skills["Blocking"].new(CharacterState):Start()
				end

			end
		end)
		
	end
	
	if Dummy.Name == "Parry" then
		Skills["Parry"].new(CharacterState):Start()
		--AnimManager.Play(Dummy,"BlockIdle",{Looped = true})
	end
	
	if Dummy.Name == "Perfect Parry" then
		Skills["PerfectParry"].new(CharacterState):Start()
		--AnimManager.Play(Dummy,"BlockIdle",{Looped = true})
	end
	

	Humanoid.Died:Once(function()
		CharacterState:Destroy()
	end)

end