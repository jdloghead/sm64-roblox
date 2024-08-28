--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action

local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags
local SurfaceClass = Enums.SurfaceClass

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Should this be on the enums?
local POLE_NONE = 0
local POLE_TOUCHED_FLOOR = 1
local POLE_FELL_OFF = 2

local HANG_NONE = 0
local HANG_HIT_CEIL_OR_OOB = 1
local HANG_LEFT_CEIL = 2

local function letGoOfLedge(m: Mario)
	local floorHeight
	m.Velocity *= Vector3.new(1, 0, 1)
	m.ForwardVel = -8

	local x = 60 * Util.Sins(m.FaceAngle.Y)
	local z = 60 * Util.Coss(m.FaceAngle.Y)

	m.Position -= Vector3.new(x, 0, z)
	floorHeight = Util.FindFloor(m.Position)

	if floorHeight < m.Position.Y - 100 then
		m.Position -= (Vector3.yAxis * 100)
	else
		m.Position = Util.SetY(m.Position, floorHeight)
	end

	return m:SetAction(Action.SOFT_BONK)
end

local function climbUpLedge(m: Mario)
	local x = 14 * Util.Sins(m.FaceAngle.Y)
	local z = 14 * Util.Coss(m.FaceAngle.Y)

	m:SetAnimation(Animations.IDLE_HEAD_LEFT)
	m.Position += Vector3.new(x, 0, z)
end

local function updateLedgeClimb(m: Mario, anim: Animation, endAction: number)
	m:StopAndSetHeightToFloor()
	m:SetAnimation(anim)

	if m:IsAnimAtEnd() then
		m:SetAction(endAction)

		if endAction == Action.IDLE then
			climbUpLedge(m)
		end
	end
end

-- Evil hack. Run.
local function getPoleValues(m: Mario): (number, Vector3)
	local poleObj = assert(m.PoleObj)

	local poleExtents = Util.GetExtents(poleObj) / Util.Scale
	local polePos = Util.ToSM64(poleObj.Position)
	local poleSize = poleExtents - polePos

	--stylua: ignore
	return
		poleSize.Y * 2, -- PoleHeight
		polePos - (Vector3.yAxis * poleSize.Y) -- PolePos
end

local function setPolePosition(m: Mario, offsetY: number): number
	local poleHeight, polePos = getPoleValues(m)
	local poleTop = poleHeight - 100.0

	local result = POLE_NONE

	if m.PolePos > poleTop then
		m.PolePos = poleTop
	end

	m.Inertia = Vector3.zero
	m.Position = Vector3.new(polePos.X, polePos.Y + m.PolePos + offsetY, polePos.Z)

	local posResolveA, collidedA = Util.FindWallCollisions(m.Position, 60.0, 50.0)
	m.Position = posResolveA
	local posResolveB, collidedB = Util.FindWallCollisions(m.Position, 30.0, 24.0)
	m.Position = posResolveB

	local collided = collidedA or collidedB
	local ceilHeight = Util.FindCeil(m.Position)

	if m.Position.Y > ceilHeight - 160.0 then
		m.Position = Util.SetY(m.Position, ceilHeight - 160.0)
		m.PolePos = m.Position.Y - polePos.Y
	end

	local floorHeight = Util.FindFloor(m.Position)
	if m.Position.Y < floorHeight then
		m:SetAction(Action.IDLE)
		result = POLE_TOUCHED_FLOOR
	elseif m.PolePos < 100 then -- hitboxDownOffset
		m:SetAction(Action.FREEFALL)
		result = POLE_FELL_OFF
	elseif collided then
		if m.Position.Y > floorHeight + 20.0 then
			m.ForwardVel = -2.0
			m:SetAction(Action.SOFT_BONK)
			result = POLE_FELL_OFF
		else
			m:SetAction(Action.IDLE)
			result = POLE_TOUCHED_FLOOR
		end
	end

	m.GfxPos = Vector3.zero
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)

	return result
end

