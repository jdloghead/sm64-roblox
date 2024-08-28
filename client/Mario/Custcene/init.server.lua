--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local Buttons = Enums.Buttons

local InputFlags = Enums.InputFlags
local ParticleFlags = Enums.ParticleFlags

local ModelFlags = Enums.ModelFlags
local MarioEyes = Enums.MarioEyes
local MarioFlags = Enums.MarioFlags
local MarioHands = Enums.MarioHands

local GroundStep = Enums.GroundStep
local AirStep = Enums.AirStep

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

local function commonDeathHandler(m: Mario, animation, frameToDeathWarp: number)
	local animFrame = m:SetAnimation(animation)

	m.BodyState.EyeState = MarioEyes.DEAD
	m:StopAndSetHeightToFloor()

	return animFrame
end

local function stuckInGroundHandler(m: Mario, animation, unstuckFrame: number, target2, target3, endAction)
	local animFrame = m:SetAnimation(animation)

	if m.Input:Has(InputFlags.A_PRESSED) then
		m.ActionTimer += 1
		if m.ActionTimer >= 5 and animFrame < unstuckFrame - 1 then
			animFrame = unstuckFrame - 1
			m:SetAnimToFrame(animFrame)
		end
	end

	m:StopAndSetHeightToFloor()

	if animFrame == -1 then
		m:PlaySoundAndSpawnParticles(Sounds.ACTION_TERRAIN_STUCK_IN_GROUND, 1)
	elseif animFrame == unstuckFrame then
		m:PlaySoundAndSpawnParticles(Sounds.ACTION_UNSTUCK_FROM_GROUND, 1)
	elseif animFrame == target2 and animFrame == target3 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
	end

	if m:IsAnimAtEnd() then
		m:SetAction(endAction, 0)
	end
end

--[[
 * cutscenePutCapOn: Put Mario's cap on.
 * Clears "cap in hand" flag, sets "cap on head" flag, plays sound
 * SOUND_ACTION_UNKNOWN43E.
]]
local function cutscenePutCapOn(m: Mario)
	m.Flags:Remove(MarioFlags.CAP_IN_HAND)
	m.Flags:Add(MarioFlags.CAP_ON_HEAD)
	m:PlaySound(Sounds.ACTION_UNKNOWN43E)
end

local function generalStarDanceHandler(m: Mario, isInWater: boolean)
	local dialogID = 0

	if m.ActionState == 0 then
		m.ActionTimer += 1

		if m.ActionTimer == 1 then
			-- disableBackgroundSound()
			-- ...
		elseif m.ActionTimer == 42 then
			m:PlaySound(Sounds.MARIO_HERE_WE_GO)
		elseif m.ActionTimer == 80 then
			if not (bit32.band(m.ActionArg, 1) > 0) then
				-- LevelTriggerWarp(m, WarpOp.STAR_EXIT)
			else
				-- enableTimeStop()
				-- createDialogBoxWithResponse()
				m.ActionState = 1
			end
		end
	elseif
		m.ActionState == 1 --[[and gDialogResponse ~= DialogResponse.NONE]]
	then
		m.ActionState = 2
	elseif m.ActionState == 2 and m:IsAnimAtEnd() then
		-- disableTimeStop()
		-- enableBackgroundSound()
		-- dialogID = getStarCollectionDialog(m)
		if dialogID > 0 then
			-- look up for dialog
			m:SetAction(Action.READING_AUTOMATIC_DIALOG, dialogID)
		else
			m:SetAction(isInWater and Action.WATER_IDLE or Action.IDLE)
		end
	end
end

local function launchMarioUntilLand(m: Mario, endAction: number, animation: Animation, forwardVel: number): boolean
	local airStepLanded = false
	m:SetForwardVel(forwardVel)
	m:SetAnimation(animation)
	airStepLanded = m:PerformAirStep(0) == AirStep.LANDED
	if airStepLanded then
		m:SetAction(endAction)
	end

	return airStepLanded
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Death states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.STANDING_DEATH, function(m: Mario)
	if m.Input:Has(InputFlags.IN_POISON_GAS) then
		return m:SetAction(Action.SUFFOCATION, 0)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	commonDeathHandler(m, Animations.DYING_FALL_OVER, 80)
	if m.AnimFrame == 77 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	return false
