--!strict
local Util = {
	GlobalTimer = 0,
	Scale = 1 / 20,
}

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Core = script.Parent.Parent

local Enums = require(Core.Client.Enums)

local SurfaceClass = Enums.SurfaceClass

----------------------------------------------FLAGS------------------------------------------------
-- Don't show debug long raycasts that hit nothing
local FFLAG_RAY_DBG_IGNORE_LONG_NIL = false
----------------------------------------------FLAGS------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true

local SHORT_TO_RAD = (2 * math.pi) / 0x10000
local RAD_TO_SHORT = 0x10000 / (2 * math.pi)
local VECTOR3_XZ = Vector3.one - Vector3.yAxis

-- Converts an angle in degrees to sm64's s16 angle units. For example, DEGREES(90) == 0x4000
local function DEGREES(x: number): number
	return Util.SignedShort(x * RAD_TO_SHORT)
end

-- Converts an angle in degrees to sm64's angle units with un-rounded range.
local function INT_DEGREES(x: number): number
	return math.floor(x * RAD_TO_SHORT)
end

local fadeOut = TweenInfo.new(0.5)

local waterPlane = Instance.new("BoxHandleAdornment")
waterPlane.Size = Vector3.new(48, 0, 48)
waterPlane.Adornee = workspace.Terrain
waterPlane.Transparency = 0.5
waterPlane.Name = "WaterPlane"

local focalPlane = waterPlane:Clone()
focalPlane.Size = Vector3.new(4, 0, 4)
focalPlane.Color3 = Color3.new(1, 0, 1)
focalPlane.Name = "FocalPlane"
focalPlane.Transparency = 0.1
focalPlane.Parent = waterPlane

-- [!!] Photosensitivity warning for this debug util
-- causes flashing colors sometimes
local wallSurfacePlane = Instance.new("Decal")
wallSurfacePlane.Texture = "rbxassetid://11996254337"
wallSurfacePlane.Name = "CollisionSurfacePlane"
wallSurfacePlane.Transparency = 0.5
wallSurfacePlane.ZIndex = 512
wallSurfacePlane.Color3 = Color3.fromRGB(128, 255, 0)

local floorSurfacePlane = wallSurfacePlane:Clone()
floorSurfacePlane.Color3 = Color3.fromRGB(0, 64, 255)

local ceilSurfacePlane = wallSurfacePlane:Clone()
ceilSurfacePlane.Color3 = Color3.fromRGB(200, 0, 0)

local CARDINAL = {
	-Vector3.xAxis,
	-Vector3.zAxis,
	Vector3.xAxis,
	Vector3.zAxis,
}

local CONSTRUCTORS = {
	Vector3 = Vector3.new,
	Vector3int16 = Vector3int16.new,
}

