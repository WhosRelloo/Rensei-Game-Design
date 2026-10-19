local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Framework = Modules.Framework

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()

local ReFX = require(Framework.ReFX)
local WCS = require(Framework.WCS)
local Controls = require(script.Controls)
local Keybinds = require(ReplicatedStorage.Modules.Managers.Keybinds)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local HitboxManager = require(ReplicatedStorage.Modules.Managers.HitboxManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local JumpHandler = require(ReplicatedStorage.Modules.Managers.JumpManager)
local SoundManager = require(ReplicatedStorage.Modules.Managers.SoundManager)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local Roll = require(script.Roll)
local Run = require(script.Run)
local Crouch = require(script.Crouch)

local InputRemote = ReplicatedStorage.Remotes.InputRemote
local DataRemote = ReplicatedStorage.Remotes.DataRemote

local Torso = Character:WaitForChild("Torso")

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local Client = WCS.CreateClient()
Client:RegisterDirectory(Modules.Skills)
Client:Start()

ReFX.Register(Modules.Effects)
ReFX.Start()

local WCSCharacter = WCS.Character
local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)

local Class = nil
local Equipped = nil
local MovesetTable = {
	Primary = "Fist",
	Block = "Block",
	Secondary = "Heavy",
	Run = "Run",
	
	--Air = "Air",
	Dash = "Roll",
	Crouch = "Crouch",
	Flashstep = "Flashstep"
}
local SkillModules = {}

for I,Module in pairs(Modules.Skills.Combat:GetDescendants()) do
	if Module:IsA("ModuleScript") then
		SkillModules[Module.Name] = require(Module)
	end
	
end

-- Attacks and blocking only start in Combat Mode (E). Releasing a held skill is always allowed.
local CombatInputs = {Primary = true, Secondary = true, Block = true, Feint = true}
local JumpAttackWindow = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Aerial.JumpWindow
local HoldingBlock = false
local LastSpace = 0
UserInputService.InputBegan:Connect(function(Input)
	if Input.KeyCode == Enum.KeyCode.Space then LastSpace = os.clock() end
end)
local function InCombatMode()
	return Character ~= nil and Character:GetAttribute("CombatMode") == true
end

-- Guns aim where the camera looks: the direction goes to the server just before the shot.
local function SendAim()
	if Character and Character:GetAttribute("Weapon") == "Guns" then
		ReplicatedStorage.Remotes.RequestRemote:FireServer("Aim", Camera.CFrame.LookVector)
	end
end

-- Knocked (downed): no actions at all until you recover or are finished.
local function Knocked()
	return Character ~= nil and Character:GetAttribute("Knocked") == true
end

local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local RequestRemote = ReplicatedStorage.Remotes.RequestRemote

local function InputHandler(SkillIndex, Start, Fresh)
	if Start and Knocked() then return end
	if Start and CombatInputs[SkillIndex] and not InCombatMode() then return end
	local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
	local SkillName = MovesetTable[SkillIndex]
	local CurrentSkill = CharacterState:GetSkillFromString(SkillName)
	if not CurrentSkill then return end
	
	local Holdable = CurrentSkill:GetSkillType() == "Holdable"
	
	if Start then
		-- Block: only a real key press may parry (Fresh); the hold-to-re-guard retries pass nothing
		if SkillName == "Block" then CurrentSkill:Start(Fresh == true) else CurrentSkill:Start() end
	elseif Holdable then
		CurrentSkill:End()
	end
	
end

-- ===== Shared actions: the keyboard bindings below and the touch buttons (Modules.UI.MobileControls,
-- via ClientActions) run these same functions. =====

