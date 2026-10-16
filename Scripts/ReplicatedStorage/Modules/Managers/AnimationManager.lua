local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Assets = ReplicatedStorage.Assets
local Animations = Assets.Animations
local Remote = script.AnimationRemote

local AnimManager = {}
local LoadedAnims = {}
local AnimationTable = {}

-- Weapon animations (Animations.Weapons) were imported as KeyframeSequences and are NOT published
-- yet: their Animation has an empty AnimationId and the sequence as a child named "Save". In Studio
-- the sequence is registered as a temporary animation so it plays in playtests; in a live server it
-- cannot play until it is published (right-click the Save > Save to Roblox, paste the id into the
-- Animation's AnimationId), and the caller's Fallback animation plays instead.
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Registered = {}
-- Animation attribute StudioPrefersSave: a published animation with a corrected unpublished copy
-- (the Save child, e.g. the cleaned climb animations). Studio plays the copy; live keeps the id.
local function Playable(Animation)
	local PreferSave = Animation:GetAttribute("StudioPrefersSave") and RunService:IsStudio()
	if Animation.AnimationId ~= "" and not PreferSave then return Animation end
	if Registered[Animation] then return Registered[Animation] end
	local Save = RunService:IsStudio() and Animation:FindFirstChildOfClass("KeyframeSequence")
	if not Save then return Animation.AnimationId ~= "" and Animation or nil end
	local Ok, Id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, Save)
	if not Ok then return Animation.AnimationId ~= "" and Animation or nil end
	local Temp = Instance.new("Animation")
	Temp.Name = Animation.Name
	Temp.AnimationId = Id
	Registered[Animation] = Temp
	return Temp
end

for I,Animation in pairs(Animations:GetDescendants()) do
	if Animation:IsA("Animation") then
		AnimationTable[Animation.Name] = Animation
	end
end

local function Resolve(Name)
	local Animation = AnimationTable[Name]
	return Animation and Playable(Animation)
end

-- NOTE: no weak-keyed tables here. A weak table drops an Instance key (Track, Animator, Character)
-- as soon as Lua holds no other reference to it -- even while the Instance is alive -- which could
-- lose a frozen track's real speed and leave it stuck in the hitstop pose.
local NpcTracks = {} -- [NPC Character] = {[Animation] = Track}; dropped when the NPC is destroyed

-- Hitstop: freeze every playing track briefly. Overlapping hitstops (several victims in one
-- swing, or being hit during your own hitstop) used to save the already-frozen 0.02 speed as
-- the "original" and restore to it -- leaving the character stuck mid-pose. Each track's real
-- speed is now saved once, and restored when the LAST overlapping hitstop ends.
local FrozenSpeed = {} -- [Track] = {Speed = real speed, Animator = its animator}
local FrozenUntil = {} -- [Animator] = os.clock() deadline
local function FreezeAnimator(Animator, Duration)
	Duration = Duration or 0.06
	local Deadline = os.clock() + Duration
	if (FrozenUntil[Animator] or 0) >= Deadline then return end
	FrozenUntil[Animator] = Deadline
	for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
		if FrozenSpeed[Track] == nil then
			FrozenSpeed[Track] = {Speed = Track.Speed, Animator = Animator}
			Track:AdjustSpeed(0.02)
		end
	end
	task.delay(Duration, function()
		if FrozenUntil[Animator] ~= Deadline then return end -- a later hitstop owns the restore
		FrozenUntil[Animator] = nil
		for Track, F in pairs(FrozenSpeed) do
			if F.Animator == Animator then
				FrozenSpeed[Track] = nil
				if math.abs(Track.Speed - 0.02) < 1e-3 then Track:AdjustSpeed(F.Speed) end
			end
		end
	end)
end
-- a track (re)started during a hitstop plays at its own speed, not the frozen one
local function Unfreeze(Track)
	FrozenSpeed[Track] = nil
end