-- Hopefully this isn't harsh on mem usage
local TagParams: { [string]: RaycastParams } = {}
local GetTagParams: (string) -> RaycastParams
do
	-- Add new parts to filters
	local function append(params: RaycastParams, object: BasePart)
		if object:IsDescendantOf(workspace.CurrentCamera) or object:IsDescendantOf(workspace.Terrain) then
			return
		end

		params:AddToFilter(object)

		local removing: RBXScriptConnection
		removing = object.AncestryChanged:Connect(function()
			if object:IsDescendantOf(workspace) then
				return
			end

			-- :(
			local filter = params.FilterDescendantsInstances
			table.remove(filter, table.find(filter, object))
			params.FilterDescendantsInstances = filter

			-- Goodbye.
			removing:Disconnect()
			removing = nil :: any
		end)
	end

	workspace.DescendantAdded:Connect(function(part)
		for tag, params in TagParams do
			if part:HasTag(tag) and part:IsA("BasePart") then
				append(params, part)
			end
		end
	end)

	GetTagParams = function(tag: string): RaycastParams
		if TagParams[tag] then
			return TagParams[tag]
		end

		local new = RaycastParams.new()
		new.FilterType = Enum.RaycastFilterType.Include
		TagParams[tag] = new

		for _, object: Instance in CollectionService:GetTagged(tag) do
			if object:IsA("BasePart") and object:IsDescendantOf(workspace) then
				append(new, object)
			end
		end

		return new
	end

	-- Ok!
	TagParams.RobloxTerrain = RaycastParams.new()
	TagParams.RobloxTerrain.FilterType = Enum.RaycastFilterType.Include
	TagParams.RobloxTerrain.FilterDescendantsInstances = { workspace.Terrain }
end

-- To assist with making proper BLJ-able staircases.
-- (or just plain ignoring some collision types)
-- Most staircases in 64 don't have wall-type collision and that's why you're able to BLJ on them.
-- (unless its collision is a slope that's not steep enough)
local function shouldIgnoreSurface(result: RaycastResult?, side: string): (RaycastResult?, boolean)
	if result and type(side) == "string" then
		result = if result.Instance:HasTag(`CollIgnore{side}`) then nil else result
		return result, (result == nil)
	end

	return result, false
end

local function normalIdFromRaycast(result: RaycastResult): Enum.NormalId
	local part = result.Instance :: BasePart
	local direction = result.Normal

	local maxDot = 0
	local maxNormalId = Enum.NormalId.Front
	for _, normalId in Enum.NormalId:GetEnumItems() do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.fromNormalId(normalId))
		local dot = normal:Dot(direction)
		if dot > 0 and dot > maxDot then
			maxDot = dot
			maxNormalId = normalId
		end
	end

	return maxNormalId
end

-- stylua: ignore
local function vectorModifier(getArgs: (Vector3 | Vector3int16, number) -> (number, number, number)):
	((vec: Vector3, value: number) -> Vector3) & 
	((vec: Vector3int16, value: number) -> Vector3int16)

	return function (vector, new)
		local constructor = CONSTRUCTORS[typeof(vector)]
		return constructor(getArgs(vector, new))
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Util
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Util.SetX = vectorModifier(function(vector, x)
	return x, vector.Y, vector.Z
end)

Util.SetY = vectorModifier(function(vector, y)
	return vector.X, y, vector.Z
end)

Util.SetZ = vectorModifier(function(vector, z)
	return vector.X, vector.Y, z
end)

function Util.ToRoblox(v: Vector3)
	return v * Util.Scale
end

function Util.ToSM64(v: Vector3)
	return v / Util.Scale
end

function Util.ToEulerAngles(v: Vector3int16): Vector3
	return Vector3.new(v.X, v.Y, v.Z) * SHORT_TO_RAD
end

function Util.ToRotation(v: Vector3int16): CFrame
	local angle = Util.ToEulerAngles(v)

	-- stylua: ignore
	local matrix = CFrame.fromAxisAngle(Vector3.yAxis, angle.Y)
	             * CFrame.fromAxisAngle(Vector3.xAxis, -angle.X)
	             * CFrame.fromAxisAngle(Vector3.zAxis, -angle.Z)

	return matrix
end

-- Returns Pitch, Yaw and Roll from a CFrame in Signed 16-bit int format.
function Util.CFrameToSM64Angles(cframe: CFrame): (number, number, number)
	local lookVector = cframe.LookVector

	local pitch = DEGREES(math.deg(math.asin(lookVector.Y)))
	local yaw = Util.Atan2s(-lookVector.X, -lookVector.Z)
	local roll = DEGREES(math.deg(math.atan2(lookVector.Y, math.sqrt(lookVector.X ^ 2 + lookVector.Z ^ 2))))

	return pitch, yaw, roll
end

-- Converts a BasePart's AssemblyAngularVelocity to Pitch Yaw Roll in Signed 16-bit int format.
-- For: AngleVelPitch, AngleVelYaw, AngleVelRoll
function Util.AngularVelocityToSM64Angles(angularVel: Vector3): (number, number, number)
	local pitch = INT_DEGREES(math.deg(angularVel.Y))
	local yaw = INT_DEGREES(math.deg(angularVel.X))
	local roll = INT_DEGREES(math.deg(angularVel.Z))

	return pitch, yaw, roll
end

-- borrowed from @poopbarreI
function Util.GetExtents(part: BasePart): Vector3
	local cframe = part.CFrame
	local size = part.Size * 0.5

	return cframe.Position
		+ cframe.RightVector:Abs() * size.X
		+ cframe.UpVector:Abs() * size.Y
		+ cframe.LookVector:Abs() * size.Z
end

function Util.DebugWater(waterLevel: number)
	if script:GetAttribute("Debug") then
		local robloxLevel = (waterLevel * Util.Scale) + 0.01
		local focus = workspace.CurrentCamera.Focus

		local x = math.floor(focus.X / 4) * 4
		local z = math.floor(focus.Z / 4) * 4

		local cf = CFrame.new(x, robloxLevel, z)
		waterPlane.Parent = script

		focalPlane.CFrame = cf
		waterPlane.CFrame = cf
	else
		waterPlane.Parent = nil
	end
end

function Util.DebugCollisionFaces(wall: RaycastResult?, ceil: RaycastResult?, floor: RaycastResult?)
	for decal, hit in
		{
			[wallSurfacePlane] = wall or false,
			[ceilSurfacePlane] = ceil or false,
			[floorSurfacePlane] = floor or false,
		}
	do
		if script:GetAttribute("Debug") then
			local part: BasePart? = if type(hit) ~= "boolean"
				then hit :: RaycastResult and hit.Instance :: BasePart
				else nil

			if
				(hit and part)
				and part ~= workspace.Terrain
				and (RunService:IsStudio() and true or part.Transparency < 1)
			then
				decal.Face = normalIdFromRaycast(hit :: RaycastResult)
				decal.Parent = part
				continue
			end
		end

		decal.Parent = nil
	end
end

function Util.Raycast(pos: Vector3, dir: Vector3, maybeParams: RaycastParams?, worldRoot: WorldRoot?): RaycastResult?
	local root = worldRoot or workspace
	local params = maybeParams or rayParams
	local result = root:Raycast(pos, dir, params)

	local length = result and result.Distance or dir.Magnitude

	if script:GetAttribute("Debug") and not (FFLAG_RAY_DBG_IGNORE_LONG_NIL and length > 256 and result == nil) then
		local color = Color3.new(result and 0 or 1, result and 1 or 0, 0)

		local line = Instance.new("LineHandleAdornment")
		line.Length = length
		line.CFrame = CFrame.new(pos, pos + dir)
		line.Thickness = 6
		line.Color3 = color
		line.Adornee = workspace.Terrain
		line.Parent = workspace.Terrain

		local tween = TweenService:Create(line, fadeOut, {
			Transparency = 1,
		})

		tween:Play()
		task.delay(fadeOut.Time, line.Destroy, line)
	end

	return result
end

-- stylua: ignore
function Util.RaycastSM64(pos: Vector3, dir: Vector3, maybeParams: RaycastParams?, worldRoot: WorldRoot?): RaycastResult?
    local result: RaycastResult? = Util.Raycast(pos * Util.Scale, dir * Util.Scale, maybeParams or rayParams, worldRoot)

    if result then
        -- Cast back to SM64 unit scale.
        result = {
            Normal = result.Normal,
            Material = result.Material,
            Instance = result.Instance,
            Distance = result.Distance / Util.Scale,
            Position = result.Position / Util.Scale,
        } :: any
    end

    return result
end

function Util.FindFloor(pos: Vector3, dir: Vector3?): (number, RaycastResult?)
	local newPos = pos
	local height = -11000

	dir = typeof(dir) == "Vector3" and dir or -Vector3.yAxis * 15000 / Util.Scale

	if Core:GetAttribute("TruncateBounds") then
		local trunc = Vector3int16.new(pos.X, pos.Y, pos.Z)

		if math.abs(trunc.X) >= 0x2000 then
			return height, nil
		end

		if math.abs(trunc.Z) >= 0x2000 then
			return height, nil
		end

		newPos = Vector3.new(trunc.X, trunc.Y, trunc.Z)
	end

	-- Odd solution for parts that have their floor ignored
	-- while being above a floor that you can stand on
	-- (exposed ceiling stuff)
	-- Behavior is technically similar to SURFACE_INTANGIBLE

	local result
	local unqueried: { [BasePart]: any } = {}

	for i = 1, 2 do
		result = Util.RaycastSM64(newPos + (Vector3.yAxis * 100), dir, rayParams, workspace)
		local _, ignored = shouldIgnoreSurface(result, "Floor")
		local hit: BasePart? = result and (result.Instance :: BasePart)

		if (ignored and result) and (hit and hit.CanQuery and hit.CanCollide) then
			unqueried[hit] = true
			hit.CanCollide = false
			hit.CanQuery = false
			result = nil

			continue
		end

		if result then
			height = Util.SignedShort(result.Position.Y)
			result.Position = Vector3.new(pos.X, height, pos.Z)
			break
		end
	end

	for part in unqueried do
		part.CanCollide = true
		part.CanQuery = true
	end
	unqueried = nil :: any

	return height, result
end

function Util.FindCeil(pos: Vector3, height: number?): (number, RaycastResult?)
	local truncateBounds = Core:GetAttribute("TruncateBounds")
	local newHeight = truncateBounds and 10000 or math.huge

	if truncateBounds then
		local trunc = Vector3int16.new(pos.X, pos.Y, pos.Z)

		if math.abs(trunc.X) >= 0x2000 then
			return newHeight, nil
		end

		if math.abs(trunc.Z) >= 0x2000 then
			return newHeight, nil
		end

		pos = Vector3.new(trunc.X, trunc.Y, trunc.Z)
	end

	local head = Vector3.new(pos.X, (height or pos.Y) + 80, pos.Z)
	local result = Util.RaycastSM64(head, Vector3.yAxis * 10000, rayParams)
	result = shouldIgnoreSurface(result, "Ceil")

	if result then
		newHeight = result.Position.Y
	end

	return newHeight, result
end

function Util.FindWallCollisions(
	pos: Vector3,
	offset: number,
	radius: number
): (Vector3, RaycastResult?, { RaycastResult })
	local origin = pos + Vector3.new(0, offset, 0)
	local lastWall: RaycastResult?
	local walls = {} :: { RaycastResult }
	local disp = Vector3.zero

	local radiusD = (radius + 0.1)

	for _, dir in CARDINAL do
		local contact = Util.RaycastSM64(origin, dir * radiusD)
		contact = shouldIgnoreSurface(contact, "Wall")

		if contact then
			local normal = contact.Normal

			if math.abs(normal.Y) < 0.01 then
				local surface = contact.Position
				local move = (surface - pos) * VECTOR3_XZ
				local dist = move.Magnitude

				if dist < radius then
					disp += (contact.Normal * VECTOR3_XZ) * (radius - dist)
				end

				if dist < radiusD then
					lastWall = contact
					table.insert(walls, contact)
				end
			end
		end
	end

	return pos + disp, lastWall, walls
end

function Util.GetFloorType(floor: RaycastResult?): number
	local instance: BasePart? = floor and floor.Instance :: BasePart

	if floor and instance then
		local material: Enum.Material = instance.Material

		local ManualDefine = instance:GetAttribute("FloorSurfaceClass")
		if SurfaceClass[ManualDefine] then
			return SurfaceClass[ManualDefine]
		end

		-- Lava surface check
		if material == Enum.Material.CrackedLava or instance:HasTag("Lava") then
			return SurfaceClass.BURNING
		end

		-- Quicksand surface check
		if (string.match(string.lower(instance.Name), "quicksand")) or instance:HasTag("Quicksand") then
			local QuicksandType = instance:GetAttribute("QuicksandType")
			if
				typeof(QuicksandType) == "string"
				and string.match(QuicksandType, "QUICKSAND")
				and SurfaceClass[QuicksandType]
			then
				return SurfaceClass[QuicksandType]
			end

			return SurfaceClass.QUICKSAND
		end
	end

	return 0
end

function Util.GetCeilType(ceil: RaycastResult?): number
	local instance: BasePart? = ceil and ceil.Instance :: BasePart

	if ceil and instance then
		local material: Enum.Material = instance.Material

		local ManualDefine = instance:GetAttribute("CeilSurfaceClass")
		if SurfaceClass[ManualDefine] then
			return SurfaceClass[ManualDefine]
		end

		if instance:HasTag("Hangable") or material == Enum.Material.DiamondPlate then
			return SurfaceClass.HANGABLE
		end
	end

	return 0
end

function Util.GetWallType(wall: RaycastResult?): number
	local instance: BasePart? = wall and wall.Instance :: BasePart

	if wall and instance then
		local material: Enum.Material = instance.Material

		local ManualDefine = instance:GetAttribute("WallSurfaceClass")
		if SurfaceClass[ManualDefine] then
			return SurfaceClass[ManualDefine]
		end

		-- Lava surface check
		if material == Enum.Material.CrackedLava or instance:HasTag("Lava") then
			return SurfaceClass.BURNING
		end
	end

	return 0
end

function Util.GetIgnoredCollisions(ray: RaycastResult?): (boolean, boolean, boolean)
	local _, ignoreWall = shouldIgnoreSurface(ray, "Wall")
	local _, ignoreFloor = shouldIgnoreSurface(ray, "Floor")
	local _, ignoreCeil = shouldIgnoreSurface(ray, "Ceil")

	return ignoreWall, ignoreFloor, ignoreCeil
end

-- stylua: ignore
function Util.FindTaggedPlane(pos: Vector3, tag: string): (number, RaycastResult?)
	local height = -11000
	local result = Util.RaycastSM64(
		pos + (Vector3.yAxis * 5000),
		Vector3.yAxis * -10000,
		GetTagParams(tag)
	)

	if result then
		height = result.Position.Y
	end

	return height, result
end

function Util.GetWaterLevel(pos: Vector3): (number, RaycastResult?)
	-- Get water height from part planes.
	-- Note that even if you're not inside of them, you'll still
	-- swim there, since it's just based on the position the Raycast
	-- landed on.
	local waterHeightFromPlane, waterPlane = Util.FindTaggedPlane(pos, "Water")
	if waterPlane then
		return waterHeightFromPlane, waterPlane
	end

	-- Check terrain water voxels instead
	local terrain = workspace.Terrain
	local robloxPos = Util.ToRoblox(pos)
	local voxelPos = terrain:WorldToCellPreferSolid(robloxPos)

	local voxelRegion = Region3.new(voxelPos * 4, (voxelPos + Vector3.one + (Vector3.yAxis * 3)) * 4)
	voxelRegion = voxelRegion:ExpandToGrid(4)

	local materials, occupancies = terrain:ReadVoxels(voxelRegion, 4)
	local size: Vector3 = occupancies.Size
	local waterLevel = -11000

	for y = 1, size.Y do
		local occupancy = occupancies[1][y][1]
		local material = materials[1][y][1]

		if occupancy >= 0.9 and material == Enum.Material.Water then
			local top = ((voxelPos.Y * 4) + (4 * y + 2))
			waterLevel = math.max(waterLevel, top / Util.Scale)
		end
	end

	-- stylua: ignore
	local terrainWaterPseudoFloor: RaycastResult? = Util.RaycastSM64(
		pos + (Vector3.yAxis * 32),
		-Vector3.yAxis * 150,
		TagParams.RobloxTerrain
	)

	if terrainWaterPseudoFloor and terrainWaterPseudoFloor.Material == Enum.Material.Water then
		if waterLevel < terrainWaterPseudoFloor.Position.Y then
			waterLevel = terrainWaterPseudoFloor.Position.Y
		end
	else
		terrainWaterPseudoFloor = nil :: any
	end

	return waterLevel, terrainWaterPseudoFloor :: any?
end

function Util.SignedShort(x: number)
	return -0x8000 + math.floor((x + 0x8000) % 0x10000)
end

function Util.SignedInt(x: number)
	return -0x80000000 + math.floor(x + 0x80000000) % 0x100000000
end

function Util.ApproachFloat(current: number, target: number, inc: number, dec: number?): number
	if dec == nil then
		dec = inc
	end

	assert(dec)

	if current < target then
		current = math.min(target, current + inc)
	else
		current = math.max(target, current - dec)
	end

	return current
end

function Util.ApproachInt(current: number, target: number, inc: number, dec: number?): number
	if dec == nil then
		dec = inc
	end

	assert(dec)

	if current < target then
		current = Util.SignedInt(current + inc)
		current = math.min(target, current)
	else
		current = Util.SignedInt(current - dec)
		current = math.max(target, current)
	end

	return Util.SignedInt(current)
end

function Util.ApproachShort(current: number, target: number, inc: number): number
	local dist = Util.SignedShort(target - current)

	if dist >= 0 then
		if dist > inc then
			current += inc
		else
			current = target
		end
	else
		if dist < -inc then
			current -= inc
		else
			current = target
		end
	end

	return Util.SignedShort(current)
end

function Util.Sins(short: number): number
	local value = Util.SignedShort(short)
	value = math.floor(value / 16) * 16

	return math.sin(value * SHORT_TO_RAD)
end

function Util.Coss(short: number): number
	local value = Util.SignedShort(short)
	value = math.floor(value / 16) * 16

	return math.cos(short * SHORT_TO_RAD)
end

local function atan2_lookup(y: number, x: number)
	local value = math.atan2(y, x) / SHORT_TO_RAD
	value = math.floor(value / 16) * 16
	return Util.SignedShort(value)
end

function Util.Atan2s(y: number, x: number): number
	local ret: number

	if x >= 0 then
		if y >= 0 then
			if y >= x then
				ret = atan2_lookup(x, y)
			else
				ret = 0x4000 - atan2_lookup(y, x)
			end
		else
			y = -y

			if y < x then
				ret = 0x4000 + atan2_lookup(y, x)
			else
				ret = 0x8000 - atan2_lookup(x, y)
			end
		end
	else
		x = -x

		if y < 0 then
			y = -y

			if y >= x then
				ret = 0x8000 + atan2_lookup(x, y)
			else
				ret = 0xC000 - atan2_lookup(y, x)
			end
		else
			if y < x then
				ret = 0xC000 + atan2_lookup(y, x)
			else
				ret = -atan2_lookup(x, y)
			end
		end
	end

	return Util.SignedShort(ret)
end

return Util
