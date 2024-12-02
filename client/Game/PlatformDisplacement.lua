--!strict
local PlatformDisplacement = {}

local SM64 = script.Parent.Parent
local Util = require(SM64.Util)
local Enums = require(SM64.Enums)
local Mario = require(SM64.Mario)
local FFlags = require(SM64.FFlags)

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

-- We may need to find the ABSOLUTE center, maybe the platform could be
-- from an assembly of welded parts.
local function getCenterOfAssemblyFromPart(part: BasePart): Vector3
	local assemblyParts = part:GetConnectedParts(true) :: { any }
	local assemblyPosition = Vector3.zero
	local assemblyMass = 0

	for _, assemblyPart in assemblyParts do
		assemblyMass += assemblyPart.Mass
		assemblyPosition += assemblyPart.Position * assemblyPart.Mass
	end

	return assemblyPosition / assemblyMass
end

-- AssemblyVelocity-based inertia, in SM64 units
local function getPlatformInertia(part: BasePart, position: Vector3): (Vector3int16, Vector3)
	local angularVel = part.AssemblyAngularVelocity
	local linearVel = Util.ToSM64(part.AssemblyLinearVelocity / 30)
	local faceAngleAdd = Vector3int16.new(0, RAD_TO_SHORT * angularVel.Y / 30, 0)

	if angularVel.Magnitude > 0.0 then
		-- Calculate our displacement
		-- thx @magicoal_nerb
		local r = position - getCenterOfAssemblyFromPart(part)
		local rPrime = CFrame.fromAxisAngle(angularVel, angularVel.Magnitude / 30) * r
		return faceAngleAdd, Util.ToSM64(rPrime - r) + linearVel
	else
		return faceAngleAdd, linearVel
	end
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
		math.clamp(positionAdd.Y, -64, FFlags.PLATFORM_DISPLACE_POS_Y and math.huge or 64),
		positionAdd.Z
	)

	if isMario then
		local m = o :: Mario

		if FFlags.USE_INERTIA then
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
	local platform: Instance? = (floor and floor.Instance)

	local apply = not (math.abs(m.Position.Y - m.FloorHeight) > 4.0)

	-- Let's apply displacement on a moving hangable ceil or when wall sliding
	-- cuz it's FUN!
	if m:GetCeilType() == SurfaceClass.HANGABLE and m.Action:Has(ActionFlags.HANGING) then
		local ceil = m.Ceil
		platform = (ceil and ceil.Instance)
		apply = true
	elseif m.Action() == Action.WALL_SLIDE and m.Wall then
		local wall = m.Wall
		platform = (wall and wall.Instance)
		apply = true
	end

	if platform and apply then
		sMarioInertiaFirstFrame = true
		sShouldApplyInertia = true
		return PlatformDisplacement.ApplyPlatformDisplacement(m, true, platform :: BasePart)
	elseif sShouldApplyInertia and FFlags.USE_INERTIA then
		PlatformDisplacement.ApplyMarioInertia(m)
	end
end

--[[
 * Apply inertia based on Mario's last platform.
]]
-- https://github.com/rovertronic/BTCM-Public-Repo/blob/782195ed025b5aaa8cb04b8c9bdc45fd34305356/src/game/platform_displacement.c#L185
-- on a real note: its actually from hackersm64 LOLOLLOOOLLOOL
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
