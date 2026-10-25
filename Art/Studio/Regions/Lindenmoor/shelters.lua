--!nocheck
-- shelters.lua: Lindenmoor import Task 8 fix round 4 (Ruling 39). Ye had two Shelter posts (beside the mill and in
-- the east hay barn), so under TownsfolkService.ShelterRadius (150) most of the expansion's townsfolk had nowhere to
-- run and curled up where they stood. This adds seven more RenseiPost markers with Kind = "Shelter" at existing
-- buildings (the farmsteads, the mine head, the lookout, the signal box) and by the training field's stand, so every
-- post in Townsfolk.Regions.Lindenmoor has a shelter within the cap. The same posts are recorded in
-- Art/Regions/Lindenmoor/layout.json. Nothing else is touched: no part is moved, changed or removed.
-- Runs in Ye (placeId 106992859583940), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @Art/Studio/Regions/Lindenmoor/shelters.lua
-- MODE = "plan"   read-only: where each post would go, the ground under it, and what stands in its way.
-- MODE = "apply"  refuses if LindenmoorExpansion has the attribute LindenmoorShelters, or any of the PostIds already
--                 exists. Adds the posts to Markers.Markers_Expansion, each tagged RenseiPost with the attributes
--                 PostId and Kind (as lm_mill_shelter) plus LindenmoorShelterAdd = true, then runs the checks.
--                 One ChangeHistory recording.
-- MODE = "undo"   destroys exactly the parts with LindenmoorShelterAdd and clears LindenmoorShelters.
-- MODE = "check"  read-only: each post is there, tagged, on the ground with nothing solid where a townsperson would
--                 stand, and the nearest shelter of every other RenseiPost in the expansion is within 150 studs.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot equal. Leaves Ye as it was.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ATTR, MARK = "LindenmoorShelters", "LindenmoorShelterAdd"
local RADIUS = 150 -- TownsfolkService.ShelterRadius (PROPOSAL, fix round 3)

-- PROPOSAL spots, measured in Ye 2026-10-24 from the buildings' own parts: a few studs out from a door (or, at the
-- lookout and the signal box, from the foot of the stairs / beside the box away from the rails), on the ground. Y is
-- the ground top + 1 (a 2-stud marker, as lm_mill_shelter). Yaw (degrees, the layout's convention: 0 looks -Z, 180
-- looks +Z) faces away from the building.
local POSTS = {
	{Id = "lm_farm1_shelter", At = Vector3.new(-919.6, 23, -831.8), Yaw = 135, By = "Barn_farm_1 door"},
	{Id = "lm_farm2_shelter", At = Vector3.new(-617.5, 23, -890.9), Yaw = 60, By = "Barn_farm_2 door"},
	{Id = "lm_farm3_shelter", At = Vector3.new(-853.7, 23, -674.6), Yaw = -158, By = "Farmhouse_farm_3 door steps"},
	{Id = "lm_mine_shelter", At = Vector3.new(692.0, 37, -748.0), Yaw = -90, By = "MineHead winder door"},
	{Id = "lm_lookout_shelter", At = Vector3.new(732.5, 33, -441.7), Yaw = -64, By = "Lookout stair foot"},
	{Id = "lm_signal_shelter", At = Vector3.new(669.9, 5, 827.2), Yaw = -45, By = "SignalBox, the side away from the rails"},
	{Id = "lm_field_shelter", At = Vector3.new(-90.0, 5, -232.0), Yaw = 0, By = "TrainingField stand"},
}

local function refuse(why) return "Shelters " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 106992859583940 then return refuse("this is not Ye") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local EX = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("LindenmoorExpansion")
if not EX then return refuse("no World.Map.LindenmoorExpansion") end
local Markers = EX:FindFirstChild("Markers") and EX.Markers:FindFirstChild("Markers_Expansion")
if not Markers then return refuse("no Markers.Markers_Expansion") end
local Model = Markers:FindFirstChild("RenseiPost36") -- lm_mill_shelter, the pattern
if not (Model and Model:GetAttribute("PostId") == "lm_mill_shelter") then return refuse("lm_mill_shelter (RenseiPost36) is not where it was") end