-- Light attack (LMB). Uppercut = the Ctrl + LMB variant. While jumping it's the jump attack.
local function Attack(Began, Uppercut)
	if Began then
		if Knocked() or not InCombatMode() then return end
		if Uppercut then RequestRemote:FireServer("Uppercut") return end
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local HState = Humanoid and Humanoid:GetState()
		local Airborne = HState == Enum.HumanoidStateType.Jumping or HState == Enum.HumanoidStateType.Freefall
		-- about to land (less than JumpAttackLandLead s until the feet touch down): a normal light. A jump attack sent
		-- then reached the server after landing and played a 0.16 s scrap of dive that can't hit (fluidity 2026-10-18)
		local Root = Airborne and Character:FindFirstChild("HumanoidRootPart")
		if Root then
			local Params = RaycastParams.new()
			Params.FilterType = Enum.RaycastFilterType.Exclude
			Params.FilterDescendantsInstances = {Character}
			local Ground = workspace:Raycast(Root.Position, Vector3.new(0, -60, 0), Params)
			if Ground then
				local Leg = Character:FindFirstChild("Left Leg")
				local Height = Root.Position.Y - Ground.Position.Y - ((Leg and Leg.Size.Y or 2) + Root.Size.Y / 2)
				local G, Up = workspace.Gravity, Root.AssemblyLinearVelocity.Y
				local ToLand = (Up + math.sqrt(math.max(0, Up * Up + 2 * G * math.max(0, Height)))) / G
				local Lead = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.TuningConfig).Light.JumpAttackLandLead
				if ToLand < (Lead or 0.25) then Airborne = false end
			end
		end
		if Airborne or (not Root and os.clock() - LastSpace <= JumpAttackWindow) then
			RequestRemote:FireServer("JumpAttack")
			return
		end
		SendAim()
	end
	InputHandler("Primary", Began)
end

-- Block (hold) / parry (press). Holding keeps re-raising the guard (Devil Hunter).
local function BlockInput(Began)
	if Began then
		HoldingBlock = true
		InputHandler("Block", true, true)
		-- Devil Hunter: while F stays held, the guard comes back up by itself the moment it
		-- can (after a stun, an attack, a guard break) -- no need to let go and press again
		task.spawn(function()
			while HoldingBlock do
				task.wait(0.1)
				local State = WCSCharacter.GetCharacterFromInstance(Character)
				local Skill = State and State:GetSkillFromString("Block")
				if HoldingBlock and Skill and not Skill:GetState().IsActive and InCombatMode() and not Knocked() then
					InputHandler("Block", true)
				end
			end
		end)
	else
		HoldingBlock = false
		InputHandler("Block", false)
	end
end

-- Alchemy Z / X / C: press = clap (hold to keep clapping), release = slam into the move, aimed where
-- the camera looks at that moment. V is the Ultimate behind Carry (CarryInput).
local function AlchemyInput(Key, Began)
	if not Began then
		RequestRemote:FireServer("Alchemy", Key, Camera.CFrame.LookVector, "End")
		return false
	end
	if Knocked() or not InCombatMode() then return false end
	RequestRemote:FireServer("Alchemy", Key, Camera.CFrame.LookVector)
	return true
end

-- V: Carry a knocked target in range, else the alchemy Ultimate (the server decides).
local function CarryInput(Began)
	if Began then
		if not Knocked() then RequestRemote:FireServer("Downed", "Carry", Camera.CFrame.LookVector) end
	else
		-- letting go of V ends a held clap if V started the Ultimate
		RequestRemote:FireServer("Alchemy", "V", Camera.CFrame.LookVector, "End")
	end
end

local function WeaponSkillInput()
	if not InCombatMode() or not Character:GetAttribute("Weapon") then return false end
	SendAim()
	RequestRemote:FireServer("WeaponSkill")
	return true
end

-- Guns (owner 2026-10-17): M1 is always the pistol whip. Shooting is its own mode: Y (rebindable "Aim")
-- toggles it with a gun drawn in Combat Mode, then RMB fires (RMB is Feint the rest of the time). The
-- server owns the mode (character attribute ShootingMode) and validates every shot (Requests.Shoot).
local function Shooting()
	return Character ~= nil and Character:GetAttribute("ShootingMode") == true
end
local function AimToggle()
	if Knocked() or not InCombatMode() or Character:GetAttribute("Weapon") ~= "Guns" then return false end
	RequestRemote:FireServer("Shoot", "Mode", not Shooting())
	return true
end
local function FireInput()
	if Knocked() or not Shooting() then return false end
	-- turn to where the camera looks, so the shot goes where you aim
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Look = Camera.CFrame.LookVector
	local Flat = Vector3.new(Look.X, 0, Look.Z)
	if Root and Flat.Magnitude > 0.1 then Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat) end
	RequestRemote:FireServer("Shoot", "Fire", Look)
	return true
end

