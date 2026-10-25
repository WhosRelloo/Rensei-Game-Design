# Gun Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Facts** below together with its own task.

**Goal:** Fix guns' shooting-mode aiming, rebalance the gun class, and give the automatic reload an animation slot with a safe fallback. That means:
- the shot goes where the crosshair is (parallax, shift lock and lock-on);
- no fire-straight-ahead fallback;
- bounded lag compensation;
- hold to fire;
- the PROPOSAL balance table;
- the `Guns_Reload` slot, with an interrupt rule and a top-up;
- hit and recoil feedback using only existing UI assets;
- touch fire and assist;
- fair enemy gunners.

**Spec:** `Documents/specs/2026-10-25-gun-rework-design.md`. Every number in it, and here, is **PROPOSAL** unless it quotes an owner decision. Its §8 lists the decisions taken without the owner, and its §9 lists the Studio checks that Task 1 answers.

**When to start:**
- After the Foundry Yard plan has finished: Backlog order item 3, "still after all the Foundry tasks".
- `sync.py`, `sync_manifest.json` and `dumphelper.lua` belong to that plan until it ends. This plan extends them only after it has ended.
- `Documents/CLAUDE.md` asks for approval before scripts are rewritten. The owner's overnight go-ahead (Backlog, 2026-10-25) covers planning. **The controller confirms the owner has seen the spec before Task 4**, the first behaviour change. Tasks 1–3 change no behaviour in the game.

**Architecture:** Four stages:
1. **Parity** (Task 1): the repo holds every script this plan touches, equal to Studio in both places. The sync tool gets a `--backup` name for this plan.
2. **Pure maths and data** (Tasks 2–3): `Rensei.GunAim` and the TuningConfig numbers, tested in the Play VM with no game wiring.
3. **The server** (Tasks 4–6, then 10):
   - the shot path (aim validated, per-gun range and falloff, flinch range, meter, the result attribute);
   - lag compensation (`PositionHistory`);
   - the reload (the slot, the interrupt, the top-up);
   - enemy gunners.
4. **The client and the close** (Tasks 7–9, then 11–12):
   - the aim camera and crosshair, hold to fire, feedback, touch;
   - Foundry parity and the full sweep;
   - the docs and the one Changelog entry.

Nothing here publishes.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), for the sync tool's change and its test.

---

## Facts (read from the repo, 2026-10-25; Task 1 confirms them in Studio)

**Places and windows.**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.

**The scripts this plan touches.** The repo path is given first, then the expected Studio path; Task 1 confirms each.

| Label | Repo | Studio | In repo? |
|---|---|---|---|
| `Rensei.TuningConfig` | `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua` | `ReplicatedStorage/Modules/Data/Rensei/TuningConfig` | yes |
| `Rensei.GunAim` | `.../Data/Rensei/GunAim.lua` | `ReplicatedStorage/Modules/Data/Rensei/GunAim` | new (Task 2) |
| `Managers.WeaponManager` | `Scripts/ReplicatedStorage/Modules/Managers/WeaponManager.lua` | `ReplicatedStorage/Modules/Managers/WeaponManager` | yes |
| `Managers.AttackRunner`, `Managers.DamageManager`, `Managers.AnimationManager` | `.../Managers/<X>.lua` | `ReplicatedStorage/Modules/Managers/<X>` | yes (read-only here; paired so the sweep covers them) |
| `UI.HUDUI`, `UI.SettingsUI`, `UI.MobileControls` | `Scripts/ReplicatedStorage/Modules/UI/<X>.lua` | `ReplicatedStorage/Modules/UI/<X>` | yes |
| `UI.LockOn` | `.../UI/LockOn.lua` | `ReplicatedStorage/Modules/UI/LockOn` | **no: export** |
| `UI.CooldownUI` | where Task 1 finds it | where Task 1 finds it | **no: export** |
| `UI.GunAimUI` | `.../UI/GunAimUI.lua` | `ReplicatedStorage/Modules/UI/GunAimUI` | new (Task 7) |
| `Requests.Shoot` | `Scripts/ServerScriptService/ServerHandler/Requests/Shoot.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/Shoot` | yes |
| `Requests.WeaponSkill`, and the `"Aim"` request if it exists | `.../Requests/<X>.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/<X>` | **no: export** |
| `RenseiServer.ServerHandler` | `Scripts/ServerScriptService/ServerHandler.server.lua` | `ServerStorage/RenseiServer/ServerHandler` | yes (already a manifest pair) |
| `RenseiServer.EnemyService` | `Scripts/ServerScriptService/EnemyService.lua` | `ServerStorage/RenseiServer/EnemyService` | yes (already a pair) |
| `RenseiServer.PositionHistory` | `Scripts/ServerScriptService/PositionHistory.lua` | `ServerStorage/RenseiServer/PositionHistory` | new (Task 5) |
| `SPScripts.ClientHandler` | `Scripts/StarterPlayer/StarterPlayerScripts/ClientHandler.client.lua` | `StarterPlayer/StarterPlayerScripts/ClientHandler` (LocalScript, a package; children Controls, Roll, Run, Crouch stay) | yes |
| `RenseiTests.Test_GunAim`, `Test_GunBalance`, `Play_Guns`, `Play_GunReload`, `Play_GunNpc` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | new |

