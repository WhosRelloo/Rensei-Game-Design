-- StyleService: which style each character fights with (Rensei.Styles). The server owns the character
-- attribute "Style" (the active style id for the class you're fighting as); combat code reads it through
-- Styles.Tuning. Saved per class in the profile's Styles table.
--   Apply(Player)        every spawn (LoadoutService.Restore): set the saved style, and keep it right when
--                        the weapon changes (switching weapons always lands on a style of the new class)
--   Select(Player, Id)   Requests.Style: validated switch, saved; only a LEARNED style (Styles.Unlocked)
--   Unlock(Player, Id)   the style trainer's dialogue (action UnlockStyle): requirements re-checked here
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Styles = require(ReplicatedStorage.Modules.Data.Rensei.Styles)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local AttackRunner = require(ReplicatedStorage.Modules.Managers.AttackRunner)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local States = ReplicatedStorage.Modules.Skills.States
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local Climbing = require(States.Climbing)

local StyleService = {}
local Watched = setmetatable({}, {__mode = "k"})

local function Data(Player)
	local Profile = DataManager:GetProfile(Player)
	return Profile and Profile.Data
end

local function Refresh(Player, Character)
	local D = Data(Player)
	local Class = Styles.ClassOf(Character)
	Character:SetAttribute("Style", Class and Styles.Saved(D, Class) or Styles.Default)
end

function StyleService.Apply(Player)
	local Character = Player.Character
	if not Character then return end
	Refresh(Player, Character)
	if not Watched[Character] then
		Watched[Character] = true
		Character:GetAttributeChangedSignal("Weapon"):Connect(function() Refresh(Player, Character) end)
	end
end

-- returns ok, message
function StyleService.Select(Player, Id)
	local Character = Player.Character
	local D = Data(Player)
	if type(Id) ~= "string" or #Id > 32 or not Character or not D then return false end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return false end
	local Class = Styles.ClassOf(Character)
	if not Class or not Styles.Valid(Class, Id) then return false, "That style isn't available for this weapon." end
	if not Styles.Unlocked(D, Id) then
		local S = Styles.Def(Id)
		local U = S and S.Unlock
		return false, U and ("You haven't learned %s. %s teaches it, at %s."):format(S.Name, U.Trainer, U.Where) or "You haven't learned that style."
	end
	if Character:GetAttribute("Style") == Id then return true end
	-- no switching to dodge a recovery, a stun or a fight: out of combat and free to act only (PROPOSAL)
	if Character:GetAttribute("InCombat") then return false, "Catch your breath first: no switching styles mid-fight." end
	if Character:GetAttribute("Knocked") or Character:GetAttribute("Carrying") or Character:GetAttribute("Gripping") then return false end
	if MovementState.Blocked(Character) or MovementState.Get(Character) then return false end
	local WC = WCS.Character.GetCharacterFromInstance(Character)
	if not WC or AttackRunner.IsRunning(Character) or WC:HasStatusEffects({Stun, Attacking, Blocking, Climbing}) then
		return false, "Not while you're mid-move."
	end
	if type(D.Styles) ~= "table" then D.Styles = {} end
	D.Styles[Class] = Id
	Character:SetAttribute("Style", Id)
	return true
end

-- returns ok, message. The trainer's dialogue only offers it when StyleReady passes; checked again here.
function StyleService.Unlock(Player, Id)
	local D = Data(Player)
	local S = type(Id) == "string" and Styles.Def(Id)
	if not D or not S or not S.Available or not S.Unlock then return false end
	if Styles.Unlocked(D, Id) then return true, ("You already know %s."):format(S.Name) end
	local Missing = Styles.Missing(D, Id)
	if #Missing > 0 then return false, ("Not yet. %s needs: %s."):format(S.Name, table.concat(Missing, ", ")) end
	if type(D.StyleUnlocks) ~= "table" then D.StyleUnlocks = {} end
	D.StyleUnlocks[Id] = true
	return true, ("You learned %s. Choose it in the Mastery menu (K), Class tab, STYLE."):format(S.Name)
end

return StyleService