local function playClimbingSounds(m: Mario, b: number)
	local isOnTree = false

	if b == 1 then
		if m:IsAnimPastFrame(1) then
			m:PlaySound(isOnTree and Sounds.ACTION_CLIMB_UP_TREE or Sounds.ACTION_CLIMB_UP_POLE)
		else
			m:PlaySound(isOnTree and Sounds.MOVING_SLIDE_DOWN_TREE or Sounds.MOVING_SLIDE_DOWN_POLE)
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

DEF_ACTION(Action.LEDGE_GRAB, function(m: Mario)
	local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
	local hasSpaceForMario = m.CeilHeight - m.FloorHeight >= 160

	if m.ActionTimer < 10 then
		m.ActionTimer += 1
	end

	if m.Floor and m.Floor.Normal.Y < 0.9063078 then
		return letGoOfLedge(m)
	end

	if m.Input:Has(InputFlags.Z_PRESSED, InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	if m.Input:Has(InputFlags.A_PRESSED) and hasSpaceForMario then
		return m:SetAction(Action.LEDGE_CLIMB_FAST)
	end

	if m.Input:Has(InputFlags.STOMPED) then
		return letGoOfLedge(m)
	end

	if m.ActionTimer == 10 and m.Input:Has(InputFlags.NONZERO_ANALOG) then
		if math.abs(intendedDYaw) <= 0x4000 then
			if hasSpaceForMario then
				return m:SetAction(Action.LEDGE_CLIMB_SLOW)
			end
		else
			return letGoOfLedge(m)
		end
	end

	local heightAboveFloor = m.Position.Y - m:FindFloorHeightRelativePolar(-0x8000, 30)

	if hasSpaceForMario and heightAboveFloor < 100 then
		return m:SetAction(Action.LEDGE_CLIMB_FAST)
	end

	if m.ActionArg == 0 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)
	end

	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.IDLE_ON_LEDGE)

	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_SLOW, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	if m.ActionTimer >= 28 then
		if
			m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE)
		then
			climbUpLedge(m)
			return m:CheckCommonActionExits()
		end
	end

	if m.ActionTimer == 10 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_EEUH, MarioFlags.MARIO_SOUND_PLAYED)
	end

	updateLedgeClimb(m, Animations.SLOW_LEDGE_GRAB, Action.IDLE)
	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_DOWN, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)
	updateLedgeClimb(m, Animations.CLIMB_DOWN_LEDGE, Action.LEDGE_GRAB)

	m.ActionArg = 1
	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_FAST, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_UH2, MarioFlags.MARIO_SOUND_PLAYED)
	updateLedgeClimb(m, Animations.FAST_LEDGE_GRAB, Action.IDLE)

	if m.AnimFrame == 8 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
	end

	return false
end)

local function PerformHangingStep(m: Mario, nextPos: Vector3)
	local ceil, floor, wall
	local ceilHeight, floorHeight
	local ceilOffset

	nextPos, wall = Util.FindWallCollisions(nextPos, 50, 50)

	m.Wall = wall
	floorHeight, floor = Util.FindFloor(nextPos)
	ceilHeight, ceil = Util.FindCeil(nextPos, floorHeight)

	if floor == nil then
		return HANG_HIT_CEIL_OR_OOB
	end

	if ceil == nil then
		return HANG_LEFT_CEIL
	end

	if ceilHeight - floorHeight <= 160 then
		return HANG_HIT_CEIL_OR_OOB
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return HANG_LEFT_CEIL
	end

	ceilOffset = ceilHeight - (nextPos.Y + 160.0)
	if ceilOffset < -30.0 then
		return HANG_HIT_CEIL_OR_OOB
	elseif ceilOffset > 30.0 then
		return HANG_LEFT_CEIL
	end

	nextPos = Util.SetY(nextPos, m.CeilHeight - 160)
	m.Position = nextPos

	m.Floor = floor
	m.FloorHeight = floorHeight
	m.Ceil = ceil
	m.CeilHeight = ceilHeight

	return HANG_NONE
end

