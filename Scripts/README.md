# Scripts (exported from Studio)

Read-only copies of Luau scripts from the Rensei Studio place, saved here so changes can be reviewed on GitHub. **The Studio place is the source of truth**; these files are not synced automatically, and editing them here changes nothing in the game.

Paths mirror the Studio tree (`Scripts/ServerScriptService/MinigameService.lua` = `game.ServerScriptService.MinigameService`). All are ModuleScripts.

| File | Studio path | Last exported |
|---|---|---|
| `ServerScriptService/MinigameService.lua` | `ServerScriptService.MinigameService` | 2026-10-16 |
| `ReplicatedStorage/Modules/UI/MinigameUI.lua` | `ReplicatedStorage.Modules.UI.MinigameUI` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Minigames.lua` | `ReplicatedStorage.Modules.Data.Rensei.Minigames` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Puzzles.lua` | `ReplicatedStorage.Modules.Data.Rensei.Puzzles` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Evidence.lua` | `ReplicatedStorage.Modules.Data.Rensei.Evidence` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Investigation.lua` | `ReplicatedStorage.Modules.Data.Rensei.Investigation` | 2026-10-16 |
| `ServerScriptService/MoralityService.lua` | `ServerScriptService.MoralityService` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Factions.lua` | `ReplicatedStorage.Modules.Data.Rensei.Factions` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Deeds.lua` | `ReplicatedStorage.Modules.Data.Rensei.Deeds` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/StoryLogic.lua` | `ReplicatedStorage.Modules.Data.Rensei.StoryLogic` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Quests.lua` | `ReplicatedStorage.Modules.Data.Rensei.Quests` | 2026-10-16 |
| `ReplicatedStorage/Modules/Data/Rensei/Dialogues.lua` | `ReplicatedStorage.Modules.Data.Rensei.Dialogues` | 2026-10-16 |
| `ServerScriptService/QuestService.lua` | `ServerScriptService.QuestService` | 2026-10-16 |
| `ServerScriptService/DialogueService.lua` | `ServerScriptService.DialogueService` | 2026-10-16 |
| `ServerScriptService/WorldService.lua` | `ServerScriptService.WorldService` | 2026-10-16 |
| `ServerScriptService/CharacterHandler/DataManager.lua` | `ServerScriptService.CharacterHandler.DataManager` | 2026-10-16 (one line redacted) |
| `ReplicatedStorage/Modules/Data/ProfileData.lua` | `ReplicatedStorage.Modules.Data.ProfileData` | 2026-10-16 |
| `ReplicatedStorage/Modules/UI/DialogueUI.lua` | `ReplicatedStorage.Modules.UI.DialogueUI` | 2026-10-16 |
| `ReplicatedStorage/Modules/Managers/DownedManager.lua` | `ReplicatedStorage.Modules.Managers.DownedManager` | 2026-10-16 |

Exports so far (all 2026-10-16): the scripts touched by the Assay Bench / Ledger Cipher work, the stuck-dialogue fix (DialogueService, DialogueUI) and the morality slice with every engine script it changed (see `Documents/Changelog.md`). Each file is byte-identical to the Studio source at the time of export, except `DataManager.lua`: one line names a specific player for a test reset, and that name is replaced with `<redacted>` because this repository is public.
