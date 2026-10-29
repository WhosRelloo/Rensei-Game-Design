-- The painted menu's uploaded art and sound (rbxassetid numbers). 0 = not uploaded yet: the menu then falls back
-- to the UI kit's frames, and panels with no image stay hidden. The owner approves every upload first.
-- Uploaded 2026-10-28 with the owner's approval ("upload the 27 images and the ambience loop"); the files are in
-- E:/Rensei/Renders/MainMenu/upload/ (ids: E:/Rensei/Work/main-menu/upload_ids.json).
return {
	Backdrop = {98408514712319, 92635237930342, 92187101187410}, -- backdrop_1..3.png, left to right
	banner = 127952045593469, clock = 139503627297301, sign = 129284526014778, chalk_circle = 136129969998513, -- the panels' ImageKeys
	CardFrame = 87280134595465, CardFrameHover = 80329862140733, ButtonFrame = 131965807839763, -- 9-slice: 60 px margins on the 860 x 150 / 700 x 76 art
	-- the baked materials (MaterialVariants Rensei<Key>): E:/Rensei/Renders/MainMenu/upload/mat_<Key>_<map>.png
	-- (stone has no metalness map: it isn't metal, and 0 leaves the variant's default)
	Materials = {
		WallStone = {color = 112094355942968, normal = 98803013250080, roughness = 105553720719718, metalness = 0},
		Flagstones = {color = 87641175814641, normal = 71680282384419, roughness = 131361637485191, metalness = 0},
		StatueStone = {color = 116607839090417, normal = 124198348534823, roughness = 132795744193128, metalness = 0},
		Iron = {color = 81990938494202, normal = 125384580996481, roughness = 99507047705406, metalness = 99107904417368},
		RustIron = {color = 75709332655179, normal = 122386389536556, roughness = 71543219595519, metalness = 137215265213083},
	},
	Ambience = 89670897735814, -- the 60 s loop (menu_ambience.py --loop): ambience_loop60.wav, uploaded by the owner
}
