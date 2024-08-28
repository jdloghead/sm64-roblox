--!strict

return {
	ATTACK_MASK = 0x000000FF,

	-- Mario Interaction Status
	MARIO_STUNNED = bit32.lshift(1, 0), -- 0x00000001 --
	MARIO_KNOCKBACK_DMG = bit32.lshift(1, 1), -- 0x00000002 --
	MARIO_UNK2 = bit32.lshift(1, 2), -- 0x00000004 --
	MARIO_DROP_OBJECT = bit32.lshift(1, 3), -- 0x00000008 --
	MARIO_SHOCKWAVE = bit32.lshift(1, 4), -- 0x00000010 --
	MARIO_UNK5 = bit32.lshift(1, 5), -- 0x00000020 --
	MARIO_UNK6 = bit32.lshift(1, 6), -- 0x00000040 --
	MARIO_UNK7 = bit32.lshift(1, 7), -- 0x00000080 --

	-- Object Interaction Status
	GRABBED_MARIO = bit32.lshift(1, 11), -- 0x00000800 --
	ATTACKED_MARIO = bit32.lshift(1, 13), -- 0x00002000 --
	WAS_ATTACKED = bit32.lshift(1, 14), -- 0x00004000 --
	INTERACTED = bit32.lshift(1, 15), -- 0x00008000 --
	UNK16 = bit32.lshift(1, 16), -- 0x00010000 --
	UNK17 = bit32.lshift(1, 17), -- 0x00020000 --
	UNK18 = bit32.lshift(1, 18), -- 0x00040000 --
	UNK19 = bit32.lshift(1, 19), -- 0x00080000 --
	TRAP_TURN = bit32.lshift(1, 20), -- 0x00100000 --
	HIT_MINE = bit32.lshift(1, 21), -- 0x00200000 --
	STOP_RIDING = bit32.lshift(1, 22), -- 0x00400000 --
	TOUCHED_BOB_OMB = bit32.lshift(1, 23), -- 0x00800000 --
}
