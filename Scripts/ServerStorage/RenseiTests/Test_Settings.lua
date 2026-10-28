-- Test_Settings (rebindable takedown key, 2026-10-28; owner: "Yes it should rebindable"): the pure rules of
-- Rensei.Settings that the server applies before it saves a player's settings (Requests.Settings -> Settings.Resolve).
-- Pure: runs in Edit through execute_luau (TestKit.Run). Expected values written by hand:
--   the takedown's default key is N (Rensei.Takedown.Key, as it was before it became rebindable);
--   the other defaults: Dash Q, Block F, Lock Target G, Weapon Skill T, Aim Y;
--   B (grip) and V (carry / alchemy Ultimate) stay reserved, and so does E (interact / Combat Mode).
--   H is reserved too (the emote wheel's hold key, Rensei.Emotes.Key; 2026-10-28 review). U is a free key: in no
--     Reserved list and bound by no script (searched: the repo and Ye's Studio-only ClientHandler.Controls).
local Settings = require(game.ReplicatedStorage.Modules.Data.Rensei.Settings)

local DEFAULTS = {Dash = "Q", Block = "F", LockTarget = "G", WeaponSkill = "T", Aim = "Y", Takedown = "N"}

return {
	-- a fresh player (no save) gets N for the takedown, and every other key as before
	TakedownDefaultsToN = function(T)
		T.Eq(Settings.Defaults.Keys.Takedown, "N", "Defaults.Keys.Takedown")
		T.Eq(Settings.Bindable.Takedown, true, "Takedown is a rebindable action")
		T.Same(Settings.Resolve(nil).Keys, DEFAULTS, "Resolve(nil).Keys")
		T.Same(Settings.Resolve({}).Keys, DEFAULTS, "Resolve({}).Keys")
	end,

	-- N is no longer reserved; B, V and E still are (the owner asked only about the takedown key)
	NIsBindable = function(T)
		T.Eq(Settings.Reserved.N, nil, "N is not in Reserved")
		T.Eq(Settings.IsBindableKey("N"), true, "N is bindable")
		T.Eq(Settings.IsBindableKey("B"), false, "B (grip) stays reserved")
		T.Eq(Settings.IsBindableKey("V"), false, "V (carry) stays reserved")
		T.Eq(Settings.IsBindableKey("E"), false, "E (interact) stays reserved")
		T.Eq(Settings.IsBindableKey("H"), false, "H (emote wheel hold) is reserved")
		T.Eq(Settings.IsBindableKey("U"), true, "control: U (free) is bindable")
	end,

	-- a saved takedown key the server accepts is kept
	SavedTakedownKeyKept = function(T)
		local R = Settings.Resolve({Keys = {Takedown = "U"}})
		T.Eq(R.Keys.Takedown, "U", "a saved U is kept")
		T.Eq(R.Keys.Dash, "Q", "Dash untouched")
	end,

	-- an invalid saved takedown key falls back to N: reserved, not a key, the wrong type
	InvalidTakedownKeyFallsBack = function(T)
		for _, Bad in ipairs({"B", "V", "E", "H", "LeftShift", "One", "NotAKey", "", 14, true}) do
			local R = Settings.Resolve({Keys = {Takedown = Bad}})
			T.Eq(R.Keys.Takedown, "N", "saved " .. tostring(Bad) .. " falls back to N")
		end
		-- Unknown is what Resolve itself leaves for an action with no free key; it is never accepted from a save
		T.Eq(Settings.Resolve({Keys = {Takedown = "Unknown"}}).Keys.Takedown, "N", "saved Unknown falls back to N")
	end,

	-- two actions on one key: the action whose DEFAULT the key is keeps it, the other goes back to its own default
	DuplicateTakedownKeyResolved = function(T)
		local A = Settings.Resolve({Keys = {Takedown = "Q"}}) -- Q is Dash's default
		T.Eq(A.Keys.Dash, "Q", "Dash keeps Q (its default)")
		T.Eq(A.Keys.Takedown, "N", "the takedown goes back to N")
		local B = Settings.Resolve({Keys = {Dash = "N"}}) -- N is the takedown's default
		T.Eq(B.Keys.Takedown, "N", "the takedown keeps N (its default)")
		T.Eq(B.Keys.Dash, "Q", "Dash goes back to Q")
		-- swapped keys are not a duplicate: both kept
		local C = Settings.Resolve({Keys = {Dash = "N", Takedown = "Q"}})
		T.Eq(C.Keys.Dash, "N", "swapped: Dash on N")
		T.Eq(C.Keys.Takedown, "Q", "swapped: the takedown on Q")
		-- both on N: N is the takedown's default, so it keeps N and Dash goes back to its (free) default Q
		local D = Settings.Resolve({Keys = {Dash = "N", Takedown = "N"}})
		T.Eq(D.Keys.Takedown, "N", "both on N: the takedown keeps it")
		T.Eq(D.Keys.Dash, "Q", "both on N: Dash back to Q")
		-- the takedown on Q with Dash on U: no duplicate, both kept
		local E = Settings.Resolve({Keys = {Dash = "U", Takedown = "Q"}})
		T.Eq(E.Keys.Takedown, "Q", "the takedown may take Dash's default once Dash moved")
		T.Eq(E.Keys.Dash, "U", "Dash on U")
		-- one key per action holds after every case
		for Name, R in pairs({A = A, B = B, C = C, D = D, E = E}) do
			local Seen = {}
			for K, Key in pairs(R.Keys) do
				T.True(Seen[Key] == nil or Key == "Unknown", Name .. ": " .. K .. " and " .. tostring(Seen[Key]) .. " share " .. Key)
				Seen[Key] = K
			end
		end
	end,

	-- a save from before H was reserved (2026-10-28): any action saved on H goes back to its own default
	SavedHFallsBack = function(T)
		local R = Settings.Resolve({Keys = {Takedown = "H", Dash = "H", Aim = "H"}})
		T.Eq(R.Keys.Takedown, "N", "a takedown saved on H goes back to N")
		T.Eq(R.Keys.Dash, "Q", "a Dash saved on H goes back to Q")
		T.Eq(R.Keys.Aim, "Y", "an Aim saved on H goes back to Y")
		for K, Key in pairs(R.Keys) do T.True(Key ~= "H", K .. " is not on H") end
	end,

	-- left free when its own default is taken too: the takedown on G (Lock Target's default) loses G, and N is held by
	-- Dash, so the takedown is left free (Unknown) rather than share a key
	DuplicateLeavesTakedownFree = function(T)
		local R = Settings.Resolve({Keys = {Takedown = "G", Dash = "N"}})
		T.Eq(R.Keys.LockTarget, "G", "Lock Target keeps G")
		T.Eq(R.Keys.Dash, "N", "Dash keeps N (nobody else on it)")
		T.Eq(R.Keys.Takedown, "Unknown", "the takedown is left free")
	end,
}