end)

DEF_ACTION(Action.DEATH_ON_BACK, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	if commonDeathHandler(m, Animations.DYING_ON_BACK, 54) == 40 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end
	return false
end)

DEF_ACTION(Action.DEATH_ON_STOMACH, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	if commonDeathHandler(m, Animations.DYING_ON_STOMACH, 54) == 40 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end
	return false
end)

DEF_ACTION(Action.QUICKSAND_DEATH, function(m: Mario)
	if m.ActionState == 0 then
		m:SetAnimation(Animations.DYING_IN_QUICKSAND)
		m:SetAnimToFrame(60)
		m.ActionState = 1
	end

	if m.ActionState == 1 then
		if m.QuicksandDepth >= 100 then
			m:PlaySoundIfNoFlag(Sounds.MARIO_WAAAOOOW, MarioFlags.ACTION_SOUND_PLAYED)
		end
		m.QuicksandDepth += 5.0
		if m.QuicksandDepth >= 180 then
			-- LevelTriggerWarp
			m.ActionState = 2
		end
	end

	m:StationaryGroundStep()
	m:PlaySound(Sounds.MOVING_QUICKSAND_DEATH)
	return false
end)

DEF_ACTION(Action.ELECTROCUTION, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	commonDeathHandler(m, Animations.ELECTROCUTION, 43)
	return false
end)

DEF_ACTION(Action.SUFFOCATION, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	commonDeathHandler(m, Animations.SUFFOCATING, 86)
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spawning states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.SPAWN_SPIN_AIRBORNE, function(m: Mario)
	m:SetForwardVel(m.ForwardVel)

	if m:PerformAirStep() == AirStep.LANDED then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
		m:SetAction(Action.SPAWN_SPIN_LANDING)
	end

	if m.ActionState == 0 and m.Position.Y - m.FloorHeight > 300 then
		if m:SetAnimation(Animations.FORWARD_SPINNING) == 0 then
			m:PlaySound(Sounds.ACTION_SPIN)
		end
	else
		m.ActionState = 1
		m:SetAnimation(Animations.GENERAL_FALL)
	end

	return false
end)

DEF_ACTION(Action.SPAWN_SPIN_LANDING, function(m: Mario)
	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.GENERAL_LAND)

	if m:IsAnimAtEnd() then
		m:SetAction(Action.IDLE)
	end

	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Stuck in ground states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.HEAD_STUCK_IN_GROUND, function(m: Mario)
	stuckInGroundHandler(m, Animations.HEAD_STUCK_IN_GROUND, 96, 105, 135, Action.IDLE)
	return false
end)

DEF_ACTION(Action.BUTT_STUCK_IN_GROUND, function(m: Mario)
	stuckInGroundHandler(m, Animations.BOTTOM_STUCK_IN_GROUND, 127, 136, -2, Action.GROUND_POUND_LAND)
	return false
end)

DEF_ACTION(Action.FEET_STUCK_IN_GROUND, function(m: Mario)
	stuckInGroundHandler(m, Animations.LEGS_STUCK_IN_GROUND, 116, 129, -2, Action.IDLE)
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Star dance states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function actStarDance(m: Mario)
	-- Pretty sure cameraYaw isn't updated rapidly
	if m.ActionTimer == 0 then
		local camera = workspace.CurrentCamera
		local lookVector = camera.CFrame.LookVector
		local cameraYaw = Util.Atan2s(-lookVector.Z, -lookVector.X)
		m.FaceAngle = Util.SetY(m.FaceAngle, cameraYaw)
	end

	m:SetAnimation(m.ActionState == 2 and Animations.RETURN_FROM_STAR_DANCE or Animations.STAR_DANCE)

	generalStarDanceHandler(m, false)
	if m.ActionState ~= 2 and m.ActionTimer >= 40 then
		m.BodyState.HandState:Set(MarioHands.PEACE_SIGN)
	end
	m:StopAndSetHeightToFloor()
	return false
end

DEF_ACTION(Action.STAR_DANCE_EXIT, actStarDance)
DEF_ACTION(Action.STAR_DANCE_NO_EXIT, actStarDance)

DEF_ACTION(Action.STAR_DANCE_WATER, function(m: Mario)
	-- Pretty sure cameraYaw isn't updated rapidly
	if m.ActionTimer == 0 then
		local camera = workspace.CurrentCamera
		local lookVector = camera.CFrame.LookVector
		local cameraYaw = Util.Atan2s(-lookVector.Z, -lookVector.X)
		m.FaceAngle = Util.SetY(m.FaceAngle, cameraYaw)
	end

	m:SetAnimation(m.ActionState == 2 and Animations.RETURN_FROM_WATER_STAR_DANCE or Animations.WATER_STAR_DANCE)

	m.GfxPos = Vector3.zero
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)
	generalStarDanceHandler(m, true)
	if m.ActionState ~= 2 and m.ActionTimer >= 62 then
		m.BodyState.HandState:Set(MarioHands.PEACE_SIGN)
	end

	return false
end)

