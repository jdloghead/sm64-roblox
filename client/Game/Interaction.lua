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
local ParticleFlags = Enums.ParticleFlags

local InteractionEnums = Enums.Interaction
local InteractionType = InteractionEnums.Type
local InteractionStatus = InteractionEnums.Status
local AttackType = InteractionEnums.AttackType

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

local acceptableCapFlags: { number } = {
	MarioFlags.NORMAL_CAP,
	MarioFlags.VANISH_CAP,
	MarioFlags.METAL_CAP,
	MarioFlags.WING_CAP,
}

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
			-- Neither ground pounding nor twirling change Mario's vertical speed on landing,
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

	-- indexes start at 64
	terrainIndex += 1
	strengthIndex += 1

	if -0x4000 <= facingDYaw and facingDYaw <= 0x4000 then
		m.ForwardVel *= -1.0
		bonkAction = sBackwardKnockbackActions[terrainIndex][strengthIndex]
	else
		m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
		bonkAction = sForwardKnockbackActions[terrainIndex][strengthIndex]
	end

	return bonkAction
end

local function takeDamageFromInteractObject(m: Mario, damage: number)
	local damage = math.floor(tonumber(damage) or 0)

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

	-- setCameraShakeFromHit(shake)

	m.HurtCounter += 4 * damage
	return damage
end

-- Vector3 point must be in SM64 Units.
local function takeDamageAndKnockback(m: Mario, point: Vector3, damage: number?)
	local point = typeof(point) == "Vector3" and point or Vector3.zero
	local damage = tonumber(damage) or 0

	local mInvulnerable = (m.InvincTimer > 0 or m.Action:Has(ActionFlags.INVULNERABLE))
		or m.Flags:Has(MarioFlags.VANISH_CAP)

	if not mInvulnerable then
		damage = takeDamageFromInteractObject(m, damage)

		if damage > 0 then
			m:PlaySound(Sounds.MARIO_ATTACKED)
		end

		return m:DropAndSetAction(determineKnockbackAction(m, point, damage), damage)
	end

	return false
end

-- Not sure how to do this function, so I'll stick with this way
local function bounceOffObject(m: Mario, object: BasePart, velY: number)
	local extents = Util.GetExtents(object)
	m.Position = Util.SetY(m.Position, extents.Y / Util.Scale)
	m.Velocity = Util.SetY(m.Velocity, velY)

	m.Flags:Add(MarioFlags.MOVING_UP_IN_AIR)
	m:PlaySound(Sounds.ACTION_BOUNCE_OFF_OBJECT)
end

-- hmm............
local function pushMarioOutOfObject(m: Mario, o: BasePart, padding: number?)
	local oExtents = Util.GetExtents(o) / Util.Scale
	local oPos = Util.ToSM64(o.Position)
	local oSize = oExtents - oPos

	local padding = tonumber(padding) or 0
	local hitboxRadius = math.max(oSize.X, oSize.Z)
	local minDistance = hitboxRadius + m.HitboxRadius + padding

	local offsetX = m.Position.X - oPos.X
	local offsetZ = m.Position.Z - oPos.Z
	local distance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)

	if distance < minDistance then
		local pushAngle
		local newMarioX
		local newMarioZ

		if distance == 0.0 then
			pushAngle = m.FaceAngle.Y
		else
			pushAngle = Util.Atan2s(offsetZ, offsetX)
		end

		newMarioX = oPos.X + minDistance * Util.Sins(pushAngle)
		newMarioZ = oPos.Z + minDistance * Util.Coss(pushAngle)

		local pos = Util.FindWallCollisions(Vector3.new(newMarioX, m.Position.Y, newMarioZ), 60.0, 50.0)
		local floorHeight, floor = Util.FindFloor(pos)

		if floor ~= nil then
			--! Doesn't update Mario's referenced floor (allows oob death when
			-- an object pushes you into a steep slope while in a ground action)
			m.Position = pos
		end
	end
end

local function resetMarioPitch(m: Mario)
	local action = m.Action()

	if action == Action.WATER_JUMP or action == Action.SHOT_FROM_CANNON or action == Action.FLYING then
		m.FaceAngle = Util.SetX(m.FaceAngle, 0)
	end
end

