-- HostageService (hostages plan Task 5, 2026-10-27; spec Documents/specs/2026-10-21-hostage-design.md, owner-approved
-- 2026-10-25): the server side of a player-on-player hostage. The client only asks (Requests.Hostage); every rule is
-- checked here, with the server's own positions. Numbers and the gate maths: Rensei.Hostage (every number a PROPOSAL
-- unless it says it was measured). Tasks 6-11 extend it (the pair policed -- Task 6, done --, the grab and the struggle
-- -- Task 7, done --, the captor menu, the shield and rescue, ransom and turn-in).
--
-- PvP ONLY (owner rule): a hostage and a captor are always players. IsNpc (EnemyType, TownsfolkId, DialogueId or an
-- EnemyService entry; pre-flight P25) is asked FIRST, before a character is ever looked up as a player: PlayerOf never
-- returns one for an NPC, StandIn refuses an NPC rig, Take refuses an NPC captor or target ("not_player") before
-- anything is marked, and Rensei.Hostage.CheckTake refuses IsNpc before every other gate. No path holds an NPC.
--
-- * THE PLAYER-LIKE ("PL"). Every function takes a real Player or (tests only) a stand-in table
--   {IsStandIn = true, Name, DisplayName, UserId, Character, Level, Data = {Money, Stats}, Party}. Only the helpers
--   below tell them apart: Char, Present, LevelOf (Data.Level, never the Level attribute that ProgressionService.Sync
--   rewrites; pre-flight P2), DataOf, PartyOf, Notify, Record, Key (the UserId).
-- * THE SEAMS (tests only). StandIn(Model, Info) registers a rig as a player-like; PartyOf answers from HostageService
--   ._PartyOf when a test sets it (ruling T1-4). Both are honoured ONLY while SeamOpen(): RunService:IsStudio() AND
--   DataManager.IsNoSave() AND HostageService._NoSave() (the swappable copy; pre-flight P24 -- a test swaps it to
--   close the seam, never the data layer's own function, and swapping it can only close the seam, never open it). A
--   live server never reads either. StandIn refuses any NPC rig (IsNpc).
-- * Context(Captor, TargetModel, Kind) -> Ctx: Rensei.Hostage.CheckTake's fields, with the server's slack (IsNpc
--   first; IsPlayer; Self; Safe for either; InDialogue for either real player; the levels; Ready / Immune; CaptorFree
--   -- alive, not Knocked / Gripping / Carrying / TakingDown / Holding / HeldBy, not attacking, no Stun but the crouch's
--   (TakedownService.Stunned, called, never copied), on the ground, not swimming --; TargetFree -- alive, none of
--   GrippedBy / CarriedBy / TakenDownBy / HeldBy / Holding / Gripping / Carrying / TakingDown, not swimming --;
--   TargetKnocked; Dist on the ground plane, Height; Range = the Kind's range + RangeSlack; Behind (rear arc +
--   AngleSlack); Clear = one torso-to-torso ray). Check(Captor, TargetModel, Kind) -> ok, reason.
-- * InSafeZone(Character) (ruling R6): the region's Safe flag; inside a part tagged Hostage.SafeTag (point in box); within
--   StationSafeRadius (3D) of a RenseiTicketClerk / RenseiStationGate in workspace; inside a RenseiPlatformTrain's
--   bounding box grown by TrainMargin.
-- * SWITCHED OFF (Task 5 fix, ruling K1: publish safety) until Task 14 flips Rensei.Hostage.Enabled. Allowed() is
--   Enabled, or else the tests' bypass: RunService:IsStudio() (asked first) AND DataManager.IsNoSave() AND
--   HostageService._TestBypass() (a test swaps it to shut the bypass; it can only make Allowed stricter). Take refuses
--   "disabled" before anything else while not Allowed; Requests.Hostage refuses too. Nothing else starts a session.
-- * Take(Captor, TargetModel) -> ok, reason. The kind is "Bind" for a knocked target, else "Grab". A non-player either
--   side is "not_player" first; then Rensei.Hostage.CheckTake (a Grab: the target's rear arc within GrabRange, else
--   "seen" or "far"; ruling R3: "hasn't noticed you" is the takedowns' rear arc, 4 studs, a clear line). Refused: the
--   next allowed time >= now + RefusedCooldown and LastHostageResult = "<Kind>:<reason>" on the captor's character.
--   Accepted: in the SAME step, no yield, HeldBy on the target and Holding on the captor (one captor per hostage, one
--   hostage per captor), the session made and indexed, its exits connected; then a Bind's Run on its own thread, or (Task
--   7) the GRAB in this same step; true, "started" (a grab whose step fails is released "error": false, "error").
-- * THE GRAB (Task 7, spec §2): no bind time and no knock to end (EndKnock is never called for it). Restrained and welded
--   at once (Restrain: the hostage locked, stunned for GrabWindow + its hold time + StunPad, tools away; Pair: the weld,
--   the captor at LeadSpeed, the lead clamp; pre-flight P5, so the pair is policed while Grabbing too); State
--   "Grabbing", S.Struggle = GrabStart (the Struggle attribute), S.GrabEnds = now + GrabWindow; Watch started; both
--   told {State = "Grabbing", Ends}. A full bar before GrabEnds: Release "grab_failed", then the captor stunned ShoveStun
--   (only the shove stuns). EVERY grab that ends without becoming Held -- shoved off or any other end -- records
--   attempted_hostage once, in Release (step 5b; fix round 1, spec §2: a failed grab still counts as an assault), never
--   took_hostage. At GrabEnds with the bar under 1: Held (BeginHeld, as the bind's step 3 from "the captor:" on), the
--   bar 0, took_hostage recorded then.
-- * Struggle(PL, Count) (Task 7): the hostage's own presses. Ignored unless PL is the hostage of a Grabbing or Held
--   session, Count is a whole number from 1 to MaxPressesPerSecond (review M7: NaN, infinities, fractions and negatives
--   refused) and the hostage has stamina; at most MaxPressesPerSecond presses per PL counted in any rolling second; each
--   spends StruggleStamina (ResourceManager.Spend) and adds Hostage.StruggleGain(own, captor's StruggleStat: Strength,
--   ruling P1; DataOf(PL).Stats, else 0). The bar is the hostage's Struggle attribute. A Held press plays Anims.Struggle
--   for StrugglePoseTime, then Anims.Held again. _Sends(PL): the Struggle messages received from PL (pre-flight P9; every
--   message, counted or not), cleared by Forget.
-- * Run (the bind, spec §2), each step in a pcall (an error releases "error"):
--     1. the captor's walk locked; S.BindAt = its root; Anims.Bind (fallback) on the captor. No sound: a bind is quiet
--        (PROPOSAL);
--     2. every Heartbeat for BindTime: Broken, the hostage no longer knocked, the captor's root more than BIND_SLACK from
--        S.BindAt, or the captor stunned -> "interrupted";
--     3. the HOLD, in one step: the knock ended at the hostage's own HP, at least MinHealthShare (DownedManager.EndKnock;
--        HeldBy was set at the take, so neither the knock's timer nor a carry's Drop can Recover-heal it first: Task 4
--        review hand-off 1), SecondWindActive cleared (ruling: a bind isn't a recovery); the hostage locked
--        (DownedManager.Lock), stunned (WCS) for its hold time + StunPad, tools unequipped; the pair welded at once
--        (DownedManager.Attach(CC, HC, Offset): the captor is the holder and its client owns the pair, ruling R1; the
--        knock ended in the same step, so the crawl clamp never sees an unwelded, unknocked hostage: hand-off 2); the
--        captor re-locked at LeadSpeed and the lead clamp started (Pair, Task 6); Anims.Hold / Anims.Held looped at Action4
--        (Restrain, shared with the grab); State "Held", S.Until (os.clock)
--        and HostageUntil (server time) on both; this take counted in Taken (pre-flight P22: only a hold is a re-take);
--        Watch started; Notify both; took_hostage recorded (a real captor, witnessed).
-- * Broken(S) -> outcome | nil (public, a test seam; review M9: while the pair is led it also ACTS -- it puts the pair
--   back, writes the owner and the hostage's humanoid, puts tools away -- so a test calling it directly moves things): "left" (either not Present), "died" (either character dead or
--   replaced), "knocked" (the captor knocked; while the pair is led, the hostage knocked: decision 5); then, while the
--   pair is LED (welded, S.Attached, and Held or -- Task 7 -- Grabbing: pre-flight P5), THE PAIR POLICED (below):
--   "teleport", "broken", "water"; then "safe" (the captor in a safe zone), "timeout" (Held and os.clock() >= S.Until).
--   The struggle is the watch's own Tick, after Broken (Task 7; Broken stays a pure seam a test can replace).
-- * THE PAIR POLICED (Task 6, ruling R1; the assassinations' final review I1). WHY THE CAPTOR'S CLIENT OWNS THE PAIR:
--   the captor has to walk while leading the hostage. A Roblox character walks only where its owning client simulates
--   it, so the captor's root must stay the captor's client's, and a weld joins the hostage's root into that one
--   assembly, which has one physics owner: the captor's client (DownedManager.Attach hands it over; for a stand-in
--   captor, the server). The takedowns' fix for I1, anchoring the player, would stop the walk, and making the hostage
--   the holder (Grip's way) would hand the walking captor to the server. So the captor's client moves the pair, and a
--   client's WalkSpeed is its own: the server's LeadSpeed lock is only advice (Task 1 measured 37.99-48.39 studs in 2 s
--   at a server WalkSpeed of 16). WHAT THE SERVER CHECKS INSTEAD, every WatchTick in Broken, with its own positions (the
--   hostage's own client owns nothing of the pair, so it can't move, jump or draw; the checks below keep it so):
--     1. the lead clamp (S.Lead = {Pos, CF, Y, T, GroundY, GroundT, Rebased}, set when the pair is welded to the
--        captor's root: the last point the server checked and allowed): D = the captor's root's ground (x / z) distance
--        from S.Lead.Pos, Dt = now - S.Lead.T.
--        - a BLINK -> "teleport" (an admin bring, a station move, an exploit: the hold ends rather than follow): D >
--          TeleportBreak, or (fix round I3) the straight path from S.Lead.Pos to the root hits world geometry (Terrain or
--          an anchored part, never a character: a move through a wall or a floor);
--        - D > Hostage.LeadAllowance(Dt), or the root more than RiseSlack above S.Lead.Y, or (fix round I3) more than a
--          free fall below the last ground point (GroundY - Y > Gravity / 2 x (now - GroundT + DROP_LAG)^2 + DROP_SLACK)
--          -> the pair PUT BACK: the captor's root moved to S.Lead.Pos (its full position, the hostage with it), its
--          velocity zeroed, HostageClamped + 1 on the captor's character, S.Lead.T = now;
--        - else S.Lead follows: Pos, CF and T = now; Y = the root's Y when the server sees a FLOOR under the captor's legs
--          (GROUND_RAY: a stair or a ramp walked up is ground; fix round I4: a floor is Terrain, an anchored part or a part
--          the server owns, never a character -- an accomplice -- nor a client's loose part), else min(S.Lead.Y, the
--          root's Y) (in the air only a descent lowers it, so a jump or a climb is held to RiseSlack); on a floor
--          GroundY / GroundT = here, now. A root that hasn't moved (under 0.05 studs) leaves Pos and T, so the window
--          grows to LeadWindow, as the crawl clamp's does (a late packet is no sprint).
--        It is the crawl clamp's shape (DownedManager's ClampCrawl) with the hostage's numbers, kept small here rather
--        than shared (pre-flight D4): the two differ in what they end (a teleport break here), in the rise check and in
--        where the point is kept (the session here, a weak table there). DownedManager.RebaseCrawl isn't used: neither
--        side is knocked.
--        A deliberate server move of a led pair calls HostageService.Rebase(Character) after it (pre-flight P6: Task 10's
--        gate push, Task 11's desk), which starts the clamp again from the root's spot. For REBASE_GRACE after it, a far
--        root is the owning client's stale echo of the spot before the move: put back to the rebased spot, neither
--        counted nor a "teleport" (DownedManager's fix round 3 saw the same echo).
--     2. the pair: the weld gone (no DownedWeld on the captor's root, or its Part1 not the hostage's root), or the
--        hostage's root more than PairSlack from the captor's root x Hostage.Offset -> "broken";
--     3. ownership: the hostage's root's network owner kept to the captor's Player (nil, the server, for a stand-in
--        captor), so it never falls back to the hostage's own client;
--     4. the hostage's own body: WalkSpeed 0, JumpHeight 0 and PlatformStand true written again when anything changed
--        them; a Tool in the hostage's character goes back to its Backpack (decision 18; a stand-in's PL.Backpack, which
--        a test gives it);
--     5. deep water (SwimService.InDeepWater, read only) for either side -> "water" (decision 17).
--   Pair(S) welds and leads the pair (Hold; Task 7's grab calls it too, P5): the hostage root's network ownership noted
--   (S.OwnerWas), the weld, S.Attached, the captor locked at LeadSpeed (its earlier lock given back first only when
--   this session made one) and S.Lead. It is IDEMPOTENT (Task 7, Task 6 re-review m3): once S.Attached it does nothing,
--   so a grab becoming a hold never notes the captor's client as the hostage root's old owner.
--   The path ray is clamped to MAX_RAY before it is cast, and a NaN move is a blink (Task 7, m1).
--   AT THE RELEASE (fix round I1 / I2: Settle, Release step 2) the captor's client never decides where the hostage is
--   left, nor how fast: the server takes the hostage's root, zeroes every part's linear and angular velocity, puts it
--   at S.Lead.CF x Offset after a "teleport", a "broken" or an "error" end (Task 7, m1) or within FIGHT_WINDOW of a
--   counted put-back (a client fighting the clamp), and gives its ownership back as it was before the hold OWNER_BACK
--   later.
-- * Watch(S): every WatchTick while not S.Over, pcall(HostageService.Broken, S); an outcome -> Release(S, outcome), an
--   error -> Release(S, "error"); else (Task 7) Tick, in its own pcall (an error -> "error"): while Grabbing or Held the
--   bar drains StruggleDrain x Dt (never below 0); a full bar resolves (Grabbing: "grab_failed" as above; Held:
--   Release "struggled", then the captor stunned BreakStun); a Grabbing session past GrabEnds becomes Held; the
--   struggle pose ends after StrugglePoseTime.
-- * RE-TAKES: a hold lasts Hostage.HoldTimeFor(n), n = this hostage's earlier holds within RetakeWindow (by any captor;
--   counted only once Held, pre-flight P22: an interrupted bind or a shoved-off grab is no hold). IMMUNITY: any release
--   sets ImmuneUntil (and GrabImmuneUntil); Context.Immune refuses both kinds while it lasts.
-- * Release(S, Outcome): THE ONE EXIT of a session (lesson: TakedownService's Release). Guarded by S.Over and the
--   session's identity (ByCaptor[Key(Captor)] == S); every step in its own pcall, so one failing never skips the rest:
--     1. S.Over; unindexed; its connections dropped;
--     2. the weld let go (DownedManager.Detach: PlatformStand off), then the hostage settled (Settle: at rest, put back
--        after a blink or a clamp fight, its old owner back OWNER_BACK later: fix round I1 / I2), only when
--        this session welded the pair (S.Attached; Task 5 fix, review I1: a Detach of a pair never attached would set
--        every part of the knocked hostage non-massless -- hair, accessories, a weapon -- and PlatformStand off);
--     3. the hostage: its lock given back when the hold locked it (not while knocked: the knock's lock nests on ours and
--        its Recover gives ours back); its Stun stopped; animations stopped; HeldBy, HostageUntil and Struggle cleared;
--        immune for ImmuneAfter (GrabImmuneUntil, server time, and ImmuneUntil). A hostage still knocked whose
--        KnockedUntil has passed is recovered (DownedManager.Recover: its timer found HeldBy and waited), as Grip does:
--        a knocked player is never left stuck (hand-off 3);
--     4. the captor: the lock given back (also for a character already gone: the entry goes, as TakedownService's F7;
--        not while knocked, as for the hostage); animations stopped; Holding and HostageUntil cleared;
--     5. the captor's cooldown (now + Cooldown) and LastHostageResult = "<Kind>:<Outcome>"; (5b, Task 7 fix round 1) a
--        grab that never became Held records attempted_hostage for the captor, witnessed, unless the captor's own
--        Player is gone;
--     6. Notify both ({State = "Free", Outcome, Role}; the captor's with Options, Task 8) and a toast (none for
--        "finished": the grip that follows is no freedom);
--     7. the Released listeners (S, Outcome), each in a pcall;
--     8. (Task 11) a running ransom demand of this session is voided.
--   A bind slower than BindTime + SLOW_PAST, or a release whose steps 1-6 take longer than SLOW_RELEASE (the
--   listeners, which may yield, aren't timed), warns its phase timings once.
-- * EXITS (Start): Players.PlayerRemoving -> _Left(P) ("left"); each session's characters' Humanoid.Died and Destroying
--   and a real owner's CharacterAdded -> "died"; game:BindToClose -> _Shutdown() ("shutdown"). Every other end goes
--   through Watch (Broken) or Free.
-- * Rebase(Character) -> bool (Task 6, pre-flight P6): the led pair that character is either side of has its lead
--   clamp started again from the captor's root's spot now (see THE PAIR POLICED); false when it leads no pair.
-- * THE CAPTOR MENU (Task 8, spec §3). MenuOptions(Captor) -> {{Id, Text, Locked, Why}}, only while that PL is the
--   captor of a Held session (else {}), in this order: Release ("Let them go"), Finish ("Finish them"), Ransom ("Demand
--   ransom": locked "They have no party here" when PartyOf(hostage) is the hostage alone, else, until Task 11, locked
--   "Not yet"); TurnIn is absent until Task 11. Every "Hostage" Notify to the captor carries Options = MenuOptions
--   (Grabbing and Free: {}), so HostageUI (Task 12) draws the wheel from it; it is sent at Held and whenever an option's
--   lock changes (Task 11). Menu(Captor, Choice, Arg) -> bool (true when the choice acted; Requests.Hostage ignores
--   it): every choice re-checks that the caller is the captor of a Held session (a hostage, a grab, a released or
--   unknown session, a non-string or unknown choice: ignored). Arg is unused by Release and Finish (review M7's range
--   check belongs to Task 11's ransom tier).
--     - "Release": Release(S, "released") at once; what it earns waits (fix round 1, controller ruling I1): a RELEASE
--       WINDOW of Hostage.ReleaseGrace (30 s; HostageService._ReleaseGrace shortens it in tests, read only while
--       SeamOpen). If the released player is knocked (a landed hit, ProgressionService.HitListeners) or gripped by the
--       ex-captor or their party inside it, nothing is paid; a grip of theirs that finishes (DownedManager.Listeners)
--       records killed_hostage, as Finish would. Someone else hurting them changes nothing. Taken again by the captor's
--       side, the window ends unpaid (the new hold has its own deeds). Either side leaving, or a shutdown, ends it unpaid
--       (a captor who left has no profile to record on). When it runs out unharmed: released_hostage recorded
--       (witnessed), then THE RELEASE HEAT (ruling, spec §3 "its Heat is only half that of the original crime"): the
--       took_hostage Heat this hold raised at the take (S.TookHeat: per jurisdiction, HeatService.Value just after
--       Announce's Record less just before -- Morality's Recorded listeners, HeatService's among them, run in that same
--       step) is halved, HeatService.Reduce(J, raised / 2). Heat that word of the taking raises later isn't touched;
--     - "Finish" (refused while the captor is stunned or attacking -- Grip's own conditions, fix round 1 I2 -- so the
--       hold goes on, and otherwise Release, the knock and the grip's marks run with no yield): Release(S, "finished")
--       (no "free" toast); DownedManager.Knock(HC) (the hostage's HP kept: Knock only sets the state); then, on its own
--       thread, the NORMAL GRIP, DownedManager.Grip(CC, HC): its styles, its stun cancel (a rescue that stuns the captor
--       mid-grip leaves the hostage knocked and alive), the ragdoll, its listeners. Done -> killed_hostage recorded
--       (witnessed). A grip that fails otherwise gives the knock back (EndKnock at the hostage's own HP); one cancelled
--       (a stun) leaves the hostage knocked and opens the release window with no payout (fix round 2: a kill by the
--       captor's side inside it is still killed_hostage). The grip's own
--       marks (Gripping / GrippedBy) keep every take, grip, carry and takedown off both of them while it runs (Task 4's
--       exclusion, both ways).
-- * Free(PL, Outcome) -> bool: that PL's session (either side) released. SessionOf(PL) -> S | nil. Forget(PL, Only):
--   the PL's cooldown (NextAt), immunity (ImmuneUntil), re-take times (Taken) and (Task 7) struggle messages and rate
--   window (Sends) forgotten; Only (a set, e.g. {ImmuneUntil = true}) forgets just those. Released: listeners (S, Outcome).
--
-- Attributes. Captor's character: Holding (the hostage's name), HostageUntil (server time, while Held),
-- LastHostageResult ("<Kind>:<reason or outcome>"; tests and logs), HostageClamped (Task 6: times the lead clamp put the
-- pair back; tests and logs). Hostage's character: HeldBy (the captor's name),
-- HostageUntil, Struggle (Task 7), GrabImmuneUntil (server time). Read: Knocked, KnockedUntil, GrippedBy, Gripping,
-- CarriedBy, Carrying, TakenDownBy, TakingDown, Traversal, SecondWindActive, EnemyType, TownsfolkId, DialogueId.
-- Session times (NextAt, ImmuneUntil, Taken, S.T0, S.Until) are os.clock(); the attributes are server time.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Rensei = Modules.Data.Rensei
local Hostage = require(Rensei.Hostage)
local Regions = require(Rensei.Regions)
local Heat = require(Rensei.Heat)
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local AttackRunner = require(Modules.Managers.AttackRunner)
local AnimationManager = require(Modules.Managers.AnimationManager)
local DownedManager = require(Modules.Managers.DownedManager)
local EnemyService = require(ServerScriptService.EnemyService)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)

local HostageService = {}
HostageService.Released = {} -- listeners (S, Outcome)
-- (pre-flight P24) the seam's own copy of the no-save switch: a test swaps THIS (and puts it back) to close the seam;
-- SeamOpen asks DataManager.IsNoSave() as well, so a swap can only close it
HostageService._NoSave = DataManager.IsNoSave
-- (ruling T1-4, tests only) function(PL) -> a list of PLs, or nil for the normal answer; read only while SeamOpen()
HostageService._PartyOf = nil
-- (Task 5 fix, ruling K1) the tests' bypass of the switch, read only in Studio with IsNoSave; a test swaps it to false to
-- see what a live server does. It can only shut the bypass, never open one.
HostageService._TestBypass = function() return true end

local BIND_SLACK = 1.0 -- PROPOSAL (the takedowns' HOLD_SLACK): studs the binding captor's root may move
local SLOW_PAST = 0.5 -- PROPOSAL: seconds past BindTime before a bind's phase timings are warned
local SLOW_RELEASE = 0.25 -- PROPOSAL: seconds a release may take before its timings are warned
-- (Task 6) PROPOSAL (DownedManager's CrawlClampGrace): seconds after a Rebase in which a far root is the client's stale echo
local REBASE_GRACE = 0.5
-- (Task 6) PROPOSAL: studs below the captor's legs a floor may be and still be the ground it stands on (the lead's Y)
local GROUND_RAY = 1.5
local STILL = 0.05 -- (Task 6) studs: a root that moved less hasn't moved (the crawl clamp's own threshold)
-- (Task 6 fix round 1, review I1-I4) PROPOSAL numbers:
local FIGHT_WINDOW = 1 -- seconds: a release this soon after a counted put-back puts the hostage back at the lead's spot
local DROP_LAG = 0.2 -- seconds added to the time since the lead was last on the ground (two watch ticks of lateness)
local DROP_SLACK = 4 -- studs a drop may exceed a free fall from the lead's last ground height
local OWNER_BACK = 0.25 -- seconds the server keeps a released hostage (at rest) before its old owner gets it back
local WORLD_TRIES = 8 -- rays a WorldHit may cast, stepping past characters and parts that aren't world geometry
-- (Task 7, Task 6 re-review m1) PROPOSAL: the longest path ray the lead clamp casts (Raycast's own limit is 15,000
-- studs); a longer move is checked along its first MAX_RAY studs, and a NaN one is a blink
local MAX_RAY = 1000
-- (Task 7, Task 6 re-review m1) the ends after which the hostage is put back at the lead's last checked spot (Settle):
-- a blink, a weld the captor's side broke, and an error (the server no longer knows what the client did last)
local PUT_BACK_ENDS = {teleport = true, broken = true, error = true}
-- (Task 8 fix round 1) PROPOSAL: seconds a release window waits, at its end, for a grip still running on the released player
local GRIP_WAIT = 10

local StandIns = {} -- [Model] = PL (tests only; read only while SeamOpen)
local ByCaptor = {} -- [Key] = S
local ByHostage = {} -- [Key] = S
local NextAt = {} -- [Key] = os.clock() from which this captor may take again
local ImmuneUntil = {} -- [Key] = os.clock() until which this PL can't be taken
local Taken = {} -- [hostage Key] = {os.clock() of each hold, any captor} (R8: memory only, no save field)
local Sends = {} -- (Task 7, pre-flight P9) [Key] = Struggle messages received from this PL (Task 12's tests read it)
local Presses = {} -- (Task 7) [Key] = {os.clock() of each counted struggle press in the last second}
local Pending = {} -- (Task 8 fix round 1) [P] = true: the release windows running (see the captor menu, below)
local CaptorSide, EndPending -- (fix round 1; defined with the release windows)

-- ===== the player-like helpers (the only places that tell a Player from a stand-in) =====
local function Hum(M) return M and M:FindFirstChildOfClass("Humanoid") end
local function Root(M) return M and M:FindFirstChild("HumanoidRootPart") end
local function Torso(M) return M:FindFirstChild("Torso") or M:FindFirstChild("UpperTorso") or Root(M) end
local function Alive(M) local H = Hum(M) return H ~= nil and M.Parent ~= nil and H.Health > 0 end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function IsPlayer(PL) return typeof(PL) == "Instance" and PL:IsA("Player") end

local function SeamOpen()
	if not RunService:IsStudio() then return false end
	local Ok, NoSave = pcall(DataManager.IsNoSave)
	if not Ok or NoSave ~= true then return false end
	local SeamOk, Seam = pcall(HostageService._NoSave)
	return SeamOk and Seam == true
end

-- (ruling K1) may a session start: the switch, or the tests' bypass (Studio first, then the no-save switch, then the seam)
function HostageService.Allowed()
	if Hostage.Enabled == true then return true end
	if not RunService:IsStudio() then return false end
	local Ok, NoSave = pcall(DataManager.IsNoSave)
	if not Ok or NoSave ~= true then return false end
	local BypassOk, Bypass = pcall(HostageService._TestBypass)
	return BypassOk and Bypass == true
end

local function IsNpc(M)
	return M:GetAttribute("EnemyType") ~= nil or M:GetAttribute("TownsfolkId") ~= nil
		or M:GetAttribute("DialogueId") ~= nil or EnemyService.Active[M] ~= nil
end

-- a real Player, or a stand-in this service registered (and only while the seam is open)
local function IsPL(PL)
	if IsPlayer(PL) then return true end
	return type(PL) == "table" and PL.IsStandIn == true and SeamOpen() and typeof(PL.Character) == "Instance"
		and StandIns[PL.Character] == PL
end

local function Char(PL) return PL and PL.Character end
local function Key(PL) return PL.UserId end
local function Present(PL)
	if IsPlayer(PL) then return PL.Parent == Players end
	local C = Char(PL)
	return C ~= nil and C:IsDescendantOf(workspace)
end
local function DataOf(PL)
	if IsPlayer(PL) then return require(ServerScriptService.ProgressionService).GetData(PL) end
	return PL.Data
end
local function LevelOf(PL)
	if IsPlayer(PL) then
		local D = DataOf(PL)
		return D and D.Level or PL:GetAttribute("Level") -- (P2: Data.Level; the attribute only without a profile)
	end
	return PL.Level
end
local function Notify(PL, Kind, Data)
	if not IsPlayer(PL) or PL.Parent ~= Players then return end
	local Ok, Err = pcall(function() require(ServerScriptService.UIService).Notify(PL, Kind, Data) end)
	if not Ok then warn("HostageService: couldn't notify", PL.Name, Err) end
end
local function Record(PL, Deed, Ctx)
	if not IsPlayer(PL) then return nil end -- (a stand-in has no profile)
	local Ok, Res = pcall(function() return require(ServerScriptService.MoralityService).Record(PL, Deed, false, Ctx) end)
	if not Ok then warn("HostageService: couldn't record", Deed, Res) return nil end
	return Res
end

-- (tests only) a rig stands in for a player; refused outside a Studio TestNoSave session, and for any NPC rig
function HostageService.StandIn(Model, Info)
	if not SeamOpen() then return nil, "seam closed" end
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or IsNpc(Model) then return nil, "not a stand-in" end
	Info = type(Info) == "table" and Info or {}
	if type(Info.UserId) ~= "number" then return nil, "no UserId" end -- (the sessions are keyed by it)
	local PL = {IsStandIn = true, Character = Model, Name = Info.Name or Model.Name, DisplayName = Info.DisplayName or Model.Name,
		UserId = Info.UserId, Level = Info.Level or 20, Data = {Money = Info.Money or 0, Stats = Info.Stats or {}, Level = Info.Level or 20},
		Party = Info.Party}
	StandIns[Model] = PL
	Model.Destroying:Once(function() if StandIns[Model] == PL then StandIns[Model] = nil end end)
	return PL
end
function HostageService.ClearStandIns() table.clear(StandIns) end

-- the player-like a character belongs to; never one for an NPC (PvP only)
function HostageService.PlayerOf(Model)
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or IsNpc(Model) then return nil end
	local P = Players:GetPlayerFromCharacter(Model)
	if P then return P end
	return SeamOpen() and StandIns[Model] or nil
end

-- the PL's party in this server, PL first among them (always included). Live: PartyService.Get(P).Members (nil for a
-- solo player: there are no solo parties). Tests: the stand-in's Party, or HostageService._PartyOf while SeamOpen.
function HostageService.PartyOf(PL)
	if HostageService._PartyOf and SeamOpen() then
		local Ok, List = pcall(HostageService._PartyOf, PL)
		if Ok and type(List) == "table" then
			local Out = {PL}
			for _, X in ipairs(List) do if X ~= PL then table.insert(Out, X) end end
			return Out
		end
	end
	local Out = {PL}
	local Members
	if IsPlayer(PL) then
		local Ok, Party = pcall(function() return require(ServerScriptService.PartyService).Get(PL) end)
		Members = Ok and type(Party) == "table" and Party.Members or nil
	else
		Members = PL.Party
	end
	for _, X in ipairs(Members or {}) do if X ~= PL then table.insert(Out, X) end end
	return Out
end

-- A and B are two different PLs in one party (as PartyService.SameParty: never a PL with itself)
function HostageService.SameParty(A, B)
	if A == nil or B == nil or A == B then return false end
	if IsPlayer(A) and IsPlayer(B) and not (HostageService._PartyOf and SeamOpen()) then
		local Ok, Same = pcall(function() return require(ServerScriptService.PartyService).SameParty(A, B) end)
		return Ok and Same == true
	end
	for _, X in ipairs(HostageService.PartyOf(A)) do if X == B then return true end end
	return false
end

-- ===== the gates =====
local function InBox(Pos, CF, Size)
	local P = CF:PointToObjectSpace(Pos)
	return math.abs(P.X) <= Size.X / 2 and math.abs(P.Y) <= Size.Y / 2 and math.abs(P.Z) <= Size.Z / 2
end
local function PosOf(X)
	if X:IsA("BasePart") then return X.Position end
	if X:IsA("Model") then return X:GetPivot().Position end
	return nil
end

function HostageService.InSafeZone(Character)
	local R = Root(Character)
	if not R then return false end
	local Pos = R.Position
	local Ok, Region = pcall(function() return require(ServerScriptService.MoralityService).RegionOf(Character) end)
	local Def = Ok and Regions.Regions[Region]
	if Def and Def.Safe == true then return true end
	for _, P in ipairs(CollectionService:GetTagged(Hostage.SafeTag)) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) and InBox(Pos, P.CFrame, P.Size) then return true end
	end
	for _, Tag in ipairs({"RenseiTicketClerk", "RenseiStationGate"}) do
		for _, X in ipairs(CollectionService:GetTagged(Tag)) do
			local At = X:IsDescendantOf(workspace) and PosOf(X)
			if At and (At - Pos).Magnitude <= Hostage.StationSafeRadius then return true end
		end
	end
	for _, X in ipairs(CollectionService:GetTagged("RenseiPlatformTrain")) do
		if X:IsDescendantOf(workspace) then
			local CF, Size
			if X:IsA("Model") then CF, Size = X:GetBoundingBox() elseif X:IsA("BasePart") then CF, Size = X.CFrame, X.Size end
			if CF and InBox(Pos, CF, Size + Vector3.one * (2 * Hostage.TrainMargin)) then return true end
		end
	end
	return false
end

local function Stunned(Character)
	return require(ServerScriptService.TakedownService).Stunned(Character)
end

local function CaptorFree(C)
	local H = Hum(C)
	if not H or not Alive(C) or DownedManager.IsKnocked(C) then return false end
	for _, A in ipairs({"Gripping", "Carrying", "TakingDown", "Holding", "HeldBy"}) do
		if C:GetAttribute(A) then return false end
	end
	if AttackRunner.IsRunning(C) or Stunned(C) then return false end
	return H.FloorMaterial ~= Enum.Material.Air and C:GetAttribute("Traversal") ~= "Swim"
end

local function TargetFree(T)
	if not Alive(T) then return false end
	for _, A in ipairs({"GrippedBy", "CarriedBy", "TakenDownBy", "HeldBy", "Holding", "Gripping", "Carrying", "TakingDown"}) do
		if T:GetAttribute(A) then return false end
	end
	return T:GetAttribute("Traversal") ~= "Swim"
end

local function InDialogue(PL)
	if not IsPlayer(PL) then return false end
	local Ok, Open = pcall(function() return require(ServerScriptService.DialogueService).IsOpen(PL) end)
	return Ok and Open == true
end

local ClearRays = RaycastParams.new()
ClearRays.FilterType = Enum.RaycastFilterType.Exclude
ClearRays.RespectCanCollide = true
ClearRays.IgnoreWater = true

function HostageService.Context(Captor, TargetModel, Kind)
	local Ctx = {Kind = Kind}
	Ctx.IsNpc = IsNpc(TargetModel) -- (first: the PvP rule)
	local Target = HostageService.PlayerOf(TargetModel)
	Ctx.IsPlayer = Target ~= nil
	local C = Char(Captor)
	Ctx.Self = TargetModel == C
	Ctx.Safe = (C ~= nil and HostageService.InSafeZone(C)) or HostageService.InSafeZone(TargetModel)
	Ctx.InDialogue = InDialogue(Captor) or (Target ~= nil and InDialogue(Target))
	Ctx.CaptorLevel = LevelOf(Captor)
	Ctx.TargetLevel = Target and LevelOf(Target) or nil
	local Now = os.clock()
	Ctx.Ready = Now >= (NextAt[Key(Captor)] or 0)
	Ctx.Immune = Target ~= nil and Now < (ImmuneUntil[Key(Target)] or 0)
	Ctx.CaptorFree = C ~= nil and CaptorFree(C)
	Ctx.TargetFree = TargetFree(TargetModel)
	Ctx.TargetKnocked = DownedManager.IsKnocked(TargetModel)
	Ctx.Range = (Kind == "Bind" and Hostage.BindRange or Hostage.GrabRange) + Hostage.RangeSlack
	local CR, TR = Root(C), Root(TargetModel)
	if CR and TR then
		local D = CR.Position - TR.Position
		Ctx.Dist, Ctx.Height = Flat(D).Magnitude, D.Y
		Ctx.Behind = Hostage.Behind(TR.CFrame.LookVector, D, Hostage.AngleSlack)
		ClearRays.FilterDescendantsInstances = {C, TargetModel}
		local A, B = Torso(C).Position, Torso(TargetModel).Position
		Ctx.Clear = workspace:Raycast(A, B - A, ClearRays) == nil
	end
	return Ctx
end

function HostageService.Check(Captor, TargetModel, Kind)
	return Hostage.CheckTake(HostageService.Context(Captor, TargetModel, Kind))
end

-- ===== sessions =====
function HostageService.SessionOf(PL)
	if PL == nil or PL.UserId == nil then return nil end
	return ByCaptor[Key(PL)] or ByHostage[Key(PL)]
end

local function Each(Fn)
	local List = {}
	for _, S in pairs(ByCaptor) do table.insert(List, S) end
	for _, S in ipairs(List) do Fn(S) end
end

local function Step(What, Fn, ...)
	local Ok, Err = pcall(Fn, ...)
	if not Ok then warn("HostageService: " .. What .. " failed:", Err) end
	return Ok
end

local function StopAnim(M, A)
	if not M then return end
	AnimationManager.Stop(M, A.Name)
	AnimationManager.Stop(M, A.Fallback)
end

local function Toast(PL, Text) Notify(PL, "Toast", {Text = Text}) end

-- (fix round I1 / I2; Release step 2) the hostage just let go: the server takes it, every part at rest (no fling from
-- the captor client's last velocity), put back at the lead's last checked spot x Offset after a "teleport" or within
-- FIGHT_WINDOW of a counted put-back (a client fighting the clamp never chooses where the hostage is left), and its
-- network owner given back as it was before the hold OWNER_BACK later (unless it is held again by then).
local function Settle(S, Outcome)
	local HC = S.HC
	local HR = Root(HC)
	if not HR or not HC.Parent then return end
	pcall(function() HR:SetNetworkOwner(nil) end)
	for _, P in ipairs(HC:GetDescendants()) do
		if P:IsA("BasePart") then
			P.AssemblyLinearVelocity = Vector3.zero
			P.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local Fight = S.PutBackAt ~= nil and os.clock() - S.PutBackAt < FIGHT_WINDOW
	if S.Lead and S.Lead.CF and (PUT_BACK_ENDS[Outcome] or Fight) then HR.CFrame = S.Lead.CF * Hostage.Offset end
	local Was = S.OwnerWas
	if not (Was and Was.Known) then return end
	task.delay(OWNER_BACK, function()
		if not HC.Parent or HC:GetAttribute("HeldBy") or Root(HC) ~= HR then return end
		pcall(function()
			if Was.Auto then HR:SetNetworkOwnershipAuto() else HR:SetNetworkOwner(Was.Owner) end
		end)
	end)
end

-- the one exit (see the header). Returns true when this call released the session.
local function Release(S, Outcome)
	if S.Over or ByCaptor[Key(S.Captor)] ~= S then return false end
	local R0 = os.clock()
	-- 1. over, unindexed, its connections dropped
	S.Over = true
	S.Outcome = Outcome
	if ByCaptor[Key(S.Captor)] == S then ByCaptor[Key(S.Captor)] = nil end
	if ByHostage[Key(S.Hostage)] == S then ByHostage[Key(S.Hostage)] = nil end
	Step("dropping the connections", function()
		for _, Conn in ipairs(S.Conns) do Conn:Disconnect() end
		table.clear(S.Conns)
	end)
	local CC, HC = S.CC, S.HC
	local NowServer = workspace:GetServerTimeNow()
	-- 2. the weld let go
	if S.Attached then
		Step("letting the hostage go", DownedManager.Detach, HC)
		Step("settling the hostage", Settle, S, Outcome)
	end
	-- 3. the hostage
	Step("unlocking the hostage", function()
		if S.HLocked and (HC.Parent == nil or not DownedManager.IsKnocked(HC)) then DownedManager.Lock(HC, false) end
	end)
	if S.Stun then Step("stopping the hostage's stun", function() S.Stun:Stop() end) end
	Step("stopping the hostage's animations", function()
		if HC.Parent then StopAnim(HC, Hostage.Anims.Held) StopAnim(HC, Hostage.Anims.Struggle) end
	end)
	Step("clearing the hostage", function()
		HC:SetAttribute("HeldBy", nil)
		HC:SetAttribute("HostageUntil", nil)
		HC:SetAttribute("Struggle", nil)
		HC:SetAttribute("GrabImmuneUntil", NowServer + Hostage.ImmuneAfter)
	end)
	ImmuneUntil[Key(S.Hostage)] = os.clock() + Hostage.ImmuneAfter
	Step("recovering a knock that ran out", function()
		if HC.Parent and Alive(HC) and DownedManager.IsKnocked(HC)
			and (HC:GetAttribute("KnockedUntil") or 0) <= workspace:GetServerTimeNow() then
			DownedManager.Recover(HC)
		end
	end)
	-- 4. the captor
	Step("unlocking the captor", function()
		if S.CLocked and (CC.Parent == nil or not DownedManager.IsKnocked(CC)) then DownedManager.Lock(CC, false) end
	end)
	Step("stopping the captor's animations", function()
		if CC.Parent then StopAnim(CC, Hostage.Anims.Bind) StopAnim(CC, Hostage.Anims.Hold) end
	end)
	Step("clearing the captor", function()
		CC:SetAttribute("Holding", nil)
		CC:SetAttribute("HostageUntil", nil)
	end)
	-- 5. the cooldown and the result
	NextAt[Key(S.Captor)] = os.clock() + Hostage.Cooldown
	Step("writing the result", function() CC:SetAttribute("LastHostageResult", S.Kind .. ":" .. tostring(Outcome)) end)
	-- 5b. (Task 7 fix round 1, review I1; spec §2: "a failed grab still counts as an assault") a grab that ends without
	-- ever becoming Held -- shoved off, or any other end (a blink, a broken weld, water, a safe zone, a knocked side,
	-- the hostage leaving, an error) -- records attempted_hostage for the captor, witnessed (Heat through the existing
	-- witness path), here in the one exit, so it is recorded once whatever ended it and a captor can't dodge it by
	-- ending the grab first. Skipped only when the captor's own Player is gone (they left: there is no one to record it
	-- on). A stand-in captor has no profile (Record does nothing for it).
	if S.Kind == "Grab" and S.HeldAt == nil and IsPlayer(S.Captor) and S.Captor.Parent == Players then
		Step("recording the failed grab", Record, S.Captor, "attempted_hostage", {Witness = true})
	end
	-- 6. both told (Task 8: the captor's with its Options, {} now the session is over; no "free" toast for a finish)
	Step("notifying", function()
		Notify(S.Captor, "Hostage", {State = "Free", Outcome = Outcome, Role = "Captor",
			Options = HostageService.MenuOptions(S.Captor)})
		Notify(S.Hostage, "Hostage", {State = "Free", Outcome = Outcome, Role = "Hostage"})
		if Outcome ~= "finished" then
			Toast(S.Captor, ("%s is free."):format(S.Hostage.DisplayName or S.Hostage.Name)) -- PROPOSAL (text)
			Toast(S.Hostage, "You're free.") -- PROPOSAL (text)
		end
	end)
	local R6 = os.clock() -- (steps 1-6: the listeners below may yield, so they aren't timed)
	-- 7. the listeners
	for _, Fn in ipairs(HostageService.Released) do Step("a Released listener", Fn, S, Outcome) end
	-- 8. (Task 11) a running ransom demand of this session is voided here
	-- phase timings of a slow bind or a slow release
	local Now = os.clock()
	if (S.State == "Binding" and Now - S.T0 > Hostage.BindTime + SLOW_PAST) or R6 - R0 > SLOW_RELEASE then
		local function At(X) return X and ("%.2f"):format(X - S.T0) or "-" end
		warn(("HostageService: a slow hold (%s, %s): take 0, bind start %s, held %s, release start %s, release done %s s"):format(
			S.Kind, tostring(Outcome), At(S.BindStarted), At(S.HeldAt), At(R0), At(Now)))
	end
	return true
end

-- ===== the led pair, policed (Task 6, ruling R1: see THE PAIR POLICED in the header) =====
-- a welded pair being led: Held, or (Task 7) Grabbing (pre-flight P5)
local function Led(S)
	return S.Attached == true and (S.State == "Held" or S.State == "Grabbing")
end

local WorldRays = RaycastParams.new()
WorldRays.FilterType = Enum.RaycastFilterType.Exclude
WorldRays.RespectCanCollide = true
WorldRays.IgnoreWater = true

-- (fix round I3 / I4) world geometry: Terrain or an anchored assembly; for a floor, also a part the server owns. Never a
-- character (any model with a Humanoid: a player, an accomplice, a rig in World.Live), never a client's loose part.
local function IsWorld(X, Floor)
	if X:IsA("Terrain") then return true end
	local A = X.Parent
	while A and A ~= workspace do
		if A:IsA("Model") and A:FindFirstChildOfClass("Humanoid") then return false end
		A = A.Parent
	end
	local R = X.AssemblyRootPart
	if X.Anchored or (R and R.Anchored) then return true end
	if not Floor then return false end
	local Ok, Owner = pcall(function() return X:GetNetworkOwner() end)
	return Ok and Owner == nil
end

-- the first world-geometry hit of the ray From + Dir (the pair, World.Live and every player's character skipped), or nil
local function WorldHit(S, From, Dir, Floor)
	local Skip = {S.CC, S.HC}
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if Live then table.insert(Skip, Live) end
	for _, P in ipairs(Players:GetPlayers()) do
		if P.Character then table.insert(Skip, P.Character) end
	end
	local Hit = nil
	for _ = 1, WORLD_TRIES do
		WorldRays.FilterDescendantsInstances = Skip
		local R = workspace:Raycast(From, Dir, WorldRays)
		if not R then break end
		if IsWorld(R.Instance, Floor) then Hit = R break end
		table.insert(Skip, R.Instance)
	end
	WorldRays.FilterDescendantsInstances = {} -- (review M6: no character kept after the call)
	return Hit
end

-- the server sees world floor under the captor's legs (review I4: never a character, never a client's loose part)
local function OnGround(S, CR)
	local H = Hum(S.CC)
	local Legs = CR.Size.Y / 2 + (H and H.HipHeight or 0) + ((H and H.RigType == Enum.HumanoidRigType.R6) and 2 or 0)
	return WorldHit(S, CR.Position, Vector3.new(0, -(Legs + GROUND_RAY), 0), true) ~= nil
end

-- a lead point: where (Pos; CF, the root's whole CFrame), the rise reference Y, when (T), and the last ground point's
-- height and time (GroundY, GroundT: a drop is measured from them)
local function NewLead(CR)
	local Now = os.clock()
	return {Pos = CR.Position, CF = CR.CFrame, Y = CR.Position.Y, T = Now, GroundY = CR.Position.Y, GroundT = Now}
end

-- the pair put back at the lead's point (its full position), at rest; counted unless it is a rebase's echo
local function PutBack(S, CR, L, Now, Echo)
	CR.CFrame += L.Pos - CR.Position
	CR.AssemblyLinearVelocity = Vector3.zero
	CR.AssemblyAngularVelocity = Vector3.zero
	if not Echo then
		S.CC:SetAttribute("HostageClamped", (S.CC:GetAttribute("HostageClamped") or 0) + 1)
		S.PutBackAt = Now
	end
	L.T = Now
end

-- 1. the lead clamp: "teleport", or nil (the pair put back when it went further, higher or lower than a led walk could)
local function LeadCheck(S)
	local CR, L = Root(S.CC), S.Lead
	if not CR or not L then return nil end
	local Now, Pos = os.clock(), CR.Position
	local Moved = Pos - L.Pos
	local Len = Moved.Magnitude
	if Len ~= Len then return "teleport" end -- (Task 7, m1: a NaN position is no walk)
	local D = Flat(Moved).Magnitude
	local Echo = L.Rebased ~= nil and Now - L.Rebased < REBASE_GRACE
	-- (Task 7, m1) the path ray clamped before it is cast: a huge move is checked along its first MAX_RAY studs
	local Ray = Len > MAX_RAY and Moved * (MAX_RAY / Len) or Moved
	-- a blink: too far, or through world geometry (a wall, a floor). It ends; Release puts the hostage back (I1).
	if not Echo and (D > Hostage.TeleportBreak or (Len >= STILL and WorldHit(S, L.Pos, Ray, false))) then
		return "teleport"
	end
	local Fall = Now - L.GroundT + DROP_LAG
	local DropMax = 0.5 * workspace.Gravity * Fall * Fall + DROP_SLACK
	if D > Hostage.LeadAllowance(Now - L.T) or Pos.Y > L.Y + Hostage.RiseSlack or L.GroundY - Pos.Y > DropMax then
		PutBack(S, CR, L, Now, Echo)
		return nil
	end
	local Ground = OnGround(S, CR)
	local Y = Ground and Pos.Y or math.min(L.Y, Pos.Y)
	if Moved.Magnitude < STILL then
		L.Y = Y -- (still: Pos and T kept, so the window grows up to LeadWindow)
		if Ground then L.GroundY, L.GroundT = Pos.Y, Now end
	else
		S.Lead = {Pos = Pos, CF = CR.CFrame, Y = Y, T = Now, Rebased = L.Rebased,
			GroundY = Ground and Pos.Y or L.GroundY, GroundT = Ground and Now or L.GroundT}
	end
	return nil
end

-- 2. the pair: "broken" when the weld is gone or the hostage's root isn't where the weld holds it
local function PairCheck(S)
	local CR, HR = Root(S.CC), Root(S.HC)
	if not CR or not HR then return "broken" end
	local W = CR:FindFirstChild("DownedWeld")
	if not W or W.Part1 ~= HR then return "broken" end
	if (HR.Position - (CR.CFrame * Hostage.Offset).Position).Magnitude > Hostage.PairSlack then return "broken" end
	return nil
end

-- 3. ownership: the hostage's root stays the captor's client's (the server's for a stand-in captor)
local function KeepOwner(S)
	local HR = Root(S.HC)
	if not HR then return end
	local Owner = IsPlayer(S.Captor) and S.Captor or nil
	pcall(function() -- (an anchored assembly refuses both calls: a test holds the captor's root)
		if HR:GetNetworkOwner() ~= Owner then HR:SetNetworkOwner(Owner) end
	end)
end

local function BackpackOf(PL)
	if IsPlayer(PL) then return PL:FindFirstChildOfClass("Backpack") end
	return typeof(PL.Backpack) == "Instance" and PL.Backpack or nil -- (a stand-in's, which a test gives it)
end

-- 4. the hostage's own body kept still, its tools put away (decision 18)
local function KeepStill(S)
	local H = Hum(S.HC)
	if H then
		if H.WalkSpeed ~= 0 then H.WalkSpeed = 0 end
		if H.JumpHeight ~= 0 then H.JumpHeight = 0 end
		if not H.PlatformStand then H.PlatformStand = true end
	end
	for _, X in ipairs(S.HC:GetChildren()) do
		if X:IsA("Tool") then
			local Bag = BackpackOf(S.Hostage)
			if Bag then X.Parent = Bag elseif H then H:UnequipTools() end
		end
	end
end

-- 5. deep water (SwimService, read only; called through its module, so a test's stub is seen)
local function InDeepWater(M)
	local Swim = ServerScriptService:FindFirstChild("SwimService")
	if not Swim then return false end
	local Ok, Deep = pcall(function() return require(Swim).InDeepWater(M) end)
	return Ok and Deep == true
end

-- the pair welded and led (Hold; Task 7's grab too, pre-flight P5): see Pair(S) in the header
local function Pair(S)
	-- (Task 7, Task 6 re-review m3) idempotent: a pair already welded (a grab becoming a hold) is left as it is, so the
	-- hostage root's owner noted before the FIRST weld is the one given back (a second note would record the captor's
	-- client, and the hostage's character would stay the captor client's after the release)
	if S.Attached then return end
	local HR = Root(S.HC)
	-- (fix round I2) the hostage root's network ownership before the hold, given back at the release
	local AutoOk, Auto = pcall(function() return HR:GetNetworkOwnershipAuto() end)
	local OwnerOk, Owner = pcall(function() return HR:GetNetworkOwner() end)
	S.OwnerWas = {Known = AutoOk and OwnerOk, Auto = Auto == true, Owner = Owner}
	if not DownedManager.Attach(S.CC, S.HC, Hostage.Offset) then error("the weld failed") end
	S.Attached = true
	if S.CLocked then DownedManager.Lock(S.CC, false) end
	DownedManager.Lock(S.CC, true, Hostage.LeadSpeed)
	S.CLocked = true
	S.Lead = NewLead(Root(S.CC))
end

-- (pre-flight P6) a script moved a led pair on purpose: its lead clamp starts again from the captor's root's spot now
function HostageService.Rebase(Character)
	if typeof(Character) ~= "Instance" then return false end
	for _, S in pairs(ByCaptor) do
		if not S.Over and S.Lead and (S.CC == Character or S.HC == Character) then
			local CR = Root(S.CC)
			if not CR then return false end
			S.Lead = NewLead(CR)
			S.Lead.Rebased = os.clock()
			return true
		end
	end
	return false
end

-- the session's ends, a test seam: see the header
function HostageService.Broken(S)
	if not Present(S.Captor) or not Present(S.Hostage) then return "left" end
	if not Alive(S.CC) or not Alive(S.HC) or Char(S.Captor) ~= S.CC or Char(S.Hostage) ~= S.HC then return "died" end
	if DownedManager.IsKnocked(S.CC) then return "knocked" end
	if Led(S) and DownedManager.IsKnocked(S.HC) then return "knocked" end -- (Held, or Task 7: Grabbing)
	if Led(S) then
		local Out = LeadCheck(S) or PairCheck(S)
		if Out then return Out end
		KeepOwner(S)
		KeepStill(S)
		if InDeepWater(S.CC) or InDeepWater(S.HC) then return "water" end
	end
	if HostageService.InSafeZone(S.CC) then return "safe" end
	if S.State == "Held" and os.clock() >= S.Until then return "timeout" end
	return nil
end

-- ===== the struggle (Task 7) =====
-- a PL's StruggleStat (Strength, ruling P1) from its save (a stand-in's Data), or 0
local function BodyOf(PL)
	local D = DataOf(PL)
	return tonumber(D and D.Stats and D.Stats[Hostage.StruggleStat]) or 0
end

local function StunFor(M, Seconds)
	local WC = M and M.Parent and WCS.Character.GetCharacterFromInstance(M)
	if WC then Stun.new(WC):Start(Seconds) end
end

local function SetBar(S, Value)
	S.Struggle = math.clamp(Value, 0, 1)
	if S.HC.Parent then S.HC:SetAttribute("Struggle", S.Struggle) end
end

-- a full bar ends the session: a grab shoved off (the captor stunned ShoveStun -- the shove's own consequence, so only
-- here; attempted_hostage is recorded by Release for every failed grab, decision 6 / fix round 1, never took_hostage),
-- or a hostage struggled free (the captor stunned BreakStun). Returns true when it ended the session.
local function Resolve(S)
	if S.Over or S.Struggle < 1 then return false end
	local CC = S.CC
	if S.State == "Grabbing" then
		if Release(S, "grab_failed") then Step("stunning the shoved-off captor", StunFor, CC, Hostage.ShoveStun) end
		return true
	elseif S.State == "Held" then
		if Release(S, "struggled") then Step("stunning the captor", StunFor, CC, Hostage.BreakStun) end
		return true
	end
	return false
end

-- the hostage's struggle pose for StrugglePoseTime after a counted press, then the held pose again
local function Pose(S, On)
	local HC = S.HC
	if On then
		S.PoseUntil = os.clock() + Hostage.StrugglePoseTime
		if S.Posing then return end
		S.Posing = true
		StopAnim(HC, Hostage.Anims.Held)
		AnimationManager.Play(HC, Hostage.Anims.Struggle.Name,
			{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Struggle.Fallback})
	else
		S.Posing = false
		StopAnim(HC, Hostage.Anims.Struggle)
		AnimationManager.Play(HC, Hostage.Anims.Held.Name,
			{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Held.Fallback})
	end
end

-- (Task 7) the hostage's own presses. Ignored unless PL is the hostage of a Grabbing or Held session, Count is a whole
-- number from 1 to MaxPressesPerSecond (review M7: never NaN, infinite or negative) and the hostage has the stamina; at
-- most MaxPressesPerSecond presses are counted per PL in any rolling second; each counted press spends StruggleStamina
-- and adds StruggleGain(own Strength, captor's Strength). Every message from a PL is counted in Sends (P9).
-- Returns true when a press counted.
function HostageService.Struggle(PL, Count)
	if PL == nil or not IsPL(PL) then return false end
	local K = Key(PL)
	Sends[K] = (Sends[K] or 0) + 1
	if type(Count) ~= "number" or Count ~= Count or Count < 1 or Count > Hostage.MaxPressesPerSecond
		or Count % 1 ~= 0 then
		return false
	end
	local S = ByHostage[K]
	if not S or S.Over or S.Hostage ~= PL or (S.State ~= "Grabbing" and S.State ~= "Held") then return false end
	local Now = os.clock()
	local Recent = {}
	for _, T in ipairs(Presses[K] or {}) do
		if Now - T < 1 then table.insert(Recent, T) end
	end
	local RM = require(Modules.Managers.ResourceManager)
	local N = 0
	for _ = 1, Count do
		if #Recent >= Hostage.MaxPressesPerSecond then break end
		if not RM.Spend(S.HC, "Stamina", Hostage.StruggleStamina) then break end -- (no stamina, no press)
		table.insert(Recent, Now)
		N += 1
	end
	Presses[K] = Recent
	if N == 0 then return false end
	SetBar(S, S.Struggle + N * Hostage.StruggleGain(BodyOf(S.Hostage), BodyOf(S.Captor)))
	if S.State == "Held" then Step("the struggle pose", Pose, S, true) end
	Resolve(S)
	return true
end

-- (pre-flight P9; Task 12's tests read it) the Struggle messages received from PL since it was last forgotten
function HostageService._Sends(PL)
	return (PL and PL.UserId ~= nil and Sends[Key(PL)]) or 0
end

local Promote -- (the grab's window over: the hold; below)

-- (Task 7) the watch's own work after Broken: the bar drained, a full bar resolved, a grab's window ended, the pose
local function Tick(S)
	local Now = os.clock()
	local Dt = Now - (S.DrainAt or Now)
	S.DrainAt = Now
	if S.State ~= "Grabbing" and S.State ~= "Held" then return end
	if S.Struggle > 0 then SetBar(S, S.Struggle - Hostage.StruggleDrain * Dt) end -- (never below 0)
	if Resolve(S) then return end
	if S.State == "Grabbing" and Now >= S.GrabEnds then
		Promote(S)
	elseif S.Posing and Now >= (S.PoseUntil or 0) then
		Step("the held pose", Pose, S, false)
	end
end

local function Watch(S)
	S.DrainAt = os.clock()
	while not S.Over do
		task.wait(Hostage.WatchTick)
		if S.Over then return end
		local Ok, Outcome = pcall(HostageService.Broken, S)
		if not Ok then
			warn("HostageService: Broken failed:", Outcome)
			Release(S, "error")
		elseif Outcome then
			Release(S, Outcome)
		else
			local TickOk, TickErr = pcall(Tick, S)
			if not TickOk then
				warn("HostageService: the struggle tick failed:", TickErr)
				Release(S, "error")
			end
		end
	end
end

-- re-takes of this hostage within RetakeWindow (any captor), the old ones dropped
local function Retakes(HKey)
	local Now, Out = os.clock(), {}
	for _, T in ipairs(Taken[HKey] or {}) do
		if Now - T < Hostage.RetakeWindow then table.insert(Out, T) end
	end
	Taken[HKey] = Out
	return #Out
end

-- step 1: the bind starts
local function BindStart(S)
	DownedManager.Lock(S.CC, true)
	S.CLocked = true
	S.BindAt = Root(S.CC).Position
	S.BindStarted = os.clock()
	local A = Hostage.Anims.Bind
	Step("the bind animation", AnimationManager.Play, S.CC, A.Name, {Priority = Enum.AnimationPriority.Action4, Fallback = A.Fallback})
end

-- step 2: true when the bind must end as an interrupt
local function BindBroken(S)
	if HostageService.Broken(S) then return true end
	if not DownedManager.IsKnocked(S.HC) then return true end -- (a bind needs a knocked hostage)
	local CR = Root(S.CC)
	if not CR or (CR.Position - S.BindAt).Magnitude > BIND_SLACK then return true end
	return Stunned(S.CC)
end

-- the hostage restrained and the pair welded, in one step (the bind's step 3; Task 7: the grab's, at once): the
-- hostage locked, stunned (WCS) for StunTime, its tools put away; the weld, the captor at LeadSpeed and the lead
-- clamp's first point (Pair, Task 6); the hold / held animations looped at Action4
local function Restrain(S, StunTime)
	local CC, HC = S.CC, S.HC
	local H = Hum(HC)
	S.Saved = {WalkSpeed = H.WalkSpeed, JumpHeight = H.JumpHeight} -- (what Lock saves too; kept for the log)
	DownedManager.Lock(HC, true)
	S.HLocked = true
	local HWC = WCS.Character.GetCharacterFromInstance(HC)
	if HWC then
		S.Stun = Stun.new(HWC)
		S.Stun:Start(StunTime)
	end
	Step("putting the hostage's tools away", function() H:UnequipTools() end)
	Pair(S)
	StopAnim(CC, Hostage.Anims.Bind)
	Step("the hold animation", AnimationManager.Play, CC, Hostage.Anims.Hold.Name,
		{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Hold.Fallback})
	Step("the held animation", AnimationManager.Play, HC, Hostage.Anims.Held.Name,
		{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Held.Fallback})
end

-- the session becomes Held for Time seconds (the bind's step 3 from "the captor:" on; Task 7: a grab whose window ended):
-- the captor at LeadSpeed (Pair, idempotent: m3), State "Held", S.Until, HostageUntil on both, the bar at 0, this take
-- counted in Taken (pre-flight P22: only a hold is a re-take). Returns the server time it ends.
local function BeginHeld(S, Time)
	Pair(S)
	local Now = os.clock()
	S.State = "Held"
	S.HeldAt = Now
	S.Until = Now + Time
	local UntilServer = workspace:GetServerTimeNow() + Time
	S.CC:SetAttribute("HostageUntil", UntilServer)
	S.HC:SetAttribute("HostageUntil", UntilServer)
	SetBar(S, 0)
	local HKey = Key(S.Hostage)
	Retakes(HKey)
	table.insert(Taken[HKey], Now)
	return UntilServer
end

-- (Task 8) a real player's Heat now, per jurisdiction (Rensei.Heat.Order), or nil (a stand-in, no profile, an error)
local function HeatNow(PL)
	if not IsPlayer(PL) then return nil end
	local Ok, Out = pcall(function()
		local HeatService = require(ServerScriptService.HeatService)
		local T = {}
		for _, J in ipairs(Heat.Order) do T[J] = HeatService.Value(PL, J) end
		return T
	end)
	return Ok and Out or nil
end

-- both told (each its own Role, pre-flight P28; Task 8: the captor's with its Options) and took_hostage recorded (a real
-- captor, witnessed). (Task 8, the release Heat) the Heat that Record raised in this same step (Morality's Recorded
-- listeners, HeatService's OnRecorded among them, run before Record returns) is kept per jurisdiction in S.TookHeat, so
-- a release unharmed can halve it.
local function Announce(S, UntilServer)
	for _, X in ipairs({{S.Captor, "Captor"}, {S.Hostage, "Hostage"}}) do
		Notify(X[1], "Hostage", {State = "Held", Role = X[2], Captor = S.Captor.Name, Hostage = S.Hostage.Name, Until = UntilServer,
			Options = X[2] == "Captor" and HostageService.MenuOptions(S.Captor) or nil})
	end
	local Before = HeatNow(S.Captor)
	Record(S.Captor, "took_hostage", {Witness = true})
	local After = Before and HeatNow(S.Captor)
	S.TookHeat = {}
	for J, V in pairs(After or {}) do
		local Raised = V - (Before[J] or 0)
		if Raised > 0 then S.TookHeat[J] = Raised end
	end
end

-- step 3: the hold, in one step (no yield until Watch is running)
local function Hold(S)
	local HC = S.HC
	if not DownedManager.EndKnock(HC, Hostage.MinHealthShare) then error("the knock couldn't be ended") end
	if HC:GetAttribute("SecondWindActive") then HC:SetAttribute("SecondWindActive", nil) end
	local Time = Hostage.HoldTimeFor(Retakes(Key(S.Hostage)))
	Restrain(S, Time + Hostage.StunPad)
	local UntilServer = BeginHeld(S, Time)
	task.spawn(Watch, S)
	local Now = os.clock()
	if Now - S.T0 > Hostage.BindTime + SLOW_PAST then
		warn(("HostageService: a slow bind: take 0, bind start %.2f, held %.2f s"):format((S.BindStarted or Now) - S.T0, Now - S.T0))
	end
	Announce(S, UntilServer)
end

-- (Task 7) the stealth grab, in the take's own step: no bind time and no knock to end (the target stands), so EndKnock
-- is never called (Task 5's concern). Restrained and welded at once, Grabbing, the bar at GrabStart, GrabWindow to fill
-- it (Watch: Tick). The hostage's Stun covers the window and the hold after it.
local function Grab(S)
	local Time = Hostage.HoldTimeFor(Retakes(Key(S.Hostage)))
	Restrain(S, Hostage.GrabWindow + Time + Hostage.StunPad)
	local Now = os.clock()
	S.State = "Grabbing"
	S.GrabEnds = Now + Hostage.GrabWindow
	SetBar(S, Hostage.GrabStart)
	task.spawn(Watch, S)
	local EndsServer = workspace:GetServerTimeNow() + Hostage.GrabWindow
	for _, X in ipairs({{S.Captor, "Captor"}, {S.Hostage, "Hostage"}}) do
		Notify(X[1], "Hostage", {State = "Grabbing", Role = X[2], Captor = S.Captor.Name, Hostage = S.Hostage.Name, Ends = EndsServer,
			Options = X[2] == "Captor" and HostageService.MenuOptions(S.Captor) or nil}) -- (Task 8: {} while Grabbing)
	end
end

-- (Task 7) a grab's window ended with the bar under 1: the hold (re-takes counted now, at Held: P22)
function Promote(S)
	local Time = Hostage.HoldTimeFor(Retakes(Key(S.Hostage)))
	Announce(S, BeginHeld(S, Time))
end

local function Run(S)
	local Ok, Err = pcall(BindStart, S)
	if not Ok then
		warn("HostageService: the bind couldn't start:", Err)
		Release(S, "error")
		return
	end
	local RunOk, RunErr = pcall(function()
		while true do
			RunService.Heartbeat:Wait()
			if S.Over then return end
			if BindBroken(S) then Release(S, "interrupted") return end
			if os.clock() - S.BindStarted >= Hostage.BindTime then break end
		end
		if S.Over then return end
		Hold(S)
	end)
	if not RunOk then
		warn("HostageService: the hold failed:", RunErr)
		Release(S, "error")
	end
end

-- a session's characters' own ends: died, destroyed, or a real owner's new character
local function Connect(S)
	local function Died() Release(S, "died") end
	for _, M in ipairs({S.CC, S.HC}) do
		local H = Hum(M)
		if H then table.insert(S.Conns, H.Died:Connect(Died)) end
		table.insert(S.Conns, M.Destroying:Connect(Died))
	end
	for _, PL in ipairs({S.Captor, S.Hostage}) do
		if IsPlayer(PL) then table.insert(S.Conns, PL.CharacterAdded:Connect(Died)) end
	end
end

function HostageService.Take(Captor, TargetModel)
	if not HostageService.Allowed() then return false, "disabled" end -- (ruling K1: switched off until Task 14)
	if not IsPL(Captor) then return false, "not_player" end
	local CC = Char(Captor)
	if not (Root(CC) and typeof(TargetModel) == "Instance" and TargetModel:IsA("Model")) then return false, "missing" end
	if IsNpc(CC) then return false, "not_player" end -- (never an NPC captor)
	local Kind = DownedManager.IsKnocked(TargetModel) and "Bind" or "Grab"
	-- (review M4) a non-player target is refused before the Context's rays and scans
	local Ctx = (IsNpc(TargetModel) or not HostageService.PlayerOf(TargetModel)) and {IsNpc = true}
		or HostageService.Context(Captor, TargetModel, Kind)
	local Ok, Reason
	if Ctx.IsNpc or not Ctx.IsPlayer then
		Ok, Reason = false, "not_player" -- (first: the PvP rule, before every other gate)
	else
		Ok, Reason = Hostage.CheckTake(Ctx) -- (a Grab: the rear arc, GrabRange, "seen" from the front; Task 7)
	end
	if not Ok then
		local K = Key(Captor)
		NextAt[K] = math.max(NextAt[K] or 0, os.clock() + Hostage.RefusedCooldown) -- (never shortens a cooldown)
		CC:SetAttribute("LastHostageResult", Kind .. ":" .. tostring(Reason))
		return false, Reason
	end
	local Target = HostageService.PlayerOf(TargetModel)
	-- the same step as the last check, no yield between: one captor per hostage, one hostage per captor
	TargetModel:SetAttribute("HeldBy", Captor.Name)
	CC:SetAttribute("Holding", Target.Name)
	local S = {Id = HttpService:GenerateGUID(false), Captor = Captor, Hostage = Target, CC = CC, HC = TargetModel,
		Kind = Kind, State = "Binding", T0 = os.clock(), Until = nil, Struggle = 0, Over = false, Conns = {}, Saved = {}}
	ByCaptor[Key(Captor)] = S
	ByHostage[Key(Target)] = S
	-- (Task 8 fix round 1) taken again by the captor's side inside a release window: that window ends unpaid (the new
	-- hold has its own deeds)
	for P in pairs(Pending) do
		if P.HC == TargetModel and CaptorSide(P, CC) then EndPending(P) end
	end
	Connect(S)
	if Kind == "Grab" then
		-- (Task 7) the grab is welded in this same step: no bind time
		local GrabOk, Err = pcall(Grab, S)
		if not GrabOk then
			warn("HostageService: the grab failed:", Err)
			Release(S, "error")
			return false, "error"
		end
	else
		task.spawn(Run, S)
	end
	return true, "started"
end

function HostageService.Free(PL, Outcome)
	local S = HostageService.SessionOf(PL)
	if not S then return false end
	return Release(S, Outcome or "freed")
end

function HostageService.Forget(PL, Only)
	if PL == nil or PL.UserId == nil then return end
	local K = Key(PL)
	if not Only or Only.NextAt then NextAt[K] = nil end
	if not Only or Only.ImmuneUntil then ImmuneUntil[K] = nil end
	if not Only or Only.Taken then Taken[K] = nil end
	if not Only or Only.Sends then Sends[K], Presses[K] = nil, nil end -- (Task 7, P9: the messages and the rate window)
end

-- ===== the captor menu (Task 8, spec §3; see THE CAPTOR MENU in the header) =====
-- the Held session Captor is the captor of, or nil
local function CaptorSession(Captor)
	if Captor == nil or not IsPL(Captor) then return nil end
	local S = ByCaptor[Key(Captor)]
	if not S or S.Over or S.Captor ~= Captor or S.State ~= "Held" then return nil end
	return S
end

function HostageService.MenuOptions(Captor)
	local S = CaptorSession(Captor)
	if not S then return {} end
	local Alone = #HostageService.PartyOf(S.Hostage) <= 1
	return {
		{Id = "Release", Text = "Let them go", Locked = false},
		{Id = "Finish", Text = "Finish them", Locked = false},
		-- (Task 11 builds the demand; until then it stays locked)
		{Id = "Ransom", Text = "Demand ransom", Locked = true, Why = Alone and "They have no party here" or "Not yet"},
		-- (TurnIn: offered near a desk with a Wanted hostage, Task 11; absent until then)
	}
end

-- ===== a release's unharmed window (Task 8 fix round 1, controller ruling I1) =====
-- A menu Release pays out (released_hostage, the took_hostage Heat halved) only after ReleaseGrace seconds in which the
-- released player was neither knocked (a landed hit that left them knocked) nor gripped by the ex-captor or their party.
-- A grip by them that finishes inside the window (or that started inside it and is still running at its end) records
-- killed_hostage, as Finish would, and nothing else. Someone else hurting the released player changes nothing. Each
-- window is a P in Pending: {Captor, Hostage, HC, TookHeat, Ends (os.clock()), Harmed (nil or why), Over, Conns}.
HostageService._ReleaseGrace = nil -- (tests only, read while SeamOpen) a shorter window in seconds

local function GraceTime()
	local X = HostageService._ReleaseGrace
	if SeamOpen() and type(X) == "number" and X > 0 and X < math.huge then return X end
	return Hostage.ReleaseGrace
end

-- is this character (or character name) the ex-captor's or one of their party's (never the released player's own)
function CaptorSide(P, Who)
	if Who == nil then return false end
	for _, X in ipairs(HostageService.PartyOf(P.Captor)) do
		local XC = X ~= P.Hostage and Char(X)
		if XC and (XC == Who or (type(Who) == "string" and XC.Name == Who)) then return true end
	end
	return false
end

function EndPending(P)
	if P.Over then return end
	P.Over = true
	Pending[P] = nil
	for _, Conn in ipairs(P.Conns) do Conn:Disconnect() end
	table.clear(P.Conns)
end

-- the window ran out unharmed: the Mercy deed, then the took_hostage Heat this hold raised halved (the ruling on spec
-- section 3). A captor who has left gets nothing (no profile to record on); nor does a stand-in (Record does nothing).
local function PayRelease(P)
	EndPending(P)
	if not (IsPlayer(P.Captor) and P.Captor.Parent == Players) then return end
	Record(P.Captor, "released_hostage", {Witness = true})
	for J, Raised in pairs(P.TookHeat) do
		Step("halving the taking's Heat", function()
			require(ServerScriptService.HeatService).Reduce(P.Captor, J, Raised / 2)
		end)
	end
end

-- ProgressionService.HitListeners: a landed hit by the captor's side that left a released player knocked in their window
local function OnHit(Attacker, Victim, Result)
	if Result ~= "Hit" then return end
	for P in pairs(Pending) do
		if not P.Over and P.HC == Victim and DownedManager.IsKnocked(Victim) and CaptorSide(P, Attacker) then
			P.Harmed = P.Harmed or "knocked"
		end
	end
end

-- DownedManager.Listeners: a grip finished someone; a released player killed by the captor's side in their window
local function OnGrip(Kind, Gripper, Target)
	if Kind ~= "Grip" then return end
	for P in pairs(Pending) do
		if not P.Over and P.HC == Target and CaptorSide(P, Gripper) then
			EndPending(P)
			if IsPlayer(P.Captor) and P.Captor.Parent == Players then Record(P.Captor, "killed_hostage", {Witness = true}) end
		end
	end
end

-- NoPay (fix round 2, controller ruling on review m2): a window that never pays out (a cancelled Finish's), only
-- watching for a kill by the captor's side
local function StartPending(S, NoPay)
	local P = {Captor = S.Captor, Hostage = S.Hostage, HC = S.HC, TookHeat = S.TookHeat or {}, Ends = os.clock() + GraceTime(),
		Harmed = nil, NoPay = NoPay == true, Over = false, Conns = {}}
	Pending[P] = true
	table.insert(P.Conns, P.HC:GetAttributeChangedSignal("GrippedBy"):Connect(function()
		if not P.Over and os.clock() < P.Ends and CaptorSide(P, P.HC:GetAttribute("GrippedBy")) then
			P.Harmed = P.Harmed or "gripped"
		end
	end))
	task.delay(P.Ends - os.clock(), function()
		-- a grip running at the window's end is waited out (its own finish decides a kill); then paid unless harmed
		local T0 = os.clock()
		while not P.Over and P.HC.Parent and P.HC:GetAttribute("GrippedBy") and os.clock() - T0 < GRIP_WAIT do task.wait(0.1) end
		if P.Over then return end
		if P.Harmed or P.NoPay then EndPending(P) else PayRelease(P) end
	end)
end

-- (tests only) every release window dropped, nothing paid (HostageKit.Clean)
function HostageService._ClearPending()
	for P in pairs(Pending) do EndPending(P) end
end

-- release: the hold ends at once; what it earns waits for the window
local function MenuRelease(S)
	if not Release(S, "released") then return false end
	StartPending(S)
	return true
end

-- finish them: refused while the captor is stunned or attacking (Grip's own conditions: it would fail at once, or wait
-- with the hostage knocked and free -- fix round 1, I2), so Release, the knock and the grip's marks run with no yield;
-- the hold let go, the hostage knocked (its HP kept), then the normal Grip on its own thread. A grip that fails other
-- than by being cancelled (a stun, a dead side) gives the knock back (EndKnock at the hostage's own HP): no free knock.
local function MenuFinish(S)
	local Captor, CC, HC = S.Captor, S.CC, S.HC
	if Stunned(CC) or AttackRunner.IsRunning(CC) then return false end
	if not Release(S, "finished") then return false end
	if not (Alive(CC) and Alive(HC)) then return true end
	Step("knocking the hostage", DownedManager.Knock, HC)
	if not DownedManager.IsKnocked(HC) then return true end
	task.spawn(function()
		local Ok, Done = pcall(DownedManager.Grip, CC, HC)
		if not Ok then warn("HostageService: the finishing grip failed:", Done) end
		if Ok and Done == true then
			Record(Captor, "killed_hostage", {Witness = true})
		elseif Alive(CC) and Alive(HC) and not Stunned(CC) and not HC:GetAttribute("GrippedBy") then
			Step("giving the knock back", DownedManager.EndKnock, HC, 0)
		elseif Alive(HC) and DownedManager.IsKnocked(HC) then
			-- (fix round 2, ruling on review m2) cancelled (a stun): the hostage stays knocked, as for any grip, and the
			-- same harm window opens, paying nothing -- a grip of the captor's side that kills them inside it is still
			-- killed_hostage, so a friend's stun can't turn a Finish into a deed-free kill
			Step("opening the cancelled Finish's window", StartPending, S, true)
		end
	end)
	return true
end

function HostageService.Menu(Captor, Choice, _Arg)
	if type(Choice) ~= "string" then return false end
	local S = CaptorSession(Captor)
	if not S then return false end
	if Choice == "Release" then return MenuRelease(S) end
	if Choice == "Finish" then return MenuFinish(S) end
	return false
end

-- the PlayerRemoving handler (a test seam): every session of that PL released as "left" (its cooldown, immunity and
-- re-take times are kept: a rejoin doesn't reset them)
function HostageService._Left(PL)
	Each(function(S)
		if S.Captor == PL or S.Hostage == PL then Release(S, "left") end
	end)
	-- (fix round 1) a release window of either side ends with nothing paid: a captor who left has no profile to record
	-- on (and can't log off to keep a payout coming), and a released player who left can no longer be spared or harmed
	for P in pairs(Pending) do
		if P.Captor == PL or P.Hostage == PL then EndPending(P) end
	end
end

-- the BindToClose handler (a test seam): every session released as "shutdown"
function HostageService._Shutdown()
	Each(function(S) Release(S, "shutdown") end)
	HostageService._ClearPending() -- (fix round 1) release windows end unpaid
end

local Started = false
function HostageService.Start()
	if Started then return end
	Started = true
	Players.PlayerRemoving:Connect(HostageService._Left)
	game:BindToClose(HostageService._Shutdown)
	-- (fix round 1) what a release window watches: landed hits and finished grips
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, OnHit)
	table.insert(DownedManager.Listeners, OnGrip)
end

return HostageService
