--!strict

return {
	DEACTIVATED = 0, -- 0x0000
	ACTIVE = bit32.lshift(1, 0), -- 0x0001
	FAR_AWAY = bit32.lshift(1, 1), -- 0x0002
	UNK2 = bit32.lshift(1, 2), -- 0x0004
	IN_DIFFERENT_ROOM = bit32.lshift(1, 3), -- 0x0008
	UNIMPORTANT = bit32.lshift(1, 4), -- 0x0010
	INITIATED_TIME_STOP = bit32.lshift(1, 5), -- 0x0020
	MOVE_THROUGH_GRATE = bit32.lshift(1, 6), -- 0x0040
	DITHERED_ALPHA = bit32.lshift(1, 7), -- 0x0080
	UNK8 = bit32.lshift(1, 8), -- 0x0100
	UNK9 = bit32.lshift(1, 9), -- 0x0200
	UNK10 = bit32.lshift(1, 10), -- 0x0400
}
