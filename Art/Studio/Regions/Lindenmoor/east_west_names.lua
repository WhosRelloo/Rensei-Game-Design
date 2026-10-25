--!nocheck
-- east_west_names.lua: Lindenmoor import Task 8 fix round 4 (Ruling 38b). Ye's compass now has north at +Z, and the
-- compass is only ever a rotation (Roblox is right-handed), so EAST is -X in Ye. The expansion's names were made in
-- the layout's "x = east" frame, so their east and west are mirrored; some village text was written for the old
-- -Z compass. This swaps the words players see in Ye's map attributes (north and south words are already right):
--   * the expansion's RenseiArea AreaName "East Lookout" (x 600..860) -> "West Lookout";
--   * AreaName "Northeast Gap" (x 640..1000, z 800..1024) -> "Northwest Gap";
--   * the village's Bramble Hollow area Description: "south-east of the farms" -> "west of the farms" (the hollow,
--     x 190..262, lies off the farms' +X side, level with their southern half);
--   * Halvard's Adit area Description: "the eastern ridge" -> "the western ridge" (the adit is at +X of the village).
-- The matching names in Rensei.Regions.Areas, the quests and the tests change in the repo with this step, and
-- Art/Regions/Lindenmoor/layout.json records the new area names.
-- Runs in Ye (placeId 106992859583940), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @Art/Studio/Regions/Lindenmoor/east_west_names.lua
-- MODE = "plan"   read-only: what would change.
-- MODE = "apply"  refuses if LindenmoorExpansion has the attribute LindenmoorEastWest, or any target isn't found with
--                 exactly its old text. Each changed attribute keeps its old value in EWFrom_<attribute>. One
--                 ChangeHistory recording.
-- MODE = "undo"   puts every EWFrom_ value back on the four targets and clears the markers.
-- MODE = "check"  read-only: the new names are in place and no area in workspace is still called East Lookout or
--                 Northeast Gap.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot equal.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ATTR = "LindenmoorEastWest"

local function refuse(why) return "EastWest " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 106992859583940 then return refuse("this is not Ye") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local EX = Map and Map:FindFirstChild("LindenmoorExpansion")
if not EX then return refuse("no World.Map.LindenmoorExpansion") end
local Markers = EX:FindFirstChild("Markers") and EX.Markers:FindFirstChild("Markers_Expansion")
if not Markers then return refuse("no Markers.Markers_Expansion") end

-- {find the instance, attribute, old phrase, new phrase} (a phrase is replaced inside the value, by find + sub)
local function areaNamed(Name)
	return function()
		for _, P in ipairs(Markers:GetChildren()) do
			if CS:HasTag(P, "RenseiArea") and P:GetAttribute("AreaName") == Name then return P end
		end
	end
end
local function areaNamedEither(Old, New) -- (the part keeps its place; found by either name so undo can find it too)
	return function() return areaNamed(Old)() or areaNamed(New)() end
end
local function path(...)
	local Names = {...}
	return function()
		local X = Map
		for _, N in ipairs(Names) do X = X and X:FindFirstChild(N) end
		return X
	end
end
local TARGETS = {
	{Find = areaNamedEither("East Lookout", "West Lookout"), Attr = "AreaName", Old = "East Lookout", New = "West Lookout"},
	{Find = areaNamedEither("Northeast Gap", "Northwest Gap"), Attr = "AreaName", Old = "Northeast Gap", New = "Northwest Gap"},
	{Find = path("Lindenmoor", "Areas", "Bramble HollowArea"), Attr = "Description", Old = "south-east of the farms", New = "west of the farms"},
	{Find = path("HalvardsAdit", "Halvard's AditArea"), Attr = "Description", Old = "the eastern ridge", New = "the western ridge"},
}

local function swapIn(Value, Old, New)
	local A, B = string.find(Value, Old, 1, true)
	if not A then return nil end
	return string.sub(Value, 1, A - 1) .. New .. string.sub(Value, B + 1)
end

local function resolve()
	local Out = {}
	for I, T in ipairs(TARGETS) do
		local X = T.Find()
		if not X then return nil, "target " .. I .. " (" .. T.Old .. ") not found" end
		Out[I] = X
	end
	return Out
end

local function snapshot()
	local Rows = {}
	local Xs = resolve() or {}
	for I, X in ipairs(Xs) do
		local A = {}
		for K, V in pairs(X:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		table.insert(Rows, I .. "|" .. X:GetFullName() .. "|" .. table.concat(A, ","))
	end
	return table.concat(Rows, "\n") .. "\n" .. tostring(EX:GetAttribute(ATTR))
end

local function recorded(Name, Fn)
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording(Name) end)
	local Ok, Err = pcall(Fn)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	else pcall(function() CHS:SetWaypoint(Name) end) end
	if not Ok then error(Err, 0) end