DEF_ACTION(Action.FALL_AFTER_STAR_GRAB, function(m: Mario)
	if m.Position.Y < m.WaterLevel - 130 then
		m:PlaySound(Sounds.ACTION_UNKNOWN430)
		m.ParticleFlags:Add(ParticleFlags.WATER_SPLASH)
		return m:SetAction(Action.STAR_DANCE_WATER, m.ActionArg)
	end

	if m:PerformAirStep(1) == AirStep.LANDED then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
		m:SetAction(bit32.band(m.ActionArg, 1) > 0 and Action.STAR_DANCE_NO_EXIT or Action.STAR_DANCE_EXIT, m.ActionArg)
	end

	m:SetAnimation(Animations.GENERAL_FALL)
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- any
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.SQUISHED, function(m: Mario)
	local squishAmount: number
	local spaceUnderCeil: number = math.max(m.CeilHeight - m.FloorHeight, 0)
	local surfAngle: number
	local underSteepSurf = false -- seems to be responsible for setting velocity?

	if m.ActionState == 0 then
		if spaceUnderCeil > 160.0 then
			m.SquishTimer = 0
			return m:SetAction(Action.IDLE)
		end

		m.SquishTimer = 0xFF

		if spaceUnderCeil >= 10.1 then
			-- Mario becomes a pancake
			squishAmount = spaceUnderCeil / 160.0
			m.GfxScale = Vector3.new(2.0 - squishAmount, squishAmount, 2.0 - squishAmount)
		else
			if not (m.Flags:Has(MarioFlags.METAL_CAP)) and m.InvincTimer == 0 then
				-- cap on: 3 units; cap off: 4.5 units
				m.HurtCounter += m.Flags:Has(MarioFlags.CAP_ON_HEAD) and 12 or 18
				m:PlaySoundIfNoFlag(Sounds.MARIO_ATTACKED, MarioFlags.MARIO_SOUND_PLAYED)
			end

			m.GfxScale = Vector3.new(1.8, 0.05, 1.8)
			m.ActionState = 1
		end
	elseif m.ActionState == 1 then
		if spaceUnderCeil >= 30.0 then
			m.ActionState = 2
		end
	elseif m.ActionState == 2 then
		m.ActionTimer += 1
		if m.ActionTimer >= 15 then
			-- 1 unit of health
			if m.Health < 0x0100 then
				-- LevelTriggerWarp OP_DEATH
				-- woosh, he's gone!
				m:SetAction(Action.DISAPPEARED)
			end
		elseif m.HurtCounter == 0 then
			-- un-squish animation
			m.SquishTimer = 30
			m:SetAction(Action.IDLE)
		end
	end

	-- steep floor
	if m.Floor ~= nil and m.Floor.Normal.Y < 0.5 then
		surfAngle = Util.Atan2s(m.Floor.Normal.Z, m.Floor.Normal.X)
		underSteepSurf = true
	end
	-- steep ceiling
	if m.Ceil ~= nil and -0.5 < m.Ceil.Normal.Y then
		surfAngle = Util.Atan2s(m.Ceil.Normal.Z, m.Ceil.Normal.X)
		underSteepSurf = true
	end

	if underSteepSurf then
		m.Velocity = Vector3.new(Util.Sins(surfAngle) * 10.0, 0, Util.Coss(surfAngle) * 10.0)

		-- Check if there's no floor 10 units away from the surface
		if m:PerformGroundStep() == GroundStep.LEFT_GROUND then
			-- instant un-squish
			m.SquishTimer = 0
			m:SetAction(Action.IDLE, 0)
			return false
		end
	end

	-- squished for more than 10 seconds, so kill Mario
	m.ActionArg += 1
	if m.ActionArg > 300 then
		-- 0 units of health
		m.Health = 0xFF
		m.HurtCounter = 0
		-- LevelTriggerWarp OP_DEATH
		m:SetAction(Action.DISAPPEARED)
	end

	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.A_POSE)
	return false
