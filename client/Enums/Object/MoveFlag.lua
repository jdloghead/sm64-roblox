--!strict

local MoveFlag = {
	LANDED = bit32.lshift(1, 0), -- 0x0001
	ON_GROUND = bit32.lshift(1, 1), -- 0x0002, mutually exclusive to OBJ_MOVE_LANDED
	LEFT_GROUND = bit32.lshift(1, 2), -- 0x0004
	ENTERED_WATER = bit32.lshift(1, 3), -- 0x0008
	AT_WATER_SURFACE = bit32.lshift(1, 4), -- 0x0010
	UNDERWATER_OFF_GROUND = bit32.lshift(1, 5), -- 0x0020
	UNDERWATER_ON_GROUND = bit32.lshift(1, 6), -- 0x0040
	IN_AIR = bit32.lshift(1, 7), -- 0x0080
	OUT_SCOPE = bit32.lshift(1, 8), -- 0x0100
	HIT_WALL = bit32.lshift(1, 9), -- 0x0200
	HIT_EDGE = bit32.lshift(1, 10), -- 0x0400
	ABOVE_LAVA = bit32.lshift(1, 11), -- 0x0800
	LEAVING_WATER = bit32.lshift(1, 12), -- 0x1000
	BOUNCE = bit32.lshift(1, 13), -- 0x2000
	ABOVE_DEATH_BARRIER = bit32.lshift(1, 14), -- 0x4000
}

--stylua: ignore
MoveFlag.MASK_ON_GROUND = bit32.bor(
    MoveFlag.LANDED,
    MoveFlag.ON_GROUND
)

MoveFlag.MASK_IN_WATER = bit32.bor(
	MoveFlag.ENTERED_WATER,
	MoveFlag.AT_WATER_SURFACE,
	MoveFlag.UNDERWATER_OFF_GROUND,
	MoveFlag.UNDERWATER_ON_GROUND
)

return MoveFlag
