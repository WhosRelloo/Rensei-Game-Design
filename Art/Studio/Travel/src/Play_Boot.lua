return {
	EveryServerScriptIsCopiedIn = function(T)
		local SSS, Bundle = game.ServerScriptService, game.ServerStorage.RenseiServer
		for _, C in ipairs(Bundle:GetChildren()) do
			T.True(SSS:FindFirstChild(C.Name) ~= nil, C.Name .. " in ServerScriptService")
		end
	end,
	ServicesStarted = function(T)
		T.True(game.ReplicatedStorage.Remotes:FindFirstChild("IntroRemote") ~= nil, "remotes exist")
		local P = game.Players:GetPlayers()[1]
		T.True(P ~= nil and P.Character ~= nil, "a character spawned")
		T.True(require(game.ServerScriptService.CharacterHandler.DataManager):GetProfile(P) ~= nil, "profile loaded")
	end,
}