local function f(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function postsById()
	local Out = {}
	for _, P in ipairs(CS:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(workspace) then
			local Id = P:GetAttribute("PostId")
			Out[Id] = Out[Id] or {}
			table.insert(Out[Id], P)
		end
	end
	return Out
end
local function added()
	local Out = {}
	for _, P in ipairs(Markers:GetChildren()) do if P:GetAttribute(MARK) == true then table.insert(Out, P) end end
	return Out
end

local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Exclude
rpG.FilterDescendantsInstances = {EX.Markers}
local opB = OverlapParams.new()
opB.FilterType = Enum.RaycastFilterType.Exclude
opB.FilterDescendantsInstances = {EX.Markers}
-- the ground top under (x, z), what is solid in a 3 x 5.5 x 3 box over it (where a rig stands)
local function site(At)
	local Hit = workspace:Raycast(Vector3.new(At.X, At.Y + 30, At.Z), Vector3.new(0, -80, 0), rpG)
	local Top = Hit and Hit.Position.Y
	local Solid = {}
	if Top then
		for _, X in ipairs(workspace:GetPartBoundsInBox(CFrame.new(At.X, Top + 3.25, At.Z), Vector3.new(3, 5.5, 3), opB)) do
			if X.CanCollide then table.insert(Solid, X.Name) end
		end
	end
	return Top, Solid, Hit and Hit.Instance
end

local function checks()
	local Out, Fails = {}, 0
	local function line(ok, s) if not ok then Fails += 1 end table.insert(Out, (ok and "  ok   " or "  FAIL ") .. s) end
	local ById = postsById()
	for _, D in ipairs(POSTS) do
		local L = ById[D.Id]
		local P = L and L[1]
		line(L ~= nil and #L == 1, D.Id .. ": one post in the place (" .. (L and #L or 0) .. ")")
		if P then
			line(P:IsDescendantOf(Markers) and P:GetAttribute(MARK) == true and P:GetAttribute("Kind") == "Shelter"
				and CS:HasTag(P, "RenseiPost"), D.Id .. ": in Markers_Expansion, tagged RenseiPost, Kind Shelter, " .. MARK)
			local Top, Solid = site(P.Position)
			line(Top ~= nil and math.abs((P.Position.Y - 1) - Top) <= 1.2, ("%s: on the ground (post foot %.2f, ground %s)"):format(D.Id, P.Position.Y - 1, Top and ("%.2f"):format(Top) or "none"))
			line(#Solid == 0, D.Id .. ": nothing solid where a townsperson stands [" .. table.concat(Solid, ",") .. "]")
		end
	end
	-- the nearest shelter of every other expansion post (a rig's root stands 3 over its post)
	local Shelters = {}
	for _, P in ipairs(CS:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Kind") == "Shelter" then table.insert(Shelters, P) end
	end
	local Rows = {}
	for _, P in ipairs(Markers:GetChildren()) do
		if CS:HasTag(P, "RenseiPost") and P:GetAttribute("Kind") ~= "Shelter" then
			local At = (P.CFrame * CFrame.new(0, 3, 0)).Position
			local Best, BestId = math.huge, "-"
			for _, S in ipairs(Shelters) do
				local Dd = (S.Position - At).Magnitude
				if Dd < Best then Best, BestId = Dd, S:GetAttribute("PostId") end
			end
			table.insert(Rows, {P:GetAttribute("PostId"), Best, BestId})
		end
	end
	table.sort(Rows, function(A, B) return A[1] < B[1] end)
	for _, R in ipairs(Rows) do line(R[2] <= RADIUS, ("%s: nearest shelter %s at %.0f"):format(R[1], R[3], R[2])) end
	return Fails, Out
end

local function snapshot()
	local Rows = {}
	for _, P in ipairs(Markers:GetChildren()) do
		local A = {}
		for K, V in pairs(P:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		table.insert(Rows, P.Name .. "|" .. P.ClassName .. "|" .. tostring(P:IsA("BasePart") and P.CFrame or "") .. "|" .. table.concat(A, ",") .. "|" .. table.concat(CS:GetTags(P), ","))
	end
	table.sort(Rows)
	return table.concat(Rows, "\n") .. "\n#RenseiPost=" .. #CS:GetTagged("RenseiPost") .. "\n" .. tostring(EX:GetAttribute(ATTR))
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
	local ById = postsById()
	for _, D in ipairs(POSTS) do if ById[D.Id] then return false, D.Id .. " already exists" end end
	-- the next free RenseiPostN names (the markers are RenseiPost25..42 today)
	local N = 0
	for _, P in ipairs(Markers:GetChildren()) do
		local K = tonumber(P.Name:match("^RenseiPost(%d+)$"))
		if K and K > N then N = K end
	end
	local Made = {}
	local Ok, Err = pcall(function()
		recorded("Lindenmoor shelters apply", function()
			for _, D in ipairs(POSTS) do
				N += 1
				local P = Instance.new("Part")
				P.Name = "RenseiPost" .. N
				P.Size = Model.Size
				P.Transparency, P.Anchored = Model.Transparency, true
				P.CanCollide, P.CanQuery, P.CanTouch = Model.CanCollide, Model.CanQuery, Model.CanTouch
				P.CastShadow = Model.CastShadow
				P.CFrame = CFrame.new(D.At) * CFrame.Angles(0, math.rad(D.Yaw), 0)
				P:SetAttribute("PostId", D.Id)
				P:SetAttribute("Kind", "Shelter")
				P:SetAttribute(MARK, true)
				P.Parent = Markers
				CS:AddTag(P, "RenseiPost")
				table.insert(Made, P)
			end
			EX:SetAttribute(ATTR, true)
		end)
	end)
	if not Ok then
		for _, P in ipairs(Made) do pcall(function() P:Destroy() end) end
		pcall(function() EX:SetAttribute(ATTR, nil) end)
		return false, "error, undone: " .. tostring(Err)
	end
	return true, ("added %d shelter posts (RenseiPost%d..%d)"):format(#Made, N - #Made + 1, N)
end

local function undo()
	local L = added()
	recorded("Lindenmoor shelters undo", function()
		for _, P in ipairs(L) do P:Destroy() end
		EX:SetAttribute(ATTR, nil)
	end)
	return ("removed %d shelter posts"):format(#L)
end

local Out = {"Shelters " .. MODE}
if MODE == "plan" then
	local ById = postsById()
	for _, D in ipairs(POSTS) do
		local Top, Solid, On = site(D.At)
		table.insert(Out, ("  %s at %s by %s: ground %s on %s; solid [%s]; %s"):format(D.Id, f(D.At), D.By,
			Top and ("%.2f"):format(Top) or "none", On and On:GetFullName():sub(-40) or "-", table.concat(Solid, ","), ById[D.Id] and "EXISTS" or "new"))
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