ClientActions.Register("Attack", function(Began) Attack(Began, false) end)
ClientActions.Register("Uppercut", function(Began) if Began then Attack(true, true) end end)
ClientActions.Register("Heavy", function(Began) InputHandler("Secondary", Began) end)
ClientActions.Register("Feint", function(Began) if Began and InCombatMode() then RequestRemote:FireServer("Feint") end end)
ClientActions.Register("Block", BlockInput)
ClientActions.Register("Dash", function(Began) if Began and not Knocked() then Roll:OnStartClient() end end)
ClientActions.Register("Jump", function(Began)
	JumpHandler.TouchJumpHeld = Began -- holding the touch jump = holding Space (wall run)
	if Began and not Knocked() then
		LastSpace = os.clock()
		JumpHandler:OnStartClient()
	end
end)
ClientActions.Register("Sprint", function(Began) if Began then Run:OnStartClient() else Run:OnEndClient() end end)
ClientActions.Register("Slide", function(Began)
	if Began and InCombatMode() then return end
	if Began then Crouch:OnStartClient() else Crouch:OnEndClient() end
end)
ClientActions.Register("WeaponSkill", function(Began) if Began then WeaponSkillInput() end end)
ClientActions.Register("Aim", function(Began) if Began then AimToggle() end end)
ClientActions.Register("Fire", function(Began) if Began then FireInput() end end)
for _, Key in ipairs({"Z", "X", "C"}) do
	ClientActions.Register("Alchemy" .. Key, function(Began) AlchemyInput(Key, Began) end)
end
ClientActions.Register("AlchemyV", CarryInput)
ClientActions.Register("Grip", function(Began) if Began and not Knocked() then RequestRemote:FireServer("Downed", "Grip") end end)

for Key, Skill in pairs(Controls) do
	-- Block is rebindable (Settings > Keybinds); it is bound below from Keybinds.
	if Skill == "Block" and Key ~= "M1" and Key ~= "M2" and Key ~= "M3" then continue end
	local EnumKey = Key == "M1" and Enum.UserInputType.MouseButton1 
		or Key == "M2" and Enum.UserInputType.MouseButton2 
		or Key == "M3" and Enum.UserInputType.MouseButton3
		or Enum.KeyCode[Key]
	
	ContextActionService:BindAction(Key, function(_, State, InputObj)
		-- Outside Combat Mode, clicks fall through to tools, click detectors and the world.
		if CombatInputs[Skill] and State == Enum.UserInputState.Begin and not InCombatMode() then
			return Enum.ContextActionResult.Pass
		end
		-- RMB = Feint (server cancels a light attack still in its windup) -- or, in guns' shooting mode, FIRE.
		if Skill == "Feint" then
			if State == Enum.UserInputState.Begin then
				if not FireInput() then ReplicatedStorage.Remotes.RequestRemote:FireServer("Feint") end
			end
			return Enum.ContextActionResult.Sink
		end
		-- LMB: the light attack -- the jump attack while jumping, Ctrl + LMB = Uppercut (Attack above)
		if Skill == "Primary" then
			if State == Enum.UserInputState.Begin or State == Enum.UserInputState.End then
				local Ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				Attack(State == Enum.UserInputState.Begin, Ctrl and State == Enum.UserInputState.Begin)
			end
			return Enum.ContextActionResult.Sink
		end
		if State == Enum.UserInputState.Begin or State == Enum.UserInputState.End then
			InputHandler(Skill, State == Enum.UserInputState.Begin)
		end
	end, false, EnumKey)
end

