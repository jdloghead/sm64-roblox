--!strict
local PlatformDisplacement = {}

----------------------------------------------FLAGS------------------------------------------------
-- Use inertia velocity for airborne (Mario only).
-- This is ported from Rovertronic's hack BTCM.
-- https://github.com/rovertronic/BTCM-Public-Repo/blob/782195ed025b5aaa8cb04b8c9bdc45fd34305356/src/game/platform_displacement.c#L185
local FFLAG_USE_INERTIA = false
-- If it should always apply uncapped +Y displacement no matter what.
-- Otherwise, stick to the ground (until the target has gone airborne).
local FFLAG_DISPLACE_POS_Y = false
---------------------------------------------------------------------------------------------------

local SM64 = script.Parent.Parent
local Util = require(SM64.Util)
local Enums = require(SM64.Enums)
local Mario = require(SM64.Mario)

local Action = Enums.Action
local ActionFlags = Enums.ActionFlags
local SurfaceClass = Enums.SurfaceClass

type Mario = Mario.Mario
type Object = any -- Use own SM64 object reference if you have own implementation

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RAD_TO_SHORT = 0x10000 / (2 * math.pi)
local XZ = Vector3.new(1, 0, 1)

local sMarioInertiaFirstFrame = false
local sShouldApplyInertia = false

-- AssemblyVelocity-based inertia, in SM64 units
--! Loses accuracy the faster it spins
--! LinearVelocity is if-ever-so-near-perfect
--  Can't win a fight between ~60FPS DeltaTime and 30FPS rigid...
local function getPlatformInertia(part: BasePart, position: Vector3): (Vector3int16, Vector3)
	local angularVel = part.AssemblyAngularVelocity
	local scalar = 30

	local faceAngleAdd = Vector3int16.new(0, RAD_TO_SHORT * angularVel.Y / scalar, 0)
	local positionAdd = Util.ToSM64(part:GetVelocityAtPosition(position) / scalar)

	return faceAngleAdd, positionAdd -- Return back to SM64 units
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Platform displacement
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--[[
 * Apply one frame of platform rotation to Mario or an object using the given
 * platform. If isMario is false, use object keys.
]]
function PlatformDisplacement.ApplyPlatformDisplacement(o: Mario | Object, isMario: boolean, platform: BasePart)
	local faceAngleAdd, positionAdd = getPlatformInertia(platform, Util.ToRoblox(o.Position))
	positionAdd = Vector3.new(
		positionAdd.X,
		math.clamp(positionAdd.Y, -64, FFLAG_DISPLACE_POS_Y and math.huge or 64),
		positionAdd.Z
	)

	if isMario then
		local m = o :: Mario

		if FFLAG_USE_INERTIA then
			m.Inertia = positionAdd
		end

		m.Position += positionAdd
		m.FaceAngle += faceAngleAdd
	else
		o.Position += positionAdd
		o.FaceAngleYaw += faceAngleAdd.Y
	end
end

--[[
 * If Mario's platform is not null, apply platform displacement.
 * Otherwise, apply inertia if allowed.
]]
function PlatformDisplacement.ApplyMarioPlatformDisplacement(m: Mario)
	local floor = m.Floor
	local platform = (floor and floor.Instance) :: BasePart?

	local offPlatform = math.abs(m.Position.Y - m.FloorHeight) > 4.0
	local climbingCeil = false

	-- Let's apply displacement on a moving hangable ceil
	-- cuz it's FUN!
	if m:GetCeilType() == SurfaceClass.HANGABLE and m.Action:Has(ActionFlags.HANGING) then
		local ceil = m.Ceil
		platform = (ceil and ceil.Instance) :: BasePart?
		climbingCeil = true
	end

	if platform and ((not offPlatform) or climbingCeil) then
		sMarioInertiaFirstFrame = true
		sShouldApplyInertia = true
		return PlatformDisplacement.ApplyPlatformDisplacement(m, true, platform)
	elseif sShouldApplyInertia and FFLAG_USE_INERTIA then
		PlatformDisplacement.ApplyMarioInertia(m)
	end
end

--[[
 * Apply inertia based on Mario's last platform.
]]
-- https://github.com/rovertronic/BTCM-Public-Repo/blob/782195ed025b5aaa8cb04b8c9bdc45fd34305356/src/game/platform_displacement.c#L185
function PlatformDisplacement.ApplyMarioInertia(m: Mario)
	-- Remove downward displacement
	if m.Inertia.Y < 0 then
		m.Inertia *= XZ
	end

	-- On the first frame of leaving the ground, boost Mario's y velocity
	if sMarioInertiaFirstFrame then
		m.Velocity += Vector3.yAxis * m.Inertia.Y
		sMarioInertiaFirstFrame = false
	end

	-- Drag
	m.Inertia = Vector3.new(m.Inertia.X * 0.97, 0, m.Inertia.Z * 0.97)

	-- Stop applying inertia once Mario has landed, or when ground pounding
	if not m.Action:Has(ActionFlags.AIR) or m.Action() == Action.GROUND_POUND then
		if m:GetFloorType() ~= SurfaceClass.FLOWING_WATER then
			m.Inertia = Vector3.zero
		end
	end
end

return PlatformDisplacement
