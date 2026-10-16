-- NPC idle poses: any NPC model under Workspace.World.NPCs with the attribute IdleAnim (the name
-- of an animation in Assets.Animations, e.g. "NPC_Chill") plays it on a loop, server-side, so every
-- player sees it. The story NPCs and the alchemy trainers use the Animation ID's sheet's NPC idles
-- (Chill / Admire; PROPOSAL picks). Changing the attribute swaps the pose; removing it stops it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)

local NPCs = workspace:WaitForChild("World"):WaitForChild("NPCs")
local Playing = {} -- [Model] = animation name (cleared when the model is destroyed)

local function Apply(Model)
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	if not Humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = Humanoid end
	local Want = Model:GetAttribute("IdleAnim")
	local Now = Playing[Model]
	if Now == Want then return end
	if Now then AnimationManager.Stop(Model, Now) end
	Playing[Model] = Want
	if Want then AnimationManager.Play(Model, Want, {Looped = true, Priority = Enum.AnimationPriority.Idle}) end
end

local function Watch(Model)
	if not Model:IsA("Model") or Playing[Model] ~= nil or not Model:FindFirstChildOfClass("Humanoid") then return end
	Model:GetAttributeChangedSignal("IdleAnim"):Connect(function() Apply(Model) end)
	Model.Destroying:Once(function() Playing[Model] = nil end)
	-- after DialogueService has dressed it (the look is applied when its talk prompt is added)
	task.delay(1, Apply, Model)
end

for _, D in ipairs(NPCs:GetDescendants()) do Watch(D) end
NPCs.DescendantAdded:Connect(function(D) task.defer(Watch, D) end)
