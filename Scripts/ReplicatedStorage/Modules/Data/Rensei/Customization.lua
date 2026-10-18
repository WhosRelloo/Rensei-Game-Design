-- Rensei character creation registry: every choice a player may make, by stable id.
-- The server accepts only ids listed here (Requests.CreateCharacter); AppearanceService builds the
-- look from them on every spawn.
--
-- SOURCES (the owner's own content, from the Assets place):
--   * nations, their skin / hair colours, eye styles, outfits and name lists: the owner's older
--     build (GameServices.Data / ServerEffects, Assets.Information.PlayerName);
--   * eyes / eyebrows / mouths / outfits: Workspace["Customization Stuff"];
--   * hair: the nation preset characters' hair mesh and the hair accessories in the place.
-- CONFIRMED by the owner 2026-10-14 ("I like it" on the proposal): six nations, cosmetic only;
-- pick the alchemy path; starting weapon = fists or a Common weapon; creation in Ye on first join.
-- PROPOSAL: the extra skin tones and hair colours beyond the nation ones; nation default outfits.

local C = {}

C.Version = 1

-- ===== Nations (cosmetic: they set the defaults) =====
C.NationOrder = {"Amestrian", "Xingnese", "Ishvalan", "Xerxian", "Aerugonian", "Drachman"}
C.Nations = {
	Amestrian = {Name = "Amestrian", Skin = "PastelBrown", HairColor = "DaisyOrange", Eyes = "Amestrian", Outfit = "Amestrian1"},
	Xingnese = {Name = "Xingnese", Skin = "PastelBrown", HairColor = "Black", Eyes = "Xingnese", Outfit = "Xingnese1"},
	Ishvalan = {Name = "Ishvalan", Skin = "Nougat", HairColor = "White", Eyes = "Ishvalan", Outfit = "Ishvalan1"},
	Xerxian = {Name = "Xerxian", Skin = "Buttermilk", HairColor = "CoolYellow", Eyes = "Xerxian", Outfit = "Xerxian1"},
	Aerugonian = {Name = "Aerugonian", Skin = "PastelBrown", HairColor = "Brown", Eyes = "Aerugonian", Outfit = "Aerugonian1"},
	Drachman = {Name = "Drachman", Skin = "PastelYellow", HairColor = "MediumBrown", Eyes = "E1", Outfit = "Drachman1"},
}
-- PROPOSAL (2026-10-15): one line per nation for the creator's nation card (the deck's setting notes).
C.NationBlurb = {
	Amestrian = "The military state at the heart of the map, still recovering from the Promised Day.",
	Xingnese = "From the eastern empire across the desert, home of alkahestry and chi-based alchemy.",
	Ishvalan = "A devout desert people of the east. Disciplined fighters who distrust alchemy.",
	Xerxian = "Descendants of the lost eastern kingdom, whose ruins still hold its secrets.",
	Aerugonian = "From the southern nation racing ahead in alchemy, and rival to Amestris.",
	Drachman = "From the cold northern empire beyond Briggs.",
}

-- ===== Colours =====
C.SkinOrder = {"Buttermilk", "PastelYellow", "PastelBrown", "LightOrange", "Nougat", "Brown", "ReddishBrown", "DarkBrown"}
C.Skins = {
	Buttermilk = BrickColor.new("Buttermilk").Color,
	PastelYellow = BrickColor.new("Pastel yellow").Color,
	PastelBrown = BrickColor.new("Pastel brown").Color,
	LightOrange = BrickColor.new("Light orange").Color, -- PROPOSAL
	Nougat = BrickColor.new("Nougat").Color,
	Brown = BrickColor.new("Brown").Color, -- PROPOSAL
	ReddishBrown = BrickColor.new("Reddish brown").Color, -- PROPOSAL
	DarkBrown = Color3.fromRGB(86, 58, 42), -- PROPOSAL
}

-- Skin colour: one of the ids above, or (Creator Plus, 2026-10-18) any colour as 6 hex digits. The menu
-- server only accepts a hex skin from a Creator Plus owner; every place renders either.
function C.SkinColorOf(A)
	local V = type(A) == "table" and A.Skin
	if type(V) ~= "string" then return C.Skins.PastelBrown end
	if C.Skins[V] then return C.Skins[V] end
	if V:match("^%x%x%x%x%x%x$") then return Color3.fromHex(V) end
	return C.Skins.PastelBrown
