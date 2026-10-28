-- Player settings: defaults, and the validation rules the server applies before saving.
local Settings = {}

Settings.Defaults = {
	CameraShake = true,
	AutoSprint = false,
	ShiftLock = false,
	Shadows = true,
	SFXVolume = 0.5,
	MusicVolume = 0.5,
	-- 2026-10-15 settings update
	CombatLog = true, -- the in-combat badge at the top of the screen (CombatLogUI)
	Compass = true, -- the minimal compass strip at the top of the screen (CompassUI, 2026-10-18)
	PostEffects = true, -- bloom / sun rays / depth of field
	UIAnimations = true, -- UIMotion (off = menus snap, for anyone who prefers still UI)
	UISounds = true, -- menu open / close sounds
	FieldOfView = 0.25, -- slider 0..1 -> 60..100 degrees (0.25 = Roblox's 70)
	Keys = {
		Dash = "Q",
		Block = "F",
		LockTarget = "G", -- moved off T (user, 2026-10-13: weapon skill is T)
		WeaponSkill = "T", -- user, 2026-10-13
		Aim = "Y", -- guns' shooting mode toggle (2026-10-17; Y was free). RMB fires while it's on.
		-- the takedown prompt (TakedownUI): tap to knock out, hold to assassinate. N, as Rensei.Takedown.Key; rebindable
		-- since the owner's "Yes it should rebindable" (2026-10-28).
		Takedown = "N",
	},
}

Settings.Toggles = {CameraShake = true, AutoSprint = true, ShiftLock = true, Shadows = true,
	CombatLog = true, Compass = true, PostEffects = true, UIAnimations = true, UISounds = true}
Settings.Sliders = {SFXVolume = true, MusicVolume = true, FieldOfView = true}

-- Field Of View slider value -> degrees
function Settings.FOV(V)
	return math.floor(60 + math.clamp(V or 0.25, 0, 1) * 40 + 0.5)
end
Settings.Bindable = {Dash = true, Block = true, LockTarget = true, WeaponSkill = true, Aim = true, Takedown = true}

-- Keys that may never be bound: everything the locked controls doc assigns (movement, heavy R,
-- slide Ctrl, shift lock Alt, carry V, grip B, alchemy Z/X/C/V, interact E, stats M, inventory `),
-- plus the hotbar, Settings (P) and keys Roblox itself owns. N is not here: it is the takedown's default key, and the
-- takedown is rebindable (2026-10-28), so N is free for any action once the takedown moves off it.
Settings.Reserved = {
	W = true, A = true, S = true, D = true, Space = true, LeftShift = true, RightShift = true,
	LeftControl = true, RightControl = true, LeftAlt = true, RightAlt = true, Escape = true,
	R = true, V = true, B = true, Z = true, X = true, C = true, E = true, M = true, P = true,
	Backquote = true, Slash = true, Tab = true,
	J = true, K = true, F2 = true, -- Journal, Mastery, admin panel
	H = true, -- emote wheel hold (Rensei.Emotes.Key, EmoteWheelUI); reserved 2026-10-28, after the takedown review
	One = true, Two = true, Three = true, Four = true, Five = true, Six = true, Seven = true,
	Eight = true, Nine = true, Zero = true,
}

function Settings.IsBindableKey(Name)
	if type(Name) ~= "string" or Settings.Reserved[Name] then return false end
	local Ok, Code = pcall(function() return Enum.KeyCode[Name] end)
	return Ok and Code ~= nil and Code ~= Enum.KeyCode.Unknown
end

-- Merge saved values over defaults so new settings always have a value.
function Settings.Resolve(Saved)
	local Out = {}
	for K, V in pairs(Settings.Defaults) do
		if type(V) == "table" then
			Out[K] = {}
			for K2, V2 in pairs(V) do Out[K][K2] = V2 end
		else
			Out[K] = V
		end
	end
	if type(Saved) == "table" then
		for K in pairs(Settings.Toggles) do if type(Saved[K]) == "boolean" then Out[K] = Saved[K] end end
		for K in pairs(Settings.Sliders) do if type(Saved[K]) == "number" then Out[K] = math.clamp(Saved[K], 0, 1) end end
		if type(Saved.Keys) == "table" then
			for K in pairs(Settings.Bindable) do
				if Settings.IsBindableKey(Saved.Keys[K]) then Out.Keys[K] = Saved.Keys[K] end
			end
			-- Two actions on one key (e.g. a save from before WeaponSkill took T, with Lock Target
			-- still on T): the action whose DEFAULT is that key keeps it; the other goes back to its
			-- own default, or is left free if that is taken too.
			local Owner = {}
			for K, Key in pairs(Out.Keys) do
				if Owner[Key] == nil or Settings.Defaults.Keys[K] == Key then Owner[Key] = K end
			end
			for K, Key in pairs(Out.Keys) do
				if Owner[Key] ~= K then
					local Default = Settings.Defaults.Keys[K]
					local Taken = false
					for Other, OtherKey in pairs(Out.Keys) do
						if Other ~= K and OtherKey == Default then Taken = true end
					end
					Out.Keys[K] = Taken and "Unknown" or Default
				end
			end
		end
	end
	return Out
end

return Settings