end

local function apply()
	if EX:GetAttribute(ATTR) then return false, "already applied (" .. ATTR .. " is set)" end
	local Xs, Why = resolve()
	if not Xs then return false, Why end
	local Plan = {}
	for I, T in ipairs(TARGETS) do
		local Value = Xs[I]:GetAttribute(T.Attr)
		local New = type(Value) == "string" and swapIn(Value, T.Old, T.New)
		if not New then return false, Xs[I]:GetFullName() .. "." .. T.Attr .. " doesn't hold '" .. T.Old .. "' (" .. tostring(Value) .. ")" end
		if Xs[I]:GetAttribute("EWFrom_" .. T.Attr) ~= nil then return false, Xs[I]:GetFullName() .. " already has EWFrom_" .. T.Attr end
		Plan[I] = {Xs[I], T.Attr, Value, New}
	end
	recorded("Lindenmoor east/west names apply", function()
		for _, P in ipairs(Plan) do
			P[1]:SetAttribute("EWFrom_" .. P[2], P[3])
			P[1]:SetAttribute(P[2], P[4])
		end
		EX:SetAttribute(ATTR, true)
	end)
	local Lines = {}
	for _, P in ipairs(Plan) do table.insert(Lines, ("  %s.%s: %q -> %q"):format(P[1]:GetFullName(), P[2], P[3], P[4])) end
	return true, table.concat(Lines, "\n")
end

local function undo()
	local N = 0
	recorded("Lindenmoor east/west names undo", function()
		for _, T in ipairs(TARGETS) do
			local X = T.Find()
			local Old = X and X:GetAttribute("EWFrom_" .. T.Attr)
			if Old ~= nil then
				X:SetAttribute(T.Attr, Old)
				X:SetAttribute("EWFrom_" .. T.Attr, nil)
				N += 1
			end
		end
		EX:SetAttribute(ATTR, nil)
	end)
	return ("restored %d attributes"):format(N)
end

local function checks()
	local Out, Fails = {}, 0
	local function line(ok, s) if not ok then Fails += 1 end table.insert(Out, (ok and "  ok   " or "  FAIL ") .. s) end
	local Xs, Why = resolve()
	line(Xs ~= nil, "all four targets found " .. (Why or ""))
	for I, T in ipairs(TARGETS) do
		local X = Xs and Xs[I]
		local V = X and X:GetAttribute(T.Attr)
		line(type(V) == "string" and string.find(V, T.New, 1, true) ~= nil and string.find(V, T.Old, 1, true) == nil,
			("%s.%s = %q"):format(X and X:GetFullName() or "?", T.Attr, tostring(V)))
	end
	local Left = {}
	for _, P in ipairs(CS:GetTagged("RenseiArea")) do
		if P:IsDescendantOf(workspace) and (P:GetAttribute("AreaName") == "East Lookout" or P:GetAttribute("AreaName") == "Northeast Gap") then
			table.insert(Left, P:GetFullName())
		end
	end
	line(#Left == 0, "no area in workspace still has an old name [" .. table.concat(Left, ", ") .. "]")
	return Fails, Out
end

local Out = {"EastWest " .. MODE}
if MODE == "plan" then
	local Xs, Why = resolve()
	if not Xs then return refuse(Why) end
	for I, T in ipairs(TARGETS) do
		local V = Xs[I]:GetAttribute(T.Attr)
		table.insert(Out, ("  %s.%s: %q -> %s"):format(Xs[I]:GetFullName(), T.Attr, tostring(V), tostring(type(V) == "string" and swapIn(V, T.Old, T.New))))
	end
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	table.insert(Out, Msg)
	local Fails, Lines = checks()
	table.insert(Out, "checks: " .. Fails .. " FAIL")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	table.insert(Out, undo())
elseif MODE == "check" then
	local Fails, Lines = checks()
	table.insert(Out, "checks: " .. Fails .. " FAIL")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if EX:GetAttribute(ATTR) then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	table.insert(Out, Msg)
	local Fails, Lines = checks()
	table.insert(Out, "checks: " .. Fails .. " FAIL")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
	table.insert(Out, undo())
	local After = snapshot()
	table.insert(Out, "round trip: " .. (Before == After and "EXACT" or "DIFFERS") .. " (" .. #Before .. " chars)")
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")