end
function C.IsCustomSkin(A)
	local V = type(A) == "table" and A.Skin
	return type(V) == "string" and C.Skins[V] == nil and V:match("^%x%x%x%x%x%x$") ~= nil
end

C.HairColorOrder = {"Black", "MediumBrown", "Brown", "DaisyOrange", "CoolYellow", "White", "Red", "Grey"}
C.HairColors = {
	Black = BrickColor.new("Black").Color,
	MediumBrown = BrickColor.new("Medium brown").Color,
	Brown = BrickColor.new("Brown").Color,
	DaisyOrange = BrickColor.new("Daisy orange").Color,
	CoolYellow = BrickColor.new("Cool yellow").Color,
	White = BrickColor.new("Institutional white").Color,
	Red = BrickColor.new("Crimson").Color, -- PROPOSAL
	Grey = BrickColor.new("Dark stone grey").Color, -- PROPOSAL
}

-- Hair colour (owner 2026-10-15: a colour wheel): HairColor is either one of the ids above (older saves,
-- nation defaults) or any colour as 6 hex digits ("d8b25a"). It tints preset and catalog-ID hair alike.
function C.HairColorOf(A)
	local V = type(A) == "table" and A.HairColor
	if type(V) ~= "string" then return C.HairColors.Black end
	if C.HairColors[V] then return C.HairColors[V] end
	if V:match("^%x%x%x%x%x%x$") then return Color3.fromHex(V) end
	return C.HairColors.Black
end

