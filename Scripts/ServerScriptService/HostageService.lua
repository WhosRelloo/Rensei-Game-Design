-- HostageService (hostages plan Task 5, 2026-10-27; spec Documents/specs/2026-10-21-hostage-design.md, owner-approved
-- 2026-10-25): the server side of a player-on-player hostage. The client only asks (Requests.Hostage); every rule is
-- checked here, with the server's own positions. Numbers and the gate maths: Rensei.Hostage (every number a PROPOSAL
-- unless it says it was measured). Tasks 6-11 extend it (the pair policed -- Task 6, done --, the grab and the struggle
-- -- Task 7, done --, the captor menu -- Task 8, done --, the shield and rescue -- Task 9, done --, ransom and turn-in
-- -- Task 11 --).
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
--   AngleSlack); Clear = one torso-to-torso ray AND (final fix round, review M3) the take spot clear: no world geometry
--   (WorldHit) from the captor's root to SPOT_REACH studs along Hostage.Offset, so the weld never snaps the hostage
--   through a thin wall). (Final fix round, review M6) for a Grab, TargetFree also refuses a target in any traversal
--   (the Traversal attribute: a climb, a wall run, a ledge) or off the ground (FloorMaterial Air). Check(Captor,
--   TargetModel, Kind) -> ok, reason.
-- * InSafeZone(Character) (ruling R6): the region's Safe flag; inside a part tagged Hostage.SafeTag (point in box); within
--   StationSafeRadius (3D) of a RenseiTicketClerk / RenseiStationGate in workspace; inside a RenseiPlatformTrain's
--   bounding box grown by TrainMargin.
-- * SWITCHED OFF (Task 5 fix, ruling K1: publish safety) until the owner's go-live step (Changelog 2026-10-29) sets
--   Rensei.Hostage.Enabled. Allowed() is Enabled, or else the tests' bypass: RunService:IsStudio() (asked first) AND DataManager.IsNoSave() AND
--   HostageService._TestBypass() (a test swaps it to shut the bypass; it can only make Allowed stricter). Take refuses
--   "disabled" before anything else while not Allowed; Requests.Hostage refuses too. Nothing else starts a session.
-- * Take(Captor, TargetModel) -> ok, reason. The kind is "Bind" for a knocked target, else "Grab". A non-player either
--   side is "not_player" first; then Rensei.Hostage.CheckTake (a Grab: the target's rear arc within GrabRange, else
--   "seen" or "far"; ruling R3: "hasn't noticed you" is the takedowns' rear arc, 4 studs, a clear line). Refused: the
--   next allowed time >= now + RefusedCooldown and LastHostageResult = "<Kind>:<reason>" on the captor's character.
--   Accepted: in the SAME step, no yield, HeldBy on the target and Holding on the captor (one captor per hostage, one
--   hostage per captor), the session made and indexed, its exits connected; then a Bind's Run on its own thread, or (Task
--   7) the GRAB in this same step; true, "started" (a grab whose step fails is released "error": false, "error"). A
--   bind's captor carries HostageBinding = true until the hold (final fix round, review M5: MoverManager hands a binding
--   captor no walk back).
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
--     3. the HOLD, in one step (final fix round, review M3: first the take spot is checked again -- the captor may have
--        turned to a wall during the bind -- and a blocked one ends it "blocked" before the knock is ended): the knock ended at the hostage's own HP, at least MinHealthShare (DownedManager.EndKnock;
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
--   replaced; final fix round, C1: a humanoid in the Dead state counts as dead whatever its Health), "knocked" (the captor knocked; while the pair is led, the hostage knocked: decision 5); then, while the
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
--        counted nor a "teleport" (DownedManager's fix round 3 saw the same echo). (Task 10, Task 6 re-review m2) only a
--        root back at the spot BEFORE the move (within a walk's allowance + RiseSlack of the lead Rebase replaced,
--        S.Lead.EchoOf; fix round 1, m3: a second Rebase inside the grace keeps the earlier spots too) is taken for
--        that echo: put back to the rebased spot, uncounted, with no ray. Any other root gets every check (the wall ray
--        and the teleport break too; a put-back in the window still isn't counted), and the lead never follows an echo,
--        so a Rebase opens no window to pass a wall or go anywhere new. Every server move of a player's character calls
--        DownedManager.MovedOnPurpose, which calls Rebase (Task 6 re-review m7; fix round 1, m4: StationService,
--        RoadService, TravelService and AdminService); a class skill's latch or grab never moves either side of a led
--        pair (Requests.ClassSkill).
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
--     1. S.Over; unindexed; its connections dropped; (Task 11) a live ransom demand voided, its unanswered popups closed;
--     2. the weld let go (DownedManager.Detach: PlatformStand off), then the hostage settled (Settle: at rest, put back
--        after a blink or a clamp fight, its old owner back OWNER_BACK later: fix round I1 / I2), only when
--        this session welded the pair (S.Attached; Task 5 fix, review I1: a Detach of a pair never attached would set
--        every part of the knocked hostage non-massless -- hair, accessories, a weapon -- and PlatformStand off);
--     3. the hostage: its lock given back when the hold locked it (not while knocked: the knock's lock nests on ours and
--        its Recover gives ours back); its Stun stopped; animations stopped; HeldBy, HostageUntil and Struggle cleared;
--        immune for ImmuneAfter (GrabImmuneUntil, server time, and ImmuneUntil). A hostage still knocked whose
--        KnockedUntil has passed is recovered (DownedManager.Recover: its timer found HeldBy and waited), as Grip does:
--        a knocked player is never left stuck (hand-off 3);
--     4. the captor: the lock given back (also for a character already gone: the entry goes, as TakedownService's F7 --
--        final fix round: DownedManager.Lock(C, false) now drops the entry of a character with no Humanoid left, so this
--        holds for both sides; not while knocked, as for the hostage); animations stopped; Holding, HostageUntil and
--        HostageBinding cleared;
--     5. the captor's cooldown (now + Cooldown) and LastHostageResult = "<Kind>:<Outcome>"; (5b, Task 7 fix round 1) a
--        grab that never became Held records attempted_hostage for the captor, witnessed, unless the captor's own
--        Player is gone; (5c, final fix round, C1) THE UNEXPLAINED DEATH: a "died" end of a LED pair (welded, Held or
--        Grabbing) whose hostage is dead always prints one audit line (the session Id, both UserIds, and whether it was
--        charged). No server-side lethal hit can reach a held player (DownedManager.Damage knocks a player at 1 HP
--        instead of killing, and Finish's grip runs only after the release), so every such death is unexplained. It is
--        charged to the captor as killed_hostage (witnessed, unless the captor's Player is gone) only while
--        HostageService.ChargeUnexplainedDeaths is true -- FALSE as shipped (PROPOSAL, for the controller and the
--        owner). WHY OFF: the final fix round's Studio Play measured the two sides. The captor's client, which owns the
--        hostage's assembly (ruling R1), could NOT kill a held stand-in: Humanoid:ChangeState(Dead), Health = 0, and
--        PlatformStand off first then both, all left the server's stand-in at full health, PlatformStanding and held
--        (client_checks.lua CaptorClientKillsHostage keeps that as a guard). But a held player's OWN client killing its
--        own character -- what Roblox's reset does -- DID reach the server (Health 0, Dead, the hold ended "died"). So
--        the only unexplained death seen is the hostage's own, and charging it would let a hostage frame their captor
--        (Mercy -8, Order -5, Crime 90) by resetting. (The review's LastHitAt window wasn't used for the charge either:
--        the captor's own light hits always land on the hostage, so it would open a window for any kill inside it.);
--     6. Notify both ({State = "Free", Outcome, Role}; the captor's with Options, Task 8) and a toast (none for
--        "finished": the grip that follows is no freedom);
--     6b. (final fix round, review I1) a release of a pair that was welded (Held or Grabbing) that leaves the hostage
--        knocked (the "knocked" end: the captor's own light hits, or a friend's front hit, beat them down) opens the
--        harm window with no payout (StartPending(S, true), the cancelled Finish's): a grip by the captor's side that
--        kills them inside it is killed_hostage, so beating a hostage down and pressing B is no deed-free kill. (Residual
--        fix, re-review NB2) never for a "finished" end: Finish records its own kill. (NB1) A re-take by the captor's
--        side marks the target's open windows unpaid at the take and ends them only when the new hold begins
--        (BeginHeld), so an interrupted re-bind keeps the window watching for the kill;
--     7. the Released listeners (S, Outcome), each in a pcall;
--   A bind slower than BindTime + SLOW_PAST, or a release whose steps 1-6 take longer than SLOW_RELEASE (the
--   listeners, which may yield, aren't timed), warns its phase timings once.
-- * EXITS (Start): Players.PlayerRemoving -> _Left(P) ("left"); each session's characters' Humanoid.Died and Destroying
--   and a real owner's CharacterAdded -> "died"; game:BindToClose -> _Shutdown() ("shutdown"). Every other end goes
--   through Watch (Broken) or Free.
-- * Rebase(Character) -> bool (Task 6, pre-flight P6): the led pair that character is either side of has its lead
--   clamp started again from the captor's root's spot now (see THE PAIR POLICED); false when it leads no pair.
-- * THE CAPTOR MENU (Task 8, spec §3). MenuOptions(Captor) -> {{Id, Text, Locked, Why}}, only while that PL is the
--   captor of a Held session (else {}), in this order: Release ("Let them go"), Finish ("Finish them"), Ransom ("Demand
--   ransom"), then (Task 11) TurnIn ("Turn them in") while it is offered. Every "Hostage" Notify to the captor carries
--   Options = MenuOptions (Grabbing and Free: {}), so HostageUI (Task 12) draws the wheel from it; it is sent at Held
--   and whenever an option's lock changes (Task 11). Menu(Captor, Choice, Arg) -> bool (true when the choice acted; Requests.Hostage ignores
--   it): every choice re-checks that the caller is the captor of a Held session (a hostage, a grab, a released or
--   unknown session, a non-string or unknown choice: ignored). Arg is unused by Release, Finish and TurnIn; Ransom's is
--   the tier index, range-checked (review M7, menu half: an integer inside RansomTiers, else refused).
--   (Task 11) Ransom is open while Held with another member of the hostage's party present here (not the captor) and no
--   demand made yet this session; it carries Tiers = Rensei.Hostage.RansomTiers(the hostage's level). Locked: "They
--   have no party here", "Waiting for an answer" (a live demand), "Already asked" (one demand per session, pre-flight
--   P14). TurnIn ("Turn them in") is listed only while it is offered (see THE TURN-IN). The captor is sent the Options
--   again (a Held notify) whenever they change (Tick compares them every WatchTick).
--     - "Release": Release(S, "released") at once; what it earns waits (fix round 1, controller ruling I1): a RELEASE
--       WINDOW of Hostage.ReleaseGrace (30 s; HostageService._ReleaseGrace shortens it in tests, read only while
--       SeamOpen). If the released player is knocked (a landed hit, ProgressionService.HitListeners) or gripped by the
--       ex-captor or their party inside it, nothing is paid (final fix round: a gun shot that knocks them counts too --
--       WeaponManager.Fire calls HostageService.WindowHit, the melee hits' OnHit, since guns record no hit); a grip of theirs that finishes (DownedManager.Listeners)
--       records killed_hostage, as Finish would; a harmed window whose hostage is still knocked at its end stays open,
--       paying nothing, until that knock ends (fix round 3, re-review N1). Someone else hurting them changes nothing. Taken again by the captor's
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
--       captor's side inside it is still killed_hostage). (Final fix round, parked T8 n2) the knock given back also
--       clears SecondWindActive, so the hostage's next knock doesn't recover at Second Wind's share. The grip's own
--       marks (Gripping / GrippedBy) keep every take, grip, carry and takedown off both of them while it runs (Task 4's
--       exclusion, both ways).
-- * THE HUMAN SHIELD AND THE RESCUE (Task 9, spec §3 / §4). One rule decides "in front" for all three: the other
--   character's root within Hostage.ShieldArc of the captor root's look (Hostage.InFront), and only for the captor of a
--   HELD session (HeldSessionOf: the Holding attribute, PlayerOf -- never an NPC's -- and that PL's own session), never
--   for an attacker who is either of the pair. The server decides who a hit lands on; no client says.
--     - Shield(Attacker, Victim) -> Model, Absorbed: the DamageManager function asks it first, after its IFramed checks
--       (enemy vs enemy, townsfolk, the squad token, all still judged against the captor) and before any victim state is
--       read. A hit from the front lands on the hostage (alive and not knocked) instead; the first such redirect of a
--       hold records used_human_shield (witnessed, on its own thread), once per hold (S.Shielded). DamageManager
--       treats a hit it redirected as damage only on the welded hostage (no hitstun, knockback or flinch: the pair's
--       physics is the captor client's, and the held pose stays). A lethal one knocks the hostage, and Broken ends the
--       hold "knocked" (decision 5).
--     - ONE SWING, ONE HIT (fix round 1, review I4): a front box holds both of the pair, so one swing reaches the hostage
--       directly and again through the captor. Each landing on a hostage is noted (StruckBy: the attacker and its
--       AttackRunner.StrikeId, or, for an attack with none, SAME_SWING seconds); the second of one swing lands nothing
--       (Shield's Absorbed, or DirectHit false for a direct hit on a HeldBy victim): DamageManager returns "IFramed".
--     - HitVictim(Attacker, Victim) (fix round 1, I5 / concern 3): ProgressionService.RecordHit asks it, so a hit the
--       shield redirected reaches every HitListener as a hit on the hostage (the callers name the captor): the Task 8
--       release window sees a knock through a shield; combat marks and training name the one hit.
--     - LineBlocked(Rig, Target) -> bool: CombatDirector.CanStrike is false while it is true, so an NPC in front holds
--       its attack; (fix round 1, I3) EnemyService circles the token holder round to the captor's flank instead
--       (spec §3: "they circle for an angle"), and its attack there is a rescue.
--     - Rescue(Attacker, Victim, Result) (OnRescueHit, a ProgressionService.HitListeners entry; the melee pipeline --
--       HitboxManager.Hitbox / Sweep, AlchemyService's hits -- calls RecordHit with the DamageManager function's result,
--       after it, so the listener sees a hit that landed; fix round 1, I2: WeaponManager.Fire calls Rescue itself for a
--       shot, guns recording no hit): "Hit" on a captor by anyone but the pair, from outside the front arc -> Release
--       "rescued"; "Parried" or "PerfectParried" of the captor's own attack by anyone but the hostage -> Release
--       "parried". A front hit is never a rescue: it is heard on the hostage (HitVictim), and the same InFront answers
--       no. A knocked captor is already "knocked" (Broken). A GUARD (GuardFaction, PROPOSAL: a law-faction NPC as the
--       takedowns name one -- Takedown.IsLawFaction of its Faction, else its perception faction -- never a townsperson;
--       none spawn yet) that rescues raises the captor's Heat ONCE by took_hostage's Crime through Rensei.Heat.Raised
--       (heard by the guard's faction where the captor stands) and HeatService.Add; no deed is recorded (fix round 1,
--       ruling I1: no Count, Conduct or cap slot).
-- * MONEY BETWEEN SAVES (Task 11, rulings R9-R11; the owner, 2026-10-27: "one server-side capped transfer ($5,000
--   max), refund on failure, no save-layer changes"). Nothing here touches the save layer: only Data.Money, through
--   ProgressionService's own SpendMoney / GrantMoney.
--     - The money adapter (module functions, so a test can stub them): _Spend(PL, n) / _Grant(PL, n) -> bool. A real
--       player: ProgressionService.SpendMoney / GrantMoney. A stand-in (registered, seam open): its Data.Money with the
--       same all-or-nothing rule (a finite n above 0, floored; a spend only when the money covers it).
--     - Transfer(Payer, Captor, Amount, DemandId) -> ok, NetOrWhy, in ONE server step with no yield (Task 1(d): SpendMoney
--       and GrantMoney don't yield; TransferNoYield pins it), on two profiles loaded in this server: "amount" unless a
--       whole number from RansomMin to RansomCap; "self" when Payer is Captor; "gone" unless both are present with a
--       profile; "travelling" while either real player is mid-teleport (FlowTeleport.Busy / InGroup: their saves may be
--       released; an error asking is "travelling" too); "afford" when the debit fails; then the credit of
--       Hostage.Net(Amount), and if it fails (or anything after the debit throws: "error", fix round 1 m1) the payer is
--       refunded the whole Amount in the same step ("gone"). Every call
--       prints ONE audit line (pre-flight P14): the demand Id, payer and captor UserIds, amount, net and the result.
--     - THE DEMAND, Menu(Captor, "Ransom", TierIndex): needs Ransom open (above) and TierIndex an integer within
--       #RansomTiers(level). S.Demand = {Id (a GUID), Amount (that tier), Until (os.clock() + RansomWait), Asked
--       ({[Key] = {PL, Popup, Answered}}), Paid = false}; S.Asked = true (one per session). Each asked member: a real
--       player gets DialogueService.Ask(Member, their own character, the captor's name, "<Captor> holds <Hostage>. Pay
--       $<n>?", {"Pay", "Refuse"}), whose answer runs Answer; a stand-in (tests) is answered through
--       HostageService._Answer(S, PL, Index) (read only while SeamOpen), the same Answer. (Fix round 1, review I2) a
--       real member is asked only while free (present, a live current character, neither InCombat nor CombatMode, no
--       DialogueService conversation open): one who isn't is asked later by Tick, so no conversation of theirs is
--       clobbered; each popup is on their CURRENT character.
--     - Answer(S, Member, Index): nothing when stale (S.Over, no demand, another demand's Id, already paid), when Member
--       wasn't asked (pre-flight P14) or has already answered. (Fix round 1, review I2) a nil answer -- a popup a fight,
--       another conversation (DialogueService.Open / Say answer a replaced popup with nil, review I1), a respawn or
--       leaving closed -- is "not now": the popup is marked gone and the member stays unanswered. Pay (1): Paid = true
--       FIRST, then Transfer (in a pcall: one that throws ends the demand unpaid, never left paid, review m1); on
--       failure Paid = false, the payer told why, and counted as a refusal; on success Release(S, "ransomed") FIRST, then
--       paid_ransom (payer) and took_ransom (captor, witnessed) each in its own pcall (P14: a throwing Record never
--       leaves a paid hostage held). Refuse (2): a refusal. Everyone refused: the captor is told "Nobody will pay." and
--       the demand ends.
--     - Tick: at Until with nothing paid, the captor is told "Nobody paid." and the demand ends; the hold goes on. Else
--       each real member unanswered with no popup up is asked (again) once free.
--     - A demand that ends (refused, timed out) or is voided (Release step 1) closes every popup still unanswered
--       (DialogueService.Close; P14).
-- * THE TURN-IN (Task 11, ruling R7, pre-flight P12 / P13). Desks() -> {Model}: the models in workspace with a DialogueId
--   whose definition (Rensei.Dialogues) has a PayFine choice, each with that choice's Action.Jurisdiction (P12: the
--   desk's own law, "State" for Brask). (Final fix round, review I4) INDEXED, never scanned per tick: while Allowed() at
--   Start, one workspace scan then and workspace.DescendantAdded after it (a Model checked once, deferred a frame, as
--   DialogueService attaches its talk prompts); every Hostage.DeskRefresh seconds the index only drops desks no longer
--   in workspace. _RefreshDesks() rebuilds it by a scan now (a test's temp desk, P23). TurnIn is offered while Held, the hostage a real player, the
--   captor's root within DeskRange of a desk's root and HeatService.Wanted(hostage, that desk's J) >= 1 (the region's
--   own jurisdiction isn't asked, P12). Menu(Captor, "TurnIn") re-checks all of that, then, with no yield: the fine --
--   Wanted <= FineMaxWanted: HeatService.Fine (its own rule: the cost, the Heat cleared); Wanted 3+ (P13, the spec
--   literally): Heat.FinePerLevel x Data.Level through SpendMoney when it can be paid; the fine PAID is the hostage's
--   Data.Money before less after (P12, never a formula). (Final fix round, review I2, the controller's conservative
--   default) NOTHING PAID -> REFUSED: no Heat cleared, no release, no bounty, no deed; the captor is told "They can't
--   pay the fine." and the hold goes on (a broke fugitive's Heat is no free wipe, at any Wanted level; the owner may
--   loosen it). Paid -> HeatService.Clear when any Heat is left; Release(S, "turned_in"); the bounty
--   Hostage.Bounty(paid) granted to the captor (_Grant); turned_in_fugitive recorded for the captor; the hostage told.
-- * Free(PL, Outcome) -> bool: that PL's session (either side) released. SessionOf(PL) -> S | nil. Forget(PL, Only):
--   the PL's cooldown (NextAt), immunity (ImmuneUntil), re-take times (Taken) and (Task 7) struggle messages and rate
--   window (Sends) forgotten; Only (a set, e.g. {ImmuneUntil = true}) forgets just those. Released: listeners (S, Outcome).
-- * (Final fix round, review M8) A PL WHO LEAVES (_Left): its Sends and Presses go at once; its NextAt, ImmuneUntil and
--   Taken entries go once they have run out (the cooldown, immunity and re-take rules still hold for a quick rejoin):
--   the ones already out now, the rest by one delayed prune at the latest of their ends, unless the UserId is back in
--   the server by then. _Prune(PL, Now) runs that prune as of Now and _Kept(PL) says which tables hold the PL (tests
--   only, while SeamOpen).
--
-- Attributes. Captor's character: Holding (the hostage's name), HostageUntil (server time, while Held), HostageBinding
-- (final fix round, M5: true from a bind's take until its hold or release),
-- LastHostageResult ("<Kind>:<reason or outcome>"; tests and logs), HostageClamped (Task 6: times the lead clamp put the
-- pair back; tests and logs). Hostage's character: HeldBy (the captor's name),
-- HostageUntil, Struggle (Task 7), GrabImmuneUntil (server time). Read: Knocked, KnockedUntil, GrippedBy, Gripping,
-- CarriedBy, Carrying, TakenDownBy, TakingDown, Traversal, SecondWindActive, EnemyType, TownsfolkId, DialogueId,
-- Faction (Task 9: a rescuing NPC's, GuardFaction).
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
local Deeds = require(Rensei.Deeds) -- (Task 9 fix round 1: a guard's Heat is took_hostage's Crime)
local Takedown = require(Rensei.Takedown) -- (Task 9 fix round 1: IsLawFaction, a guard's faction)
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
-- (final fix round, C1; PROPOSAL, for the controller and the owner) whether a led hostage's unexplained death (no
-- server-side hit) is charged to the captor as killed_hostage. False: only audited, since the Play measurement found
-- the hostage's own client is what can cause one (a reset), never the captor's (see Release step 5c in the header)
HostageService.ChargeUnexplainedDeaths = false

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
-- (fix round 3, re-review N1) PROPOSAL: the longest a harmed window stays open past its end while the hostage is knocked
local KNOCK_WAIT = 120
-- (final fix round, review M3) PROPOSAL: studs the take spot is checked ahead of the captor's root: Hostage.Offset's 1.5
-- plus half the hostage root's 1-stud depth
local SPOT_REACH = 2.0

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
local StartPending -- (final fix round, review I1: Release opens a knocked hostage's window; defined with the windows)
local VoidDemand, DemandTick, OptionsTick -- (Task 11; defined with the ransom, below)
local SpotClear -- (final fix round, review M3; defined with the led pair's rays, below)

-- ===== the player-like helpers (the only places that tell a Player from a stand-in) =====
local function Hum(M) return M and M:FindFirstChildOfClass("Humanoid") end
local function Root(M) return M and M:FindFirstChild("HumanoidRootPart") end
local function Torso(M) return M:FindFirstChild("Torso") or M:FindFirstChild("UpperTorso") or Root(M) end
local function Alive(M) local H = Hum(M) return H ~= nil and M.Parent ~= nil and H.Health > 0 end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function IsPlayer(PL) return typeof(PL) == "Instance" and PL:IsA("Player") end
-- (final fix round, C1) dead on the server: no Health left, or the humanoid in the Dead state (a state its owning client
-- may have set, whatever the Health reads)
local function DeadNow(M)
	local H = Hum(M)
	if not H then return false end
	local Ok, State = pcall(function() return H:GetState() end)
	return H.Health <= 0 or (Ok and State == Enum.HumanoidStateType.Dead)
end
-- a PL's UserId for an audit line ("?" when it can't be read)
local function Uid(PL)
	local Ok, U = pcall(function() return PL.UserId end)
	return Ok and tostring(U) or "?"
end
-- (final fix round, review M4) a guard already up -- WCS's Blocking and PerfectParry statuses -- dropped, as
-- DownedManager.Knock drops them at a knock
local function DropGuard(M)
	local WC = M and M.Parent and WCS.Character.GetCharacterFromInstance(M)
	if not WC then return end
	for _, X in ipairs(WC:GetAllActiveStatusEffects()) do
		if X.Name == "Blocking" or X.Name == "PerfectParry" then pcall(function() X:Stop() end) end
	end
end

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

local function TargetFree(T, Kind)
	if not Alive(T) then return false end
	for _, A in ipairs({"GrippedBy", "CarriedBy", "TakenDownBy", "HeldBy", "Holding", "Gripping", "Carrying", "TakingDown"}) do
		if T:GetAttribute(A) then return false end
	end
	if T:GetAttribute("Traversal") == "Swim" then return false end
	-- (final fix round, review M6, PROPOSAL) a grab takes a target standing on the ground: none mid-traversal (a climb, a
	-- wall run, a ledge: any Traversal) and none in the air, so nobody is pulled down off a ledge and welded mid-move
	if Kind == "Grab" then
		if T:GetAttribute("Traversal") ~= nil then return false end
		local H = Hum(T)
		if not H or H.FloorMaterial == Enum.Material.Air then return false end
	end
	return true
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
	Ctx.TargetFree = TargetFree(TargetModel, Kind)
	Ctx.TargetKnocked = DownedManager.IsKnocked(TargetModel)
	Ctx.Range = (Kind == "Bind" and Hostage.BindRange or Hostage.GrabRange) + Hostage.RangeSlack
	local CR, TR = Root(C), Root(TargetModel)
	if CR and TR then
		local D = CR.Position - TR.Position
		Ctx.Dist, Ctx.Height = Flat(D).Magnitude, D.Y
		Ctx.Behind = Hostage.Behind(TR.CFrame.LookVector, D, Hostage.AngleSlack)
		ClearRays.FilterDescendantsInstances = {C, TargetModel}
		local A, B = Torso(C).Position, Torso(TargetModel).Position
		-- (final fix round, review M3) and the spot the weld will put the hostage on is on the captor's side of any wall
		Ctx.Clear = workspace:Raycast(A, B - A, ClearRays) == nil and SpotClear(C, TargetModel)
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

-- (Task 11) the captor's options as one string: Tick sends them again when it changes
local function OptionsKey(O)
	local Bits = {}
	for _, X in ipairs(O or {}) do table.insert(Bits, tostring(X.Id) .. ":" .. tostring(X.Locked) .. ":" .. tostring(X.Why)) end
	return table.concat(Bits, "|")
end

-- a welded pair being led: Held, or (Task 7) Grabbing (pre-flight P5). (Final fix round: above Release, which reads it)
local function Led(S)
	return S.Attached == true and (S.State == "Held" or S.State == "Grabbing")
end

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
	-- (final fix round, C1) read before anything is let go: a led pair's hostage dead with no server-side lethal hit
	-- (none can reach a held player: see step 5c in the header) -- the captor's client, which owns its assembly
	local ClientKill = Outcome == "died" and Led(S) and DeadNow(S.HC)
	-- (final fix round, review I1) a pair that was welded: its knocked hostage gets the harm window (step 6b)
	local WasLed = S.Attached == true
	-- 1. over, unindexed, its connections dropped
	S.Over = true
	S.Outcome = Outcome
	if ByCaptor[Key(S.Captor)] == S then ByCaptor[Key(S.Captor)] = nil end
	if ByHostage[Key(S.Hostage)] == S then ByHostage[Key(S.Hostage)] = nil end
	Step("dropping the connections", function()
		for _, Conn in ipairs(S.Conns) do Conn:Disconnect() end
		table.clear(S.Conns)
	end)
	-- 1b. (Task 11) a live ransom demand of this session voided, its unanswered popups closed (before anything here can
	-- yield; Answer refuses an over session anyway)
	if S.Demand then Step("voiding the ransom demand", VoidDemand, S) end
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
		CC:SetAttribute("HostageBinding", nil) -- (final fix round, M5)
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
	-- 5c. (final fix round, C1) the unexplained death: see the header
	if ClientKill then
		local Charge = HostageService.ChargeUnexplainedDeaths == true
		print(("HostageService: AUDIT a held hostage died with no server-side hit (%s): session=%s captor=%s hostage=%s "
			.. "kind=%s state=%s"):format(Charge and "charged to the captor as killed_hostage" or "not charged",
			tostring(S.Id), Uid(S.Captor), Uid(S.Hostage), tostring(S.Kind), tostring(S.State)))
		if Charge and IsPlayer(S.Captor) and S.Captor.Parent == Players then
			Step("charging the death to the captor", Record, S.Captor, "killed_hostage", {Witness = true})
		end
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
	-- 6b. (final fix round, review I1) a welded pair's hostage left knocked: the harm window, paying nothing. (Residual
	-- fix, re-review NB2) never for "finished": MenuFinish records its own kill, and a hostage already knocked when it
	-- released (a hit in the same step) would otherwise be charged twice
	if WasLed and Outcome ~= "finished" then
		Step("opening the knocked hostage's window", function()
			if HC.Parent and Alive(HC) and DownedManager.IsKnocked(HC) then StartPending(S, true) end
		end)
	end
	local R6 = os.clock() -- (steps 1-6: the listeners below may yield, so they aren't timed)
	-- 7. the listeners
	for _, Fn in ipairs(HostageService.Released) do Step("a Released listener", Fn, S, Outcome) end
	-- phase timings of a slow bind or a slow release
	local Now = os.clock()
	if (S.State == "Binding" and Now - S.T0 > Hostage.BindTime + SLOW_PAST) or R6 - R0 > SLOW_RELEASE then
		local function At(X) return X and ("%.2f"):format(X - S.T0) or "-" end
		warn(("HostageService: a slow hold (%s, %s): take 0, bind start %s, held %s, release start %s, release done %s s"):format(
			S.Kind, tostring(Outcome), At(S.BindStarted), At(S.HeldAt), At(R0), At(Now)))
	end
	return true
end

-- ===== the led pair, policed (Task 6, ruling R1: see THE PAIR POLICED in the header; Led is above Release) =====
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

-- (final fix round, review M3) the take spot: no world geometry from the captor's root SPOT_REACH studs along
-- Hostage.Offset (where the weld puts the hostage), so a take never snaps the hostage through a thin wall
function SpotClear(CC, HC)
	local CR = Root(CC)
	if not CR then return false end
	local Ahead = (CR.CFrame * Hostage.Offset).Position - CR.Position
	if Ahead.Magnitude < 1e-3 then return true end
	return WorldHit({CC = CC, HC = HC}, CR.Position, Ahead.Unit * SPOT_REACH, false) == nil
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
	-- (Task 10, Task 6 re-review m2) the rebase's echo is only the root back at the spot BEFORE the server's move (the
	-- owning client's stale copy of it: within a walk's allowance of the lead the move replaced, L.EchoOf): put back to
	-- the rebased spot, uncounted, with no ray. Any other root gets every check below, the wall ray included, so a
	-- Rebase never opens a window to walk through a wall or anywhere new, however often a server move (a gate's
	-- Touched, say) calls it. (Not D > TeleportBreak alone: the echo of a short or a vertical move -- a pair lifted onto
	-- a ledge, pushed back from a gate -- is under TeleportBreak and may lie through the floor or wall it was moved past.)
	-- (fix round 1, review m3) L.EchoOf lists every spot a move replaced inside this grace (a second Rebase keeps the
	-- first's), so the stale echo of the ORIGINAL spot is still an echo
	if Echo and Len >= STILL then
		for _, Was in ipairs(L.EchoOf or {}) do
			if (Pos - Was.Pos).Magnitude <= Hostage.LeadAllowance(Now - Was.T) + Hostage.RiseSlack then
				PutBack(S, CR, L, Now, true)
				return nil
			end
		end
	end
	-- (Task 7, m1) the path ray clamped before it is cast: a huge move is checked along its first MAX_RAY studs
	local Ray = Len > MAX_RAY and Moved * (MAX_RAY / Len) or Moved
	-- a blink: too far, or through world geometry (a wall, a floor). It ends; Release puts the hostage back (I1).
	if D > Hostage.TeleportBreak or (Len >= STILL and WorldHit(S, L.Pos, Ray, false)) then
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
		S.Lead = {Pos = Pos, CF = CR.CFrame, Y = Y, T = Now, Rebased = L.Rebased, EchoOf = L.EchoOf,
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
	Step("dropping the captor's guard", DropGuard, S.CC) -- (final fix round, review M4: no hold entered guarding)
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
			local Old = S.Lead -- (Task 10, m2) the lead the move replaced: where the client's stale echo would be
			S.Lead = NewLead(CR)
			S.Lead.Rebased = os.clock()
			-- (fix round 1, review m3) and the spots earlier moves replaced while their grace is still open
			local Echoes = {}
			if Old then
				table.insert(Echoes, {Pos = Old.Pos, T = Old.T})
				if Old.Rebased and S.Lead.Rebased - Old.Rebased < REBASE_GRACE then
					for _, E in ipairs(Old.EchoOf or {}) do table.insert(Echoes, E) end
				end
			end
			S.Lead.EchoOf = Echoes
			return true
		end
	end
	return false
end

-- the session's ends, a test seam: see the header
function HostageService.Broken(S)
	if not Present(S.Captor) or not Present(S.Hostage) then return "left" end
	if not Alive(S.CC) or not Alive(S.HC) or DeadNow(S.CC) or DeadNow(S.HC) or Char(S.Captor) ~= S.CC
		or Char(S.Hostage) ~= S.HC then
		return "died" -- (final fix round, C1: a Dead state counts, whatever the Health)
	end
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
	-- (Task 11) a demand past its Until ends; the captor's options sent again when they changed
	if S.State == "Held" and not S.Over then
		if S.Demand then Step("the ransom demand's clock", DemandTick, S) end
		if not S.Over then Step("the captor's options", OptionsTick, S) end
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

-- (final fix round, review M8) K's cooldown, immunity and re-take times that have run out by Now dropped; returns the
-- os.clock() the last one still kept runs out, or nil when none is left
local function Prune(K, Now)
	local Last = nil
	local function Keep(T) Last = math.max(Last or T, T) end
	if NextAt[K] and NextAt[K] <= Now then NextAt[K] = nil elseif NextAt[K] then Keep(NextAt[K]) end
	if ImmuneUntil[K] and ImmuneUntil[K] <= Now then ImmuneUntil[K] = nil elseif ImmuneUntil[K] then Keep(ImmuneUntil[K]) end
	if Taken[K] then
		local Out = {}
		for _, T in ipairs(Taken[K]) do
			if Now - T < Hostage.RetakeWindow then table.insert(Out, T) Keep(T + Hostage.RetakeWindow) end
		end
		Taken[K] = #Out > 0 and Out or nil
	end
	return Last
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
-- hostage locked, stunned (WCS) for StunTime, its tools put away, (final fix round, review M4) a guard it already had
-- up (the Blocking / PerfectParry statuses) dropped, as Knock does, and the captor's too in Pair; the weld, the captor
-- at LeadSpeed and the lead
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
	Step("dropping the hostage's guard", DropGuard, HC) -- (final fix round, review M4: as Knock does)
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
	-- (final fix round residual, NB1) the captor side's windows this take marked unpaid end now that the hold has begun
	for _, P in ipairs(S.Retaken or {}) do EndPending(P) end
	S.Retaken = nil
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
	local Options = HostageService.MenuOptions(S.Captor)
	S.OptionsKey = OptionsKey(Options) -- (Task 11: Tick sends them again when they change)
	for _, X in ipairs({{S.Captor, "Captor"}, {S.Hostage, "Hostage"}}) do
		Notify(X[1], "Hostage", {State = "Held", Role = X[2], Captor = S.Captor.Name, Hostage = S.Hostage.Name, Until = UntilServer,
			Options = X[2] == "Captor" and Options or nil})
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
	-- (final fix round, review M3) the captor may have turned to a wall during the bind: the spot checked again, before
	-- the knock is ended (a blocked hold leaves the hostage as the bind found them)
	if not SpotClear(S.CC, HC) then Release(S, "blocked") return end
	if not DownedManager.EndKnock(HC, Hostage.MinHealthShare) then error("the knock couldn't be ended") end
	S.CC:SetAttribute("HostageBinding", nil) -- (final fix round, M5: the bind is over; the lead's walk from here)
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
	-- (ruling K1: switched off until the owner's go-live step, Changelog 2026-10-29)
	if not HostageService.Allowed() then return false, "disabled" end
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
	if Kind == "Bind" then CC:SetAttribute("HostageBinding", true) end -- (final fix round, M5: cleared at the hold)
	local S = {Id = HttpService:GenerateGUID(false), Captor = Captor, Hostage = Target, CC = CC, HC = TargetModel,
		Kind = Kind, State = "Binding", T0 = os.clock(), Until = nil, Struggle = 0, Over = false, Conns = {}, Saved = {}}
	ByCaptor[Key(Captor)] = S
	ByHostage[Key(Target)] = S
	-- (Task 8 fix round 1) taken again by the captor's side inside a release window: that window pays nothing from here
	-- (the new hold has its own deeds). (Final fix round residual, re-review NB1) it is only marked unpaid now, and ENDS
	-- when the new hold begins (BeginHeld): a re-take that never becomes a hold (a bind interrupted, a grab shoved off)
	-- leaves it watching, so a grip by the captor's side after it is still killed_hostage
	S.Retaken = {}
	for P in pairs(Pending) do
		if not P.Over and P.HC == TargetModel and CaptorSide(P, CC) then
			P.NoPay = true
			table.insert(S.Retaken, P)
		end
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

-- ===== money between saves (Task 11, rulings R9-R11; see MONEY BETWEEN SAVES in the header) =====
-- the owner (2026-10-27): "one server-side capped transfer ($5,000 max), refund on failure, no save-layer changes"
local function MoneyStep(N)
	return type(N) == "number" and N == N and N > 0 and N < math.huge
end

-- the money adapter: a real player through ProgressionService (all or nothing), a registered stand-in through its Data
function HostageService._Spend(PL, N)
	if IsPlayer(PL) then return require(ServerScriptService.ProgressionService).SpendMoney(PL, N) == true end
	if not IsPL(PL) or type(PL.Data) ~= "table" or not MoneyStep(N) then return false end
	N = math.floor(N)
	if (tonumber(PL.Data.Money) or 0) < N then return false end
	PL.Data.Money -= N
	return true
end
function HostageService._Grant(PL, N)
	if IsPlayer(PL) then return require(ServerScriptService.ProgressionService).GrantMoney(PL, N) == true end
	if not IsPL(PL) or type(PL.Data) ~= "table" or not MoneyStep(N) then return false end
	PL.Data.Money = (tonumber(PL.Data.Money) or 0) + math.floor(N)
	return true
end

-- one money step through the adapter (module fields, so a test's stub is seen), in a pcall: true when it went through.
-- A step that errored after the money had already moved (a Sync failing after the debit) counts as done, so a refund
-- or a credit is never skipped for it.
local function Apply(Fn, PL, N)
	local D = DataOf(PL)
	local Before = type(D) == "table" and tonumber(D.Money) or nil
	local Ok, Done = pcall(Fn, PL, N)
	if Ok then return Done == true end
	warn("HostageService: a money step failed:", Done)
	local After = type(D) == "table" and tonumber(D.Money) or nil
	return Before ~= nil and After ~= nil and After ~= Before
end

-- a real player mid-teleport (FlowTeleport.Busy / InGroup: their save may be released); fails closed on an error
local function Moving(PL)
	if not IsPlayer(PL) then return false end
	local FT = ServerScriptService:FindFirstChild("FlowTeleport")
	if not FT then return false end -- (no teleports in this place)
	local Ok, Busy = pcall(function()
		local M = require(FT)
		return M.Busy(PL) or M.InGroup(PL)
	end)
	return not Ok or Busy == true
end

local function DoTransfer(Payer, Captor, Amount)
	if type(Amount) ~= "number" or Amount ~= math.floor(Amount) or Amount < Hostage.RansomMin or Amount > Hostage.RansomCap then
		return false, "amount"
	end
	if Payer ~= nil and Payer == Captor then return false, "self" end
	if not (IsPL(Payer) and IsPL(Captor)) or not (Present(Payer) and Present(Captor))
		or not (DataOf(Payer) and DataOf(Captor)) then
		return false, "gone"
	end
	if Moving(Payer) or Moving(Captor) then return false, "travelling" end
	if not Apply(HostageService._Spend, Payer, Amount) then return false, "afford" end
	-- (fix round 1, review m1) the debit happened: whatever follows, the payer is refunded unless the credit went through
	local CreditOk, Net = pcall(function()
		local N = Hostage.Net(Amount)
		return Apply(HostageService._Grant, Captor, N) and N or nil
	end)
	if CreditOk and Net then return true, Net end
	if not CreditOk then warn("HostageService: the ransom credit threw:", Net) end
	if not Apply(HostageService._Grant, Payer, Amount) then -- refunded in the same step
		warn(("HostageService: a ransom REFUND FAILED: payer %s, $%d"):format(tostring(Payer.UserId), Amount))
	end
	return false, CreditOk and "gone" or "error"
end

-- (hostages Task 11, rulings R9-R11) one server step on two loaded profiles: debit, then credit, refund on failure. No
-- yield. One audit line per call (pre-flight P14).
function HostageService.Transfer(Payer, Captor, Amount, DemandId)
	local Ok, NetOrWhy = DoTransfer(Payer, Captor, Amount)
	print(("HostageService: ransom transfer demand=%s payer=%s captor=%s amount=%s net=%s result=%s"):format(
		tostring(DemandId), Uid(Payer), Uid(Captor), tostring(Amount), Ok and tostring(NetOrWhy) or "0",
		Ok and "ok" or tostring(NetOrWhy)))
	return Ok, NetOrWhy
end

-- the hostage's party members present here who could pay: never the hostage, never the captor
local function Payers(S)
	local Out = {}
	for _, X in ipairs(HostageService.PartyOf(S.Hostage)) do
		if X ~= S.Hostage and X ~= S.Captor and IsPL(X) and Present(X) then table.insert(Out, X) end
	end
	return Out
end

-- why Ransom is locked, or nil (one demand per session, pre-flight P14)
local function RansomLock(S)
	if S.Demand then return "Waiting for an answer" end -- PROPOSAL (text)
	if S.Asked then return "Already asked" end
	if #Payers(S) == 0 then return "They have no party here" end
	return nil
end

-- the payer's toast when the transfer refused (PROPOSAL texts)
local TRANSFER_WHY = {
	afford = "You can't pay that.",
	travelling = "Not while travelling.",
}

-- the demand ends (refused by all, timed out, a transfer that threw) or is voided (Release): gone first, so the answers
-- its closing popups send are stale, then every popup still open closed (pre-flight P14). (Fix round 1, review I1:
-- DialogueService.Open / Say answer a replaced popup with nil, so E.Popup is true only for a live ransom popup.)
local function EndDemand(S)
	local D = S.Demand
	if not D then return end
	S.Demand = nil
	local DS = require(ServerScriptService.DialogueService)
	for _, E in pairs(D.Asked) do
		if E.Popup then
			E.Popup = false
			if IsPlayer(E.PL) then Step("closing a ransom popup", DS.Close, E.PL) end
		end
	end
end
VoidDemand = EndDemand

-- a member's answer (the popup's, or a test's through _Answer): see the header
local function Answer(S, Id, Member, Index)
	local D = S.Demand
	if S.Over or not D or Id == nil or D.Id ~= Id or D.Paid then return false end
	local E = Member ~= nil and Member.UserId ~= nil and D.Asked[Key(Member)] or nil
	if not E or E.PL ~= Member or E.Answered then return false end -- (only an asked member, once: P14)
	-- (fix round 1, review I2) only Pay (1) and Refuse (2) answer; nil (a popup closed by a fight, another conversation,
	-- a respawn, leaving) is "not now", and the member is asked again once free (DemandTick)
	if Index ~= 1 and Index ~= 2 then return false end
	E.Answered = true
	if Index == 1 then
		D.Paid = true -- (first: a second answer in the same frame finds it paid)
		local CallOk, Ok, NetOrWhy = pcall(HostageService.Transfer, Member, S.Captor, D.Amount, D.Id)
		if not CallOk then
			-- (fix round 1, review m1) never left "paid": the demand ends unpaid (the money steps refund themselves)
			warn("HostageService: the ransom transfer threw; the demand ends unpaid:", Ok)
			D.Paid = false
			Toast(Member, "The ransom didn't go through.") -- PROPOSAL (text)
			EndDemand(S)
			return false
		end
		if Ok then
			Release(S, "ransomed") -- (first: a throwing Record can't leave a paid hostage held, P14)
			Step("recording paid_ransom", Record, Member, "paid_ransom", {})
			Step("recording took_ransom", Record, S.Captor, "took_ransom", {Witness = true})
			Toast(Member, ("You paid $%d. %s is free."):format(D.Amount, S.Hostage.DisplayName or S.Hostage.Name)) -- PROPOSAL (text)
			Toast(S.Captor, ("Ransom paid: $%d."):format(NetOrWhy)) -- PROPOSAL (text)
			return true
		end
		D.Paid = false
		Toast(Member, TRANSFER_WHY[NetOrWhy] or "The ransom didn't go through.") -- PROPOSAL (text)
	end
	-- a refusal (Refuse, a failed payment): when nobody is left to answer, the demand ends
	for _, X in pairs(D.Asked) do
		if not X.Answered then return false end
	end
	Toast(S.Captor, "Nobody will pay.")
	EndDemand(S)
	return false
end

-- (tests only, read while SeamOpen) a stand-in's answer to the live demand: the same Answer the popup's answer runs
function HostageService._Answer(S, PL, Index)
	if not SeamOpen() or type(S) ~= "table" then return false end
	return Answer(S, S.Demand and S.Demand.Id, PL, Index)
end

-- (fix round 1, review I2) a real member free for a popup now: present, a live current character, not fighting
-- (DialogueService's own test: InCombat or CombatMode) and no conversation open
local function CanAsk(M)
	if not IsPlayer(M) or M.Parent ~= Players then return false end
	local C = Char(M)
	if not (C and Alive(C)) then return false end
	if C:GetAttribute("InCombat") == true or C:GetAttribute("CombatMode") == true then return false end
	local Ok, Open = pcall(function() return require(ServerScriptService.DialogueService).IsOpen(M) end)
	return Ok and Open == false
end

-- the popup for one asked member, on their CURRENT character (DialogueService's range check holds after a respawn).
-- Its nil answer only marks the popup gone; an answer of an older popup of theirs changes nothing.
local function AskMember(S, D, E)
	local M = E.PL
	E.Asks = (E.Asks or 0) + 1
	local N = E.Asks
	E.Popup = true
	local Ok, Err = pcall(function()
		require(ServerScriptService.DialogueService).Ask(M, Char(M), D.Speaker, D.Text, {"Pay", "Refuse"}, function(Index)
			if E.Asks ~= N then return end
			E.Popup = false
			if Index == nil then return end -- "not now": asked again once free
			Answer(S, D.Id, M, Index)
		end)
	end)
	if not Ok then
		warn("HostageService: couldn't ask", M.Name, Err)
		E.Popup = false
	end
end

-- Tick: a demand past its Until, nothing paid, ends (the hold goes on); else (fix round 1, review I2) each real member
-- not yet answered and with no popup up is asked once they are free
function DemandTick(S)
	local D = S.Demand
	if not D or D.Paid then return end
	if os.clock() >= D.Until then
		Toast(S.Captor, "Nobody paid.")
		EndDemand(S)
		return
	end
	for _, E in pairs(D.Asked) do
		if S.Demand ~= D then return end
		if not E.Answered and not E.Popup and CanAsk(E.PL) then AskMember(S, D, E) end
	end
end

-- the demand (Menu "Ransom"): see the header. TierIndex an integer inside the tiers (review M7, menu half)
local function MenuRansom(S, TierIndex)
	if RansomLock(S) then return false end
	local Tiers = Hostage.RansomTiers(LevelOf(S.Hostage))
	if type(TierIndex) ~= "number" or TierIndex ~= TierIndex or TierIndex % 1 ~= 0 or TierIndex < 1 or TierIndex > #Tiers then
		return false
	end
	local Members = Payers(S)
	if #Members == 0 then return false end
	local CaptorName = S.Captor.DisplayName or S.Captor.Name
	local D = {Id = HttpService:GenerateGUID(false), Amount = Tiers[TierIndex], Until = os.clock() + Hostage.RansomWait,
		Asked = {}, Paid = false, Speaker = CaptorName}
	D.Text = ("%s holds %s. Pay $%d?"):format(CaptorName, S.Hostage.DisplayName or S.Hostage.Name, D.Amount)
	S.Demand, S.Asked = D, true
	for _, M in ipairs(Members) do D.Asked[Key(M)] = {PL = M, Popup = false, Answered = false} end
	-- (fix round 1, review I2) a member fighting or already in a conversation isn't asked now (no conversation of
	-- theirs is clobbered); DemandTick asks them once free
	for _, M in ipairs(Members) do
		local E = D.Asked[Key(M)]
		if S.Demand == D and CanAsk(M) then AskMember(S, D, E) end
	end
	return true
end

-- ===== the turn-in (Task 11, ruling R7, pre-flight P12 / P13; see THE TURN-IN in the header) =====
local DeskList = {} -- {{Model, J}}: the desks the last scan found
local PayFineOf = {} -- [DialogueId] = the PayFine choice's jurisdiction, or false (none)

local function PayFineJ(Defs, Id)
	if PayFineOf[Id] ~= nil then return PayFineOf[Id] end
	local Def, J = Defs[Id], false
	if type(Def) == "table" and type(Def.Nodes) == "table" then
		for _, Node in pairs(Def.Nodes) do
			for _, Choice in ipairs(type(Node) == "table" and type(Node.Choices) == "table" and Node.Choices or {}) do
				for _, A in ipairs(type(Choice) == "table" and (Choice.Actions or {Choice.Action}) or {}) do
					if not J and type(A) == "table" and A.Kind == "PayFine" then J = A.Jurisdiction or "State" end
				end
			end
		end
	end
	PayFineOf[Id] = J
	return J
end

-- (final fix round, review I4) X's desk entry {Model, J} when it is a desk, else nil
local function DeskOf(X, Defs)
	if not X:IsA("Model") then return nil end
	local Id = X:GetAttribute("DialogueId")
	local J = Id ~= nil and PayFineJ(Defs, Id) or nil
	return J and {Model = X, J = J} or nil
end

-- (final fix round, review I4) one model added to the index, once (workspace.DescendantAdded, deferred a frame)
local function IndexDesk(X)
	if not X:IsDescendantOf(workspace) then return end
	for _, E in ipairs(DeskList) do if E.Model == X then return end end
	local E = DeskOf(X, require(Rensei.Dialogues))
	if E then table.insert(DeskList, E) end
end

-- (final fix round, review I4) the index without the desks no longer in workspace
local function PruneDesks()
	local Out = {}
	for _, E in ipairs(DeskList) do
		if E.Model:IsDescendantOf(workspace) then table.insert(Out, E) end
	end
	DeskList = Out
end

-- the models in workspace with a DialogueId whose definition has a PayFine choice, found by one scan now (Start, and
-- the tests' temp desk); returns how many
function HostageService._RefreshDesks()
	local Defs = require(Rensei.Dialogues)
	local Out = {}
	for _, X in ipairs(workspace:GetDescendants()) do
		local E = DeskOf(X, Defs)
		if E then table.insert(Out, E) end
	end
	DeskList = Out
	return #Out
end

function HostageService.Desks()
	local Out = {}
	for _, X in ipairs(DeskList) do
		if X.Model:IsDescendantOf(workspace) then table.insert(Out, X.Model) end
	end
	return Out
end

-- the desk a Held session's captor stands within DeskRange of, its hostage (a real player) Wanted in that desk's own
-- jurisdiction (P12), or nil
local function TurnInDesk(S)
	if S.State ~= "Held" or not IsPlayer(S.Hostage) then return nil end
	local CR = Root(S.CC)
	if not CR then return nil end
	local HeatService = require(ServerScriptService.HeatService)
	for _, X in ipairs(DeskList) do
		local M = X.Model
		if M:IsDescendantOf(workspace) then
			local R = M:FindFirstChild("HumanoidRootPart") or M.PrimaryPart
			local At = R and R.Position or M:GetPivot().Position
			if (At - CR.Position).Magnitude <= Hostage.DeskRange then
				local Ok, W = pcall(HeatService.Wanted, S.Hostage, X.J)
				if Ok and type(W) == "number" and W >= 1 then return X end
			end
		end
	end
	return nil
end

-- turn in (Menu "TurnIn"): see the header. No yield from the re-check to the release.
local function MenuTurnIn(S)
	local Desk = TurnInDesk(S)
	if not Desk then return false end
	local H, Captor, J = S.Hostage, S.Captor, Desk.J
	local D = DataOf(H)
	if type(D) ~= "table" then return false end
	local HeatService = require(ServerScriptService.HeatService)
	local Before = tonumber(D.Money) or 0
	local Said = nil
	local Ok, Err = pcall(function()
		if HeatService.Wanted(H, J) <= Heat.FineMaxWanted then
			local Fined, Msg = HeatService.Fine(H, J) -- (its own rule: the cost, the money, the Heat cleared)
			if Fined then Said = Msg end -- (fix round 1, review m3: a refusal isn't shown; the Heat is cleared below)
		else
			-- (P13, the spec literally) past a desk fine: the same fine (HeatService.Fine's cost, which it refuses above
			-- FineMaxWanted) charged when it can be paid
			local Cost = Heat.FinePerLevel * math.max(1, tonumber(D.Level) or 1)
			if require(ServerScriptService.ProgressionService).SpendMoney(H, Cost) then
				Said = ("Paid a fine of %d."):format(Cost)
			end
		end
	end)
	if not Ok then warn("HostageService: the turn-in's fine failed:", Err) end
	local Paid = math.max(0, Before - (tonumber(D.Money) or 0)) -- (P12: what the fine really took)
	-- (final fix round, review I2, the controller's conservative default) nothing paid, nothing done: no Heat cleared, no
	-- release, no bounty, no deed, and the hold goes on (a broke fugitive's Heat is no free wipe; the owner may loosen it)
	if Paid <= 0 then
		Toast(Captor, "They can't pay the fine.") -- PROPOSAL (text)
		return false
	end
	-- the Heat cleared once the fine is paid (Wanted 3+: whatever the desk's own fine would leave)
	Step("clearing the fugitive's Heat", function()
		if HeatService.Value(H, J) > 0 then HeatService.Clear(H, J) end
	end)
	Release(S, "turned_in")
	local Bounty = Hostage.Bounty(Paid)
	if Bounty > 0 and not Apply(HostageService._Grant, Captor, Bounty) then
		warn(("HostageService: the turn-in's bounty ($%d) wasn't granted"):format(Bounty))
	end
	Step("recording turned_in_fugitive", Record, Captor, "turned_in_fugitive", {})
	Toast(H, "You were turned in. " .. (Said or "Your Heat is cleared.")) -- PROPOSAL (text)
	Toast(Captor, ("Bounty: $%d."):format(Bounty)) -- PROPOSAL (text)
	return true
end

function HostageService.MenuOptions(Captor)
	local S = CaptorSession(Captor)
	if not S then return {} end
	local Why = RansomLock(S)
	local Out = {
		{Id = "Release", Text = "Let them go", Locked = false},
		{Id = "Finish", Text = "Finish them", Locked = false},
		{Id = "Ransom", Text = "Demand ransom", Locked = Why ~= nil, Why = Why, Tiers = Hostage.RansomTiers(LevelOf(S.Hostage))},
	}
	if TurnInDesk(S) then table.insert(Out, {Id = "TurnIn", Text = "Turn them in", Locked = false}) end -- PROPOSAL (text)
	return Out
end

-- Tick: the captor sent their options again (a Held notify) when they changed (a stand-in captor is never told)
function OptionsTick(S)
	if not IsPlayer(S.Captor) then return end
	local O = HostageService.MenuOptions(S.Captor)
	local K = OptionsKey(O)
	if K == S.OptionsKey then return end
	S.OptionsKey = K
	Notify(S.Captor, "Hostage", {State = "Held", Role = "Captor", Captor = S.Captor.Name, Hostage = S.Hostage.Name,
		Until = S.CC:GetAttribute("HostageUntil"), Options = O})
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
-- (final fix round, the parked T9 ruling) the same check for a gun shot: WeaponManager.Fire calls it with the shot's
-- result (guns record no hit, so the HitListeners never hear one)
function HostageService.WindowHit(Attacker, Victim, Result) OnHit(Attacker, Victim, Result) end

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
-- watching for a kill by the captor's side. (Final fix round, review I1) Release opens one for a welded pair's hostage it
-- leaves knocked (forward-declared above Release)
function StartPending(S, NoPay)
	local P = {Captor = S.Captor, Hostage = S.Hostage, HC = S.HC, TookHeat = S.TookHeat or {}, Ends = os.clock() + GraceTime(),
		Harmed = nil, NoPay = NoPay == true, Over = false, Conns = {}}
	Pending[P] = true
	table.insert(P.Conns, P.HC:GetAttributeChangedSignal("GrippedBy"):Connect(function()
		if not P.Over and os.clock() < P.Ends and CaptorSide(P, P.HC:GetAttribute("GrippedBy")) then
			P.Harmed = P.Harmed or "gripped"
		end
	end))
	task.delay(P.Ends - os.clock(), function()
		local function WaitWhile(Cond, Max)
			local T0 = os.clock()
			while not P.Over and P.HC.Parent and Cond() and os.clock() - T0 < Max do task.wait(0.1) end
		end
		-- a grip running at the window's end is waited out (its own finish decides a kill); then paid unless harmed
		WaitWhile(function() return P.HC:GetAttribute("GrippedBy") ~= nil end, GRIP_WAIT)
		if P.Over then return end
		if not (P.Harmed or P.NoPay) then PayRelease(P) return end
		-- (fix round 3, re-review N1) harmed, or a cancelled Finish's, with the hostage still knocked: the window stays open,
		-- paying nothing, until that knock ends (a recovery, a grip's end, death), so a knock late in the window can't be
		-- finished after it as a deed-free kill; a grip by the captor's side that kills inside it is killed_hostage (OnGrip)
		if Alive(P.HC) and DownedManager.IsKnocked(P.HC) then
			P.NoPay, P.Ends = true, math.huge
			WaitWhile(function()
				return Alive(P.HC) and (DownedManager.IsKnocked(P.HC) or P.HC:GetAttribute("GrippedBy") ~= nil)
			end, KNOCK_WAIT)
		end
		EndPending(P)
	end)
end

local function ClearAllPending()
	for P in pairs(Pending) do EndPending(P) end
end

-- (tests only, read while SeamOpen: fix round 3, re-review n4) every release window dropped, nothing paid
-- (HostageKit.Clean); _PendingCount() the windows still open
function HostageService._ClearPending()
	if SeamOpen() then ClearAllPending() end
end
function HostageService._PendingCount()
	if not SeamOpen() then return 0 end
	local N = 0
	for _ in pairs(Pending) do N += 1 end
	return N
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
			-- (final fix round, parked T8 n2) and Second Wind's mark with it: this knock's recovery never ran, so the next
			-- knock mustn't recover at Second Wind's share (spending Second Wind itself stays an owner question)
			Step("clearing Second Wind's mark", function() HC:SetAttribute("SecondWindActive", nil) end)
		elseif Alive(HC) and DownedManager.IsKnocked(HC) then
			-- (fix round 2, ruling on review m2) cancelled (a stun): the hostage stays knocked, as for any grip, and the
			-- same harm window opens, paying nothing -- a grip of the captor's side that kills them inside it is still
			-- killed_hostage, so a friend's stun can't turn a Finish into a deed-free kill
			Step("opening the cancelled Finish's window", StartPending, S, true)
		end
	end)
	return true
end

function HostageService.Menu(Captor, Choice, Arg)
	if type(Choice) ~= "string" then return false end
	local S = CaptorSession(Captor)
	if not S then return false end
	if Choice == "Release" then return MenuRelease(S) end
	if Choice == "Finish" then return MenuFinish(S) end
	if Choice == "Ransom" then return MenuRansom(S, Arg) end -- (Task 11)
	if Choice == "TurnIn" then return MenuTurnIn(S) end -- (Task 11)
	return false
end

-- the PlayerRemoving handler (a test seam): every session of that PL released as "left" (its cooldown, immunity and
-- re-take times are kept: a rejoin doesn't reset them)
-- ===== the human shield and the rescue (Task 9, spec §3 / §4; see THE HUMAN SHIELD AND THE RESCUE in the header) =====
-- (fix round 1, review I4) PROPOSAL: seconds within which a second landing of the same attacker on the same hostage is
-- the same swing when the attack has no AttackRunner strike id (a one-frame HitboxManager.Hitbox / Radius, a cast): three
-- server frames, below the shortest gap between two strikes of one attack (Shadow Step's 0.08 s)
local SAME_SWING = 0.05
-- (fix round 1, review I5 / concern 3) PROPOSAL: seconds a redirect is remembered for the RecordHit that follows it (the
-- pipeline calls RecordHit in the same step, right after the DamageManager function)
local REDIRECT_FOR = 0.1
local StruckBy = setmetatable({}, {__mode = "k"}) -- [hostage character] = {By, Strike, At}: the last landing on it
local Redirected = setmetatable({}, {__mode = "k"}) -- [attacker] = {From (captor), To (hostage), At}: its last redirect

-- the Held session whose captor's character is M, or nil (PlayerOf first: never an NPC's, the PvP rule)
local function HeldSessionOf(M)
	if typeof(M) ~= "Instance" or not M:GetAttribute("Holding") then return nil end
	local PL = HostageService.PlayerOf(M)
	local S = PL and ByCaptor[Key(PL)]
	if not S or S.Over or S.State ~= "Held" or S.CC ~= M then return nil end
	return S
end

-- Other (any character: a player's, a stand-in's, an NPC's) stands in S's captor's front arc (Hostage.InFront: the
-- captor root's look against the line from the captor's root to Other's). The shield, the rescue and the blocked line
-- all ask this one rule, so a hit the shield took is never also a rescue.
local function InFrontOf(S, Other)
	local CR = Root(S.CC)
	if not CR or typeof(Other) ~= "Instance" then return false end
	local OR = Root(Other)
	local At = OR and OR.Position or (Other:IsA("Model") and Other:GetPivot().Position) or nil
	return At ~= nil and Hostage.InFront(CR.CFrame.LookVector, At - CR.Position)
end

-- (fix round 1, ruling I1) a guard is a law-faction NPC, as the takedowns name one (TakedownService's FactionOf and
-- Takedown.IsLawFaction: its Faction attribute, else its perception faction, the State's or the Militia's law), and
-- never a townsperson (a TownsfolkId). Returns its faction, or nil. No law guards spawn yet (audit H14).
local function GuardFaction(M)
	if typeof(M) ~= "Instance" or not M:IsA("Model") or not IsNpc(M) or M:GetAttribute("TownsfolkId") ~= nil then return nil end
	local PS = require(ServerScriptService.PerceptionService).Npcs[M]
	local F = M:GetAttribute("Faction") or (PS and PS.Faction) or nil
	return Takedown.IsLawFaction(F) and F or nil
end

-- (fix round 1, ruling I1) a guard freed the captor's hostage: the captor's Heat raised ONCE by the taking's Crime, by the
-- existing rule (Rensei.Heat.Raised: where the captor stands, heard by the guard's faction; HeatService.Add, with the
-- deed's HeatCap; TakedownService's found-guard Heat has the same shape), and no deed recorded -- no Count, no Conduct, no daily cap slot, no toast, no rumour
local function GuardHeat(S, Faction)
	if not (IsPlayer(S.Captor) and S.Captor.Parent == Players) then return end
	local Def = Deeds.took_hostage
	local Region = require(ServerScriptService.MoralityService).RegionOf(S.CC)
	local HeatService = require(ServerScriptService.HeatService)
	for _, X in ipairs(Heat.Raised(Regions.Regions[Region], {Faction}, Def)) do
		HeatService.Add(S.Captor, X.J, X.Amount, Region, Def.HeatCap)
	end
end

-- (fix round 1, review I4) true when this landing on the hostage HC is the attacker's second of one swing (the same
-- AttackRunner strike, or without one, within SAME_SWING): the swing already landed on it. Else it is noted as the last.
local function SameSwing(HC, Attacker)
	local Id = AttackRunner.StrikeId(Attacker)
	local Now = os.clock()
	local Last = StruckBy[HC]
	if Last and Last.By == Attacker and Last.Strike == Id and (Id ~= nil or Now - Last.At < SAME_SWING) then return true end
	StruckBy[HC] = {By = Attacker, Strike = Id, At = Now}
	return false
end

-- DamageManager (server only, its first step after the IFramed checks): who a hit on Victim lands on -> Model, Absorbed.
-- The hostage when Victim is the captor of a Held session, the hostage is up (alive, not knocked), the attacker is
-- neither of the pair, and it stands in the captor's front arc; otherwise Victim. Absorbed (fix round 1, I4) is true when
-- that swing already landed on the hostage (one swing, one hit): DamageManager then lands nothing. The first redirect of
-- a hold records used_human_shield (witnessed), once per hold. (I5) The redirect is remembered for HitVictim.
function HostageService.Shield(Attacker, Victim)
	Redirected[Attacker] = nil
	local S = HeldSessionOf(Victim)
	if not S or Attacker == S.HC or Attacker == S.CC then return Victim, false end
	if not Alive(S.HC) or DownedManager.IsKnocked(S.HC) or not InFrontOf(S, Attacker) then return Victim, false end
	Redirected[Attacker] = {From = Victim, To = S.HC, At = os.clock()}
	if SameSwing(S.HC, Attacker) then return S.HC, true end
	if not S.Shielded then
		S.Shielded = true
		task.spawn(Record, S.Captor, "used_human_shield", {Witness = true}) -- (never delays the hit)
	end
	return S.HC, false
end

-- (fix round 1, review I4) DamageManager, for a victim with HeldBy hit directly: false when that swing already landed on
-- it through the shield (or directly), so it lands once
function HostageService.DirectHit(Attacker, Victim)
	if typeof(Victim) ~= "Instance" or not Victim:GetAttribute("HeldBy") then return true end
	return not SameSwing(Victim, Attacker)
end

-- (fix round 1, review I5 / concern 3) ProgressionService.RecordHit: the character a hit really landed on. A hit the
-- shield redirected is reported by its caller on the captor; this gives the hostage instead (once: the note is used up),
-- so every HitListener -- the Task 8 release window, the combat marks, training, encounters -- hears the real victim.
function HostageService.HitVictim(Attacker, Victim)
	local R = typeof(Attacker) == "Instance" and Redirected[Attacker]
	if not R or R.From ~= Victim or os.clock() - R.At > REDIRECT_FOR then return Victim end
	Redirected[Attacker] = nil
	return R.To
end

-- CombatDirector.CanStrike: Rig's line to Target runs through a hostage (Target is the captor of a Held session and Rig,
-- neither of the pair, stands in its front arc), so Rig holds its attack
function HostageService.LineBlocked(Rig, Target)
	local S = HeldSessionOf(Target)
	if not S or Rig == S.HC or Rig == S.CC then return false end
	return InFrontOf(S, Rig)
end

-- the rescue (a ProgressionService.HitListeners entry; fix round 1, ruling I2: WeaponManager.Fire calls it for a shot):
-- a landed hit on a captor from behind or the side by anyone but the pair -> "rescued"; a parry of the captor's attack
-- by anyone but the hostage -> "parried". Through the one Release. A guard that did it raises the captor's Heat once.
-- A hit the shield redirected reaches the listeners as a hit on the hostage (HitVictim), which holds nobody.
function HostageService.Rescue(Attacker, Victim, Result)
	local S, Rescuer, Outcome
	if Result == "Hit" then
		S = HeldSessionOf(Victim)
		if not S or Attacker == S.HC or Attacker == S.CC or InFrontOf(S, Attacker) then return false end
		Rescuer, Outcome = Attacker, "rescued"
	elseif Result == "Parried" or Result == "PerfectParried" then
		S = HeldSessionOf(Attacker)
		if not S or Victim == S.CC or Victim == S.HC then return false end
		Rescuer, Outcome = Victim, "parried"
	else
		return false
	end
	if not Release(S, Outcome) then return false end
	local Faction = GuardFaction(Rescuer)
	if Faction then Step("the guard's Heat", GuardHeat, S, Faction) end
	return true
end
local function OnRescueHit(Attacker, Victim, Result) HostageService.Rescue(Attacker, Victim, Result) end

function HostageService._Left(PL)
	Each(function(S)
		if S.Captor == PL or S.Hostage == PL then Release(S, "left") end
	end)
	-- (fix round 1) a release window of either side ends with nothing paid: a captor who left has no profile to record
	-- on (and can't log off to keep a payout coming), and a released player who left can no longer be spared or harmed
	for P in pairs(Pending) do
		if P.Captor == PL or P.Hostage == PL then EndPending(P) end
	end
	-- (final fix round, review M8) the per-player tables pruned: see A PL WHO LEAVES in the header
	if PL ~= nil and PL.UserId ~= nil then
		local K = Key(PL)
		Sends[K], Presses[K] = nil, nil
		local Last = Prune(K, os.clock())
		if Last then
			task.delay(Last - os.clock() + 0.1, function()
				if not Players:GetPlayerByUserId(K) then Prune(K, os.clock()) end
			end)
		end
	end
end

-- (tests only, while SeamOpen) the prune as of Now, and which tables hold PL now
function HostageService._Prune(PL, Now)
	if not SeamOpen() or PL == nil or PL.UserId == nil or type(Now) ~= "number" then return end
	Prune(Key(PL), Now)
end
function HostageService._Kept(PL)
	if not SeamOpen() or PL == nil or PL.UserId == nil then return nil end
	local K = Key(PL)
	return {NextAt = NextAt[K] ~= nil, ImmuneUntil = ImmuneUntil[K] ~= nil, Taken = Taken[K] ~= nil, Sends = Sends[K] ~= nil,
		Presses = Presses[K] ~= nil}
end

-- the BindToClose handler (a test seam): every session released as "shutdown"
function HostageService._Shutdown()
	Each(function(S) Release(S, "shutdown") end)
	ClearAllPending() -- (fix round 1) release windows end unpaid
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
	-- (Task 9) the rescue: a rear or side hit on a captor, a parry of the captor's attack
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, OnRescueHit)
	-- (Task 11; final fix round, review I4) the State desks, while hostages may start (on a live server, none until the
	-- owner's go-live step sets Rensei.Hostage.Enabled): ONE workspace scan now, then each Model added to workspace
	-- checked once (deferred a frame, as DialogueService attaches its talk prompts), and every DeskRefresh seconds only
	-- the gone desks dropped from the index. No workspace scan runs per tick.
	if HostageService.Allowed() then
		Step("indexing the desks", HostageService._RefreshDesks)
		workspace.DescendantAdded:Connect(function(X)
			if X:IsA("Model") then task.defer(function() Step("indexing a desk", IndexDesk, X) end) end
		end)
		task.spawn(function()
			while true do
				task.wait(Hostage.DeskRefresh)
				Step("pruning the desks", PruneDesks)
			end
		end)
	end
end

return HostageService