local function UpdateHangMoving(m: Mario)
	local stepResult
	local nextPos = Vector3.zero
	local maxSpeed = 4.0

	m.ForwardVel += 1.0
	if m.ForwardVel > maxSpeed then
		m.ForwardVel = maxSpeed
	end

	local currY = Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y)

	m.FaceAngle = Util.SetY(m.FaceAngle, m.IntendedYaw - Util.ApproachFloat(currY, 0, 0x800, 0x800))

	m.SlideYaw = m.FaceAngle.Y
	m:SetForwardVel(m.ForwardVel)

	m.Velocity = Vector3.new(m.SlideVelX, 0.0, m.SlideVelZ)

	assert(m.Ceil)
	nextPos = Util.SetX(nextPos, m.Position.X - m.Ceil.Normal.Y * m.Velocity.X)
	nextPos = Util.SetZ(nextPos, m.Position.Z - m.Ceil.Normal.Y * m.Velocity.Z)
	nextPos = Util.SetY(nextPos, m.Position.Y)

	stepResult = PerformHangingStep(m, nextPos)

	m.GfxPos = Vector3.zero
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)
	return stepResult
end

local function UpdateHangStationary(m: Mario)
	m:SetForwardVel(0)

	m.Position = Util.SetY(m.Position, m.CeilHeight - 160.0)
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)
	m.Velocity = Vector3.zero
	m.GfxPos = Vector3.zero
end

DEF_ACTION(Action.START_HANGING, function(m: Mario)
	m.ActionTimer += 1

	if m.Input:Has(InputFlags.NONZERO_ANALOG) and m.ActionTimer >= 31 then
		return m:SetAction(Action.HANGING, 0)
	end

	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	m:SetAnimation(Animations.HANG_ON_CEILING)
	m:PlaySoundIfNoFlag(Sounds.ACTION_HANGING_STEP, MarioFlags.ACTION_SOUND_PLAYED)
	UpdateHangStationary(m)

	if m:IsAnimAtEnd() then
		m:SetAction(Action.HANGING, 0)
	end

	return false
end)

DEF_ACTION(Action.HANGING, function(m: Mario)
	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.HANG_MOVING, m.ActionArg)
	end

	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if bit32.btest(m.ActionArg, 1) then
		m:SetAnimation(Animations.HANDSTAND_LEFT)
	else
		m:SetAnimation(Animations.HANDSTAND_RIGHT)
	end

	UpdateHangStationary(m)

	return false
end)

DEF_ACTION(Action.HANG_MOVING, function(m: Mario)
	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if bit32.btest(m.ActionArg, 1) then
		m:SetAnimation(Animations.MOVE_ON_WIRE_NET_RIGHT)
	else
		m:SetAnimation(Animations.MOVE_ON_WIRE_NET_LEFT)
	end

	if m.AnimFrame == 12 then
		m:PlaySound(Sounds.ACTION_HANGING_STEP)
	end

	if m:IsAnimPastEnd() then
		m.ActionArg = bit32.bxor(m.ActionArg, 1)
		if m.Input:Has(InputFlags.NO_MOVEMENT) then
			return m:SetAction(Action.HANGING, m.ActionArg)
		end
	end

	if UpdateHangMoving(m) == 2 then
		m:SetAction(Action.FREEFALL, 0)
	end

	return false
end)

DEF_ACTION(Action.HOLDING_POLE, function(m: Mario)
	if m.Input:Has(InputFlags.Z_PRESSED) or m.Health < 0x100 then
		m.ForwardVel = -2.0
		m.PoleObj = nil :: any
		return m:SetAction(Action.SOFT_BONK)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		m.PoleObj = nil :: any
		m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
		return m:SetAction(Action.WALL_KICK_AIR)
	end

	local poleHeight = getPoleValues(m)
	local poleTop = poleHeight - 100.0

	if m.Controller.StickY > 16.0 then
		if m.PolePos < poleTop - 0.4 then
			return m:SetAction(Action.CLIMBING_POLE)
		end

		if m.Controller.StickY > 50.0 then
			return m:SetAction(Action.TOP_OF_POLE_TRANSITION)
		end
	end

	if m.Controller.StickY < -16.0 then
		m.PoleYawVel -= m.Controller.StickY * 2
		if m.PoleYawVel > 0x1000 then
			m.PoleYawVel = 0x1000
		end

		m.FaceAngle += Vector3int16.new(0, m.PoleYawVel, 0)
		m.PolePos -= m.PoleYawVel / 0x100

		playClimbingSounds(m, 2)
	else
		m.PoleYawVel = 0
		m.FaceAngle -= Vector3int16.new(0, m.Controller.StickX * 16.0, 0)
	end

	if setPolePosition(m, 0.0) == POLE_NONE then
		m:SetAnimation(Animations.IDLE_ON_POLE)
	end

	return false
end)

