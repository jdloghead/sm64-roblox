--!strict

local Flags = require(script.Flags)
export type Flags = Flags.Class

-- Fun types
type s32 = number
type f32 = number
type u32 = number
type s16 = number
type s8 = number
type u8 = number

export type Controller = {
	RawStickX: number,
	RawStickY: number,

	StickX: number,
	StickY: number,
	StickMag: number,

	ButtonDown: Flags,
	ButtonPressed: Flags,

	NotRelative: boolean?,
}

export type BodyState = {
	Action: number,

	CapState: Flags,
	EyeState: number,
	HandState: Flags,

	WingFlutter: boolean,
	ModelState: Flags,

	HeldObjLastPos: Vector3,
	GrabPos: number,

	PunchType: number,
	PunchTimer: number,

	TorsoAngle: Vector3int16,
	HeadAngle: Vector3int16,
}

export type MarioState = {
	Input: Flags,
	Flags: Flags,

	Action: Flags,
	PrevAction: Flags,
	ParticleFlags: Flags,
	HitboxHeight: number,
	HitboxRadius: number,
	TerrainType: number,
	HeldObj: Instance?,

	ActionState: number,
	ActionTimer: number,
	ActionArg: number,

	IntendedMag: number,
	IntendedYaw: number,
	InvincTimer: number,

	FramesSinceA: number,
	FramesSinceB: number,

	WallKickTimer: number,
	DoubleJumpTimer: number,

	FaceAngle: Vector3int16,
	AngleVel: Vector3int16,
	ThrowMatrix: CFrame?,

	GfxAngle: Vector3int16,
	GfxScale: Vector3,
	GfxPos: Vector3,

	SlideYaw: number,
	TwirlYaw: number,

	Position: Vector3,
	Velocity: Vector3,

	Inertia: Vector3,
	ForwardVel: number,
	SlideVelX: number,
	SlideVelZ: number,

	Wall: RaycastResult?,
	Ceil: RaycastResult?,
	Floor: RaycastResult?,

	WaterSurfacePseudoFloor: RaycastResult?,

	CeilHeightSquish: number?,
	CeilHeight: number,
	FloorHeight: number,
	FloorAngle: number,
	WaterLevel: number,
	GasLevel: number,

	BodyState: BodyState,
	Controller: Controller,

	Health: number,
	HurtCounter: number,
	HealCounter: number,
	SquishTimer: number,

	NumCoins: number,

	CapTimer: number,
	BurnTimer: number,
	PeakHeight: number,
	SteepJumpYaw: number,
	WalkingPitch: number,
	QuicksandDepth: number,
	LongJumpIsSlow: boolean,

	AnimCurrent: Animation?,
	AnimFrameCount: number,

	AnimAccel: number,
	AnimAccelAssist: number,

	AnimFrame: number,
	AnimDirty: boolean,
	AnimReset: boolean,
	AnimSetFrame: number,
	AnimSkipInterp: number,

	-- Hacky solutions...
	PoleObj: BasePart?,
	PoleYawVel: number,
	PolePos: number,
}

export type ObjectState = {
	-- Roblox helpers
	RbxConnections: { RBXScriptConnection | thread | Instance },
	RbxInstance: Instance?,
	OctreeNonstatic: boolean?,

	-- Object Fields

	-- Object Collision
	CollidedObjInteractTypes: Flags,
	NumCollidedObjs: s16,
	CollidedObjs: { any },

	-- Flags & values
	RawData: { [any]: any }, -- ?

	ActiveFlags: Flags,
	Flags: Flags,

	MarkedForDeletion: boolean?,

	-- Object data
	HitboxRadius: number,
	HitboxHeight: number,

	HurtboxRadius: number,
	HurtboxHeight: number,

	HitboxDownOffset: number?,

	Behavior: string?,

	GfxPos: Vector3,
	GfxAngle: Vector3int16,
	GfxScale: Vector3,
	ThrowMatrix: CFrame,

	-- 0x088 (0x00), the first field, is object-specific and defined below the common fields.
	Position: Vector3,
	Velocity: Vector3,

	IntangibleTimer: s32,

	ForwardVel: f32,
	ForwardVelS32: s32?,

	LeftVel: f32?,
	UpVel: f32?,

	MoveAnglePitch: s32,
	MoveAngleYaw: s32,
	MoveAngleRoll: s32,

	FaceAnglePitch: s32,
	FaceAngleYaw: s32,
	FaceAngleRoll: s32,

	Gravity: f32?,
	FloorHeight: f32,
	MoveFlags: Flags,

	-- 0x0F4-0x110 (0x1B-0x22) are object specific and defined below the common fields.
	AngleVelPitch: s32?,
	AngleVelYaw: s32?,
	AngleVelRoll: s32?,

	HeldState: u32?,
	WallHitboxRadius: f32?,

	Friction: f32?,
	Buoyancy: f32?,
	DragStrength: f32?,
	Bounciness: f32?,

	InteractType: number,
	InteractStatus: Flags,

	Action: number,
	SubAction: number,
	PrevAction: number,
	Timer: s32,

	DistanceToMario: f32?,
	AngleToMario: s32?,

	Home: Vector3,

	DamageOrCoinValue: s32?,
	Health: s32?,
	BhvParams: Flags,
	BhvParams2ndByte: number,

	InteractionSubtype: Flags,
	CollisionDistance: f32?,

	NumLootCoins: s32?,
	DrawingDistance: f32?,

	-- 0x1AC-0x1B2 (0x48-0x4A) are object specific and defined below the common fields.
	WallAngle: s32,
	FloorType: s16?,

	AngleToHome: s32?,
	Floor: RaycastResult?,
	DeathSound: Sound?,
}

export type ObjectHitboxState = {
	InteractType: u32,

	DamageOrCoinValue: s8?,
	NumLootCoins: s8?,
	Health: s8?,

	DownOffset: u8,
	Radius: s16,
	Height: s16,

	HurtboxRadius: s16,
	HurtboxHeight: s16,
}

return table.freeze({
	Flags = Flags,
})