-- obsolete atm
local function attackObject(o, interaction: number): number
	local attackType = 0

	if interaction == InteractionType.GROUND_POUND_OR_TWIRL then
		attackType = AttackType.GROUND_POUND_OR_TWIRL
	elseif interaction == InteractionType.PUNCH then
		attackType = AttackType.PUNCH
	elseif interaction == InteractionType.KICK or interaction == InteractionType.TRIP then
		attackType = AttackType.KICK_OR_TRIP
	elseif interaction == InteractionType.SLIDE_KICK or interaction == InteractionType.FAST_ATTACK_OR_SHELL then
		attackType = AttackType.FAST_ATTACK
	elseif interaction == InteractionType.HIT_FROM_ABOVE then
		attackType = AttackType.FROM_ABOVE
	elseif interaction == InteractionType.HIT_FROM_BELOW then
		attackType = AttackType.FROM_BELOW
	end

	-- o.InteractStatus:Set(attackType + bit32.bor(InteractionStatus.INTERACTED, InteractionStatus.WAS_ATTACKED))
	return attackType
end

-- obsolete atm
local function marioStopRidingObject(m: Mario)
	--[[
	if m.RiddenObj ~= nil then
		m.RiddenObj.InteractStatus:Add(InteractionStatus.STOP_RIDING)
		stopShellMusic()
		m.RiddenObj = nil
	end
	]]
end

-- obsolete atm
local function marioGrabUsedObject(m: Mario)
	--[[
	if m.HeldObj == nil then
		m.HeldObj = m.UsedObj
		objSetHeldState(m.HeldObj, bhvCarrySomething3)
	end
	]]
end

-- obsolete atm
local function marioDropHeldObject(m: Mario)
	--[[
	if m.HeldObj ~= nil then
		if m.HeldObj.Behavior == "KoopaShellUnderwater" then
			stopShellMusic()
		end

		objSetHeldState(m.HeldObj, bhvCarrySomething4)

		-- ! When dropping an object instead of throwing it, it will be put at Mario's
        -- y-positon instead of the HOLP's y-position. This fact is often exploited when
        -- cloning objects.

		local holp = m.BodyState.HeldObjLastPos
		m.HeldObj.Position = Vector3.new(holp.X, m.Position.Y, holp.Z)

		m.HeldObj.MoveAngleYaw = m.FaceAngle.Y

		m.HeldObj = nil
	end
	]]
end

-- obsolete atm
local function marioThrowHeldObject(m: Mario)
	--[[
	if m.HeldObj ~= nil then
		if m.HeldObj.Behavior == "KoopaShellUnderwater" then
			stopShellMusic()
		end

		objSetHeldState(m.HeldObj, bhvCarrySomething5)

		local holp = m.BodyState.HeldObjLastPos
		m.HeldObj.Position = Vector3.new(
			holp.X + 32.0 * Util.Sins(m.FaceAngle.Y),
			m.Position.Y,
			holp.Z + 32.0 * Util.Coss(m.FaceAngle.Y)
		)

		m.HeldObj.MoveAngleYaw = m.FaceAngle.Y

		m.HeldObj = nil
	end
	]]
end

local function marioStopRidingAndHolding(m: Mario)
	marioDropHeldObject(m)
	marioStopRidingObject(m)

	--if m.Action() == Action.RIDING_HOOT then
	--	 m.UsedObj.InteractStatus = false
	--	 m.UsedObj.HootMarioReleaseTime = Util.GlobalTimer
	--end
end

function doesMarioHaveNormalCapOnHead(m: Mario): boolean
	return bit32.band(m.Flags(), bit32.bor(MarioFlags.CAPS, MarioFlags.CAP_ON_HEAD))
		== bit32.bor(MarioFlags.NORMAL_CAP, MarioFlags.CAP_ON_HEAD)
end

-- obsolete atm
local function marioBlowOffCap(m: Mario, capSpeed: number)
	local capObject = nil

	if doesMarioHaveNormalCapOnHead(m) then
		m.Flags:Remove(MarioFlags.NORMAL_CAP, MarioFlags.CAP_ON_HEAD)

		-- capObject = spawnObject(...?)

		-- capObject.Position = Util.SetY(capObject.Position, m.Action:Has(ActionFlags.SHORT_HITBOX) and 120 or 180)
		-- capObject.ForwardVel = capSpeed
		-- capObject.MoveAngleYaw = Util.SignedShort(m.FaceAngle.Y + 0x400)

		--if m.ForwardVel < 0.0 then
		--	capObject.MoveAngleYaw = Util.SignedShort(m.FaceAngle.Y + 0x8000)
		--end
	end