end)

DEF_ACTION(Action.DISAPPEARED, function(m: Mario)
	m.BodyState.ModelState:Add(ModelFlags.INVISIBLE)
	m:SetAnimation(Animations.A_POSE)
	m:StopAndSetHeightToFloor()

	if m.ActionArg > 0 then
		m.ActionArg -= 1
		--if not bit32.band(m.ActionArg, 0xFFFF) then
		--	LevelTriggerWarp(m, bit32.rshift(m.ActionArg, 16));
		--end
	end

	return false
end)

DEF_ACTION(Action.PUTTING_ON_CAP, function(m: Mario)
	local animFrame = m:SetAnimation(Animations.PUT_CAP_ON)

	if animFrame == 0 then
		-- enableTimeStop()
	end

	if animFrame == 28 then
		cutscenePutCapOn(m)
	end

	if m:IsAnimAtEnd() then
		m:SetAction(Action.IDLE)
		-- disableTimeStop()
	end

	m:StationaryGroundStep()
	return false
end)

DEF_ACTION(Action.DEBUG_FREE_MOVE, function(m: Mario)
	local controller = m.Controller

	local pos
	local speed
	local action

	m.Inertia = Vector3.zero

	speed = controller.ButtonDown:Has(Buttons.B_BUTTON) and 4 or 1
	if controller.ButtonDown:Has(Buttons.L_TRIG) then
		speed = 0.01
	end

	m:SetAnimation(Animations.A_POSE)
	pos = m.Position

	if controller.ButtonDown:Has(Buttons.U_JPAD) then
		pos += Vector3.yAxis * (16.0 * speed)
	end
	if controller.ButtonDown:Has(Buttons.D_JPAD) then
		pos -= Vector3.yAxis * (16.0 * speed)
	end

	if m.IntendedMag > 0 then
		pos += Vector3.new(32.0 * speed * Util.Sins(m.IntendedYaw), 0, 32.0 * speed * Util.Coss(m.IntendedYaw))
	end

	local floorHeight, surf = Util.FindFloor(pos)
	if surf ~= nil then
		if pos.Y < floorHeight then
			pos = Util.SetY(pos, floorHeight)
		end
		m.Position = pos
	end

	m.FaceAngle = Vector3int16.new(0, m.IntendedYaw, 0)
	m.GfxPos = Vector3.zero
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)

	if controller.ButtonPressed:Has(Buttons.A_BUTTON) then
		if m.Position.Y <= m.WaterLevel - 100 then
			action = Action.WATER_IDLE
		else
			action = Action.IDLE
		end

		m:SetAction(action)
	end

	return false
end)

DEF_ACTION(Action.SHOCKED, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_WAAAOOOW, MarioFlags.ACTION_SOUND_PLAYED)
	m:PlaySound(Sounds.MOVING_SHOCKED)
	-- setCameraShakeFromHit(SHAKE_SHOCK)

	if m:SetAnimation(Animations.SHOCKED) == 0 then
		m.ActionTimer += 1
		m.Flags:Add(MarioFlags.METAL_SHOCK)
	end

	if m.ActionArg == 0 then
		m:SetForwardVel(0)
		if m:PerformAirStep(1) == AirStep.LANDED then
			m:PlayLandingSound()
			m.ActionArg = 1
		end
	else
		if m.ActionTimer >= 6 then
			m.InvincTimer = 30
			m:SetAction(m.Health < 0x100 and Action.ELECTROCUTION or Action.IDLE)
		end
		m:StopAndSetHeightToFloor()
	end

	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
