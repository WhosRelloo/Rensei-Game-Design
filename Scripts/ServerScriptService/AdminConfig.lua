-- Who may open the admin panel (AdminService checks this on EVERY command, not just on open).
-- Server-only: lives in ServerScriptService so clients never see the list.
-- Owner 2026-10-19: "lock it behind me and ImWaymonTTK" -- exactly these two accounts, everywhere, Studio
-- playtests included (the old group-rank and anyone-in-Studio rules are gone). Add a UserId here to add staff.
return {
	Users = {
		[37484441] = true, -- WhosRello (owner)
		[4161273705] = true, -- ImWaymonTTK
	},
}
