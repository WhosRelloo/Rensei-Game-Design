-- GunAim (gun rework 2026-10-25): the pure maths of a gunshot, shared by the client (where the crosshair points) and the
-- server (what the shot may hit, how fast it may be asked for). Numbers live in TuningConfig.Weapons.Guns.Aim (PROPOSAL).
-- No Instance is read here except through the arguments.
local GunAim = {}

GunAim.MUZZLE = Vector3.new(0, 1.5, 0) -- the shot leaves from the head: root + this (WeaponManager.Fire's origin since 2026-10-17)

function GunAim.Muzzle(RootPosition)
	return RootPosition + GunAim.MUZZLE
end

local function Finite(V)
	return V.X == V.X and V.Y == V.Y and V.Z == V.Z
		and math.abs(V.X) < math.huge and math.abs(V.Y) < math.huge and math.abs(V.Z) < math.huge
end

-- The characters a shot or the touch assist may pick: Models with a Humanoid that are children of Live, or (unless
-- DirectOnly) children of a Folder directly in Live -- the townsfolk folder. One list for WeaponManager.ShotTarget,
-- PositionHistory and GunAimUI's assist, so they can't drift. (Task 1's survey recorded World.Live's layout; if characters
-- sit deeper, widen this here, once.)
function GunAim.Candidates(Live, DirectOnly)
	local Out = {}
	for _, C in ipairs(Live:GetChildren()) do
		if C:IsA("Model") and C:FindFirstChildOfClass("Humanoid") then
			table.insert(Out, C)
		elseif C:IsA("Folder") and not DirectOnly then
			for _, M in ipairs(C:GetChildren()) do
				if M:IsA("Model") and M:FindFirstChildOfClass("Humanoid") then table.insert(Out, M) end
			end
		end
	end
	return Out
end

-- A token bucket per key: Rate a second, Burst at once. Allow(Key, Now) -> bool; Forget(Key). Now is passed in, so a
-- test drives the clock. (ServerHandler's shared Limiter stays as it is; this one is the Fire request's own.)
function GunAim.Limiter(Rate, Burst)
	local Buckets = {}
	local function Allow(Key, Now)
		local B = Buckets[Key]
		if not B then
			B = {Tokens = Burst, At = Now}
			Buckets[Key] = B
		end
		B.Tokens = math.min(Burst, B.Tokens + (Now - B.At) * Rate)
		B.At = Now
		if B.Tokens < 1 then return false end
		B.Tokens -= 1
		return true
	end
	local function Forget(Key) Buckets[Key] = nil end
	return Allow, Forget
end

-- Where the crosshair points: the first thing the camera ray meets past the shooter. Cast(From, Vector) -> a hit position
-- or nil (the caller's raycast and filter). The ray starts level with the muzzle, so nothing between the camera and the
-- shooter counts.
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

-- Dir turned by up to Deg degrees on each axis at random (Rng: a Random, so tests can seed it).
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