if RunService:IsClient() then
	function AnimManager.Initiate()
		local Player = Players.LocalPlayer
		local Character = Player.Character
		
		local function CharacterAdded(Character)
			-- CharacterAdded fires before the character's children replicate: on a respawn this used to
			-- error on Character.Humanoid and load NO animations for the new life ("Animation not found")
			local Humanoid = Character:WaitForChild("Humanoid", 10)
			local Animator = Humanoid and Humanoid:WaitForChild("Animator", 10)
			if not Animator or not Character.Parent then return end
			LoadedAnims[Character] = {}
			local Sources = Animations.Shared:GetDescendants()
			if Animations:FindFirstChild("Weapons") then
				for _, A in ipairs(Animations.Weapons:GetDescendants()) do table.insert(Sources, A) end
			end
			for I,Animation in pairs(Sources) do
				local Source = Animation:IsA("Animation") and Playable(Animation)
				if Source then
					LoadedAnims[Character][Animation.Name] = Animator:LoadAnimation(Source)
				end
			end
			
			local AnimateScript = Character:WaitForChild("Animate", 10)
			if not AnimateScript then return end
			AnimateScript.idle.Animation1.AnimationId = Animations.Shared.Movement.Default.Idle.AnimationId
			AnimateScript.walk.WalkAnim.AnimationId = Animations.Shared.Movement.Default.Walk.AnimationId
			AnimateScript.run.RunAnim.AnimationId = Animations.Shared.Movement.Default.Walk.AnimationId
		end
		
		if Character then task.spawn(CharacterAdded, Character) end
		
		Player.CharacterAdded:Connect(CharacterAdded)

		Player.CharacterRemoving:Connect(function(Character)
			if LoadedAnims[Character] then
				LoadedAnims[Character] = nil
			end
		end)
		
		Remote.OnClientEvent:Connect(function(Function,...)
			if AnimManager[Function] then
				return AnimManager[Function](Player.Character,...)
			end
		end)
	end
	
	function AnimManager.Has(Character, Animation)
		return LoadedAnims[Character] ~= nil and LoadedAnims[Character][Animation] ~= nil
	end

	function AnimManager.Play(Character,Animation,Data)
		Data = Data or {}
		if LoadedAnims[Character] and not LoadedAnims[Character][Animation] and Data.Fallback then
			Animation = Data.Fallback
		end
		if LoadedAnims[Character] and LoadedAnims[Character][Animation] then
			if Data.Stop then
				if LoadedAnims[Character][Data.Stop] then
					LoadedAnims[Character][Data.Stop]:Stop()
				else
					warn("Stop animation not found")
				end
			end
			local TimePosition = Data.TimePosition or 0
			local Speed = Data.Speed or 1
			LoadedAnims[Character][Animation].Priority = Data.Priority or LoadedAnims[Character][Animation].Priority
			LoadedAnims[Character][Animation].Looped = Data.Looped
			-- Play() resets the speed to 1, so the speed is applied after it.
			LoadedAnims[Character][Animation]:Play()
			Unfreeze(LoadedAnims[Character][Animation])
			if Data.Reverse then
				-- played backwards from its last frame (sheathing with an equip animation)
				LoadedAnims[Character][Animation]:AdjustSpeed(-Speed)
				TimePosition = math.max(0, LoadedAnims[Character][Animation].Length - 0.02)
			else
				LoadedAnims[Character][Animation]:AdjustSpeed(Speed)
			end
			LoadedAnims[Character][Animation].TimePosition = TimePosition
			
			if Data.After then
				coroutine.wrap(function()
					LoadedAnims[Character][Animation].Stopped:Wait()
					AnimManager.Play(Character,Data.After)
				end)()
			end
			return LoadedAnims[Character][Animation]
		else
			warn("Animation not found:", Animation)
		end
	end

	function AnimManager.Stop(Character,Animation)
		-- silent when missing: an unpublished weapon animation is simply not loaded
		if LoadedAnims[Character] and LoadedAnims[Character][Animation] then
			LoadedAnims[Character][Animation]:Stop()
		end
	end

	function AnimManager.GetPlayingAnims(Character)
		local PlayingAnims = {}
		if LoadedAnims[Character] then
			for I,Anim in pairs(LoadedAnims[Character]) do
				if Anim.IsPlaying then
					table.insert(PlayingAnims,Anim)
				end
			end
		end
		return PlayingAnims
	end
	
	function AnimManager.StopAllAnims(Character)
		for I,Anim in pairs(AnimManager.GetPlayingAnims(Character)) do
			Anim:Stop()
		end
	end

	-- Hitstop: freeze every playing track briefly, then restore its speed.
	function AnimManager.Hitstop(Character, Duration)
		local Animator = Character and Character:FindFirstChildOfClass("Humanoid") and Character.Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then return end
		FreezeAnimator(Animator, Duration)
	end
else
	function AnimManager.Play(Character,Animation,Data)
		Data = Data or {}
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player,"Play",Animation,Data)
		else
			if Data.Stop then
				AnimManager.StopAllAnims(Character)
			end
			
			local Source = Resolve(Animation) or (Data.Fallback and Resolve(Data.Fallback))
			if not Source then return end
			-- one track per NPC per animation (loading a fresh track every attack piles them up)
			if not NpcTracks[Character] then
				NpcTracks[Character] = {}
				Character.Destroying:Once(function() NpcTracks[Character] = nil end)
			end
			local Track = NpcTracks[Character][Source]
			if not Track then
				Track = Character.Humanoid.Animator:LoadAnimation(Source)
				NpcTracks[Character][Source] = Track
			end
			local TimePosition = Data.TimePosition or 0
			local Speed = Data.Speed or 1
			if Data.Priority then Track.Priority = Data.Priority end
			if Data.Looped ~= nil then Track.Looped = Data.Looped end
			Track:Play()
			Unfreeze(Track)
			if Data.Reverse then
				Track:AdjustSpeed(-Speed)
				TimePosition = math.max(0, Track.Length - 0.02)
			else
				Track:AdjustSpeed(Speed)
			end
			Track.TimePosition = TimePosition
			
			if Data.After then
				coroutine.wrap(function()
					Track.Stopped:Wait()
					AnimManager.Play(Character,Data.After)
				end)()
			end
		end
	end

	function AnimManager.Stop(Character,Animation)
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player,"Stop",Animation)
		else
			for Source, Track in pairs(NpcTracks[Character] or {}) do
				if Source.Name == Animation and Track.IsPlaying then Track:Stop() end
			end
		end
	end

	function AnimManager.GetPlayingAnims(Character)
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player,"GetPlayingAnims")
		else
			return Character.Humanoid.Animator:GetPlayingAnimationTracks()
		end
	end
	
	function AnimManager.Hitstop(Character, Duration)
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player, "Hitstop", Duration)
		else
			FreezeAnimator(Character.Humanoid.Animator, Duration)
		end
	end

	function AnimManager.StopAllAnims(Character)
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player,"StopAllAnims")
		else
			for I,Anim in pairs(AnimManager.GetPlayingAnims(Character)) do
				Anim:Stop()
			end
		end
	end
end




return AnimManager
