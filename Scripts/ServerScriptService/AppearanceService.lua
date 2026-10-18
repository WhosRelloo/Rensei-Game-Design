-- AppearanceService: builds a character's look from profile Identity.Appearance (ids from
-- Modules.Data.Rensei.Customization) on every spawn, and again right after character creation.
-- Server-side, so every client sees the same thing. Everything it adds is tagged with the
-- attribute RenseiLook so a re-apply replaces only its own pieces.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Customization = require(ReplicatedStorage.Modules.Data.Rensei.Customization)

local AppearanceService = {}

local BODY = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

local function Clear(Character)
	for _, D in ipairs(Character:GetDescendants()) do
		if D:GetAttribute("RenseiLook") then D:Destroy() end
	end
end

local function Decal(Head, Texture, Name)
	local D = Instance.new("Decal")
	D.Name = Name
	D.Face = Enum.NormalId.Front
	D.Texture = Texture
	D:SetAttribute("RenseiLook", true)
	D.Parent = Head
end

local function Hair(Character, Humanoid, Def, Color)
	if not Def or not Def.Mesh then return end
	local Accessory = Instance.new("Accessory")
	Accessory.Name = "RenseiHair"
	Accessory:SetAttribute("RenseiLook", true)
	local Handle = Instance.new("Part")
	Handle.Name = "Handle"
	Handle.Size = Def.Size
	Handle.CanCollide, Handle.CanQuery, Handle.CanTouch, Handle.Massless = false, false, false, true
	Handle.Color = Color
	local Mesh = Instance.new("SpecialMesh")
	Mesh.MeshType = Enum.MeshType.FileMesh
	Mesh.MeshId = Def.Mesh
	-- (the hair meshes' own textures are left off: they're coloured -- the anime hair is red -- and a
	-- tint can't change that, so the part's colour = the chosen hair colour shows instead)
	Mesh.Parent = Handle
	local Attach = Instance.new("Attachment")
	Attach.Name = "HairAttachment"
	Attach.CFrame = Def.Attach
	Attach.Parent = Handle
	Handle.Parent = Accessory
	-- welded straight to the head's HairAttachment (Humanoid:AddAccessory doesn't attach on a
	-- client-side model, e.g. the menu's preview rig)
	local Head = Character:FindFirstChild("Head")
	local HeadAttach = Head and Head:FindFirstChild("HairAttachment")
	if not HeadAttach then Accessory:Destroy() return end
	local Weld = Instance.new("Weld")
	Weld.Name = "AccessoryWeld"
	Weld.Part0 = Head
	Weld.Part1 = Handle
	Weld.C0 = HeadAttach.CFrame
	Weld.C1 = Attach.CFrame
	Weld.Parent = Handle
	Handle.CFrame = Head.CFrame * Weld.C0 * Weld.C1:Inverse()
	Accessory.Parent = Character
end

-- ===== Hair by catalog ID (Look.HairId) =====
-- The server builds the accessory once from a HumanoidDescription (works for any catalog hair) and
-- keeps it in ReplicatedStorage.HairCache as "<id>"; clients wait for that copy.
local Cache = ReplicatedStorage:FindFirstChild("HairCache")
if not Cache and RunService:IsServer() then
	Cache = Instance.new("Folder")
	Cache.Name = "HairCache"
	Cache.Parent = ReplicatedStorage
end
local Loading = {} -- [id] = true while the server builds it

-- The cached hair Accessory for Id (yields), or nil + a message.
function AppearanceService.LoadHair(Id)
	if type(Id) ~= "number" or Id <= 0 then return nil, "No hair ID." end
	local Key = tostring(Id)
	if not RunService:IsServer() then
		Cache = Cache or ReplicatedStorage:WaitForChild("HairCache", 5)
		local Found = Cache and Cache:WaitForChild(Key, 5)
		return Found, not Found and "That hair didn't load." or nil
	end
	while Loading[Key] do task.wait() end
	local Found = Cache:FindFirstChild(Key)
	if Found then return Found end
	Loading[Key] = true
	local Ok, Model = pcall(function()
		local D = Instance.new("HumanoidDescription")
		D.HairAccessory = Key
		return Players:CreateHumanoidModelFromDescription(D, Enum.HumanoidRigType.R6)
	end)
	Loading[Key] = nil
	if not Ok or not Model then return nil, "That hair ID didn't load." end
	local Accessory
	for _, C in ipairs(Model:GetChildren()) do
		if C:IsA("Accessory") then Accessory = C break end
	end
	local Handle = Accessory and Accessory:FindFirstChild("Handle")
	if not Handle then Model:Destroy() return nil, "That ID isn't a hair accessory." end
	Accessory.Parent = nil
	Model:Destroy()
	for _, D in ipairs(Accessory:GetDescendants()) do
		if D:IsA("JointInstance") or D:IsA("WeldConstraint") or D:IsA("BaseScript") then D:Destroy() end
	end
	Accessory.Name = Key
	Accessory.Parent = Cache
	return Accessory
end

