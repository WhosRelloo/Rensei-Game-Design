-- The painted menu's camera pan into a slot's alcove (owner 2026-10-28: "when you click a character slot it pans to
-- your character slot"; then "Make the camera animation smoother and a little slower, but I like it").
-- The same move as the approved preview (Art/MainMenu/menu_anim.py): 3.5 s on a cubic curve that eases forward out of
-- the menu view, rises a little, and settles into the alcove from slightly above; smootherstep (no jolt at either
-- end), the field of view eased along with it. While a pan runs, MenuClient's own camera follow is paused.
-- MenuPan.Run(Camera, FromCF, FromFov, ToCF, ToFov, Seconds, OnStep) yields until done; OnStep(p) gets 0..1.

local RunService = game:GetService("RunService")

local MenuPan = {}
MenuPan.Seconds = 3.5

local function Ease5(P)
	P = math.clamp(P, 0, 1)
	return P * P * P * (P * (P * 6 - 15) + 10)
end

function MenuPan.Run(Camera, FromCF, FromFov, ToCF, ToFov, Seconds, OnStep)
	Seconds = Seconds or MenuPan.Seconds
	local S, E = FromCF.Position, ToCF.Position
	local Dir = E - S
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	local Fwd = Flat.Magnitude > 0.01 and Flat.Unit or FromCF.LookVector
	-- the curve's handles: out of the menu view along its own forward, into the alcove from a little above and behind
	local Rise = math.max(1.5, Dir.Magnitude * 0.06)
	local C1 = S + FromCF.LookVector * (Dir.Magnitude * 0.3) + Vector3.new(0, Rise, 0)
	local C2 = E - Fwd * (Dir.Magnitude * 0.28) + Vector3.new(0, Rise * 1.1, 0)
	local T0 = os.clock()
	while true do
		local Raw = math.clamp((os.clock() - T0) / Seconds, 0, 1)
		local P = Ease5(Raw)
		local U = 1 - P
		local Pos = S * U ^ 3 + C1 * (3 * U * U * P) + C2 * (3 * U * P * P) + E * P ^ 3
		local Rot = FromCF.Rotation:Lerp(ToCF.Rotation, P)
		Camera.CFrame = CFrame.new(Pos) * Rot
		Camera.FieldOfView = FromFov + (ToFov - FromFov) * P
		if OnStep then OnStep(Raw) end
		if Raw >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end

return MenuPan