DEF_ACTION(Action.CLIMBING_POLE, function(m: Mario)
	local camera = workspace.CurrentCamera
	local lookVector = camera.CFrame.LookVector
	local cameraYaw = Util.Atan2s(-lookVector.Z, -lookVector.X)

	if m.Input:Has(InputFlags.A_PRESSED) then
		m.PoleObj = nil :: any
		m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
		return m:SetAction(Action.WALL_KICK_AIR)
	end

	if m.Controller.StickY < 8.0 then
		return m:SetAction(Action.HOLDING_POLE)
	end

	m.PolePos += m.Controller.StickY / 8.0
	m.PoleYawVel = 0

	local face = Util.SignedShort(cameraYaw - m.FaceAngle.Y)
	m.FaceAngle = Util.SetY(m.FaceAngle, cameraYaw - Util.ApproachFloat(face, 0, 0x400))

	if setPolePosition(m, 0.0) == POLE_NONE then
		local sp24 = m.Controller.StickY / 4.0 * 0x10000

		m:SetAnimationWithAccel(Animations.CLIMB_UP_POLE, sp24)
		playClimbingSounds(m, 1)
	end

	return false
end)

DEF_ACTION(Action.GRAB_POLE_SLOW, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)

	if setPolePosition(m, 0.0) == POLE_NONE then
		m:SetAnimation(Animations.GRAB_POLE_SHORT)
		if m:IsAnimAtEnd() then
			m:SetAction(Action.HOLDING_POLE)
		end
	end

	return false
end)

DEF_ACTION(Action.GRAB_POLE_FAST, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)
	m.FaceAngle += Vector3int16.new(0, m.PoleYawVel, 0)
	m.PoleYawVel = m.PoleYawVel * 8 / 10

	if setPolePosition(m, 0.0) == POLE_NONE then
		if m.PoleYawVel > 0x800 then
			m:SetAnimation(Animations.GRAB_POLE_SWING_PART1)
		else
			m:SetAnimation(Animations.GRAB_POLE_SWING_PART2)
			if m:IsAnimAtEnd() then
				m.PoleYawVel = 0
				m:SetAction(Action.HOLDING_POLE)
			end
		end
	end

	return false
end)

DEF_ACTION(Action.TOP_OF_POLE_TRANSITION, function(m: Mario)
	m.PoleYawVel = 0

	if m.ActionArg == 0 then
		m:SetAnimation(Animations.START_HANDSTAND)
		if m:IsAnimAtEnd() then
			return m:SetAction(Action.TOP_OF_POLE)
		end
	else
		m:SetAnimation(Animations.RETURN_FROM_HANDSTAND)
		if m.AnimFrame >= 16 then
			return m:SetAction(Action.HOLDING_POLE)
		end
	end

	setPolePosition(m, 0.0) -- OH NO!!! ITS return_mario_anim_y_translation
	return false
end)

DEF_ACTION(Action.TOP_OF_POLE, function(m: Mario)
	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.TOP_OF_POLE_JUMP)
	end
	if m.Controller.StickY < -16.0 then
		return m:SetAction(Action.TOP_OF_POLE_TRANSITION, 1)
	end

	m.FaceAngle += Vector3int16.new(0, m.Controller.StickX * 16.0)

	m:SetAnimation(Animations.HANDSTAND_IDLE)
	setPolePosition(m, 0.0) -- OH NO!!! ITS return_mario_anim_y_translation
	return false
end)
