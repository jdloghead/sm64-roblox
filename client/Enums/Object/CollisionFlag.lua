--!strict

local CollisionFlag = {
	GROUNDED = bit32.lshift(1, 0),
	HIT_WALL = bit32.lshift(1, 1),
	UNDERWATER = bit32.lshift(1, 2),
	NO_Y_VEL = bit32.lshift(1, 3),
}

CollisionFlag.LANDED = bit32.bor(CollisionFlag.GROUNDED, CollisionFlag.NO_Y_VEL)

return CollisionFlag