-- Wear the cached hair Template: welded to the head attachment its handle names (as Hair() does).
-- Color (nil = keep the hair's own texture): the texture comes off so the part colour shows, the same
-- way the preset hairs take the hair colour.
local function CatalogHair(Character, Template, Color)
	local Head = Character:FindFirstChild("Head")
	local Accessory = Template:Clone()
	Accessory.Name = "RenseiHair"
	Accessory:SetAttribute("RenseiLook", true)
	local Handle = Accessory:FindFirstChild("Handle")
	local Attach, HeadAttach
	for _, A in ipairs(Handle:GetChildren()) do
		if A:IsA("Attachment") and Head:FindFirstChild(A.Name) then Attach, HeadAttach = A, Head[A.Name] break end
	end
	if not Attach then Accessory:Destroy() return end
	if Color then
		for _, D in ipairs(Handle:GetDescendants()) do
			if D:IsA("SpecialMesh") then D.TextureId = "" D.VertexColor = Vector3.one end
			if D:IsA("SurfaceAppearance") then D:Destroy() end
		end
		if Handle:IsA("MeshPart") then Handle.TextureID = "" end
		for _, D in ipairs(Handle:GetChildren()) do if D:IsA("SurfaceAppearance") then D:Destroy() end end
		Handle.Color = Color
	end
	Handle.Anchored = false
	Handle.CanCollide, Handle.CanQuery, Handle.CanTouch, Handle.Massless = false, false, false, true
	local Weld = Instance.new("Weld")
	Weld.Name = "AccessoryWeld"
	Weld.Part0 = Head
	Weld.Part1 = Handle
	Weld.C0 = HeadAttach.CFrame
	Weld.C1 = Attach.CFrame
	Weld.Parent = Handle
	Handle.CFrame = Head.CFrame * Weld.C0 * Weld.C1:Inverse()
	Accessory.Parent = Character
end

-- Apply Look (a Customization.Clean table) and Name to Character.
function AppearanceService.Apply(Character, Look, Name)
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local Head = Character and Character:FindFirstChild("Head")
	if not Humanoid or not Head or type(Look) ~= "table" then return end
	Clear(Character)

	-- skin
	local Skin = Customization.SkinColorOf(Look) -- (a preset id or a Creator Plus hex colour)
	if Skin then
		local BC = Character:FindFirstChildOfClass("BodyColors")
		if BC then BC:Destroy() end
		for _, N in ipairs(BODY) do
			local P = Character:FindFirstChild(N)
			if P then P.Color = Skin end
		end
	end

	-- face: the default face goes, eyes + brows + mouth decals come in
	local Old = Head:FindFirstChild("face")
	if Old and Old:IsA("Decal") then Old:Destroy() end
	if Customization.Eyes[Look.Eyes] then Decal(Head, Customization.Eyes[Look.Eyes], "Eyes") end
	if Customization.Brows[Look.Brows] then Decal(Head, Customization.Brows[Look.Brows], "Brows") end
	if Customization.Mouths[Look.Mouth] then Decal(Head, Customization.Mouths[Look.Mouth], "Mouth") end

	-- outfit
	local Fit = Customization.Outfits[Look.Outfit]
	if Fit then
		for _, C in ipairs(Character:GetChildren()) do
			if C:IsA("Shirt") or C:IsA("Pants") or C:IsA("ShirtGraphic") then C:Destroy() end
		end
		local Shirt = Instance.new("Shirt")
		Shirt.Name = "Shirt"
		Shirt.ShirtTemplate = Fit.Shirt
		Shirt.Parent = Character
		local Pants = Instance.new("Pants")
		Pants.Name = "Pants"
		Pants.PantsTemplate = Fit.Pants
		Pants.Parent = Character
	end

	-- body: the gender's meshes (CharacterMesh, so shirts and pants still show)
	for _, C in ipairs(Character:GetChildren()) do
		if C:IsA("CharacterMesh") then C:Destroy() end
	end
	for Part, Mesh in pairs(Customization.Bodies[Look.Body] or {}) do
		local CM = Instance.new("CharacterMesh")
		CM.Name = "Body" .. Part
		CM.BodyPart = Enum.BodyPart[Part]
		CM.MeshId = tonumber(Mesh:match("%d+"))
		CM:SetAttribute("RenseiLook", true)
		CM.Parent = Character
	end

	local HairColor = Customization.HairColorOf(Look)
	-- hair: catalog IDs win over the preset, all worn together (they load in the background; a newer
	-- Apply cancels them)
	local Token = (Character:GetAttribute("RenseiLookToken") or 0) + 1
	Character:SetAttribute("RenseiLookToken", Token)
	local Ids = Customization.HairIdsOf(Look)
	if #Ids > 0 then
		task.spawn(function()
			local Worn = 0
			for _, Id in ipairs(Ids) do
				local Template = AppearanceService.LoadHair(Id)
				if Character:GetAttribute("RenseiLookToken") ~= Token or not Character.Parent then return end
				if Template then CatalogHair(Character, Template, not Look.HairOwnColors and HairColor or nil) Worn += 1 end
			end
			if Worn == 0 then -- none loaded: the preset hair instead of a bald head
				Hair(Character, Humanoid, Customization.Hair[Look.Hair], HairColor)
			end
		end)
	else
		Hair(Character, Humanoid, Customization.Hair[Look.Hair], HairColor)
	end

	if type(Name) == "string" and Name ~= "" then
		Humanoid.DisplayName = Name
		Character:SetAttribute("CharacterName", Name)
	end
end

-- From a profile's Identity (spawn / after creation). Not created yet: the nation-less default look.
function AppearanceService.ApplyIdentity(Character, Identity)
	if type(Identity) ~= "table" then return end
	local Look = Identity.CharacterCreated and Customization.Clean(Identity.Origin, Identity.Appearance)
		or Customization.Default(Identity.Origin)
	AppearanceService.Apply(Character, Look, Identity.CharacterCreated and Identity.Name or nil)
end

return AppearanceService
