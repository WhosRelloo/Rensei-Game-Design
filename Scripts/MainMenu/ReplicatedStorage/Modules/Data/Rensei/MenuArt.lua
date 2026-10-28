-- The painted menu's uploaded art and sound (rbxassetid numbers). 0 = not uploaded yet: the menu then falls back
-- to the UI kit's frames, and panels with no image stay hidden. The owner approves every upload first.
return {
	Backdrop = {0, 0, 0}, -- E:/Rensei/Renders/MainMenu/upload/backdrop_1..3.png, left to right
	banner = 0, clock = 0, sign = 0, chalk_circle = 0, -- the decal panels' ImageKey attributes
	CardFrame = 0, CardFrameHover = 0, ButtonFrame = 0, -- 9-slice: 60 px margins on the 860 x 150 / 700 x 76 art
	-- the baked materials (MaterialVariants Rensei<Key>): E:/Rensei/Renders/MainMenu/upload/mat_<Key>_<map>.png
	Materials = {
		WallStone = {color = 0, normal = 0, roughness = 0, metalness = 0},
		Flagstones = {color = 0, normal = 0, roughness = 0, metalness = 0},
		StatueStone = {color = 0, normal = 0, roughness = 0, metalness = 0},
		Iron = {color = 0, normal = 0, roughness = 0, metalness = 0},
		RustIron = {color = 0, normal = 0, roughness = 0, metalness = 0},
	},
	Ambience = 0, -- the 60 s loop (menu_ambience.py --loop)
}
