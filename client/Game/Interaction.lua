-- SM64 Objects are a nightmare!!!!!!!!!!!!!!!!!
-- WE HAVE TO COME UP WITH OBJECT-LESS SOLUTIONS
--!strict
local Interaction = {}

local SM64 = script.Parent.Parent
local Root = SM64.Parent

local Mario = require(SM64.Mario)
local Enums = require(SM64.Enums)
local Util = require(SM64.Util)

local Animations = Mario.Animations
local Sounds = Mario.Sounds

local Action = Enums.Action
local ActionFlags = Enums.ActionFlags
local ActionGroup = Enums.ActionGroups

local MarioFlags = Enums.MarioFlags

local InteractionType = Enums.InteractionType

type Mario = Mario.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Knockback Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local sForwardKnockbackActions = {
	{ Action.SOFT_FORWARD_GROUND_KB, Action.FORWARD_GROUND_KB, Action.HARD_FORWARD_GROUND_KB },
	{ Action.FORWARD_AIR_KB, Action.FORWARD_AIR_KB, Action.HARD_FORWARD_GROUND_KB },
	{ Action.FORWARD_WATER_KB, Action.FORWARD_WATER_KB, Action.FORWARD_WATER_KB },
}

local sBackwardKnockbackActions = {
	{ Action.SOFT_BACKWARD_GROUND_KB, Action.BACKWARD_GROUND_KB, Action.HARD_BACKWARD_GROUND_KB },
	{ Action.BACKWARD_AIR_KB, Action.BACKWARD_AIR_KB, Action.HARD_BACKWARD_GROUND_KB },
	{ Action.BACKWARD_WATER_KB, Action.BACKWARD_WATER_KB, Action.BACKWARD_WATER_KB },
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Converts an angle in degrees to sm64's s16 angle units. For example, DEGREES(90) == 0x4000
local function DEGREES(x: number): number
	return Util.SignedShort(x * 0x10000 / 360)
end

local function robloxLookToSM64Angle(lookVector: Vector3): number
	local lookAngle = math.deg(math.atan2(lookVector.X, lookVector.Z))
	return DEGREES(lookAngle)
end

-- Vector3 point must be in SM64 Units.
local function marioObjAngleToObject(m: Mario, point: Vector3): number
	local dx = point.X - m.Position.X
	local dz = point.Z - m.Position.Z

	return Util.Atan2s(dz, dx)
end

-- Vector3 point must be in SM64 Units.
local function determineInteraction(m: Mario, point: Vector3): number
	local interaction = 0
	local action = m.Action

	if action:Has(ActionFlags.ATTACKING) then
		if action() == Action.PUNCHING or action() == Action.MOVE_PUNCHING or action() == Action.JUMP_KICK then
			local dYawToObject = Util.SignedShort(marioObjAngleToObject(m, point) - m.FaceAngle.Y)

			if m.Flags:Has(MarioFlags.PUNCHING) then
				-- 120 degrees total, or 60 each way
				if -0x2AAA <= dYawToObject and dYawToObject <= 0x2AAA then
					interaction = InteractionType.PUNCH
				end
			end
			if m.Flags:Has(MarioFlags.KICKING) then
				-- 120 degrees total, or 60 each way
				if -0x2AAA <= dYawToObject and dYawToObject <= 0x2AAA then
					interaction = InteractionType.KICK
				end
			end
			if m.Flags:Has(MarioFlags.TRIPPING) then
				-- 180 degrees total, or 90 each way
				if -0x4000 <= dYawToObject and dYawToObject <= 0x4000 then
					interaction = InteractionType.TRIP
				end
			end
		elseif action() == Action.GROUND_POUND or action() == Action.TWIRLING then
			if m.Velocity.Y < 0.0 then
				interaction = InteractionType.GROUND_POUND_OR_TWIRL
			end
		elseif action() == Action.GROUND_POUND_LAND or action() == Action.TWIRL_LAND then
			-- Neither ground pounding nor twirling change Mario's vertical speed on landing.,
			-- so the speed check is nearly always true (perhaps not if you land while going upwards?)
			-- Additionally, actionState it set on each first thing in their action, so this is
			-- only true prior to the very first frame (i.e. active 1 frame prior to it run).
			if m.Velocity.Y < 0.0 and m.ActionState == 0 then
				interaction = InteractionType.GROUND_POUND_OR_TWIRL
			end
		elseif action() == Action.SLIDE_KICK or action() == Action.SLIDE_KICK_SLIDE then
			interaction = InteractionType.SLIDE_KICK
		elseif action:Has(ActionFlags.RIDING_SHELL) then
			interaction = InteractionType.FAST_ATTACK_OR_SHELL
		elseif m.ForwardVel < -26.0 and 26.0 <= m.ForwardVel then
			interaction = InteractionType.FAST_ATTACK_OR_SHELL
		end
	end

	-- Prior to this, the interaction type could be overwritten. This requires, however,
	-- that the interaction not be set prior. This specifically overrides turning a ground
	-- pound into just a bounce.
	if interaction == 0 and action:Has(ActionFlags.AIR) then
		if m.Velocity.Y < 0.0 then
			if m.Position.Y > point.Y then
				interaction = InteractionType.HIT_FROM_ABOVE
			end
		else
			if m.Position.Y < point.Y then
				interaction = InteractionType.HIT_FROM_BELOW
			end
		end
	end

	return interaction
end

-- Vector3 point must be in SM64 Units.
local function determineKnockbackAction(m: Mario, point: Vector3, oDamageOrCoinValue: number): number
	local oDamageOrCoinValue = tonumber(oDamageOrCoinValue) or 0

	local bonkAction

	local terrainIndex = 0 -- 1 = air, 2 = water, 0 = default
	local strengthIndex = 0

	local angleToObject = marioObjAngleToObject(m, point)
	local facingDYaw = Util.SignedShort(angleToObject - m.FaceAngle.Y)
	local remainingHealth = Util.SignedShort(m.Health - 0x40 * m.HurtCounter)

	if m.Action:Has(ActionFlags.SWIMMING, ActionFlags.METAL_WATER) then
		terrainIndex = 2
	elseif m.Action:Has(ActionFlags.AIR, ActionFlags.ON_POLE, ActionFlags.HANGING) then
		terrainIndex = 1
	end

	if remainingHealth < 0x100 or oDamageOrCoinValue >= 4 then
		strengthIndex = 2
	elseif oDamageOrCoinValue >= 2 then
		strengthIndex = 1
	end

	m.FaceAngle = Util.SetY(m.FaceAngle, angleToObject)

	if terrainIndex == 2 then
		if m.ForwardVel < 28.0 then
			m:SetForwardVel(28.0)
		end
	else
		if m.ForwardVel < 16.0 then
			m:SetForwardVel(16.0)
		end
	end

	if -0x4000 <= facingDYaw and facingDYaw <= 0x4000 then
		m.ForwardVel *= -1.0
		bonkAction = sBackwardKnockbackActions[terrainIndex + 1][strengthIndex + 1]
	else
		m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
		bonkAction = sForwardKnockbackActions[terrainIndex + 1][strengthIndex + 1]
	end

	return bonkAction
end

local function takeDamageFromInteractObject(m: Mario, damage: number)
	local damage = math.floor(tonumber(damage) or 1)

	--[[local shake = 3
	if damage >= 4 then
		shake = 5 -- SHAKE_LARGE_DAMAGE
	elseif damage >= 2 then
		shake = 4 -- SHAKE_MED_DAMAGE
	else
		shake = 3 -- SHAKE_SMALL_DAMAGE
	end]]

	if not m.Flags:Has(MarioFlags.CAP_ON_HEAD) then
		damage += (damage + 1) / 2
	end

	if m.Flags:Has(MarioFlags.METAL_CAP) then
		damage = 0
	end

	-- SetCameraShakeFromHit(shake)

	m.HurtCounter += 4 * damage
	return damage
end

-- Vector3 point must be in SM64 Units.
local function takeDamageAndKnockback(m: Mario, point: Vector3, damage: number)
	local point = typeof(point) == "Vector3" and point or Vector3.zero
	local damage = tonumber(damage) or 0

	if
		(m.InvincTimer <= 0 and not m.Action:Has(ActionFlags.INVULNERABLE)) and not m.Flags:Has(MarioFlags.VANISH_CAP)
	then
		damage = takeDamageFromInteractObject(m, damage)

		if damage > 0 then
			m:PlaySound(Sounds.MARIO_ATTACKED)
		end

		return m:DropAndSetAction(determineKnockbackAction(m, point, damage), damage)
	end

	return false
end

-- Vector3 look is a LookVector, preferably from a CFrame.
-- Get LookVector from the Door object.
local function shouldPushOrPullDoor(m: Mario, look: Vector3): number
	local dx = point.X - m.Position.X
	local dz = point.Z - m.Position.Z

	local dYaw = Util.SignedShort(robloxLookToSM64Angle(look) - Util.Atan2s(dz, dx))

	return (dYaw >= -0x4000 and dYaw <= 0x4000) and 0x00000001 or 0x00000002
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mario Interactions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Interaction.InteractFlame(m: Mario)
	local burningAction = Action.BURNING_JUMP

	if
		m.Health > 0xFF
		and m.InvincTimer <= 0
		and (m.BurnTimer == 0 or m.BurnTimer >= 160)
		and not m.Action:Has(ActionFlags.INVULNERABLE)
		and not m.Flags:Has(MarioFlags.METAL_CAP, MarioFlags.VANISH_CAP)
	then
		if m.Action:Has(ActionFlags.SWIMMING, ActionFlags.METAL_WATER) and m.WaterLevel - m.Position.Y > 50.0 then
			m:PlaySound(Sounds.GENERAL_FLAME_OUT)
		else
			m.BurnTimer = 0
			m:PlaySound(Sounds.MARIO_ON_FIRE)

			if m.Action:Has(ActionFlags.AIR) and m.Velocity.Y < 0 then
				burningAction = Action.BURNING_FALL
			end

			return m:DropAndSetAction(burningAction, 1)
		end
	end

	return false
end

-- Vector3 point must be in SM64 Units.
function Interaction.InteractDamage(m: Mario, point: Vector3, damage: number): boolean
	if takeDamageAndKnockback(m, point, damage) then
		return true
	end

	--if (!(o->oInteractionSubtype & INT_SUBTYPE_DELAY_INVINCIBILITY)) {
	--    sDelayInvincTimer = TRUE;
	--}

	return false
end

-- Vector3 point must be in SM64 Units.
function Interaction.InteractKoopaShell(m: Mario, point: Vector3)
	if not m.Action:Has(ActionFlags.RIDING_SHELL) then
		local interaction = determineInteraction(m, point)

		if
			interaction == InteractionType.HIT_FROM_ABOVE
			or m.Action() == Action.WALKING
			or m.Action() == Action.HOLD_WALKING
		then
			-- m.InteractObj = o
			-- m.UsedObj = o
			-- m.RiddenObj = o

			-- AttackObject(o, interaction)
			-- UpdateMarioSoundAndCamera(m)
			-- PlayShellMusic()
			-- MarioDropHeldObject(m)

			--! Puts Mario in ground action even when in air, making it easy to
			-- escape air actions into crouch slide (shell cancel)
			return m:SetAction(Action.RIDING_SHELL_GROUND, 0)
		end

		-- PushMarioOutOfObject(m, o, 2.0)
	end

	return false
end

return Interaction