end

-- obsolete atm
local function marioLoseCapToEnemy(m: Mario, arg: number)
	local wasWearingCap = false

	if doesMarioHaveNormalCapOnHead(m) then
		-- saveFileSetFlags(arg == 1 and SaveFlag.CAP_ON_KLEPTO or SaveFlag.CAP_ON_UKIKI)
		m.Flags:Remove(MarioFlags.NORMAL_CAP, MarioFlags.CAP_ON_HEAD)
		wasWearingCap = true
	end

	return wasWearingCap
end

-- obsolete atm
local function marioRetreiveCap(m: Mario)
	marioDropHeldObject(m)
	-- saveFileClearFlags(SaveFlag.CAP_ON_KLEPTO, SaveFlag.CAP_ON_UKIKI)
	m.Flags:Remove(MarioFlags.CAP_ON_HEAD)
	m.Flags:Remove(MarioFlags.NORMAL_CAP, MarioFlags.CAP_IN_HAND)
end

-- obsolete atm
local function ableToGrabObject(m: Mario): boolean
	local action = m.Action()

	if action == Action.DIVE_SLIDE or action == Action.DIVE then
		--if not o.InteractionSubtype:Has(IntSubtype.GRABS_MARIO) then
		--	return true
		--end
	elseif action == Action.PUNCHING or action == Action.MOVE_PUNCHING then
		if m.ActionArg < 2 then
			return true
		end
	end

	return false
end

-- obsolete atm
local function marioGetCollidedObject(m: Mario, interactType: number)
	--[[
	for i = 0, m.NumCollidedObjs, 1 do
		local object = m.CollidedObjs[i]

		if object.InteractType == interactType then
			return object
		end
	end
	]]

	return nil
end

-- obsolete atm
local function marioCheckObjectGrab(m: Mario)
	local result = false

	--[[
	if m.Input:Has(InputFlags.INTERACT_OBJ_GRABBABLE) and m.InteractObj then
		local Script = m.InteractObj.Behavior

		if Script == "Bowser" then

		else
			local facingDYaw = Util.SignedShort(marioObjAngleToObject(m, m.InteractObj) - m.FaceAngle.Y)
			if facingDYaw >= -0x2AAA and facingDYaw <= 0x2AAA then
				m.UsedObj = m.InteractObj

				if not m.Action:Has(ActionFlags.AIR) then
					m:SetAction(m.Action:Has(ActionFlags.DIVING) and Action.DIVE_PICKING_UP or Action.PICKING_UP)
				end

				result = true
			end
		end
	end
	]]

	return result
end

-- ?
local function hitObjectFromBelow(m: Mario)
	m.Velocity = Util.SetY(m.Velocity, 0)
	-- setCameraShakeFromHit(SHAKE_HIT_FROM_BELOW)
end

local function bounceBackFromAttack(m: Mario, interaction: number)
	local action = m.Action()

	if bit32.btest(interaction, InteractionType.PUNCH, InteractionType.KICK, InteractionType.TRIP) then
		if action == Action.PUNCHING then
			rawset(m.Action :: any, "Value", Action.MOVE_PUNCHING)
		end

		if m.Action:Has(ActionFlags.AIR) then
			m:SetForwardVel(-16.0)
		else
			m:SetForwardVel(-48.0)
		end

		m.ParticleFlags:Add(ParticleFlags.TRIANGLE)
	end

	if
		bit32.btest(
			interaction,
			InteractionType.PUNCH,
			InteractionType.KICK,
			InteractionType.TRIP,
			InteractionType.FAST_ATTACK_OR_SHELL
		)
	then
		m:PlaySound(Sounds.ACTION_HIT_2)
	end
end