-- ===== Face (decals on the head's front) =====
local function List(Prefix, Ids)
	local Order, Map = {}, {}
	for I, Id in ipairs(Ids) do
		local Key = Prefix .. I
		table.insert(Order, Key)
		Map[Key] = "rbxassetid://" .. Id
	end
	return Order, Map
end

C.EyeOrder, C.Eyes = List("E", {2818168556, 2818166000, 2818161566, 2801594973, 2801585179, 2801594656, 2801595347, 2801605473,
	2801605125, 2818161322, 2818161064, 2801605712, 2801605956, 2818165738, 2818165600, 2801584953, 2801584512})
-- the nation eye styles of the older build
for _, N in ipairs({{"Amestrian", 4646121226}, {"Ishvalan", 4645668536}, {"Xerxian", 4645903833}, {"Aerugonian", 4648608648}}) do
	table.insert(C.EyeOrder, N[1])
	C.Eyes[N[1]] = "rbxassetid://" .. N[2]
end
table.insert(C.EyeOrder, "Xingnese")
C.Eyes.Xingnese = C.Eyes.E11 -- the older build's Xingnese eyes are E11

C.BrowOrder, C.Brows = List("B", {2801687635, 2801687922, 2801688112, 2801696705, 2801697005, 2801697189, 2801716156, 2801716326})
C.MouthOrder, C.Mouths = List("M", {2801731770, 2801732091, 2801732538, 2801741665, 2801741881, 2801742053, 2801751305, 2801751501,
	2801751773, 2801759774, 2801759987, 2801760198, 2801767539, 2801767831, 2801768094, 2801778269, 2801778560, 2801778896,
	2813765960, 2813766627, 2813767341, 2818152144, 2818152352, 2818152574, 2818152743})

-- ===== Outfits (shirt + pants) =====
local function Fit(Name, Shirt, Pants)
	return {Name = Name, Shirt = "rbxassetid://" .. Shirt, Pants = "rbxassetid://" .. Pants}
end
C.OutfitOrder = {
	"Amestrian1", "Amestrian2", "Xingnese1", "Xingnese2", "Ishvalan1", "Xerxian1", "Xerxian2", "Aerugonian1", "Drachman1",
	"AlkahestryTattoos", "AlkahestryApprentice", "AlkahestryMaster", "AerugonianPrince", "AerugonianGeneral", "AerugonianPirate",
	"ChemistGarbs", "IshvalanFighter", "GodsFistPriest", "GodsFistMember", "DesertVagabond", "CouncilHR", "CouncilHunter",
	"CouncilCountess", "EasternAssassin", "EasternTraveller", "SouthernExplorer", "XerxianMerchant",
}
C.Outfits = {
	Amestrian1 = Fit("Amestrian Garb", 4450249970, 4450250671),
	Amestrian2 = Fit("Amestrian Garb 2", 4487682277, 4487689769),
	Xingnese1 = Fit("Xingnese Garb", 3921787562, 3921798276),
	Xingnese2 = Fit("Xingnese Garb 2", 3705228028, 3705230217),
	Ishvalan1 = Fit("Ishvalan Garb", 4015075968, 4015074425),
	Xerxian1 = Fit("Xerxian Garb", 4603767926, 4603768311),
	Xerxian2 = Fit("Xerxian Garb 2", 4015184165, 4015182195),
	Aerugonian1 = Fit("Aerugonian Garb", 4358047969, 4358050412),
	Drachman1 = Fit("Drachman Garb", 2987767155, 2993898780),
	AlkahestryTattoos = Fit("Alkahestry Tattoos", 608070487, 608071759),
	AlkahestryApprentice = Fit("Alkahestry Apprentice", 609748436, 609749595),
	AlkahestryMaster = Fit("Alkahestry Master", 608096458, 608071759),
	AerugonianPrince = Fit("Aerugonian Prince", 2948720655, 2948721407),
	AerugonianGeneral = Fit("Aerugonian General", 3869931667, 3869925335),
	AerugonianPirate = Fit("Aerugonian Pirate", 4974618755, 4974622189),
	ChemistGarbs = Fit("Chemist Garbs", 4971054551, 4971056121),
	IshvalanFighter = Fit("Ishvalan Fighter", 4971048648, 4971051960),
	GodsFistPriest = Fit("Gods Fist Priest", 4971125512, 4971121348),
	GodsFistMember = Fit("Gods Fist Member", 574930307, 2366828509),
	DesertVagabond = Fit("Desert Vagabond", 2416444224, 2416447837),
	CouncilHR = Fit("Alchemical Council HR", 2993897906, 2993898780),
	CouncilHunter = Fit("Alchemical Council Hunter", 3787682067, 3787684144),
	CouncilCountess = Fit("Alchemical Countess", 2792455029, 2792455929),
	EasternAssassin = Fit("Eastern Assassin", 591251002, 591251372),
	EasternTraveller = Fit("Eastern Traveller", 3013138103, 3013139501),
	SouthernExplorer = Fit("Southern Explorer", 2805289520, 2795698700),
	XerxianMerchant = Fit("Xerxian Merchant", 3604934724, 3604935778),
}

-- ===== Hair (a part with a SpecialMesh, worn as an accessory on the head's HairAttachment) =====
-- Attach = the accessory's HairAttachment in the hair part's space. Texture is the source asset's
-- texture, kept for reference only: AppearanceService leaves it off so the chosen hair colour applies.
local V = Vector3.new
C.HairOrder = {"Bald", "Short", "Spiky", "Anime", "Pixie", "Swept", "Ponytail"}
C.Hair = {
	Bald = {Name = "Bald"},
	Short = {Name = "Short", Mesh = "rbxassetid://1017165558", Size = V(1.744, 1.660, 1.704),
		Attach = CFrame.new(-0.022, 0.379, -0.118)}, -- the nation presets' hair
	Spiky = {Name = "Spiky", Mesh = "rbxassetid://7805064587", Texture = "rbxassetid://7900022736", Size = V(1, 1, 1),
		Attach = CFrame.new(-0.003, 0.194, 0.187) * CFrame.Angles(0, math.pi, 0)},
	Anime = {Name = "Anime", Mesh = "rbxassetid://346578029", Texture = "rbxassetid://376784260", Size = V(1.25, 0.91, 1.14),
		Attach = CFrame.new(0, 0.1, -0.06)},
	Pixie = {Name = "Pixie", Mesh = "rbxassetid://11387054529", Texture = "rbxassetid://11387057110", Size = V(1, 1, 1),
		Attach = CFrame.new(0.065, 0.644, 0) * CFrame.Angles(0, math.pi / 2, 0)},
	Swept = {Name = "Swept", Mesh = "rbxassetid://17443122552", Texture = "rbxassetid://4486606505", Size = V(1, 1, 1),
		Attach = CFrame.new(0.012, 1.286, 0.110) * CFrame.Angles(math.rad(2.4), math.pi, 0)},
	Ponytail = {Name = "Ponytail", Mesh = "rbxassetid://110644667953947", Texture = "rbxassetid://4486606505", Size = V(1, 1, 1),
		Attach = CFrame.new(-0.006, 1.139, -0.514)},
}

-- Hair by Roblox catalog ID (owner 2026-10-15): up to HairIdSlots ids in HairIds, worn together (like
-- the reference video's three hair boxes) instead of the preset Hair. AppearanceService.LoadHair loads
-- them; they take the hair colour unless HairOwnColors is on.
C.HairIdMax = 1e15
C.HairIdSlots = 3

local function ValidId(V) return type(V) == "number" and V == math.floor(V) and V > 0 and V < C.HairIdMax end

-- The cleaned hair-id list of an appearance table (also reads the older single HairId).
function C.HairIdsOf(A)
	local Out = {}
	local Src = type(A) == "table" and (type(A.HairIds) == "table" and A.HairIds or {A.HairId}) or {}
	for I = 1, C.HairIdSlots do
		local V = Src[I]
		if ValidId(V) and not table.find(Out, V) then table.insert(Out, V) end
	end
	return Out
end

-- A catalog ID from typed text: a bare number or a catalog / marketplace link. nil if none.
function C.ParseHairId(Text)
	if type(Text) ~= "string" then return nil end
	local Digits = Text:match("/(%d+)") or Text:match("^%s*(%d+)%s*$")
	local Id = Digits and tonumber(Digits)
	return (Id and Id > 0 and Id < C.HairIdMax) and Id or nil
end

-- ===== Starting weapon: fists ("") or a Common weapon =====
-- owner 2026-10-18: the creator offers these six only (the guns are found in game)
C.StartWeapons = {"", "Katana", "Rapier", "Caestus", "Greatsword", "Daggers"}
-- every Common weapon, guns included (enemy spawns pick from this; Rensei EnemyService)
C.CommonWeapons = {"", "Katana", "Rapier", "Caestus", "Greatsword", "Daggers", "Renetti", "Sykov"}

-- ===== Identity (owner 2026-10-14: first name, gender, etc.) =====
C.Genders = {"Male", "Female"}
-- Body by gender (owner 2026-10-15: "Female" must change the look): the female body is the torso of
-- the owner's "ROBLOX Girl torso R6" rig (menu place Workspace; R6 CharacterMesh 48112070).
-- Appearance.Body = the gender.
C.Bodies = {
	Male = {},
	Female = {Torso = "rbxassetid://48112070"},
}
-- PROPOSAL (2026-10-15): the hair each gender starts with, so picking one shows on the preview.
C.GenderHair = {Male = "Short", Female = "Ponytail"}
-- Pronouns for dialogue / story text.
C.Pronouns = {
	Male = {Subject = "he", Object = "him", Possessive = "his"},
	Female = {Subject = "she", Object = "her", Possessive = "her"},
}

-- ===== Names: first name typed (filtered by the server) or picked from the nation's list;
-- surname optional, typed (filtered). The full name = first [+ surname]. =====
C.NameMin, C.NameMax = 2, 16
C.Names = {
	Amestrian = {"Adrian", "Albert", "Alphonse", "Ava", "Bonifaz", "Cloud", "Diana", "Edward", "Emmy", "Florian", "Freya", "Hubert", "Iga", "Kamila", "Kevin", "Lew", "Lilianna", "Ludwika", "Magus", "Maja", "Meine", "Oswald", "Romy", "Stella", "Susan", "Valeska", "Walter", "Wendell", "Winry", "Wulf"},
	Xingnese = {"Ami", "Ayano", "Chang", "Chinatsu", "Hideki", "Jiro", "Kanji", "Katsuro", "Kenta", "Koda", "Koji", "Ling", "Marasu", "Mei", "Na", "Naoko", "Ren", "Rikuto", "Ronin", "Shinsuke", "Shiro", "Takuma", "Wei", "Xun", "Yoko", "Yosuke", "Yu", "Yumi", "Yuuto", "Zhen", "Zhihao"},
	Ishvalan = {"Abim", "Aran", "Ari", "Arieh", "Atarah", "Ba'al", "Carmi", "Chanayah", "Chulda", "Havilah", "Hosanna", "Ionas", "Jamin", "Jesh", "Leo", "Matthew", "Michol", "Noa", "Omer", "Peter", "Phestos", "Qemu'el", "Rachel", "Rina", "Sargon", "Simon", "Thaddeus", "Tobit", "Tomar", "Uri", "Yefet", "Yonah"},
	Xerxian = {"Agapios", "Apollo", "Archelaos", "Archimedes", "Aristeides", "Aristodemos", "Drakon", "Drusa", "Faustus", "Helena", "Kleopatra", "Kyrillos", "Laurentius", "Livia", "Lucanus", "Lysistrata", "Marcius", "Paulus", "Percy", "Platon", "Prisca", "Roxana", "Roxas", "Thomas", "Tony", "Tullius", "Valens", "Valeria", "Von", "Xeno", "Zane", "Zoe"},
	Aerugonian = {"Anselmo", "Arnolfo", "Balbino", "Bartolo", "Celso", "Ezio", "Franco", "Fredo", "Fulvio", "Laura", "Leone", "Lorenzo", "Loretta", "Luigi", "Luisa", "Mario", "Mary", "Matilda", "Monica", "Nazario", "Orfeo", "Quintino", "Raffaella", "Rocco", "Romina", "Sasone", "Saveria", "Silvando", "Ugo", "Vasco", "Vespasiano"},
	Drachman = {"Adelina", "Aleksandr", "Aleksandra", "Alexey", "Anastasia", "Arina", "Boris", "Danyl", "Daria", "Denis", "Dmitry", "Elizaveta", "Grigori", "Irina", "Konstantin", "Ksenia", "Maksim", "Nikolai", "Polina", "Rasputin", "Roman", "Sergey", "Sofia", "Svetlana", "Victoria", "Vladimir", "Yekaterina", "Yelena", "Yevgeny"},
}

function C.FullName(First, Last)
	return (type(Last) == "string" and Last ~= "") and (First .. " " .. Last) or First
end

-- Letters, spaces, apostrophes and hyphens; 2-16 characters; starts with a letter.
function C.NameShapeOk(Name)
	if type(Name) ~= "string" then return false end
	if #Name < C.NameMin or #Name > C.NameMax then return false end
	return Name:match("^%a[%a '%-]*$") ~= nil and not Name:find("  ")
end

-- The starter outfit: your nation's (owner 2026-10-15: "your nation decides your starter outfit").
function C.OutfitFor(Nation)
	return (C.Nations[Nation] or C.Nations.Amestrian).Outfit
end

-- The look a nation gives when nothing else is chosen.
function C.Default(Nation)
	local N = C.Nations[Nation] or C.Nations.Amestrian
	return {
		Version = C.Version,
		Skin = N.Skin, Hair = "Short", HairColor = N.HairColor,
		Eyes = N.Eyes, Brows = "B1", Mouth = "M1", Outfit = N.Outfit, Markings = "", HairIds = {},
		HairOwnColors = false, -- true: catalog-ID hair keeps its own texture instead of HairColor
		Body = "Male",
	}
end

-- A full, valid appearance from a client table (unknown / missing fields fall back to the
-- nation default). Returns the cleaned table.
function C.Clean(Nation, A)
	local D = C.Default(Nation)
	if type(A) ~= "table" then return D end
	local function Pick(Field, Map)
		local V = A[Field]
		return (type(V) == "string" and Map[V] ~= nil) and V or D[Field]
	end
	return {
		Version = C.Version,
		Skin = (C.Skins[A.Skin] or C.IsCustomSkin(A)) and A.Skin or D.Skin, Hair = Pick("Hair", C.Hair),
		HairColor = (type(A.HairColor) == "string" and (C.HairColors[A.HairColor] or A.HairColor:match("^%x%x%x%x%x%x$"))) and A.HairColor or D.HairColor,
		HairOwnColors = A.HairOwnColors == true,
		Body = C.Bodies[A.Body] and A.Body or "Male",
		Eyes = Pick("Eyes", C.Eyes), Brows = Pick("Brows", C.Brows), Mouth = Pick("Mouth", C.Mouths),
		Outfit = Pick("Outfit", C.Outfits), Markings = "",
		HairIds = C.HairIdsOf(A),
	}
end

-- ===== NPC looks (owner 2026-10-15: NPC fits randomised from the creator's assets, true to their nation) =====
-- PROPOSAL: which skins / hair colours / eyes / outfits read as each nation. Outfits come from the
-- creator's list, grouped by their origin (Alchemical Council = Amestris, Alkahestry / Eastern = Xing,
-- Gods Fist = Ishval). Eyes: the nation's own style half the time, otherwise a generic one.
C.NationLooks = {
	Amestrian = {Skins = {"PastelBrown", "PastelYellow", "Buttermilk", "LightOrange"},
		HairColors = {"DaisyOrange", "CoolYellow", "MediumBrown", "Brown", "Black"},
		Outfits = {"Amestrian1", "Amestrian2", "ChemistGarbs", "CouncilHR", "CouncilHunter", "CouncilCountess"}},
	Xingnese = {Skins = {"PastelBrown", "Buttermilk", "LightOrange"}, HairColors = {"Black", "MediumBrown"},
		Outfits = {"Xingnese1", "Xingnese2", "AlkahestryTattoos", "AlkahestryApprentice", "AlkahestryMaster", "EasternAssassin", "EasternTraveller"}},
	Ishvalan = {Skins = {"Nougat", "Brown", "ReddishBrown", "DarkBrown"}, HairColors = {"White", "Grey"},
		Outfits = {"Ishvalan1", "IshvalanFighter", "GodsFistPriest", "GodsFistMember", "DesertVagabond"}},
	Xerxian = {Skins = {"Buttermilk", "PastelYellow", "LightOrange"}, HairColors = {"CoolYellow", "DaisyOrange", "White"},
		Outfits = {"Xerxian1", "Xerxian2", "XerxianMerchant", "DesertVagabond"}},
	Aerugonian = {Skins = {"PastelBrown", "LightOrange", "Nougat"}, HairColors = {"Brown", "MediumBrown", "Black", "Red"},
		Outfits = {"Aerugonian1", "AerugonianPrince", "AerugonianGeneral", "AerugonianPirate", "SouthernExplorer"}},
	Drachman = {Skins = {"PastelYellow", "Buttermilk"}, HairColors = {"MediumBrown", "White", "Grey", "CoolYellow"},
		Outfits = {"Drachman1"}},
}
C.GenderHairs = {
	Male = {"Short", "Spiky", "Anime", "Swept", "Bald"},
	Female = {"Ponytail", "Pixie", "Anime", "Swept"},
}
local GenericEyes = {}
for _, Id in ipairs(C.EyeOrder) do if Id:match("^E%d+$") then table.insert(GenericEyes, Id) end end

-- A random look true to Nation (nil = any nation). Returns Look, Nation, Gender. Rng: a Random (optional).
function C.RandomLook(Nation, Rng)
	Rng = Rng or Random.new()
	local function Pick(T) return T[Rng:NextInteger(1, #T)] end
	Nation = C.NationLooks[Nation] and Nation or Pick(C.NationOrder)
	local Pool = C.NationLooks[Nation]
	local Gender = Pick(C.Genders)
	local Eyes = (C.Eyes[C.Nations[Nation].Eyes] and Rng:NextNumber() < 0.5) and C.Nations[Nation].Eyes or Pick(GenericEyes)
	return {
		Version = C.Version,
		Skin = Pick(Pool.Skins), HairColor = Pick(Pool.HairColors), Hair = Pick(C.GenderHairs[Gender]), HairIds = {},
		Eyes = Eyes, Brows = Pick(C.BrowOrder), Mouth = Pick(C.MouthOrder), Outfit = Pick(Pool.Outfits),
		Markings = "", HairOwnColors = false, Body = Gender,
	}, Nation, Gender
end

return C
