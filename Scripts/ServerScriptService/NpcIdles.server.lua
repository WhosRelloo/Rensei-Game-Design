-- NPC idle poses: any NPC (a non-player character with a Humanoid, anywhere in Workspace) with the
-- attribute IdleAnim (the name of an animation in Assets.Animations, e.g. "NPC_Chill") plays it on a
-- loop, server-side, so every player sees it. Changing the attribute swaps the pose; removing it stops it.
-- The NPCs are built with every part anchored, and Roblox doesn't animate anchored parts, so a posed NPC
-- keeps only its HumanoidRootPart anchored (it still can't fall or be pushed) and frees the parts jointed
-- to it (2026-10-18). The picks per NPC are in Documents/Animations.md ("NPC idles").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)

local Playing = {} -- [Model] = animation name
local Watched = {} -- [Model] = true

-- The parts joined to the root through Motor6Ds / welds (body parts, accessory handles). A prop that
-- merely sits inside the model and isn't jointed to the body stays anchored.
local function Jointed(Model, Root)
	local Links = {}
	for _, J in ipairs(Model:GetDescendants()) do
		if (J:IsA("JointInstance") or J:IsA("WeldConstraint")) and J.Part0 and J.Part1 then
			Links[J.Part0] = Links[J.Part0] or {}
			Links[J.Part1] = Links[J.Part1] or {}
			table.insert(Links[J.Part0], J.Part1)
			table.insert(Links[J.Part1], J.Part0)
		end
	end
	local Seen, Queue = {[Root] = true}, {Root}
	while #Queue > 0 do
		local P = table.remove(Queue)
		for _, Q in ipairs(Links[P] or {}) do
			if not Seen[Q] then Seen[Q] = true table.insert(Queue, Q) end
		end
	end
	return Seen
end

local function Loosen(Model)
	local Root = Model:FindFirstChild("HumanoidRootPart")
	if not Root then return end
	Root.Anchored = true
	for Part in pairs(Jointed(Model, Root)) do
		if Part ~= Root and Part:IsA("BasePart") then Part.Anchored = false end
	end
end

local function Apply(Model)
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid or not Model.Parent then return end
	if not Humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = Humanoid end
	local Want = Model:GetAttribute("IdleAnim")
	local Now = Playing[Model]
	if Now == Want then return end
	if Now then AnimationManager.Stop(Model, Now) end
	Playing[Model] = Want
	if Want then
		Loosen(Model)
		AnimationManager.Play(Model, Want, {Looped = true, Priority = Enum.AnimationPriority.Idle})
	end
end

local function Watch(Model)
	if Watched[Model] or not Model:IsA("Model") or Players:GetPlayerFromCharacter(Model) then return end
	if not Model:FindFirstChildOfClass("Humanoid") then return end
	Watched[Model] = true
	Model:GetAttributeChangedSignal("IdleAnim"):Connect(function() Apply(Model) end)
	Model.Destroying:Once(function() Playing[Model], Watched[Model] = nil, nil end)
	-- dressing can rebuild the body (new joints / parts) after the pose started: free those too
	Model.DescendantAdded:Connect(function(D)
		if Playing[Model] and (D:IsA("JointInstance") or D:IsA("WeldConstraint") or D:IsA("BasePart")) then
			task.defer(Loosen, Model)
		end
	end)
	-- after DialogueService has dressed it (the look is applied when its talk prompt is added)
	if Model:GetAttribute("IdleAnim") then task.delay(1, Apply, Model) end
end

for _, D in ipairs(workspace:GetDescendants()) do
	if D:IsA("Humanoid") and D.Parent then Watch(D.Parent) end
end
workspace.DescendantAdded:Connect(function(D)
	if D:IsA("Humanoid") then
		task.defer(function() if D.Parent then Watch(D.Parent) end end)
	end
end)
