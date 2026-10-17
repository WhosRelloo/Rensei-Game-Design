-- Trainer practice after acquisition (TrainingService). Everything pays through
-- ProgressionService.AddTraining, so the stage's 20 MP cap and the Truth/Gate still apply.
-- All numbers PROPOSALS; titles and lines are placeholders.
--   Lessons[Id] = {Path, Title, Minigame (a Rensei.Minigames id), Source, Mult, PerDay, Requires, Done}
--     an exam-grade minigame at the trainer; a pass pays once per day per lesson.
--   Exercises[Id] = {Path, Title, Anim, Seconds, Source, Mult, PerDay, Requires, Start, Done}
--     a timed drill: hold still (within 2.5 studs) out of combat for Seconds while the animation plays.

-- (the path itself, however it was set: a questline, or the admin panel for testing)
local function Acquired(Path) return {SavedAffinity = Path} end

return {
	Lessons = {
		flame_lesson = {Path = "Flame", Title = "Reaction Drill", Minigame = "lesson_flame", Source = "Lesson", Mult = 1, PerDay = 1,
			Requires = Acquired("Flame"), Done = "Clean. Again tomorrow - control rots if you leave it."},
		ice_lesson = {Path = "Ice", Title = "Phase Drill", Minigame = "lesson_ice", Source = "Lesson", Mult = 1, PerDay = 1,
			Requires = Acquired("Ice"), Done = "Patient. That's the whole of it. Come back tomorrow."},
		earth_lesson = {Path = "Earth", Title = "Load Drill", Minigame = "lesson_earth", Source = "Lesson", Mult = 1, PerDay = 1,
			Requires = Acquired("Earth"), Done = "Sound work. A wall that stands tomorrow is worth two that stand today."},
		wind_lesson = {Path = "Wind", Title = "Pressure Drill", Minigame = "lesson_wind", Source = "Lesson", Mult = 1, PerDay = 1,
			Requires = Acquired("Wind"), Done = "You heard it before you saw it. Good. Tomorrow, harder."},
		metal_lesson = {Path = "Metal", Title = "Material Drill", Minigame = "lesson_metal", Source = "Lesson", Mult = 1, PerDay = 1,
			Requires = Acquired("Metal"), Done = "Acceptable. Which from me means good. Tomorrow."},
	},
	Exercises = {
		flame_exercise = {Path = "Flame", Title = "Breath Control", Anim = "Misc_Meditate", Seconds = 20, Source = "Exercise", Mult = 1, PerDay = 6,
			Requires = Acquired("Flame"), Start = "Breathe. Hold the heat in your chest and don't let it climb.", Done = "Your breathing steadies. The heat stays where you put it."},
		ice_exercise = {Path = "Ice", Title = "Stillness", Anim = "NPC_Kneel", Seconds = 25, Source = "Exercise", Mult = 1.1, PerDay = 6,
			Requires = Acquired("Ice"), Start = "Kneel. Don't move until the frost on the stone stops spreading.", Done = "The frost settles. So do you."},
		earth_exercise = {Path = "Earth", Title = "Groundwork", Anim = "Misc_Pushups", Seconds = 20, Source = "Exercise", Mult = 1, PerDay = 6,
			Requires = Acquired("Earth"), Start = "Down. Feel the ground push back.", Done = "Your arms burn. The ground didn't move. Good."},
		wind_exercise = {Path = "Wind", Title = "Core Hold", Anim = "NPC_Plank", Seconds = 20, Source = "Exercise", Mult = 1, PerDay = 6,
			Requires = Acquired("Wind"), Start = "Hold the plank. Breathe with the draught, not against it.", Done = "You held it through three gusts. Your balance is better for it."},
		metal_exercise = {Path = "Metal", Title = "Forge Cadence", Anim = "Misc_Build", Seconds = 22, Source = "Exercise", Mult = 1, PerDay = 6,
			Requires = Acquired("Metal"), Start = "Work the practice bar. Same strike, same place, every time.", Done = "Twenty strikes, one mark. That's the craft."},
	},
}