ContextActionService:BindAction("Space",function(_, State, InputObj)
	if State == Enum.UserInputState.Begin and not Knocked() then
		JumpHandler:OnStartClient()
	end
end, false, Enum.KeyCode.Space)
-- Dash and Block follow the player's keybinds and rebind live when Settings changes them.
local function BindRebindable(Name)
	if Name == "Dash" then
		ContextActionService:UnbindAction("RenseiDash")
		ContextActionService:BindAction("RenseiDash",function(_, State, InputObj)
			if State == Enum.UserInputState.Begin and not Knocked() then
				Roll:OnStartClient()
			end
		end, false, Keybinds.Get("Dash"))
	elseif Name == "WeaponSkill" then
		ContextActionService:UnbindAction("RenseiWeaponSkill")
		ContextActionService:BindAction("RenseiWeaponSkill", function(_, State)
			if State ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			return WeaponSkillInput() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
		end, false, Keybinds.Get("WeaponSkill"))
	elseif Name == "Aim" then
		ContextActionService:UnbindAction("RenseiAim")
		ContextActionService:BindAction("RenseiAim", function(_, State)
			if State ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			return AimToggle() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
		end, false, Keybinds.Get("Aim"))
	elseif Name == "Block" then
		ContextActionService:UnbindAction("RenseiBlock")
		ContextActionService:BindAction("RenseiBlock", function(_, State, InputObj)
			if State == Enum.UserInputState.Begin then
				BlockInput(true)
			elseif State == Enum.UserInputState.End then
				BlockInput(false)
			end
		end, false, Keybinds.Get("Block"))
	end
end
BindRebindable("Dash")
BindRebindable("Block")
BindRebindable("WeaponSkill")
BindRebindable("Aim")

-- Downed actions (controls doc): V = Carry (V is also the alchemy Ultimate; the server gives
-- Carry priority when a knocked target is in range, else casts the Ultimate), B = Grip.
ContextActionService:BindAction("RenseiCarry", function(_, State)
	if State == Enum.UserInputState.Begin then
		CarryInput(true)
	elseif State == Enum.UserInputState.End then
		CarryInput(false)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.V)
ContextActionService:BindAction("RenseiGrip", function(_, State)
	if State == Enum.UserInputState.Begin and not Knocked() then
		ReplicatedStorage.Remotes.RequestRemote:FireServer("Downed", "Grip")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.B)
-- Alchemy (controls doc): Z primary, X secondary, C utility (V = Ultimate, above). Combat Mode only.
-- Press = clap (hold the key to keep clapping), release = slam into the move, aimed where the camera
-- looks at that moment. The server validates the rest (AlchemyService).
for _, Key in ipairs({"Z", "X", "C"}) do
	ContextActionService:BindAction("RenseiAlchemy" .. Key, function(_, State)
		if State == Enum.UserInputState.End then
			AlchemyInput(Key, false)
			return Enum.ContextActionResult.Pass
		end
		if State ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		return AlchemyInput(Key, true) and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[Key])
end
Keybinds.Changed:Connect(BindRebindable)
ContextActionService:BindAction("LeftShift",function(_, State, InputObj)
	if State == Enum.UserInputState.Begin then
		Run:OnStartClient()
	elseif State == Enum.UserInputState.End then
		Run:OnEndClient()
	end
end, false, Enum.KeyCode.LeftShift)
ContextActionService:BindAction("RenseiSlide",function(_, State, InputObj)
	-- Crouch/slide is an out-of-combat movement option. In Combat Mode, Ctrl is only the
	-- Uppercut modifier (Ctrl + LMB).
	if State == Enum.UserInputState.Begin and InCombatMode() then
		return Enum.ContextActionResult.Pass
	end
	if State == Enum.UserInputState.Begin then
		Crouch:OnStartClient()
	elseif State == Enum.UserInputState.End then
		Crouch:OnEndClient()
	end
end, false, Enum.KeyCode.LeftControl)

local function CharacterAdded(NewCharacter)
	Character = NewCharacter
	-- Hard landings (aerial dive, knockbacks) must never trip the player onto their back.
	task.spawn(function()
		local Humanoid = NewCharacter:WaitForChild("Humanoid", 10)
		if Humanoid then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end
	end)
	CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
end

CharacterAdded(Character)
Player.CharacterAdded:Connect(CharacterAdded)

DataRemote.OnClientEvent:Connect(function(Profile)
	ProfileData = Profile
end)

--RunService.RenderStepped:Connect(function(deltaTime)
--	local Magnitude = math.clamp(Torso.AssemblyLinearVelocity.Magnitude/2,0,30)
--	print(Magnitude)
--	Magnitude = Magnitude < 10 and 0 or Magnitude
--	Camera.FieldOfView = Lerp(Camera.FieldOfView, 70 + (Magnitude), .1)
--end)

JumpHandler:OnConstructClient()


HitboxManager.Initiate()
MoverManager.Initiate()
AnimationManager.Initiate()
WeaponManager.StartClient()