--!strict

local InteractionType = {
	GROUND_POUND_OR_TWIRL = 0x01,
	PUNCH = 0x02,
	KICK = 0x04,
	TRIP = 0x08,
	SLIDE_KICK = 0x10,
	FAST_ATTACK_OR_SHELL = 0x20,
	HIT_FROM_ABOVE = 0x40,
	HIT_FROM_BELOW = 0x80,
}

InteractionType.ATTACK_NOT_FROM_BELOW = bit32.bor(
	InteractionType.GROUND_POUND_OR_TWIRL,
	InteractionType.PUNCH,
	InteractionType.KICK,
	InteractionType.TRIP,
	InteractionType.SLIDE_KICK,
	InteractionType.FAST_ATTACK_OR_SHELL,
	InteractionType.HIT_FROM_ABOVE
)

InteractionType.ANY_ATTACK = bit32.bor(
	InteractionType.GROUND_POUND_OR_TWIRL,
	InteractionType.PUNCH,
	InteractionType.KICK,
	InteractionType.TRIP,
	InteractionType.SLIDE_KICK,
	InteractionType.FAST_ATTACK_OR_SHELL,
	InteractionType.HIT_FROM_ABOVE,
	InteractionType.HIT_FROM_BELOW
)

InteractionType.ATTACK_NOT_WEAK_FROM_ABOVE = bit32.bor(
	InteractionType.GROUND_POUND_OR_TWIRL,
	InteractionType.PUNCH,
	InteractionType.KICK,
	InteractionType.TRIP,
	InteractionType.HIT_FROM_BELOW
)

return InteractionType
