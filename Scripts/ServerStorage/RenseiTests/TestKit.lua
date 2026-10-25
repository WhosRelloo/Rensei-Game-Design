-- TestKit (2026-10-19): a tiny assertion runner for Rensei's Studio tests (ServerStorage.RenseiTests).
-- A test module returns {[Name] = function(T) ... end}. Run() calls each test, sorted by name, and returns
-- "PASS n / FAIL n" plus one line per failure, and whether everything passed. Pure modules run in Edit mode
-- through execute_luau; services run inside a Play-mode Script (they need the game VM).
local TestKit = {}

local function Same(A, B, Path)
	if type(A) ~= type(B) then return false, Path .. ": " .. type(A) .. " vs " .. type(B) end
	if type(A) ~= "table" then
		if A ~= B then return false, Path .. ": " .. tostring(A) .. " vs " .. tostring(B) end
		return true
	end
	for K, V in pairs(A) do
		local Ok, Why = Same(V, B[K], Path .. "." .. tostring(K))
		if not Ok then return false, Why end
	end
	for K in pairs(B) do
		if A[K] == nil then return false, Path .. "." .. tostring(K) .. ": missing" end
	end
	return true
end

function TestKit.Run(Suite)
	local Names = {}
	for Name in pairs(Suite) do table.insert(Names, Name) end
	table.sort(Names)
	local Lines, Pass, Fail = {}, 0, 0
	for _, Name in ipairs(Names) do
		local T = {}
		function T.Eq(A, B, Msg)
			if A ~= B then error((Msg and Msg .. ": " or "") .. "expected " .. tostring(B) .. ", got " .. tostring(A), 2) end
		end
		function T.Near(A, B, Eps, Msg)
			if type(A) ~= "number" or math.abs(A - B) > (Eps or 1e-6) then
				error((Msg and Msg .. ": " or "") .. "expected ~" .. tostring(B) .. ", got " .. tostring(A), 2)
			end
		end
		function T.True(V, Msg) if not V then error(Msg or "expected true", 2) end end
		function T.Same(A, B, Msg)
			local Ok, Why = Same(A, B, "")
			if not Ok then error((Msg and Msg .. ": " or "") .. Why, 2) end
		end
		local Ok, Err = pcall(Suite[Name], T)
		if Ok then Pass += 1 else Fail += 1; table.insert(Lines, "FAIL " .. Name .. ": " .. tostring(Err)) end
	end
	table.insert(Lines, 1, string.format("PASS %d / FAIL %d", Pass, Fail))
	return table.concat(Lines, "\n"), Fail == 0
end

-- (Foundry Yard plan Task 4b) runs Fn() with Player's character held still Dist (default 6) studs in front of Model's
-- root, facing it, then puts the character back as it was (pivot, anchoring, velocity) and returns Fn's results. For
-- a server call that checks the player is near (TownsfolkService.Talk's range, Ruling 31). Yields only if Fn does.
function TestKit.Beside(Player, Model, Fn, Dist)
	local C = Player and Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	local At = Model and Model:FindFirstChild("HumanoidRootPart")
	if not (Root and At) then return Fn() end
	local Pivot, Anchored = C:GetPivot(), Root.Anchored
	local Look = Vector3.new(At.CFrame.LookVector.X, 0, At.CFrame.LookVector.Z)
	Look = Look.Magnitude > 1e-3 and Look.Unit or Vector3.new(0, 0, -1)
	local P = At.Position + Look * (Dist or 6)
	Root.Anchored = true
	C:PivotTo(CFrame.lookAt(P, Vector3.new(At.Position.X, P.Y, At.Position.Z)))
	local R = table.pack(pcall(Fn))
	C:PivotTo(Pivot)
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.Anchored = Anchored
	if not R[1] then error(R[2], 0) end
	return table.unpack(R, 2, R.n)
end

return TestKit
