-- GuardKit (stealth missions Plan 1 Task 4, 2026-10-29): the guard suites' shared fixture (Play_Guard; Play_GuardRadio
-- and Play_GuardMemory in Tasks 5-6). Required, never copied. Run in the game VM (LMRunSuite), never in Edit. It builds on
-- TakedownKit (its floor, Spawn, Free, Run, Guard and clean-up); nothing here re-implements them.
--   * GuardKit.Guard(Body): refuses, before anything runs, unless DataManager.IsNoSave() (the owner's save is never
--     written by a guard case). Then TakedownKit.Guard, with GuardService.SetAuto(false) inside (the radio and memory
--     clock moves only when a case steps it) and, in its clean-up (even when Body fails), GuardService.Reset() and
--     SetAuto(true), before the kit removes the rigs.
--   * GuardKit.Service(): GuardService, or an error naming it when it doesn't exist.
--   * GuardKit.Net(Name): a fresh radio net name, unique per case (and per call). Every one starts "GuardKit_"
--     (GuardKit.NET_PREFIX), the prefix GuardService.Reset clears (its TEST_NET; fix round 1): a net named otherwise
--     survives Reset, so a case using one untracks its guards itself.
--   * GuardKit.Guardsman(Type, At, Info) -> Rig, G: TakedownKit.Spawn (passive, on the floor at At), Kit.Free (its root
--     unanchored, so it can walk), then GuardService.Track(Rig, Info).
--   * GuardKit.Route(Offsets): standing CFrames (a root 3 studs above the kit floor) at Kit.Spot() + each offset (a
--     Vector3, Y ignored), each facing the next; the last faces on, the way the route ran into it.
--   * GuardKit.Step(Seconds): GuardService.Step(0.2) and Kit.Run(0.2) (PerceptionService) by turns, each pair followed
--     by task.wait(0.2), so EnemyService's Brain and the Mover run in real time alongside.
local SSS = game:GetService("ServerScriptService")
local Kit = require(script.Parent.TakedownKit)

local GuardKit = {}

function GuardKit.Service()
	local M = SSS:FindFirstChild("GuardService")
	assert(M, "GuardService exists (ServerScriptService.GuardService)")
	return require(M)
end

function GuardKit.Guard(Body)
	local DM = require(SSS.CharacterHandler.DataManager)
	if not DM.IsNoSave() then
		error("GuardKit.Guard: DataManager.IsNoSave() is false (TestNoSave isn't on); refusing a guard case", 0)
	end
	Kit.Guard(function()
		local GS = GuardKit.Service()
		GS.SetAuto(false)
		local Ok, Err = pcall(Body)
		local COk, CErr = pcall(GS.Reset)
		GS.SetAuto(true)
		if not Ok then error(Err, 0) end
		if not COk then error(CErr, 0) end
	end)
end

GuardKit.NET_PREFIX = "GuardKit_" -- (fix round 1) GuardService.TEST_NET: keep the two in step
local Seq = 0
function GuardKit.Net(Name)
	Seq += 1
	return ("%s%s_%d_%d"):format(GuardKit.NET_PREFIX, tostring(Name), Seq, math.random(1e6))
end

function GuardKit.Guardsman(Type, At, Info)
	local GS = GuardKit.Service()
	local Rig = Kit.Spawn(Type, At)
	Kit.Free(Rig)
	return Rig, GS.Track(Rig, Info)
end

function GuardKit.Route(Offsets)
	local Spot = Kit.Spot()
	local Pts = {}
	for I, O in ipairs(Offsets) do Pts[I] = Spot + Vector3.new(O.X, 3, O.Z) end
	local Out = {}
	for I, P in ipairs(Pts) do
		local Ahead = Pts[I + 1] and (Pts[I + 1] - P) or (Pts[I - 1] and (P - Pts[I - 1])) or Vector3.new(0, 0, -1)
		Ahead = Vector3.new(Ahead.X, 0, Ahead.Z)
		Out[I] = CFrame.lookAt(P, P + (Ahead.Magnitude > 1e-3 and Ahead.Unit or Vector3.new(0, 0, -1)))
	end
	return Out
end

function GuardKit.Step(Seconds)
	local GS = GuardKit.Service()
	for _ = 1, math.floor(Seconds / 0.2 + 0.5) do
		GS.Step(0.2)
		Kit.Run(0.2)
		task.wait(0.2)
	end
end

return GuardKit
