-- ProfileGuard (data-storage audit 2026-10-18): keeps every open "PlayerData" profile saveable.
-- KEEP THIS FILE THE SAME IN EVERY PLACE (Ye's DataManager, the menu's MenuData and the tutorial's FlowData use it).
--
-- A DataStore can't hold NaN or infinite numbers, or Roblox values (Vector3, CFrame, Instance, functions...). ONE such
-- value anywhere in a profile makes every later save of it fail, and the whole session's progress is lost without a
-- sound. The guard repairs those in place (a bad number -> 0, an unstorable value or key removed) and warns once per
-- problem: when the profile opens (Track), every Interval seconds while it's open, and right before a release (Final).
-- A table that mixes list and named keys is only reported: converting it could break the code that reads it.

local ProfileGuard = {}
ProfileGuard.Interval = 30 -- seconds between checks of an open profile (ProfileService auto-saves every ~30 s)

local Tracked = {} -- [Profile] = label (plain table, cleared on release)
local Reported = {} -- [Profile] = {[message] = true}: each problem is warned once

local function Walk(T, Path, Out, Depth, Seen)
	if Seen[T] then table.insert(Out, Path .. ": the same table twice (left as is)") return end
	if Depth > 24 then table.insert(Out, Path .. ": nested too deep (left as is)") return end
	Seen[T] = true
	local Num, Str = 0, 0
	for K, V in pairs(T) do
		local KT = type(K)
		if KT == "number" and K == K and K ~= math.huge and K ~= -math.huge then
			Num += 1
		elseif KT == "string" then
			Str += 1
		else
			T[K] = nil
			table.insert(Out, Path .. ": removed an unstorable " .. KT .. " key")
			continue
		end
		local P = Path .. "." .. tostring(K)
		local VT = typeof(V)
		if VT == "number" then
			if V ~= V or V == math.huge or V == -math.huge then
				T[K] = 0
				table.insert(Out, P .. " was " .. tostring(V) .. ", set to 0")
			end
		elseif VT == "table" then
			Walk(V, P, Out, Depth + 1, Seen)
		elseif VT ~= "string" and VT ~= "boolean" then
			T[K] = nil
			table.insert(Out, P .. ": removed an unstorable " .. VT)
		end
	end
	if Num > 0 and Str > 0 then table.insert(Out, Path .. ": mixes list and named keys (reported only)") end
end

-- Repair Data in place. Returns the list of what was found / fixed (empty = clean).
function ProfileGuard.Clean(Data)
	local Out = {}
	if type(Data) == "table" then Walk(Data, "Data", Out, 0, {}) end
	return Out
end

local function Guard(Profile)
	local Found = ProfileGuard.Clean(Profile.Data)
	if #Found == 0 then return end
	local Seen = Reported[Profile] or {}
	Reported[Profile] = Seen
	local New = {}
	for _, F in ipairs(Found) do
		if not Seen[F] then Seen[F] = true table.insert(New, F) end
	end
	if #New > 0 then warn("[ProfileGuard] " .. tostring(Tracked[Profile] or "profile") .. ": " .. table.concat(New, "; ")) end
end

-- A profile just loaded (after Migrate + Reconcile): check it now and while it stays open.
function ProfileGuard.Track(Profile, Label)
	if not Profile then return end
	Tracked[Profile] = Label or "profile"
	Guard(Profile)
	Profile:ListenToRelease(function()
		Tracked[Profile] = nil
		Reported[Profile] = nil
	end)
end

-- Right before Profile:Release() (leave, teleport, slot switch): the release saves.
function ProfileGuard.Final(Profile)
	if Profile and Profile.Data then Guard(Profile) end
end

task.spawn(function()
	while true do
		task.wait(ProfileGuard.Interval)
		for Profile in pairs(Tracked) do
			local Ok, Err = pcall(Guard, Profile)
			if not Ok then warn("[ProfileGuard]", Err) end
		end
	end
end)

return ProfileGuard
