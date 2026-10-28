-- Studio-only PREVIEW of the painted menu's art, before anything is uploaded (owner: "ask me before uploading
-- anything"). Points PaintedStage's panels and the Rensei* MaterialVariants at local files through rbxasset://
-- (Studio's content folder has a junction, textures/RenseiPreview -> E:/Rensei/Renders/MainMenu/upload, so the files
-- stay on E:). Only this PC's Studio can see them; a live player would see blanks, so CLEAR before any publish
-- (MODE = "clear"); every instance touched carries the attribute RenseiPreviewTexture.
-- Run in Edit:  python -I Art/Tools/rbxc.py luau "placeId: 123967384111466" Edit @Art/Studio/MainMenu/preview_textures.lua
local MODE = "apply" -- "apply" | "clear"
local BASE = "rbxasset://textures/RenseiPreview/"
local Stage = workspace:FindFirstChild("PaintedStage")
if not Stage then return "no PaintedStage" end
local FILES = {banner = "banner.png", clock = "clock.png", sign = "sign.png", chalk_circle = "chalk_circle.png",
	Backdrop1 = "backdrop_1.png", Backdrop2 = "backdrop_2.png", Backdrop3 = "backdrop_3.png"}
local n = 0
for _, p in ipairs(Stage:GetDescendants()) do
	local key = p:IsA("BasePart") and p:GetAttribute("ImageKey")
	local img = key and p:FindFirstChild("Image")
	if img then
		if MODE == "apply" and FILES[key] then
			img.Texture = BASE .. FILES[key]
			img:SetAttribute("RenseiPreviewTexture", true)
			n += 1
		elseif MODE == "clear" and img:GetAttribute("RenseiPreviewTexture") then
			img.Texture = ""
			img:SetAttribute("RenseiPreviewTexture", nil)
			n += 1
		end
	end
end
-- Studio renders local files on decals but not inside a MaterialVariant, so the preview also lays each baked colour
-- map on its parts as tiled Textures (PreviewTex, at the variant's tile size). Uploaded, the variants carry all four maps.
local SPT = {}
for _, mv in ipairs(game:GetService("MaterialService"):GetChildren()) do
	if mv:IsA("MaterialVariant") then SPT[mv.Name] = mv.StudsPerTile end
end
for i, p in ipairs(Stage:GetDescendants()) do
	if p:IsA("BasePart") then
		local key = p.MaterialVariant:match("^Rensei(%w+)$")
		if MODE == "apply" and key and not p:FindFirstChild("PreviewTex") then
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				local t = Instance.new("Texture")
				t.Name = "PreviewTex"
				t.Face = face
				t.Texture = BASE .. ("mat_%s_color.png"):format(key)
				t.StudsPerTileU, t.StudsPerTileV = SPT[p.MaterialVariant] or 5, SPT[p.MaterialVariant] or 5
				t:SetAttribute("RenseiPreviewTexture", true)
				t.Parent = p
			end
		elseif MODE == "clear" then
			for _, t in ipairs(p:GetChildren()) do
				if t.Name == "PreviewTex" and t:GetAttribute("RenseiPreviewTexture") then t:Destroy() end
			end
		end
	end
	if i % 400 == 0 then task.wait() end
end
local MS = game:GetService("MaterialService")
for _, mv in ipairs(MS:GetChildren()) do
	local key = mv:IsA("MaterialVariant") and mv.Name:match("^Rensei(%w+)$")
	if key then
		for kind, prop in pairs({color = "ColorMap", normal = "NormalMap", roughness = "RoughnessMap", metalness = "MetalnessMap"}) do
			if MODE == "apply" then
				mv[prop] = BASE .. ("mat_%s_%s.png"):format(key, kind)
			elseif mv:GetAttribute("RenseiPreviewTexture") then
				mv[prop] = ""
			end
		end
		mv:SetAttribute("RenseiPreviewTexture", MODE == "apply" or nil)
		n += 1
	end
end
return ("preview %s: %d panels / materials"):format(MODE, n)