--[[
local function shouldPushOrPullDoor(m: Mario, point: Vector3, cframe: CFrame): number
	local dx = point.X - m.Position.X
	local dz = point.Z - m.Position.Z

	local _, dYaw = Util.CFrameToSM64Angles(cframe)
	dYaw = Util.SignedShort(dYaw - Util.Atan2s(dz, dx))

	return (dYaw >= -0x4000 and dYaw <= 0x4000) and 0x00000001 or 0x00000002
end
]]

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mario Interactions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Interaction.InteractFlame(m: Mario): boolean
	local burningAction = Action.BURNING_JUMP

	if
		m.Health > 0xFF
		and m.InvincTimer <= 0
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
function Interaction.InteractKoopaShell(m: Mario, point: Vector3, o: BasePart?): boolean
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

			-- attackObject(o, interaction)
			-- updateMarioSoundAndCamera(m)
			-- playShellMusic()
			-- marioDropHeldObject(m)

			--! Puts Mario in ground action even when in air, making it easy to
			-- escape air actions into crouch slide (shell cancel)
			return m:SetAction(Action.RIDING_SHELL_GROUND, 0)
		end

		if o then
			pushMarioOutOfObject(m, o, 2.0)
		end
	end

	return false
end

function Interaction.InteractCap(m: Mario, capFlag: number): boolean
	local capMusic = 0
	local capTime = 0

	if m.Action() ~= Action.GETTING_BLOWN and table.find(acceptableCapFlags, capFlag) then
		-- m.InteractObj = o
		-- o.oInteractStatus = INT_STATUS_INTERACTED

		m.Flags:Remove(MarioFlags.CAP_ON_HEAD, MarioFlags.CAP_IN_HAND)
		m.Flags:Add(capFlag)

		if capFlag == MarioFlags.VANISH_CAP then
			capTime = 600
			-- capMusic = SEQUENCE_ARGS(4, SEQ_EVENT_POWERUP)
		elseif capFlag == MarioFlags.METAL_CAP then
			capTime = 600
			-- capMusic = SEQUENCE_ARGS(4, SEQ_EVENT_METAL_CAP)
		elseif capFlag == MarioFlags.WING_CAP then
			capTime = 1800
			-- capMusic = SEQUENCE_ARGS(4, SEQ_EVENT_POWERUP)
		end

		if capTime > m.CapTimer then
			m.CapTimer = capTime
		end

		if m.Action:Has(ActionFlags.IDLE) or m.Action() == Action.WALKING then
			m.Flags:Add(MarioFlags.CAP_IN_HAND)
			m:SetAction(Action.PUTTING_ON_CAP)
		else
			m.Flags:Add(MarioFlags.CAP_ON_HEAD)
		end

		m:PlaySound(Sounds.MARIO_HERE_WE_GO)

		if capMusic ~= 0 then
			-- playCapMusic(capMusic)
		end

		return true
	end

	return false
end

function Interaction.InteractStarOrKey(m: Mario): boolean
	local starGrabAction = Action.STAR_DANCE_EXIT
	local noExit = true -- (o->oInteractionSubtype & INT_SUBTYPE_NO_EXIT) != 0;
	local grandStar = false -- (o->oInteractionSubtype & INT_SUBTYPE_GRAND_STAR) != 0;

	if m.Health >= 0x100 then
		marioStopRidingAndHolding(m)

		if not noExit then
			m.HurtCounter = 0
			m.HealCounter = 0
			if m.CapTimer > 1 then
				m.CapTimer = 1
			end
		end

		if noExit then
			starGrabAction = Action.STAR_DANCE_NO_EXIT
		end

		if m.Action:Has(ActionFlags.SWIMMING) then
			starGrabAction = Action.STAR_DANCE_WATER
		end

		if m.Action:Has(ActionFlags.AIR) then
			starGrabAction = Action.FALL_AFTER_STAR_GRAB
		end

		-- o.InteractStatus = IntStatus.INTERACTED
		-- m.InteractObj = o
		-- m.UsedObj = o

		-- starIndex = bit32.band(bit32.rshift(o.BhvParams, 24), 0x1F)
		-- saveFileCollectStarOrKey(m.NumCoins, starIndex)

		-- m.NumStars = saveFileGetTotalStarCount(gCurrSaveFileNum - 1, COURSE_MIN - 1, COURSE_MAX - 1)

		--if not noExit then
		--	dropQueuedBackgroundMusic()
		--	fadeoutLevelMusic(126)
		--end

		m:PlaySound(Sounds.MENU_STAR_SOUND)

		if grandStar then
			return m:SetAction(Action.JUMBO_STAR_CUTSCENE)
		end

		return m:SetAction(starGrabAction, (noExit and 1 or 0) + 2 * (grandStar and 1 or 0))
	end

	return false
