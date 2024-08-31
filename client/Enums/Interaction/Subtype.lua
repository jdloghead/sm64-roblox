--!strict

return {
	-- INTERACT_WARP
	FADING_WARP = 0x00000001,

	-- Damaging interactions
	DELAY_INVINCIBILITY = 0x00000002,
	BIG_KNOCKBACK = 0x00000008, -- Used by Bowser, sets Mario's forward velocity to 40 on hit --

	-- INTERACT_GRABBABLE
	GRABS_MARIO = 0x00000004, -- Also makes the object heavy --
	HOLDABLE_NPC = 0x00000010, -- Allows the object to be gently dropped, and sets vertical speed to 0 when dropped with no forwards velocity --
	DROP_IMMEDIATELY = 0x00000040, -- This gets set by grabbable NPCs that talk to Mario to make him drop them after the dialog is finished --
	KICKABLE = 0x00000100,
	NOT_GRABBABLE = 0x00000200, -- Used by Heavy-Ho to allow it to throw Mario, without Mario being able to pick it up --

	-- INTERACT_DOOR
	STAR_DOOR = 0x00000020,

	--INTERACT_BOUNCE_TOP
	TWIRL_BOUNCE = 0x00000080,

	-- INTERACT_STAR_OR_KEY
	NO_EXIT = 0x00000400,
	GRAND_STAR = 0x00000800,

	-- INTERACT_TEXT
	SIGN = 0x00001000,
	NPC = 0x00004000,

	-- INTERACT_CLAM_OR_BUBBA
	EATS_MARIO = 0x00002000,
}
