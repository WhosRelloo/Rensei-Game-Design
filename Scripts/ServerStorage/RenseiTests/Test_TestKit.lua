return {
	EqPasses = function(T) T.Eq(1 + 1, 2) end,
	NearPasses = function(T) T.Near(0.1 + 0.2, 0.3, 1e-9) end,
	SamePasses = function(T) T.Same({A = {1, 2}, B = "x"}, {B = "x", A = {1, 2}}) end,
	SameCatchesDifference = function(T)
		local Ok = pcall(T.Same, {A = 1}, {A = 2})
		T.True(not Ok, "Same should fail on a difference")
	end,
}