end

function Interaction.InteractBounceTop(m: Mario, part: BasePart, damage: number?, isTwirlBounce: boolean?): boolean
	local oPos = Util.ToSM64(part.Position)
	local interaction = 0

	if m.Flags:Has(MarioFlags.METAL_CAP) then
		interaction = InteractionType.FAST_ATTACK_OR_SHELL
	else
		interaction = determineInteraction(m, oPos)
	end

	if bit32.btest(interaction, InteractionType.ATTACK_NOT_FROM_BELOW) then
		attackObject(part, interaction)
		bounceBackFromAttack(m, interaction)

		if bit32.btest(interaction, InteractionType.HIT_FROM_ABOVE) then
			if isTwirlBounce then
				bounceOffObject(m, part, 80.0)
				resetMarioPitch(m)

				m:PlaySound(Sounds.MARIO_TWIRL_BOUNCE)
				return m:DropAndSetAction(Action.TWIRLING)
			else
				bounceOffObject(m, part, 30.0)
			end
		end
	elseif takeDamageAndKnockback(m, oPos, damage) then
		return true
	end

	--if (!(o->oInteractionSubtype & INT_SUBTYPE_DELAY_INVINCIBILITY)) {
	--    sDelayInvincTimer = TRUE;
	--}

	return false
end

function Interaction.InteractShock(m: Mario, point: Vector3, damage: number): boolean
	local sInvulnerable = m.Action:Has(ActionFlags.INVULNERABLE) or m.InvincTimer ~= 0

	if not sInvulnerable and not m.Flags:Has(MarioFlags.VANISH_CAP) then
		local actionArg = m.Action:Has(ActionFlags.AIR, ActionFlags.ON_POLE, ActionFlags.HANGING) == false

		-- m.InteractObj = o

		takeDamageFromInteractObject(m, damage)
		m:PlaySound(Sounds.MARIO_ATTACKED)

		if m.Action:Has(ActionFlags.SWIMMING, ActionFlags.METAL_WATER) then
			return m:DropAndSetAction(Action.WATER_SHOCKED)
		else
			return m:DropAndSetAction(Action.SHOCKED, actionArg and 1 or 0)
		end
	end

	return false
end

function Interaction.InteractPole(m: Mario, o: BasePart): boolean
	local oExtents = Util.GetExtents(o) / Util.Scale
	local oPos = Util.ToSM64(o.Position)
	local oSize = oExtents - oPos
	oPos -= Vector3.yAxis * oSize.Y

	local actionId = bit32.band(m.Action(), 0x1FF)

	if actionId >= 0x080 and actionId < 0x0A0 then
		if not m.PrevAction:Has(ActionFlags.ON_POLE) then
			local velConv = m.ForwardVel
			local lowSpeed = m.ForwardVel <= 10.0

			marioStopRidingAndHolding(m)
			-- m.InteractObj = o
			m.PoleObj = o
			m.Velocity = Util.SetY(m.Velocity, 0)
			m.ForwardVel = 0

			m.PoleYawVel = 0
			m.PolePos = m.Position.Y - oPos.Y

			if lowSpeed then
				return m:SetAction(Action.GRAB_POLE_SLOW)
			end

			--! @bug Using m.ForwardVel here is assumed to be 0.0f due to the set from earlier.
			--       This is fixed in the Shindou version.
			m.PoleYawVel = velConv * 0x100 + 0x1000 -- FIXED VER
			-- m.PoleYawVel = m.ForwardVel * 0x100 + 0x1000 -- UNFIXED VER

			resetMarioPitch(m)
			return m:SetAction(Action.GRAB_POLE_FAST)
		end
	end

	return false
end

function Interaction.InteractCoin(m: Mario, coinValue: number): boolean
	m.NumCoins += coinValue
	m.HealCounter += 4 * coinValue

	-- o.InteractStatus = IntStatus.INTERACTED

	--[[
	if CourseIsMainCourse(gCurrCourseNum) and m.NumCoins - coinValue < 100 and m.NumCoins >= 100 then
		bhvSpawnStarNoLevelExit(StarIndex.HUNDRED_COINS)
	end
	]]

	return false
end

return Interaction
