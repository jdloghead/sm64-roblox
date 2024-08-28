--!strict
local PlatformDisplacement = {}

local SM64 = script.Parent.Parent
local Util = require(SM64.Util)
local Mario = require(SM64.Mario)

type Mario = Mario.Mario
type Object = any -- Use own SM64 object reference if you have own implementation

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RAD_TO_SHORT = 0x10000 / (2 * math.pi)

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

	o.Position += positionAdd
	if isMario then
		(o :: any).Inertia = positionAdd
		o.FaceAngle += faceAngleAdd
	else
		o.FaceAnglePitch += faceAngleAdd.Y
		o.FaceAngleYaw += faceAngleAdd.X
		o.FaceAngleRoll += faceAngleAdd.Z
	end
end

function PlatformDisplacement.ApplyMarioPlatformDisplacement(m: Mario)
	local floor = m.Floor
	local platform = (floor and floor.Instance) :: BasePart?
	local offFloor = math.abs(m.Position.Y - m.FloorHeight) > 4.0

	if (floor and platform) and not offFloor then
		return PlatformDisplacement.ApplyPlatformDisplacement(m, true, platform)
	end
end

return PlatformDisplacement