**What the code does today** (the spec's §§1–3 have the line numbers):
- the shot fires from `Root + (0, 1.5, 0)` along the camera's look;
- the server cone falls back to straight ahead;
- there's no rewind;
- one shot per press;
- NPCs never call `SetAim`;
- `Resolve` scales Fan the Hammer against the whip's damage;
- Mastery deepens falloff;
- the whiff penalty applies to shots;
- shots give 4 meter and flinch at any range.

**Animations:**
- No reload animation exists anywhere the docs record.
- `AnimationManager` preloads everything in `Assets.Animations.Shared` and `.Weapons` on the client. It skips an `Animation` whose id is empty and that has no `Save` child (`Playable` returns nil).
- On the server, `Play` on a player sends a remote to that player's client.
- A name missing on the client with no `Fallback` warns "Animation not found". The reload code therefore never asks to play an empty slot.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. The crosshair is the existing `Gui.Crosshair` marker. The hint and the touch buttons are the existing HUD text and MobileControls buttons. No new images, fonts or sounds.
- **Owner decisions kept:**
  - "Guns: no reload button, automatic only";
  - "M1 with a gun is a melee pistol whip and never fires a bullet";
  - Y toggles shooting mode and RMB fires while it's on.
- **Never invent an asset id.** The reload slot stays empty until the owner pastes the id of an animation they uploaded.

**Labels and records:**
- Label every invented number **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 12, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server|Client> @file.lua`.
  - Only the first return value prints, cut at 30,000 characters.
  - For a longer return, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks, and delete it.
  - If `Client` isn't accepted by rbxc, Task 7's client checks run as a TEMP LocalScript (see Task 7).
- **Studio state:** `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`.
- **Play:** `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Never touch the Studio window "bloodydeadpool53's Place".
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/gun-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.

- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. **Lock.** In Ye (Edit), `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:gun<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. **Hook.** In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`. Then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua`. It returns "dump helper installed".
  3. **Start Play.** In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. Then take the dump: `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`. Save it to the scratch folder as `quests_gun<task>_1.txt`.
  4. **Suites.** Run them with `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  5. **Restore.** Run `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - Dump again (`quests_gun<task>_2.txt`). It must equal the first dump character for character.
     - `LMTestHook:Invoke("diff")` may list only the known encode-quirk keys (Settings, Story, Morality). **Any other key**, for example Inventory, Loadout or Hotbar, means stop: keep Play running and report both dumps and the diff to the controller.
  6. **Stop** Play.
  7. **Unhook.** In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`. Then remove the helper: copy `dumphelper.lua` to the scratch folder, set its MODE line to `"remove"` there (only that line), and run the copy in Edit. It returns "removed <n>".
  8. **Unlock.** Only then, clear PlayLock in both places.
- **Guns in tests:**
  - Test shooters are **NPC rigs** armed with `WeaponManager.Give`.
  - The player's character gets a gun only through `WeaponManager.Give` in Play (Tasks 7–9), never through LoadoutService or the inventory, so no inventory write is asked for.
- **Script edits are refused while Play runs.**
- **In Play, the world is a copy.** Instance changes made in Play (a stand-in animation id, dummies) vanish at Stop. Save data is real: the hook's restore puts it back.
- **Edit's require cache.** Edit keeps a module's result between `execute_luau` calls. Every suite here runs **in the Play VM** (`LMRunSuite`), because each requires a module this plan changes.

**Scripts live in both places.**
- Every script is edited in the repo first, then set into **both** places with the sync tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-GunRework_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- `--check` must print `DIFFER 0 / MISSING 0` for **both** places at the end of every task that touched a script.
- Each task adds its own pairs to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (the format in the Foundry plan, Task 1), with `Places: ["ye", "foundry"]`.
- **Backups:** the tool clones a script once into `ServerStorage.RenseiBackups["Pre-GunRework_2026-10-25"]` before its first change in this plan. A created script gets no backup and carries `FoundryDataAdd = true` (the tool's existing mark).
- **The normalised hash** is the one in the Foundry plan's Global Constraints (`NormHash` / `norm_hash`).
- **Packages:** `Modules`, `RenseiServer` and `ClientHandler` are packages. Syncing changes both places' package copies. Publishing them is the owner's (Task 12's checkpoint).

**Reversible Studio scripts** (only the reload slot, Task 6) follow the Foundry plan's contract:
- `local MODE = "plan"`, with the modes plan / apply / undo / check / test;
- refusals while Play runs or PlayLock is set;
- a pcall journal;
- one ChangeHistoryService recording;
- the marks `GunReworkAdd = true` and the flag attribute `GunReloadSlot` on `Assets.Animations`;
- `check` written as failure conditions only.

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or against a control that keeps today's rule), and fails. Then it passes after.
- **A check that cannot fail is not a check.** Never choose a test spot or input by reading the property under test. Expected numbers are worked by hand in the test, never read from TuningConfig at check time. The balance bands are constants in the test.
- **No duplicated test logic.** Shared helpers go in `RenseiTests.GunKit` (Task 4), required, never copied.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync.py`, `test_sync.py`, `sync_manifest.json` | `--backup`; the gun pairs | 1 (pairs added in every task) |
| Exported: `UI/LockOn.lua`, CooldownUI, `Requests/WeaponSkill.lua`, `Requests/Aim.lua` (if it exists), `Managers/SkillMods.lua` | Parity only | 1 |
| `Scripts/README.md` | Export rows | 1 |
| `Rensei/GunAim.lua` (new), `RenseiTests/Test_GunAim.lua` (new) | The pure maths | 2 |
| `Rensei/TuningConfig.lua`, `Managers/WeaponManager.lua` (`Resolve`, `DamageMult`), `RenseiTests/Test_GunBalance.lua` (new) | The numbers | 3 |
| `Managers/WeaponManager.lua` (aim, `Fire`), `Requests/Shoot.lua`, `RenseiTests/GunKit.lua`, `Play_Guns.lua` (new) | The server shot path | 4 |
| `ServerScriptService/PositionHistory.lua` (new), `ServerHandler.server.lua`, `WeaponManager.lua`, `Play_Guns.lua` | Lag compensation | 5 |
| `Art/Studio/Guns/reload_slot.lua` (new), `WeaponManager.lua`, `Requests/Shoot.lua`, `RenseiTests/Play_GunReload.lua` (new) | The reload | 6 |
| `UI/GunAimUI.lua` (new), `ClientHandler.client.lua`, `UI/SettingsUI.lua`, `UI/HUDUI.lua`, `Art/Studio/Guns/client_checks.lua` (new) | Client aim, hold to fire | 7 |
| `UI/GunAimUI.lua`, `ClientHandler.client.lua` | Feedback | 8 |
| `UI/GunAimUI.lua`, `UI/MobileControls.lua`, `UI/HUDUI.lua`, `ClientHandler.client.lua` | Touch | 9 |
| `ServerScriptService/EnemyService.lua`, `RenseiTests/Play_GunNpc.lua` (new) | Enemy gunners | 10 |
| (no new files) | Foundry parity and the sweep | 11 |
| `Documents/Changelog.md`, `COMBAT_SYSTEM.md`, `Controls.md`, `Animations.md`, `Backlog.md` | Docs | 12 |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`. `Managers/` and `UI/` are under `Scripts/ReplicatedStorage/Modules/`. `RenseiTests/` is `Scripts/ServerStorage/RenseiTests/`. `Requests/` is `Scripts/ServerScriptService/ServerHandler/Requests/`.

---

### Task 1: Parity: every gun script in the repo, equal to Studio, in both places

**Files:**
- **Modify:**
  - `Art/Studio/Regions/Foundry/data/sync.py` (`--backup`);
  - `test_sync.py`;
  - `sync_manifest.json`;
  - `Scripts/README.md`.
- **Create (exports, read-only from Ye):**
  - `Scripts/ReplicatedStorage/Modules/UI/LockOn.lua`;
  - CooldownUI at its found path;
  - `Scripts/ReplicatedStorage/Modules/Managers/SkillMods.lua`;
  - `Scripts/ServerScriptService/ServerHandler/Requests/WeaponSkill.lua`;
  - `Requests/Aim.lua` if it exists.
- **No game behaviour changes.**

**Interfaces:**
- `sync.py --backup <Name>`: optional. It defaults to the existing `BACKUP` constant (`Pre-FoundryData_2026-10-24`), so every existing call stays byte-for-byte the same. The name flows into each bundle's `BACKUP` line (`write_bundle(pair, out_dir, backup)`).
- **Manifest pairs added**, all with `Places: ["ye", "foundry"]` and `Create: false`:
  - `Rensei.TuningConfig`;
  - `Managers.WeaponManager`, `Managers.AttackRunner`, `Managers.DamageManager`, `Managers.AnimationManager`, `Managers.SkillMods`;
  - `UI.HUDUI`, `UI.SettingsUI`, `UI.MobileControls`, `UI.LockOn`, `UI.CooldownUI`;
  - `Requests.Shoot`, `Requests.WeaponSkill` (and `Requests.Aim` if found);
  - `SPScripts.ClientHandler` (LocalScript).
- `RenseiServer.ServerHandler` and `RenseiServer.EnemyService` are already pairs.

**Steps:**
- [ ] **Step 1: Write the new `test_sync.py` test; it fails.** A bundle generated with `backup="Pre-GunRework_2026-10-25"` carries that name on its `BACKUP` line, and one generated without it carries `Pre-FoundryData_2026-10-24`. RED: `write_bundle` takes no backup argument.
- [ ] **Step 2: Add `--backup`** (argparse, passed to `write_bundle`). Run `test_sync.py`. Expected: all pass, the old tests unchanged.
- [ ] **Step 3: Read Ye read-only and answer the spec's §9 checks** in the task report:
  - **Scripts:** the paths of CooldownUI, the `"Aim"` request handler (or "none") and `Requests.WeaponSkill`. Does WeaponSkill call `WeaponManager.Resolve` for Fan the Hammer, and does Fan need `ShootingMode`?
  - **The lock-on camera:** where it puts the camera, and whether it sets `AutoRotate`.
  - **UI:** `Gui.Crosshair`'s class, its ScreenGui's `IgnoreGuiInset`, `AnchorPoint` and `Position`, and the HUD ScreenGui's `IgnoreGuiInset`.
  - **Assets:** `Assets.Animations.Weapons`'s children (is there a `Guns` folder?), and whether `ReplicatedStorage.Assets` is a package.
  - **Other places:** whether the Tutorial place holds the `Modules` package.
  - **An R6 rig's extents:** measure `game.StarterPlayer.StarterCharacter`'s parts relative to its HumanoidRootPart, reported as the min and max corner, rounded to 0.1. This sets `Aim.HitBox` and `HitBoxOffset` in Task 3. Expected about (−2, −3, −0.5) to (2, 2.2, 0.5).
  - **Settings:** where client effects read Settings > Camera Shake.

  The Play-only checks (§9 items 5 and 6, RMB camera turn and `World.Live`'s layout) are answered in Task 4's first Play session.
- [ ] **Step 4: Export** each Studio-only script's Source to its repo path, byte for byte with CRLF normalised to LF. Add the manifest pairs.
- [ ] **Step 5: RED, then parity.**
  - Before Step 4, `sync.py --place ye --check` failed for the new pairs: test_sync's "every manifest Repo file exists" was RED.
  - Now run `sync.py --place ye --check` and `--place foundry --check`. Expected: `DIFFER 0 / MISSING 0` for both.
  - If an **existing** repo copy differs from Ye, Studio wins: export Ye's copy over the repo file and list it in the report.
  - If Foundry differs from Ye on a gun pair, report it; the controller rules before any sync.
- [ ] **Step 6:** Add the exported files' rows to `Scripts/README.md`'s table, with the date 2026-10-25.
- [ ] **Step 7: Commit** `sync.py`, `test_sync.py`, `sync_manifest.json`, `Scripts/README.md` and the exported files: `"Gun rework Task 1: gun scripts in the repo equal to Studio; sync --backup"`.

---

### Task 2: `Rensei.GunAim`: the pure maths of a shot

**Files:**
- **Create:**
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/GunAim.lua`;
  - `Scripts/ServerStorage/RenseiTests/Test_GunAim.lua`.
- **Manifest:** `Rensei.GunAim` (`Create: true`) and `RenseiTests.Test_GunAim` (`Create: true`).

**Interfaces** (the whole module; Instances come in only as arguments):

```lua
-- GunAim (gun rework 2026-10-25): the pure maths of a gunshot, shared by the client (where the crosshair points) and the
-- server (what the shot may hit). Numbers live in TuningConfig.Weapons.Guns.Aim (PROPOSAL). No Instance is read here
-- except through the arguments, so RenseiTests.Test_GunAim checks it without a game.
local GunAim = {}

GunAim.MUZZLE = Vector3.new(0, 1.5, 0) -- the shot leaves from the head: root + this (WeaponManager.Fire's origin since 2026-10-17)

function GunAim.Muzzle(RootPosition)
	return RootPosition + GunAim.MUZZLE
end

local function Finite(V)
	return V.X == V.X and V.Y == V.Y and V.Z == V.Z
		and math.abs(V.X) < math.huge and math.abs(V.Y) < math.huge and math.abs(V.Z) < math.huge
end

-- Where the crosshair points: the first thing the camera ray meets past the shooter. Cast(From, Vector) -> a hit position
-- or nil (the caller's raycast and filter). The ray starts level with the muzzle, so nothing between the camera and the
-- shooter (a wall behind you, your own body) counts.
function GunAim.AimPoint(CamOrigin, CamDir, Muzzle, Range, Cast)
	CamDir = CamDir.Unit
	local Skip = math.max(0, (Muzzle - CamOrigin):Dot(CamDir))
	local From = CamOrigin + CamDir * Skip
	local Hit = Cast and Cast(From, CamDir * Range)
	return Hit or (From + CamDir * Range)
end

-- The shot's direction: from the muzzle to the aim point. An aim point nearer than MinDist, or behind, falls back to the
-- camera's direction.
function GunAim.Direction(Muzzle, AimPoint, CamDir, MinDist)
	local To = AimPoint - Muzzle
	if To.Magnitude < (MinDist or 2) or To:Dot(CamDir) <= 0 then return CamDir.Unit end
	return To.Unit
end

-- Server: may this character shoot along Dir? Returns Dir.Unit, or nil and the reason.
function GunAim.Validate(Dir, RootLook, MaxYawDeg, MaxPitchDeg)
	if typeof(Dir) ~= "Vector3" or not Finite(Dir) then return nil, "malformed" end
	local M = Dir.Magnitude
	if M < 0.5 or M > 1.5 then return nil, "length" end
	Dir = Dir.Unit
	if math.abs(math.deg(math.asin(math.clamp(Dir.Y, -1, 1)))) > MaxPitchDeg then return nil, "pitch" end
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	local Look = Vector3.new(RootLook.X, 0, RootLook.Z)
	if Flat.Magnitude > 1e-3 and Look.Magnitude > 1e-3 then
		if math.deg(math.acos(math.clamp(Flat.Unit:Dot(Look.Unit), -1, 1))) > MaxYawDeg then return nil, "behind" end
	end
	return Dir
end

-- Distance t along Origin + Dir * t (Dir unit, 0 <= t <= MaxDist) to the box (CFrame, Size), or nil. Slab test.
function GunAim.RayBox(Origin, Dir, MaxDist, BoxCFrame, Size)
	local O = BoxCFrame:PointToObjectSpace(Origin)
	local D = BoxCFrame:VectorToObjectSpace(Dir)
	local TMin, TMax = 0, MaxDist
	for _, Axis in ipairs({"X", "Y", "Z"}) do
		local Oa, Da, Ha = O[Axis], D[Axis], Size[Axis] / 2
		if math.abs(Da) < 1e-9 then
			if Oa < -Ha or Oa > Ha then return nil end
		else
			local T1, T2 = (-Ha - Oa) / Da, (Ha - Oa) / Da
			if T1 > T2 then T1, T2 = T2, T1 end
			TMin, TMax = math.max(TMin, T1), math.min(TMax, T2)
			if TMin > TMax then return nil end
		end
	end
	return TMin
end

-- History = {{T = time, CF = CFrame}, ...}, oldest first. The CFrame at time T: linear between samples, clamped to the ends.
function GunAim.Rewind(History, T)
	local N = #History
	if N == 0 then return nil end
	if T >= History[N].T then return History[N].CF end
	if T <= History[1].T then return History[1].CF end
	for I = N - 1, 1, -1 do
		local A, B = History[I], History[I + 1]
		if T >= A.T then return A.CF:Lerp(B.CF, (T - A.T) / math.max(B.T - A.T, 1e-6)) end
	end
	return History[1].CF
end

-- Seconds to rewind a player's shot: one-way ping (Player:GetNetworkPing(), as Block.lua reads it) + Interp, capped.
function GunAim.RewindTime(Ping, Cfg)
	return math.clamp((tonumber(Ping) or 0) + Cfg.Interp, 0, Cfg.MaxRewind)
end

-- Point Blank inside Passive.Range, else the gun's falloff {Start, End, Min} (or the class one).
function GunAim.RangeMult(D, Passive, Falloff)
	if D <= Passive.Range then return Passive.Mult end
	local F = Falloff or Passive.Falloff
	if F and D > F.Start then return 1 - (1 - F.Min) * math.clamp((D - F.Start) / (F.End - F.Start), 0, 1) end
	return 1
end

-- Weapon Mastery strengthens a passive's bonus only; it never deepens a penalty (falloff). Was 1 + (M - 1) * Mastery for all M.
function GunAim.Mastered(M, Mastery)
	if M > 1 then return 1 + (M - 1) * Mastery end
	return M
end

function GunAim.Flinches(D, Cfg)
	return D <= Cfg.FlinchRange
end

-- Touch aim assist: the centre nearest the ray within MaxDeg and MaxDist, or nil.
function GunAim.Assist(Origin, Dir, Centres, MaxDeg, MaxDist)
	local Best, BestDeg = nil, MaxDeg
	for _, P in ipairs(Centres) do
		local To = P - Origin
		local D = To.Magnitude
		if D > 1 and D <= MaxDist then
			local Deg = math.deg(math.acos(math.clamp(To.Unit:Dot(Dir.Unit), -1, 1)))
			if Deg < BestDeg then Best, BestDeg = P, Deg end
		end
	end
	return Best
end

-- Dir turned by up to Deg degrees at random (Rng: a Random, so tests can seed it).
function GunAim.Spread(Dir, Deg, Rng)
	if not Deg or Deg <= 0 then return Dir end
	local S = math.rad(Deg)
	local Yaw, Pitch = (Rng:NextNumber() * 2 - 1) * S, (Rng:NextNumber() * 2 - 1) * S
	return (CFrame.lookAt(Vector3.zero, Dir) * CFrame.Angles(Pitch, Yaw, 0)).LookVector
end

-- Seconds between two shots, and burst / sustained damage per second. Stats: a Guns.Items entry; Shot: a Guns.Shots def.
function GunAim.Interval(Shot, Stats)
	return Shot.Startup + Shot.Active + (Stats.Recovery or Shot.Recovery)
end
function GunAim.DPS(Shot, Stats)
	local I = GunAim.Interval(Shot, Stats)
	return Stats.Damage / I, Stats.Damage * Stats.Magazine / (I * Stats.Magazine + Stats.Reload)
end

return GunAim
```

**Note on `Spread`:** it rotates by up to Deg on each axis, so a corner sample reaches Deg × √2 off the line. The test checks the per-axis bound.

**`Test_GunAim`** returns a TestKit suite. Its cases, with the numbers worked by hand:
- **`ParallaxShotMeetsCrosshair`:**
  - Setup: muzzle M = (0, 6.5, 0). Camera C = M + (1.75, 1.5, 12) = (1.75, 8, 12), looking at P = (0, 6.5, −40), the centre of a **2 × 2 × 2 box (a head)** at P.
  - `AimPoint(C, (P − C).Unit, M, 120, Cast)`, where Cast is a stub that runs `RayBox` on that box and returns `From + Vec.Unit * t`.
  - `Direction(M, Point, CamDir)` from M hits the box (`RayBox ~= nil`).
  - **Control:** `RayBox(M, CamDir, 120, Box)` is nil. Today's rule misses. Worked by hand: at z = −40 the parallel ray is at x ≈ −1.35 and y ≈ 5.35, outside the box's ±1.
- **`AimPointSkipsBehindShooter`:** a stub wall 3 studs in front of the camera (between the camera and the muzzle) isn't the aim point.
- **`DirectionFallsBackWhenClose`:** an aim point 1 stud ahead returns `CamDir`.
- **`ValidateAccepts`:** the forward direction `(0, 0, −1)` with look `(0, 0, −1)` returns a unit vector.
- **`ValidateRefuses`:** each of these is nil, with its reason:
  - `Vector3.new(0/0, 0, 1)` ("malformed");
  - `Vector3.zero` ("length");
  - `(0, 0, −3)` ("length");
  - a direction 80° up ("pitch");
  - 150° from the look ("behind").
- **`RayBoxHits`:**
  - the origin (0, 0, 10), direction (0, 0, −1), a 2 × 2 × 2 box at the origin gives t = 9 (within 1e-6);
  - the same box rotated 45° about Y gives t = 10 − √2;
  - from inside it gives 0;
  - parallel and outside gives nil.
- **`RewindInterpolates`:**
  - samples at T 0 and 1 with positions (0, 0, 0) and (10, 0, 0);
  - T 0.25 gives x = 2.5;
  - T −1 gives 0, and T 5 gives 10;
  - an empty history gives nil.
- **`RewindTimeCapped`:** with `{Interp = 0.1, MaxRewind = 0.25}`, ping 0.05 → 0.15, ping 0.4 → 0.25, ping "x" → 0.1.
- **`RangeMult`:** with Passive `{Range = 12, Mult = 1.2}` and falloff `{Start = 20, End = 70, Min = 0.5}`:
  - 5 → 1.2;
  - 20 → 1;
  - 45 → 0.75;
  - 80 → 0.5.
- **`MasteredNeverDeepens`:**
  - `Mastered(0.5, 1.75)` = 0.5. Control: the old formula gives 0.125;
  - `Mastered(1.2, 1.75)` = 1.35.
- **`Flinch`:** 24.9 is true and 25.1 is false, with `{FlinchRange = 25}`.
- **`AssistPicks`:**
  - from the origin along (0, 0, −1), centres at (0, 0, −30) rotated 2° and 1°: the 1° centre is picked;
  - one at 3° alone gives nil;
  - one at 2° beyond MaxDist gives nil.
- **`SpreadBounded`:**
  - `Random.new(7)`, 200 samples of `Spread((0, 0, −1), 2.5, Rng)`;
  - each sample's yaw and pitch stay within 2.5° + 1e-6;
  - at least one exceeds 1.25° on some axis;
  - `Spread(Dir, 0, Rng)` returns Dir.
- **`DPS`:** `Shot = {Startup = 0.12, Active = 0.02, Recovery = 0.2}` with `Stats = {Damage = 20, Magazine = 6, Reload = 2.0, Recovery = 0.36}` gives interval 0.5, burst 40, sustained 24.

**Steps:**
- [ ] **Step 1:** Write `Test_GunAim` and a **stub** `GunAim` whose `Direction` returns `CamDir.Unit` (today's rule) and whose other functions `error("todo")`. Sync both to Ye.
- [ ] **Step 2: RED.** Play in Ye (the protocol; PlayLock `Ye:gun2`). `LMRunSuite("Test_GunAim")`. Expected: `ParallaxShotMeetsCrosshair` fails on the stub's `Direction`, and every other case fails on "todo". Record the counts.
- [ ] **Step 3:** Write the module as above. Sync it to Ye. Play: `Test_GunAim`. Expected: all pass. Record `PASS n / FAIL 0`.
- [ ] **Step 4:** Sync both files to Foundry. Run `--check` for both places.
- [ ] **Step 5: Commit** `GunAim.lua`, `Test_GunAim.lua` and the manifest: `"Gun rework Task 2: GunAim, the pure maths of a shot (PROPOSAL numbers)"`.

---

### Task 3: The numbers: TuningConfig, `Resolve` and the Mastery rule

**Files:**
- **Modify:**
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua`;
  - `Scripts/ReplicatedStorage/Modules/Managers/WeaponManager.lua` (`Resolve` and `DamageMult` only).
- **Create:** `Scripts/ServerStorage/RenseiTests/Test_GunBalance.lua`.
- **Manifest:** `RenseiTests.Test_GunBalance` (`Create: true`).

**Interfaces:**

**TuningConfig.** Make these exact changes in `Weapons.Guns`, keeping the comment style. Each line ends with `-- PROPOSAL (gun rework 2026-10-25)`.
- **`Shots`:** add `NoWhiffPenalty = true` to each of the four hits. Damage, Startup and the rest are unchanged.
- **`Skill` (Fan the Hammer):** `Damage = 12, Range = 40, Spread = 3`. Everything else is unchanged.
- **`Items`:**
  ```lua
  Revolver = {Damage = 20, Magazine = 6, Reload = 1.8, Recovery = 0.42, Range = 70, Falloff = {Start = 20, End = 70, Min = 0.5}, Kick = 1.5},
  Renetti = {Damage = 10, Magazine = 12, Reload = 1.6, Recovery = 0.2, Range = 60, Falloff = {Start = 15, End = 60, Min = 0.5}, Kick = 0.5},
  ["Forge Tac"] = {Damage = 26, Magazine = 5, Reload = 1.8, Recovery = 0.62, Range = 110, Falloff = {Start = 40, End = 110, Min = 0.5}, Kick = 2.0},
  Sykov = {Damage = 13, Magazine = 10, Reload = 1.7, Recovery = 0.24, Range = 90, Falloff = {Start = 25, End = 90, Min = 0.5}, Kick = 0.8},
  ```
- **New in `Weapons.Guns`:**
  ```lua
  Aim = {
  	MaxYaw = 100, MaxPitch = 70, -- degrees a shot may leave your facing / the horizon
  	AimFresh = 0.5, -- seconds a stored aim (Fan the Hammer's "Aim") stays good (was 2)
  	Interp = 0.1, MaxRewind = 0.25, -- lag compensation: one-way ping + Interp, capped
  	HitBox = Vector3.new(4, 5.2, 2), HitBoxOffset = Vector3.new(0, -0.4, 0), -- a character's box around its root (Task 1 measured)
  	FlinchRange = 25, -- shots stun only this close
  	MaxFirePerSecond = 12, -- Fire requests per player per second; more are dropped
  	Buffer = 0.2, -- client: a press this long before the gun is ready still fires
  	ShoulderOffset = Vector3.new(1.75, 0.5, 0), -- the aim camera (Humanoid.CameraOffset)
  	TouchAssist = 2.5, -- degrees; 0 = off
  	SnapDeg = 120, SnapWindow = 0.1, -- the snap log
  },
  Reload = {Anim = "Guns_Reload", AnimLength = nil}, -- the slot (Task 6); AnimLength is set once the owner uploads it
  NpcShot = {Startup = 0.35, Telegraph = true, Spread = 2.5}, -- enemy gunners (Task 10)
  ```
  If Task 1's R6 measurement differs from (4, 5.2, 2) and (0, −0.4, 0), use the measured values, rounded up to 0.1.
- **`TuningConfig.Meter`:** add `OnShotHit = 2, -- PROPOSAL (gun rework): a gun shot that lands (melee hits stay OnLightHit 4)`.

**`WeaponManager.Resolve`.** This replaces lines 61–73:
```lua
-- Copy of a gun SHOT's def with the held gun's damage, fire rate, range and falloff (gun rework 2026-10-25). Skills (Fan the
-- Hammer) keep their own numbers: the same for every gun. (They were scaled by the gun against Light.Hits[1], which has been the
-- pistol whip since 2026-10-17, so a Forge Tac's fan did 72.)
function WeaponManager.Resolve(Character, Def)
	local Stats = WeaponManager.ItemStats(Character)
	if not Stats or not Def.Shot then return Def end
	local Out = table.clone(Def)
	Out.Damage = Stats.Damage or Def.Damage
	Out.Recovery = Stats.Recovery or Def.Recovery
	Out.Range = Stats.Range or Def.Range
	Out.Falloff = Stats.Falloff
	return Out
end
```

**`WeaponManager.DamageMult`:**
- Change its body to `return GunAim.Mastered(PassiveDamageMult(Attacker, Victim, SkillInfo), SkillMods.Mult(Attacker, "WeaponPassive"))`.
- In `PassiveDamageMult`'s `Guns` branch, use `return GunAim.RangeMult(SkillInfo.ShotDistance or math.huge, P, SkillInfo.Falloff)` when `SkillInfo.Ranged`.
- Add `local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)` at the top.

**`Test_GunBalance`.** The constants are in the test: `BURST_MAX = 37`, `SUSTAINED = {20, 26}`. Cases:
- **`BurstAndSustainedInBand`:** each `Guns.Items` entry through `GunAim.DPS(Guns.Shots[1], Stats)`.
- **`Identities`:**
  - Forge Tac's Range is the largest;
  - Renetti's interval is the smallest;
  - the Revolver has the highest burst of the four (it's the close-range hand cannon).
- **`NoGunDominates`:** for every pair, A isn't ≥ B on Damage, Magazine, Range and (lower is better) Reload, while being strictly better on one.
- **`FanSameForEveryGun`:**
  - a fake character `{GetAttribute = function(_, K) return ({Weapon = "Guns", WeaponItem = X})[K] end}` for each item;
  - `WeaponManager.Resolve(Fake, Guns.Skill).Damage` is the same for all four, and equals `Guns.Skill.Damage`.
- **`ShotMeter`:** `Meter.OnShotHit == 2` and `Meter.OnLightHit == 4`.
- **`ShotsNoWhiff`:** every `Guns.Shots[i].NoWhiffPenalty == true`.

**Steps:**
- [ ] **Step 1: RED.**
  - Write `Test_GunBalance` and sync it to Ye. Play (PlayLock `Ye:gun3`), run `Test_GunBalance`.
  - Expected failures on today's numbers:
    - `BurstAndSustainedInBand` (Revolver 40.0, Forge Tac 40.7 and 27.4);
    - `NoGunDominates` (Forge Tac over the Revolver);
    - `FanSameForEveryGun`;
    - `ShotMeter`;
    - `ShotsNoWhiff`.
  - Record them.
- [ ] **Step 2:** Make the TuningConfig, `Resolve` and `DamageMult` changes. Sync `Rensei.TuningConfig` and `Managers.WeaponManager` to Ye.
- [ ] **Step 3: GREEN.** Play: run `Test_GunBalance` and `Test_GunAim`. Expected: all pass.
- [ ] **Step 4:** Sync to Foundry. `--check` both places.
- [ ] **Step 5: Commit** TuningConfig, WeaponManager, `Test_GunBalance` and the manifest: `"Gun rework Task 3: gun balance numbers, Fan the Hammer and Mastery fixes (PROPOSAL)"`.

---

### Task 4: The server shot path

**Gate:** the controller confirms the owner has seen the spec (header, "When to start").

**Files:**
- **Modify:**
  - `Scripts/ReplicatedStorage/Modules/Managers/WeaponManager.lua` (the gun section);
  - `Scripts/ServerScriptService/ServerHandler/Requests/Shoot.lua`.
- **Create:**
  - `Scripts/ServerStorage/RenseiTests/GunKit.lua`;
  - `Scripts/ServerStorage/RenseiTests/Play_Guns.lua`.
- **Manifest:** `RenseiTests.GunKit` and `RenseiTests.Play_Guns` (`Create: true`).

**Interfaces:**

**`WeaponManager.SetAim(Character, Dir)`** now validates. It returns the unit direction, or nil:
```lua
function WeaponManager.SetAim(Character, Dir)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Cfg = Tuning.Weapons.Guns.Aim
	local Ok = Root and GunAim.Validate(Dir, Root.CFrame.LookVector, Cfg.MaxYaw, Cfg.MaxPitch)
	Aim[Character] = Ok and {Dir = Ok, At = os.clock()} or {Bad = true, At = os.clock()}
	return Ok
end
```

**`AimDirection(Character, Root)`:**
- a fresh (< `Aim.AimFresh`) valid aim gives its direction;
- a fresh bad aim gives **nil** (the shot is refused);
- no fresh aim gives the root's flat look. That's for NPCs, and for skills with no aim sent.

`MAX_AIM_ANGLE` goes.

**`WeaponManager.ShotTarget(Shooter, Origin, Dir, MaxT, At)`:**
- It returns `Model, t` or nil: the nearest live character whose box (`Aim.HitBox` at the root CFrame × `CFrame.new(Aim.HitBoxOffset)`) the ray meets before MaxT.
- **Candidates:** Models with a living Humanoid that are children of `World.Live`, or children of a Folder directly in `World.Live`. Task 4's first Play session records `World.Live`'s layout; if it holds deeper characters, widen this and say so in the report.
- **The root CFrame:** `History and History.At(M, At) or Root.CFrame`. `History` is `ServerScriptService:FindFirstChild("PositionHistory")`, which is nil until Task 5 and in places without it.
- It's exported for tests.

**`WeaponManager.Fire(Character, SkillName, Def)`.** This replaces lines 367–410:

```lua
	-- One hitscan shot (gun rework 2026-10-25). The direction is the validated aim (AimDirection); an aim that failed
	-- validation fires nothing and spends no round (it used to fire straight ahead). The shot stops at the first wall
	-- (World.Live excluded from that ray) and hits the nearest character box before it (ShotTarget; Task 5 rewinds them).
	function WeaponManager.Fire(Character, SkillName, Def)
		local Results = {}
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root or not WeaponManager.CanFire(Character) then return Results end
		local Cfg = Tuning.Weapons.Guns.Aim
		local Dir = AimDirection(Character, Root)
		if not Dir then return Results end
		Character:SetAttribute("Ammo", Character:GetAttribute("Ammo") - 1)
		Dir = GunAim.Spread(Dir, Def.Spread, ShotRandom)
		local Origin = GunAim.Muzzle(Root.Position)
		local Range = (Def.Range or 90) * SkillMods.Mult(Character, "GunRange") -- Marksman
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {Character, workspace.World.Visuals, workspace.World.Live}
		local Wall = workspace:Raycast(Origin, Dir * Range, Params)
		local WallT = Wall and (Wall.Position - Origin).Magnitude or Range
		local Victim, T = WeaponManager.ShotTarget(Character, Origin, Dir, WallT, RewindAt(Character))
		local EndT = T or WallT
		local Tool = HeldTool(Character)
		local Barrel = Tool and Tool:FindFirstChild("Barrel", true)
		Barrel = Barrel and Barrel:IsA("BasePart") and Barrel or nil
		Tracer(Barrel and Barrel.Position or Origin, Origin + Dir * EndT)
		MuzzleFlash(Barrel, Dir)
		local Shown = "Miss"
		if Victim then
			local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
			local DamageManager = require(ReplicatedStorage.Modules.Managers.DamageManager)
			local Info = table.clone(SkillData[SkillName])
			Info.Damage = Def.Damage
			Info.Ranged = true
			Info.ShotDistance = T
			Info.Falloff = Def.Falloff
			Info.Meter = Tuning.Meter.OnShotHit
			if not GunAim.Flinches(T, Cfg) then Info.StunTime = 0 end -- no flinch past FlinchRange (DamageManager skips a 0 stun)
			local Result = DamageManager(Character, Victim, Info)
			table.insert(Results, {Victim = Victim, Result = Result})
			Shown = (Result == "Hit" and "Hit") or ((Result == "Blocked" or Result == "Shielded" or Result == "Countered") and "Blocked") or "Miss"
		end
		Character:SetAttribute("LastShotResult", Shown) -- the hit marker (GunAimUI, Task 8)
		Character:SetAttribute("LastShotAt", workspace:GetServerTimeNow())
		if Character:GetAttribute("Ammo") <= 0 then WeaponManager.Reload(Character) end
		return Results
	end
```

**Its helpers:**
- `local ShotRandom = Random.new()`.
- `local function RewindAt(Character) return workspace:GetServerTimeNow() end`. Task 5 replaces its body.
- `Spread` goes through `GunAim.Spread`; the inline math at the old lines 375–378 is removed.

**`Requests/Shoot.lua`, the Fire branch:**
- **Rate limit:** a per-player count in a 1-second window. Past `Aim.MaxFirePerSecond`, return.
- **Aim:** `local Dir = WeaponManager.SetAim(Character, Arg); if not Dir then return end`. This replaces `if Arg ~= nil then ... end`. **An invalid aim returns before AttackRunner,** so no animation plays and no round is spent.
- **The snap log:** if the previous Fire from this character was under `Aim.SnapWindow` seconds ago and the angle between the two directions is over `Aim.SnapDeg`, add 1 to the character's `GunSnapCount` attribute. That's all it does.

**`GunKit`** (test helpers, required by every gun suite):
- **`GunKit.Dummy(Pos, Name)`:** an R6 dummy cloned from `game.StarterPlayer.StarterCharacter`, anchored, in `World.Live`, at Pos, with `Humanoid.MaxHealth = Health = 1000`, and with `EnemyType` unset (so DamageManager doesn't refuse it as an NPC ally). Returns the Model.
- **`GunKit.Shooter(Pos, LookAt, Item)`:** a dummy facing LookAt, armed with `WeaponManager.Give(Model, Item)`, with `CombatMode = true` and a WCS character (the same way EnemyService makes one; copy that call, cited by line in the helper's comment).
- **`GunKit.Clean()`:** destroys every Model it made.
- **`GunKit.Shot(Shooter, Dir)`:** calls `SetAim`, then `WeaponManager.Fire(Shooter, "Guns_Shot1", WeaponManager.Resolve(Shooter, Tuning.Weapons.Guns.Shots[1]))`. Returns the results and the target's damage taken (Health before minus after).

**`Play_Guns`.** Every case builds its own dummies with GunKit in an open spot. That's a flat 200 × 200 area found by Step 1, never chosen by reading what the case checks. Cases:
- **`HitsWhatItAimsAt`:** Revolver, target 30 studs ahead, aimed at its root. Exactly 1 result.
- **`BehindIsRefused`:** aim (0, 0, +1) while facing −Z. No result, `Ammo` unchanged (6), `LastShotAt` unchanged.
- **`RangePerGun`:** a target at 65 studs. The Renetti gets no result (range 60); the Forge Tac gets one (110).
- **`Falloff`:** Revolver at 45 studs, a fresh target. Damage 15 ± 0.5 (20 × 0.75, worked by hand; the shooter's `PhysicalMultiplier` attribute is set to 1 by GunKit).
- **`MasteryDoesNotDeepen`:** the same, with the shooter's SkillMods `WeaponPassive` set to its max. The tree's API in `Managers.SkillMods` (exported in Task 1) shows how a test sets it; do it on the dummy only. Damage is still 15 ± 0.5.
- **`FlinchOnlyClose`:** at 10 studs the target gains the WCS Stun status; at 40 it doesn't.
- **`WallStops`:** a 10 × 10 × 1 anchored part between the shooter and the target at 15 studs. No result, and `LastShotResult == "Miss"`.
- **`RateLimit`:** 20 calls to the Shoot request function with a player stand-in in under 0.1 s produce at most 12 SetAim calls. The request function is `require(ServerScriptService.ServerHandler.Requests.Shoot)`; use the test player in Play. **No shot reaches AttackRunner,** because the player has no gun: this only counts the limiter, through a `Shoot.TestCount` hook. **Alternative if a hook is unwelcome:** the controller rules; leave the case out and say so.
- **`ResultAttribute`:** after a hit, `LastShotResult == "Hit"`. After a blocked hit (the target's Blocking status started, facing the shooter), `"Blocked"`.

**Steps:**
- [ ] **Step 1: The first Play in Ye** (PlayLock `Ye:gun4`). Before any change, answer the spec's §9 items 5 and 6:
  - In the Server: `World.Live`'s layout, its children by class and name pattern.
  - Then pick and record an open flat spot for the suites: a 200 × 200 area with ground and nothing within 10 studs above it, checked by raycasts.
  - Item 5, RMB turning the camera, is a Client check. With the player given a Revolver via `WeaponManager.Give` and `ShootingMode` set, run a TEMP LocalScript that records `Camera.CFrame` before and after a simulated RMB hold. If simulated input can't be sent, record "not checked; owner checks by hand". Remove it after.
- [ ] **Step 2: RED.**
  - Write GunKit and `Play_Guns`, and sync them to Ye.
  - Play: `Play_Guns`. Expected failures on today's code:
    - `BehindIsRefused` (it fires forward and spends a round);
    - `RangePerGun` (today 90 for both);
    - `MasteryDoesNotDeepen` — this one is green after Task 3, so note that it passed;
    - `FlinchOnlyClose`;
    - `ResultAttribute`;
    - `RateLimit`.
  - `HitsWhatItAimsAt` and `WallStops` pass today; they guard against regression. `Falloff` fails: today's range falloff starts at 25, so 45 studs gives about 0.85, not 0.75.
  - Record each.
- [ ] **Step 3:** Make the WeaponManager and Shoot changes. Sync `Managers.WeaponManager` and `Requests.Shoot` to Ye.
- [ ] **Step 4: GREEN.** Play: `Play_Guns`, `Test_GunAim`, `Test_GunBalance`, `Play_Stealth`, `Play_Assault`. Expected: the gun suites all pass, and Stealth and Assault are as before (record the counts).
- [ ] **Step 5:** Sync to Foundry. `--check` both places.
- [ ] **Step 6: Commit** WeaponManager, Shoot, GunKit, `Play_Guns` and the manifest: `"Gun rework Task 4: server shot path: validated aim, per-gun range and falloff, flinch range, shot result"`.

---

### Task 5: Lag compensation (`PositionHistory`)

**Files:**
- **Create:** `Scripts/ServerScriptService/PositionHistory.lua`.
- **Modify:**
  - `Scripts/ServerScriptService/ServerHandler.server.lua` (one line);
  - `WeaponManager.lua` (`RewindAt`);
  - `Play_Guns.lua` (new cases).
- **Manifest:** `RenseiServer.PositionHistory` (`ServerStorage/RenseiServer/PositionHistory`, ModuleScript, `Create: true`).

**Interfaces:**
```lua
-- PositionHistory (gun rework 2026-10-25): the last KEEP seconds of every live character's root CFrame, so a player's shot is
-- tested where its shooter saw the target (lag compensation, capped by TuningConfig.Weapons.Guns.Aim.MaxRewind). PROPOSAL.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)

local PositionHistory = {}
local KEEP = 0.5 -- seconds kept (PROPOSAL: twice MaxRewind)
local STEP = 1 / 30 -- seconds between samples
local Samples = {} -- [Model] = {{T, CF}, ...} oldest first
local Started = false

-- the same candidates as WeaponManager.ShotTarget: World.Live's character Models and those one Folder down
function PositionHistory.Models()
	local Out = {}
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if not Live then return Out end
	for _, C in ipairs(Live:GetChildren()) do
		if C:IsA("Model") and C:FindFirstChildOfClass("Humanoid") then
			table.insert(Out, C)
		elseif C:IsA("Folder") then
			for _, M in ipairs(C:GetChildren()) do
				if M:IsA("Model") and M:FindFirstChildOfClass("Humanoid") then table.insert(Out, M) end
			end
		end
	end
	return Out
end

function PositionHistory.Sample(Now)
	for _, M in ipairs(PositionHistory.Models()) do
		local Root = M:FindFirstChild("HumanoidRootPart")
		if Root then
			local H = Samples[M]
			if not H then
				H = {}
				Samples[M] = H
				M.Destroying:Once(function() Samples[M] = nil end)
			end
			table.insert(H, {T = Now, CF = Root.CFrame})
			while #H > 1 and Now - H[1].T > KEEP do table.remove(H, 1) end
		end
	end
	for M in pairs(Samples) do
		if not M.Parent then Samples[M] = nil end
	end
end

-- Where Model's root was at server time At (nil when it has no history yet).
function PositionHistory.At(Model, At)
	local H = Samples[Model]
	return H and GunAim.Rewind(H, At) or nil
end

function PositionHistory.Start()
	if Started then return end
	Started = true
	local Last = 0
	RunService.Heartbeat:Connect(function()
		local Now = workspace:GetServerTimeNow()
		if Now - Last >= STEP then
			Last = Now
			PositionHistory.Sample(Now)
		end
	end)
end

return PositionHistory
```

**Wiring:**
- **`ServerHandler.server.lua`:** after its Requests are loaded, add `task.spawn(function() local M = game:GetService("ServerScriptService"):WaitForChild("PositionHistory", 30) if M then require(M).Start() end end)`. If Task 1 found the RenseiServer modules in a different run-time parent, use that parent.
- **`WeaponManager`:** `ShotTarget` uses `PositionHistory.Models()` when the module exists, so the two lists can't drift. Without it, it uses its own copy of the same loop.
- **`RewindAt`:**
  ```lua
  local function RewindAt(Character)
  	local Player = Players:GetPlayerFromCharacter(Character)
  	if not Player then return workspace:GetServerTimeNow() end -- NPCs see the truth
  	local Ok, Ping = pcall(Player.GetNetworkPing, Player)
  	return workspace:GetServerTimeNow() - GunAim.RewindTime(Ok and Ping or 0, Tuning.Weapons.Guns.Aim)
  end
  ```

**New `Play_Guns` cases:**
- **`HistoryTracksAMover`:**
  - A dummy is moved by the test along +X at 16 studs/s for 1 s: `PivotTo` every Heartbeat from a start x0, with the path computed by the test.
  - Then `PositionHistory.At(Dummy, Now − 0.2)` is within 0.6 studs (16 × one 1/30 step + slack) of the test's own x at that time.
- **`RewindHitsWhereItWas`:**
  - Same mover. Right after it stops at x1, shoot `ShotTarget(Shooter, Origin, Dir, 200, Now − 0.2)` with Dir aimed at the test's own position for Now − 0.2 (x1 − 3.2). It hits.
  - **Control:** the same ray with `At = Now` misses, because the box is 3.2 studs further, wider than its 2-stud half-width margin.
- **`RewindCapped`:** `GunAim.RewindTime(2.0, Cfg) == 0.25`, so a ray at where the dummy was 0.6 s ago misses with `At = Now − RewindTime(2.0)`.

**Steps:**
- [ ] **Step 1: RED.** Add the cases and sync `Play_Guns` to Ye. Play (`Ye:gun5`): `Play_Guns`. Expected: the three new cases fail ("PositionHistory" missing). Record.
- [ ] **Step 2:** Write PositionHistory and the wiring. Sync `RenseiServer.PositionHistory`, `RenseiServer.ServerHandler` and `Managers.WeaponManager` to Ye.
- [ ] **Step 3: GREEN.** Play: `Play_Guns` all pass. Also record the server's Heartbeat time with 30 dummies in `World.Live`, with and without sampling: the mean over 300 frames. **The cost must be under 0.2 ms per frame;** otherwise report it.
- [ ] **Step 4:** Sync to Foundry. `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 5: lag compensation (PositionHistory, capped rewind)"`.

---

### Task 6: The reload: the animation slot, the interrupt rule, the top-up

**Files:**
- **Create:**
  - `Art/Studio/Guns/reload_slot.lua` (reversible);
  - `Scripts/ServerStorage/RenseiTests/Play_GunReload.lua`.
- **Modify:**
  - `WeaponManager.lua` (`Reload`, a new `CancelReload`);
  - `Requests/Shoot.lua` (the top-up).
- **Manifest:** `RenseiTests.Play_GunReload` (`Create: true`).

**Interfaces:**

**`reload_slot.lua`** (the contract in Global Constraints):
- **`apply`** creates one `Animation` named `Guns_Reload`, with `AnimationId = ""`, no children and `GunReworkAdd = true`:
  - **where:** `ReplicatedStorage.Assets.Animations.Weapons.Guns` if Task 1 found a `Guns` folder, else `Assets.Animations.Weapons`;
  - **flag:** it sets `Assets.Animations:SetAttribute("GunReloadSlot", true)`;
  - **refusals:** it refuses if any `Animation` named `Guns_Reload` already exists anywhere under `Assets.Animations`.
- **`undo`** destroys only an instance carrying `GunReworkAdd` and clears the flag. **It refuses if its AnimationId isn't empty**: the owner has filled it, and undoing would lose their id.
- **`check` fails when:**
  - there isn't exactly one `Guns_Reload`;
  - it isn't under `Weapons`;
  - it has a child;
  - its id isn't empty and `TuningConfig.Weapons.Guns.Reload.AnimLength` is nil. That last rule is reported as "owner filled the id; set AnimLength".
- **`test`:** as the contract says.
- **Run it in both places** (Edit).

**`WeaponManager` reload.** The server branch gains:
```lua
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local StunState = require(ReplicatedStorage.Modules.Skills.States.Stun)
	local ReloadToken = {} -- [Character] = the running reload's token

	-- the reload animation, only when the slot holds a real id (an empty slot plays nothing and warns nothing)
	local function ReloadAnimReady()
		local Name = Tuning.Weapons.Guns.Reload.Anim
		for _, A in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
			if A:IsA("Animation") and A.Name == Name then return A.AnimationId ~= "" end
		end
		return false
	end

	-- the interrupt rule (gun rework, PROPOSAL): things done to you cancel a reload; your own actions don't
	local function ReloadBlocked(Character)
		local WC = WCS.Character.GetCharacterFromInstance(Character)
		return (WC and WC:HasStatusEffects({StunState})) or Character:GetAttribute("Knocked") == true
			or Character:GetAttribute("GrippedBy") ~= nil or Character:GetAttribute("CarriedBy") ~= nil
			or Character:GetAttribute("Traversal") == "Swim"
	end
```

**`WeaponManager.Reload(Character)`:**
- **The guards:** today's guards (not already reloading, not full), plus `if ReloadBlocked(Character) then` a restart watcher and return.
- **A new token.**
- **The attributes:** `ReloadTime` and `ReloadingUntil`, as today.
- **The animation:** if `ReloadAnimReady()`, play it:
  ```lua
  AnimationManager.Play(Character, Cfg.Anim, {
  	Priority = Enum.AnimationPriority.Action,
  	Speed = Cfg.AnimLength and Cfg.AnimLength / ReloadTime or 1,
  })
  ```
- **The loop:** each Heartbeat until `ReloadingUntil`. If the token changed, stop. If `ReloadBlocked`, call `CancelReload` and then the restart watcher.
- **At the end:** if the token still holds and the same item is equipped, `Ammo = Magazine`. Clear both attributes and the token.

**`WeaponManager.CancelReload(Character)`:**
- If a token exists: clear it and the two attributes, and if `ReloadAnimReady()`, `AnimationManager.Stop(Character, Cfg.Anim)`.

**The restart watcher:**
- It runs in a thread: Heartbeat until `not ReloadBlocked`, or until the character or its `WeaponItem` changes.
- Then, if `Ammo < MaxAmmo`, it calls `Reload`.
- One watcher per character (a table guard).

**`Requests/Shoot.lua`, the top-up.** In `Watch`, connect `Character:GetAttributeChangedSignal("ShootingMode")`. When it turns nil while `WeaponManager.ItemStats(Character)` exists and `Ammo < MaxAmmo`, call `WeaponManager.Reload(Character)`.

**Fan the Hammer:** with fewer than 3 rounds, `Fire` refuses the later strikes (`CanFire` false) and the reload starts on the last round, as today. Nothing changes.

**`Play_GunReload`.** NPC shooters via GunKit. Cases:
- **`EmptyReloadsInTime`:** a Revolver fired 6 times. Then `ReloadingUntil − now` is 1.8 ± 0.05; after 1.9 s, `Ammo == 6`.
- **`StunCancelsAndRestarts`:**
  - Empty, then at 0.5 s into the reload, start a 0.4 s WCS Stun on the shooter.
  - Within one frame `ReloadingUntil` is nil.
  - After the stun ends, a new `ReloadingUntil` is set to about 1.8 s from the stun's end (± 0.1).
  - `Ammo` is 6 only after that.
- **`OwnActionsDoNotCancel`:** empty, then run the whip `Guns_Light1` through AttackRunner at 0.3 s. `ReloadingUntil` is unchanged, and `Ammo == 6` at 1.9 s.
- **`TopUpOnModeOff`:** fire 2 (4 left), set `ShootingMode` true then nil. A reload starts; `Ammo == 6` after 1.9 s.
- **`EmptySlotPlaysNothing`:**
  - The slot's id is empty (as applied).
  - During a reload, `Humanoid.Animator:GetPlayingAnimationTracks()` has no track whose `Animation.Name == "Guns_Reload"`.
  - The server log gained no "Animation not found" line (count it with `LogService:GetLogHistory()` before and after).
- **`FilledSlotPlays`:**
  - In Play only (the world is a copy), set the slot's AnimationId to the id of `Guns_Whip1`, an existing published gun animation, as a stand-in: read it from that Animation, never typed in.
  - During a reload, the NPC's Animator plays a track named `Guns_Reload`.
  - Then put the id back to "" (Stop discards it anyway).

**Steps:**
- [ ] **Step 1:** Write `reload_slot.lua`. In **Ye (Edit)**: run `plan`, then `test` (the snapshots must be equal), then `apply`, then `check`. Expected: `PASS / FAIL 0`.
- [ ] **Step 2: RED.**
  - Write `Play_GunReload` and sync it to Ye. Play (`Ye:gun6`): `Play_GunReload`.
  - Expected:
    - `StunCancelsAndRestarts` fails (today a stun doesn't cancel);
    - `TopUpOnModeOff` fails;
    - `FilledSlotPlays` fails (nothing plays the slot).
  - `EmptyReloadsInTime` passes (Task 3's 1.8), `OwnActionsDoNotCancel` passes, and `EmptySlotPlaysNothing` passes.
  - Record.
- [ ] **Step 3:** Make the WeaponManager and Shoot changes. Sync to Ye.
- [ ] **Step 4: GREEN.** Play: `Play_GunReload` all pass, plus `Play_Guns`.
- [ ] **Step 5:** Run `reload_slot.lua` `test` then `apply` then `check` in **Foundry (Edit; Ye's PlayLock nil)**. Sync to Foundry. `--check` both places.
- [ ] **Step 6: Commit** `reload_slot.lua`, WeaponManager, Shoot, `Play_GunReload` and the manifest: `"Gun rework Task 6: reload slot Guns_Reload (empty until the owner uploads), interrupt rule, top-up"`.

---

### Task 7: Client aim: the aim camera, the crosshair, lock-on, hold to fire

**Files:**
- **Create:**
  - `Scripts/ReplicatedStorage/Modules/UI/GunAimUI.lua`;
  - `Art/Studio/Guns/client_checks.lua`.
- **Modify:**
  - `ClientHandler.client.lua`;
  - `UI/SettingsUI.lua`;
  - `UI/HUDUI.lua`.
- **Manifest:** `UI.GunAimUI` (`Create: true`).

**Interfaces:**

**`GunAimUI`.** The module `Start()` and `AimDirection()`; `Kick()` and `Assist` are no-ops until Tasks 8 and 9.
```lua
-- GunAimUI (gun rework 2026-10-25): guns' shooting mode on the client. While ShootingMode is on:
--   * the aim camera (PROPOSAL): mouse locked to the centre, the camera over the right shoulder (Aim.ShoulderOffset), the
--     character turned with the camera -- unless locked on (LockOn owns the camera then);
--   * the crosshair is the game's own marker (UIState.Gui.Crosshair), drawn where the shot will go;
--   * AimDirection(): from the muzzle (GunAim.MUZZLE) through what the crosshair covers, or at the lock-on target.
-- SettingsUI's shift-lock loop pauses while ShootingMode is on; leaving the mode hands the camera back.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local UIState = require(script.Parent.UIState)
local LockOn = require(script.Parent.LockOn)

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Cfg = Tuning.Weapons.Guns.Aim
local GameSettings = UserSettings():GetService("UserGameSettings")
local GunAimUI = {}

local function Char() return Player.Character end
local function Shooting()
	local C = Char()
	return C ~= nil and C:GetAttribute("ShootingMode") == true
end
local function LockedRoot()
	local T = LockOn.Target
	return T and T.Parent and T:FindFirstChild("HumanoidRootPart") or nil
end
local function Crosshair() return UIState.Gui:FindFirstChild("Crosshair") end
local HomePosition = nil -- the marker's own Position, put back when the lock-on stops moving it

-- the crosshair's centre as a camera ray (its ScreenGui decides whether the top-bar inset counts)
local function CrosshairRay()
	local Cross = Crosshair()
	local Gui = Cross and Cross:FindFirstAncestorOfClass("ScreenGui")
	local V = Camera.ViewportSize
	if not (Cross and Gui and Cross.Visible) then return Camera:ViewportPointToRay(V.X / 2, V.Y / 2) end
	local P = Cross.AbsolutePosition + Cross.AbsoluteSize / 2
	if Gui.IgnoreGuiInset then return Camera:ViewportPointToRay(P.X, P.Y) end
	return Camera:ScreenPointToRay(P.X, P.Y)
end
GunAimUI.CrosshairRay = CrosshairRay -- (client_checks)

local function Cast(From, Vec)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Char(), workspace.World.Visuals}
	local R = workspace:Raycast(From, Vec, Params)
	return R and R.Position or nil
end

function GunAimUI.AimDirection()
	local C = Char()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root then return Camera.CFrame.LookVector end
	local Muzzle = GunAim.Muzzle(Root.Position)
	local Target = LockedRoot()
	if Target then
		local To = Target.Position - Muzzle
		if To.Magnitude > 1 then return To.Unit end
	end
	local Ray = CrosshairRay()
	local Stats = WeaponManager.ItemStats(C)
	local Point = GunAim.AimPoint(Ray.Origin, Ray.Direction, Muzzle, (Stats and Stats.Range or 90) + 10, Cast)
	Point = GunAimUI.Assist(Ray, Point) -- Task 9 (touch); returns Point unchanged until then
	return GunAim.Direction(Muzzle, Point, Ray.Direction.Unit, 2)
end
function GunAimUI.Assist(_, Point) return Point end
function GunAimUI.Kick() end -- Task 8

local Owned = false -- this module set the camera / mouse (so it puts them back exactly once)
local function Release()
	if not Owned then return end
	Owned = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local H = Char() and Char():FindFirstChildOfClass("Humanoid")
	if H then H.CameraOffset = Vector3.zero end
	pcall(function() GameSettings.RotationType = Enum.RotationType.MovementRelative end)
	local Cross = Crosshair()
	if Cross then
		Cross.Visible = false
		if HomePosition then Cross.Position = HomePosition end
	end
end

function GunAimUI.Start()
	local Cross = Crosshair()
	HomePosition = Cross and Cross.Position
	RunService:BindToRenderStep("RenseiGunAim", Enum.RenderPriority.Camera.Value + 1, function()
		local Gui = UIState.Gui
		local MenuOpen = (Gui:FindFirstChild("bg") and Gui.bg.Visible) or (Gui:FindFirstChild("Dialogue") and Gui.Dialogue.Visible)
		if not Shooting() or MenuOpen then Release() return end
		Owned = true
		local H = Char():FindFirstChildOfClass("Humanoid")
		local CrossNow = Crosshair()
		if CrossNow then CrossNow.Visible = true end
		local Target = LockedRoot()
		if Target then
			-- LockOn owns the camera: free the mouse, draw the marker on the target
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			if H then H.CameraOffset = Vector3.zero end
			if CrossNow then
				local Gui2 = CrossNow:FindFirstAncestorOfClass("ScreenGui")
				local P = (Gui2 and Gui2.IgnoreGuiInset) and Camera:WorldToViewportPoint(Target.Position) or Camera:WorldToScreenPoint(Target.Position)
				CrossNow.Position = UDim2.fromOffset(P.X, P.Y)
			end
			return
		end
		if CrossNow and HomePosition then CrossNow.Position = HomePosition end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		if H then
			H.CameraOffset = Cfg.ShoulderOffset
			H.AutoRotate = true
		end
		pcall(function() GameSettings.RotationType = Enum.RotationType.CameraRelative end)
	end)
end

return GunAimUI
```

**Notes on the crosshair:**
- `UDim2.fromOffset(P.X, P.Y)` assumes the marker's `AnchorPoint` is (0.5, 0.5) and its parent spans the screen. If Task 1 found otherwise, convert through the parent's `AbsolutePosition` and say so in the report.
- The blocked-line dim is Task 8's.

**`SettingsUI.lua`:** the first line inside the shift-lock `RenderStepped` function becomes:
```lua
if Player.Character and Player.Character:GetAttribute("ShootingMode") then return end -- GunAimUI owns the camera (gun rework)
```

**`HUDUI.lua` `UpdateShooting`:** don't create the "+" `Crosshair` label. The `Hint` keeps its font: take `FontFace` from `HUD.CashFrame.Display`, as today. It's built standalone with the same properties the clone had.

**`ClientHandler.client.lua`:**
- **Require:** `local GunAimUI = require(Modules.UI.GunAimUI)`, then call `GunAimUI.Start()` next to `WeaponManager.StartClient()`.
- **`SendAim()`** sends `GunAimUI.AimDirection()` instead of `Camera.CFrame.LookVector`.
- **`FireInput` is replaced** by hold to fire with a buffer:
  ```lua
  local GunCfg = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Weapons.Guns.Aim
  local FireHeld, FireWanted, FireLoop = false, 0, nil
  local function GunReady()
  	return Character:GetAttribute("CombatState") == nil and (Character:GetAttribute("Ammo") or 0) > 0
  		and (Character:GetAttribute("ReloadingUntil") or 0) <= workspace:GetServerTimeNow()
  end
  local function SendShot()
  	local Dir = GunAimUI.AimDirection()
  	local Root = Character:FindFirstChild("HumanoidRootPart")
  	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
  	-- face the shot (the aim camera already turns you; this keeps the server's facing check safe)
  	if Root and Flat.Magnitude > 0.1 and not Character:GetAttribute("LockedOn") then
  		Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat)
  	end
  	RequestRemote:FireServer("Shoot", "Fire", Dir)
  	GunAimUI.Kick()
  end
  -- Began true: press (returns false when not shooting, so RMB falls back to Feint); Began false: release
  local function FireInput(Began)
  	if Began == false then FireHeld = false return true end
  	if Knocked() or not Shooting() then return false end
  	FireHeld, FireWanted = true, os.clock()
  	if FireLoop then return true end
  	FireLoop = task.spawn(function()
  		local Sent = 0
  		while Shooting() and not Knocked() and (FireHeld or os.clock() - FireWanted <= GunCfg.Buffer) do
  			if GunReady() and os.clock() - Sent >= 0.1 then
  				Sent, FireWanted = os.clock(), 0
  				SendShot()
  				task.wait(0.1) -- let the server's CombatState reach us
  			else
  				RunService.Heartbeat:Wait()
  			end
  		end
  		FireLoop = nil
  	end)
  	return true
  end
  ```
  **The `LockedOn` check:** use the facing check the LockOn module needs. Task 1 recorded whether LockOn sets an attribute or `AutoRotate`. If it sets neither, test `LockOn.Target` through the module.
- **`ClientActions.Register("Fire", function(Began) FireInput(Began) end)`.**
- **The RMB branch:**
  ```lua
  if State == Enum.UserInputState.Begin then
  	if not FireInput(true) then RequestRemote:FireServer("Feint") end
  elseif State == Enum.UserInputState.End then
  	FireInput(false)
  end
  ```

**`client_checks.lua`.** It's run as the Client, or as a TEMP LocalScript in `StarterPlayerScripts` that writes its result to a StringValue in `ReplicatedStorage.GunChecks_TEMP`, read from the Server. Its checks:
- **`CrosshairRayMatchesMarker`:** with ShootingMode on and no lock-on, project `CrosshairRay()` 50 studs out back to the screen (`WorldToScreenPoint`, or `WorldToViewportPoint` per the inset). It lands within 1 px of the marker's centre.
- **`AimHitsDummyUnderCrosshair`:**
  - A 1 × 1 × 1 anchored marker part (made on the Server) is placed 40 studs along `CrosshairRay()`'s direction from its origin. It's narrower than the 1.75-stud shoulder offset, so the control can't graze it.
  - `RayBox(Muzzle, AimDirection(), 120, Marker.CFrame, Marker.Size)` hits.
  - **Control:** `RayBox(Muzzle, Camera.CFrame.LookVector, ...)` misses.
- **`LockOnAimsAtTarget`:** with `LockOn.Target` set to the dummy (through the module's own function; Task 1 recorded its API), the angle between `AimDirection()` and (dummy root − muzzle) is under 0.5°.
- **`ReleaseRestores`:** after ShootingMode goes nil, `MouseBehavior` is `Default` (with shift lock off), `CameraOffset` is zero, and the marker is hidden.

**Steps:**
- [ ] **Step 1: RED.**
  - Write `client_checks.lua` against a `GunAimUI` that doesn't exist yet. Its `AimDirection` fallback is today's `Camera.CFrame.LookVector`; implement the check's import with a pcall and that fallback.
  - Play in Ye (`Ye:gun7`): give the player a Revolver (`WeaponManager.Give`), set `CombatMode` and `ShootingMode` (Server), and run the checks.
  - Expected: `CrosshairRayMatchesMarker` and `AimHitsDummyUnderCrosshair` fail, or report "no marker" when the marker isn't visible. Record.
- [ ] **Step 2:** Write GunAimUI and the ClientHandler, SettingsUI and HUDUI changes. Sync `UI.GunAimUI`, `SPScripts.ClientHandler`, `UI.SettingsUI` and `UI.HUDUI` to Ye.
- [ ] **Step 3: GREEN.** Play: `client_checks` all pass, and `Play_Guns` still passes. **By hand in the same session:**
  - hold RMB for 2 s with the Revolver: shots come out at the gun's rate (count `LastShotAt` changes: 3 or 4);
  - press Y: the camera returns to normal.
- [ ] **Step 4:** Sync to Foundry. `--check` both places.
- [ ] **Step 5: Commit** GunAimUI, ClientHandler, SettingsUI, HUDUI, `client_checks.lua` and the manifest: `"Gun rework Task 7: aim camera, crosshair on the shot, lock-on aim, hold to fire"`.

---

### Task 8: Feedback: recoil, bloom, the hit marker, a blocked line of fire

**Files:**
- **Modify:**
  - `UI/GunAimUI.lua`;
  - `Art/Studio/Guns/client_checks.lua` (new checks).

**Interfaces** (all in GunAimUI, existing assets only):
- **`GunAimUI.Kick()`:**
  - If the gun's `Items[WeaponItem].Kick` exists, store `KickLeft = Kick` and `KickAt = os.clock()`.
  - A RenderStep bound at `Camera.Value + 2` applies `Camera.CFrame *= CFrame.Angles(math.rad(KickLeft * K), 0, 0)` with `K = 1 − (os.clock() − KickAt) / 0.18`, clamped to 0..1.
  - Only when the Camera Shake setting is on: read it the way Task 1 found.
  - **The bloom** always plays: the marker's `Size` is scaled 1.25× for 0.1 s, then put back to its own size (saved at Start).
- **The hit marker:**
  - Watch the character's `LastShotAt` attribute and read `LastShotResult`.
  - **"Hit":** tint the marker (255, 90, 70) and pulse its size 1.35× → 1 over 0.15 s.
  - **"Blocked":** tint it (170, 170, 170).
  - **Then** restore its own colour.
  - **Tint:** use `ImageColor3` for an ImageLabel or `BackgroundColor3` for a Frame, per Task 1's class.
- **The blocked line of fire:**
  - Each frame in shooting mode, cast from the muzzle to the current aim point (`Cast`).
  - If it hits more than 1.5 studs short of the point, set the marker's transparency (`ImageTransparency`, or `BackgroundTransparency`) to 0.6; otherwise back to its own value.

**New client checks:**
- **`HitMarkerFlashes`:** set `LastShotResult = "Hit"` and bump `LastShotAt` from the Server on the player's character. Within 0.05 s the marker's colour differs from its own; by 0.3 s it's back.
- **`BlockedLineDims`:** a 10 × 10 × 1 part placed 3 studs to the side of the muzzle, in line with the camera's view but not the head's (the test computes the spot from the muzzle and the camera, not from the marker). The marker's transparency becomes 0.6.
- **`KickRecovers`:** call `Kick()`. The camera's pitch rises, then is back within 0.1° after 0.25 s.

**Steps:**
- [ ] **Step 1: RED.** Add the three checks. Play (`Ye:gun8`) and run them. Expected: all three fail (no feedback yet). Record.
- [ ] **Step 2:** Make the changes. Sync `UI.GunAimUI` to Ye.
- [ ] **Step 3: GREEN.** Play: all client checks pass. By hand: shoot a GunKit dummy, and see the flash and the kick.
- [ ] **Step 4:** Sync to Foundry. `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 8: recoil, crosshair bloom, hit marker and blocked-line dim (existing marker only)"`.

---

### Task 9: Touch screens

**Files:**
- **Modify:**
  - `UI/GunAimUI.lua` (`Assist`);
  - `UI/HUDUI.lua` (the hint);
  - `UI/MobileControls.lua` (only if Task 1 or a check shows the FIRE release isn't sent);
  - `client_checks.lua`.

**Interfaces:**
- **`GunAimUI.Assist(Ray, Point)`:**
  - Only when `UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled` and `Aim.TouchAssist > 0`.
  - **Candidates:** the root positions of `World.Live`'s **direct** child Models, never the townsfolk folder: a living Humanoid, not your own character, and visible (a `Cast` from the camera reaches it).
  - `GunAim.Assist(Ray.Origin, Ray.Direction, Centres, Cfg.TouchAssist, range + 10)`.
  - Returns the picked centre or Point.
- **The hint:** on touch, "SHOOTING MODE · hold FIRE to shoot · STOP to leave".
- **FIRE hold:** MobileControls already sends `Began = false` on release (`Press`, lines 91–101), so the Task 7 handler gets it. Change nothing there unless the check below fails.

**New client checks:**
- **`AssistOnTouchOnly`:** the check calls `GunAim.Assist` through `GunAimUI.Assist` with a forced flag `GunAimUI.ForceTouch = true` (a test seam, false by default). A dummy 2° off the crosshair at 30 studs gets picked; with the seam off, Point is unchanged.
- **`AssistIgnoresTownsfolk`:** a dummy parented into `World.Live.Townsfolk` (or the folder Task 4 recorded) at 1° isn't picked.

**Steps:**
- [ ] **Step 1: RED.** Add the checks. Play (`Ye:gun9`). Expected: both fail (`Assist` is a no-op). Record.
- [ ] **Step 2:** Make the changes. Sync `UI.GunAimUI` and `UI.HUDUI` (and MobileControls if changed) to Ye.
- [ ] **Step 3: GREEN.** Play: all client checks pass.
- [ ] **Step 4: Studio's device emulator, by hand** (a phone profile):
  - AIM shows;
  - hold FIRE fires repeatedly;
  - STOP leaves.

  If the emulator can't be driven, say so. It stays an owner check (Task 12).
- [ ] **Step 5:** Sync to Foundry. `--check` both places.
- [ ] **Step 6: Commit**: `"Gun rework Task 9: touch: hold FIRE, aim assist (touch only, never townsfolk), hint"`.

---

### Task 10: Enemy gunners: windup, telegraph, spread, aim at the centre

**Files:**
- **Modify:** `Scripts/ServerScriptService/EnemyService.lua` (the gun branch of `Attack`, lines 254–266).
- **Create:** `Scripts/ServerStorage/RenseiTests/Play_GunNpc.lua`.
- **Manifest:** `RenseiTests.Play_GunNpc` (`Create: true`).

**Interfaces.** In the gun loop, replace the `AttackRunner.Run(...)` call with:
```lua
				-- gun rework 2026-10-25 (PROPOSAL): a readable, fallible shot -- a 0.35 s windup with the crit telegraph,
				-- aimed at the target's centre (was the root's flat look: it missed anyone higher or lower), 2.5 deg spread
				local N = Tuning.Weapons.Guns.NpcShot
				local Muzzle = GunAim.Muzzle(Root.Position)
				local To = Target.HumanoidRootPart.Position - Muzzle
				if To.Magnitude > 1 then WeaponManager.SetAim(Rig, GunAim.Spread(To.Unit, N.Spread, NpcRandom)) end
				local Def = table.clone(WeaponManager.Resolve(Rig, Weapon.Shots[Shot]))
				Def.Startup, Def.Telegraph = N.Startup, N.Telegraph
				AttackRunner.Run(WC, Def, Weapon.Class .. "_Shot" .. Shot, {WalkSpeed = 6, Strike = WeaponManager.Fire})
```
- Add `local GunAim = require(...Rensei.GunAim)` and `local NpcRandom = Random.new()` near the top.
- `Face(Target)` stays before it.
- `AnimSpeed` re-times the shot animation to the longer windup by itself (`AnimPeak` / (Startup + Active / 2) = 0.35 / 0.36 ≈ 0.97).

**`Play_GunNpc`.** Spawn an enemy gunner through EnemyService's own spawn function, using the type with a Sykov or Renetti (cite the function in the suite's header). Point it at a GunKit dummy. Cases:
- **`WindupIsReadable`:** from the shot's `CombatState = "Startup"` to `"Active"`, 0.35 ± 0.05 s.
- **`HitsATargetAbove`:**
  - A dummy on an anchored 4-stud block, 15 studs away.
  - With spread forced to 0 (`TuningConfig.Weapons.Guns.NpcShot.Spread` set to 0 in Play for this case, then put back), the shot hits.
  - **RED:** today's flat aim at head height passes over the target's torso, so it misses.
- **`SpreadStaysInCone`:** 30 shots' stored aims (read `SetAim`'s argument through a Play-only wrapper of `WeaponManager.SetAim` installed by the suite and removed after) are each within 2.5° per axis of the line to the target.

**Steps:**
- [ ] **Step 1: RED.** Write `Play_GunNpc` and sync it to Ye. Play (`Ye:gun10`). Expected: `WindupIsReadable` fails (0.12) and `HitsATargetAbove` fails. Record.
- [ ] **Step 2:** Make the change. Sync `RenseiServer.EnemyService` to Ye.
- [ ] **Step 3: GREEN.** Play:
  - `Play_GunNpc` all pass;
  - `Play_Stealth` and `Play_Assault` as before;
  - a 60-second watch of one bandit gunner against the player (God mode via the admin attribute `AdminGod` on the player's character in Play): it fires, misses sometimes, and reloads.
- [ ] **Step 4:** Sync to Foundry. `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 10: enemy gunners: readable windup, centre aim, spread"`.

---

### Task 11: Foundry parity and the full sweep

**Files:** none new. This task fixes only what it finds, in the task that owns it (the controller rules).

**Steps:**
- [ ] **Step 1:** Run `sync.py --place ye --check` and `--place foundry --check`. Expected: `DIFFER 0 / MISSING 0` for both, covering every pair, the Foundry plan's included. Run `reload_slot.lua` `check` in both places: `FAIL 0`.
- [ ] **Step 2: Play in Ye** (`Ye:gun11`), in this order:
  - `Test_GunAim`, `Test_GunBalance`;
  - `Play_Guns`, `Play_GunReload`, `Play_GunNpc`;
  - `Play_Stealth`, `Play_Assault`, `Play_TownsfolkHurt`, `Play_LindenmoorSmoke`;
  - then `client_checks.lua`.

  Record every result.
- [ ] **Step 3: Play in Foundry** (`Foundry:gun11`, with Ye in Edit):
  - `Play_Boot` first (it must lead: the Foundry plan's note);
  - then `Play_Guns`, `Play_GunReload`, `Play_GunNpc`;
  - and `Play_FoundrySmoke` (or the Foundry plan's final smoke suite by its name);
  - then `client_checks.lua`.

  The known failures (Play_Travel 5/2 and Play_RideEvents 8/1 on the owner's ticket) aren't regressions.
- [ ] **Step 4: The checkpoint list for Task 12.** Write the package contents:
  - **`Modules`:** TuningConfig, GunAim, WeaponManager, GunAimUI, SettingsUI, HUDUI, and MobileControls if changed;
  - **`RenseiServer`:** ServerHandler, `Requests.Shoot`, EnemyService, PositionHistory;
  - **`ClientHandler`;**
  - **place changes in both:** `Assets.Animations…Guns_Reload` (empty) and the RenseiTests suites;
  - **plus** whether the Tutorial place carries `Modules` (Task 1).
- [ ] **Step 5:** No commit unless something was fixed. Any fix is committed by its owning task's files, with the message `"Gun rework Task 11: <what>"`.

---

### Task 12: Docs, the Changelog entry and the held Discord post

**Files:**
- **Modify:**
  - `Documents/Changelog.md`;
  - `Documents/COMBAT_SYSTEM.md`;
  - `Documents/Controls.md`;
  - `Documents/Animations.md`;
  - `Documents/Backlog.md`.

**Interfaces.** The content each document must hold. Facts and counts come from Tasks 1–11's reports.

**`COMBAT_SYSTEM.md`:** the Guns row and a short "Guns" section:
- shooting mode's aim camera and crosshair;
- the per-gun table (Damage, Magazine, Reload, fire interval, Range and falloff);
- Point Blank;
- flinch within 25;
- 2 meter per hit;
- Fan the Hammer 12 × 3;
- the reload rule (automatic, the top-up, the interrupt);
- lag compensation's cap.

Each number is marked PROPOSAL.

**`Controls.md`:**
- RMB: "With guns in shooting mode: fire (hold to keep firing)".
- Y: "the camera moves over your shoulder while it's on".
- The touch table gains **Aim / Stop (with a gun, in Combat Mode) → Y** and **Fire (hold to keep firing; shows while shooting) → Right Mouse**.
- A line: "On touch screens, shots near an enemy lean onto them."

**`Animations.md`:** a Weapons row:

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Gun Reload (needs the owner's upload) | `Guns_Reload` (empty id) | ➖ | the automatic reload; plays once the id is set; set `TuningConfig.Weapons.Guns.Reload.AnimLength` to its length |

**`Backlog.md`:**
- The gun class rework item is ticked, with a pointer to the Changelog entry, and "**reload animation: waiting for the owner's upload**".
- **Follow-ups:**
  - a touch lock-on button;
  - a pistol-whip–specific look at the reload;
  - review the PROPOSAL decisions in the spec's §8.

**`Changelog.md`:** one entry, `## 2026-10-25 — Guns rework: aiming fixed, the class rebalanced, a reload animation slot (not live)`. It holds:
- what was wrong (the spec's A1–A8 and B1–B6, one line each);
- what changed (aim, balance table, reload, feedback, touch, enemy gunners, anti-exploit);
- the owner's decisions kept;
- **"Decisions taken without the owner"** (the spec's §8 list, short);
- **"Owner action":** upload the reload animation, add it to the sheet, paste the id into `Guns_Reload`, set `AnimLength`;
- every test count from Tasks 2–11;
- "Not tested": the phone, if Task 9 couldn't drive it, and two real players;
- the backups `RenseiBackups["Pre-GunRework_2026-10-25"]` in both places;
- **the rollback order** (Edit):
  1. revert the scripts from that backup in both places, for this plan's labels;
  2. delete the scripts this plan created (GunAim, GunAimUI, PositionHistory, GunKit and the five suites) in both places;
  3. `reload_slot.lua` undo in both places;
- **the publish checkpoint** (Task 11, step 4), in the World Travel.md §10 order:
  1. packages from Ye;
  2. Foundry's packages updated by hand and checked with `sync.py --check`;
  3. the places;
  4. Migrate to Latest Update last.

  It may be published only together with whatever hold is then in force.

**Its `### Discord announcement`:**
- It starts "Hold: not live yet. Post this when the owner publishes the gun update."
- Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - shooting mode now aims where your crosshair is: the camera moves over your shoulder, and locked-on shots go to your target;
  - hold right mouse (or FIRE) to keep shooting;
  - each gun feels different:
    - Revolver: a hard-hitting hand cannon;
    - Renetti: quick and close;
    - Forge Tac: a long-range marksman pistol;
    - Sykov: the all-rounder;
  - hits flash your crosshair, and guns kick;
  - reloading is still automatic, and now also tops up when you leave shooting mode; getting hit interrupts it;
  - Fan the Hammer is a close-range move now;
  - bandit gunners give you a moment to react and don't hit every shot;
  - touch players get a little aim help.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report or TuningConfig as committed.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, test counts or PROPOSAL.
- [ ] **Step 3:** This is the plan's only Changelog entry.
- [ ] **Step 4:** The controller names the checkpoint and the owner action (the reload upload) to the owner in chat. This plan publishes nothing.
- [ ] **Step 5: Commit** the five docs: `"Gun rework Task 12: docs, changelog (held Discord post), reload upload asked of the owner"`.

---

## Self-review notes

**Coverage of the request:**
1. **"Fix gun shoot mode aiming mechanics":**
   - parallax and shift lock: Tasks 2 and 7;
   - lock-on: Task 7;
   - the free mouse: Task 7's aim camera;
   - the crosshair tied to the shot: Task 7;
   - turn-and-shoot: Task 4's refusal plus Task 7's facing;
   - moving targets: Task 5;
   - eaten clicks: Task 7;
   - NPC aim: Task 10;
   - touch: Task 9.
2. **"Balance out the gun class completely":**
   - per-gun numbers and identities: Task 3, tested against bands;
   - Fan the Hammer and the Mastery bug: Task 3;
   - meter, whiff and flinch range: Tasks 3–4;
   - PvE fairness: Task 10;
   - anti-exploit: Tasks 4–5.
3. **"Add a reload animation":**
   - the named slot `Guns_Reload` with a silent fallback: Task 6;
   - the owner's upload is asked for in Task 12;
   - no asset id is invented.

**Rules kept:**
- automatic reload only (the top-up is automatic);
- M1 stays the whip;
- Y and RMB are unchanged;
- existing UI assets only;
- no publishing;
- one Changelog entry with a held post.

**Order and dependencies:**
- 1 before everything;
- 2 before 3–5, 7 and 10 (GunAim);
- 3 before 4 (the numbers it reads);
- 4 before 5 (`ShotTarget`), 6 (GunKit) and 10;
- 7 before 8 and 9;
- 11 after 1–10; 12 last.

Play sessions are serial across the places. `reload_slot.lua` runs in Edit only.

**Each task can be rejected on its own:**
- Tasks 1–3 change no behaviour in the game: 1 is parity, 2 is unused maths, and 3 is numbers, though the numbers apply to live shots once synced. If the owner rejects the balance, revert Task 3 alone.
- Task 4 is the server path.
- Task 5 can be removed by deleting PositionHistory: `ShotTarget` falls back to current positions.
- Task 6's slot is reversible.
- Tasks 7–9 are client-only.
- Task 10 is NPC-only.

**Names used across tasks:**
- the backup `Pre-GunRework_2026-10-25`;
- the flag `GunReloadSlot` and the mark `GunReworkAdd`;
- the attributes `LastShotResult`, `LastShotAt` and `GunSnapCount`;
- `TuningConfig.Weapons.Guns.Aim`, `.Reload`, `.NpcShot` and `Meter.OnShotHit`;
- `WeaponManager.ShotTarget` and `CancelReload`;
- `PositionHistory.Models` and `.At`;
- `GunAimUI.AimDirection`, `.Kick`, `.Assist` and `.ForceTouch`;
- `RenseiTests.GunKit`.
