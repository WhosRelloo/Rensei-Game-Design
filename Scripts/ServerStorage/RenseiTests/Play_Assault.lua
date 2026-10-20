-- the assault hook (HeatService.OnHit): a hit on a watcher, fed through the real combat entry point
-- (ProgressionService.RecordHit -> HitListeners). Melee can't reach watchers yet (HitboxManager only hits
-- World.Live), so this drives the hook directly. Run inside the snapshot / restore harness.
local SSS = game.ServerScriptService
local PG = require(SSS.ProgressionService)
local CS = game:GetService("CollectionService")
local Player = game.Players:GetPlayers()[1]
local C = Player.Character
local function Watcher(Name) for _, M in ipairs(CS:GetTagged("RenseiWatcher")) do if M.Name == Name then return M end end end
return {
	HitOnAWatcherIsAssault = function(T)
		local D = PG.GetData(Player)
		D.Morality.Heat = {}
		D.Morality.Deeds.assault_townsfolk = nil
		local Tobin = Watcher("Tobin")
		local Home = C:GetPivot()
		local R = Tobin.HumanoidRootPart
		C:PivotTo(CFrame.lookAt(R.Position + R.CFrame.LookVector * 4, R.Position))
		task.wait(0.6)
		PG.RecordHit(C, Tobin, "Hit")
		task.wait(0.3)
		local E = D.Morality.Deeds.assault_townsfolk
		T.True(E ~= nil and E.Count == 1, "assault recorded once")
		PG.RecordHit(C, Tobin, "Hit")
		task.wait(0.3)
		T.Eq(D.Morality.Deeds.assault_townsfolk.Count, 1, "a second hit within 30 s is the same assault")
		local Dummy = workspace.World.Live:FindFirstChild("Blocking")
		if Dummy then PG.RecordHit(C, Dummy, "Hit") task.wait(0.2) end
		T.Eq(D.Morality.Deeds.assault_townsfolk.Count, 1, "hitting a training dummy isn't assault")
		C:PivotTo(Home)
	end,
}
