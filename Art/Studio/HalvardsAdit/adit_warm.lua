-- Halvard's Adit: warm lantern pools (2026-10-20). Each hanging lantern gets a soft orange spill light inside an
-- Attachment (LightService only counts lights parented directly to a part, so stealth exposure is unchanged).
-- Re-runnable. Every number is a PROPOSAL.
local A = workspace.World.Map.HalvardsAdit
local D = A.Dressing
local old = D:FindFirstChild("Warm")
if old then old:Destroy() end
local F = Instance.new("Part")
F.Name = "Warm"
F.Size = Vector3.new(1, 1, 1)
F.Transparency = 1
F.Anchored, F.CanCollide, F.CanQuery, F.CanTouch = true, false, false, false
F.CFrame = A.Lights:GetChildren()[1].CFrame
F.Parent = D
local n = 0
for _, l in ipairs(A.Lights:GetChildren()) do
	if l.Name == "Lantern" then
		local at = Instance.new("Attachment")
		at.Parent = F
		at.WorldPosition = l.Position - Vector3.new(0, 1, 0)
		local L = Instance.new("PointLight")
		L.Color = Color3.fromRGB(255, 150, 70)
		L.Brightness = 1.6
		L.Range = 16
		L.Shadows = true
		L.Parent = at
		n += 1
	end
end
return n .. " warm pools"
