-- Test_AditRoute (2026-10-20): the part ground (World.Map.Ground) must never fill the Adit's route: the walkable
-- space above every floor / ramp, and the boarded mouth's opening (between the frame posts, floor to lintel).
local A = workspace.World.Map.HalvardsAdit
local function aabb(cf, size)
	local function ext(a) return math.abs(cf.RightVector[a]) * size.X + math.abs(cf.UpVector[a]) * size.Y + math.abs(cf.LookVector[a]) * size.Z end
	local half = Vector3.new(ext("X"), ext("Y"), ext("Z")) / 2
	return cf.Position - half, cf.Position + half
end
local function Boxes()
	local Out = {}
	for _, f in ipairs(A.Structure:GetChildren()) do
		if f:IsA("BasePart") and (f.Name:sub(1, 5) == "Floor" or f.Name == "Ramp") then
			table.insert(Out, {f.Name, f.CFrame * CFrame.new(0, f.Size.Y / 2 + 4, 0), Vector3.new(f.Size.X - 1, 6.4, f.Size.Z - 1)})
		end
	end
	local M = A.Interactables.BoardedMouth
	local posts = {}
	for _, c in ipairs(M:GetChildren()) do if c.Name == "FramePost" then table.insert(posts, c) end end
	local a1, b1 = aabb(posts[1].CFrame, posts[1].Size)
	local a2, b2 = aabb(posts[2].CFrame, posts[2].Size)
	local zlo, zhi = math.min(b1.Z, b2.Z), math.max(a1.Z, a2.Z)
	local llo = aabb(M.FrameLintel.CFrame, M.FrameLintel.Size)
	local ylo = math.min(a1.Y, a2.Y) + 1.2 -- above the floor-level surface slabs
	local x = posts[1].Position.X
	table.insert(Out, {"BoardedMouth", CFrame.new(x, (ylo + llo.Y) / 2, (zlo + zhi) / 2), Vector3.new(8, llo.Y - ylo, zhi - zlo - 0.2)})
	return Out
end
return {
	GroundLeavesTheRouteOpen = function(T)
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = {workspace.World.Map.Ground}
		for _, B in ipairs(Boxes()) do
			for _, p in ipairs(workspace:GetPartBoundsInBox(B[2], B[3], op)) do
				T.True(not p.CanCollide or p.Size.Y <= 1.01, ("%s blocks %s at %s"):format(p:GetFullName(), B[1], tostring(p.Position)))
			end
		end
	end,
}

