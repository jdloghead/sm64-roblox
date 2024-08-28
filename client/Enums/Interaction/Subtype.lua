--!strict

return {
	-- INTERACT_WARP
	FADING_WARP = 00000001,

	-- Damaging interactions
	DELAY_INVINCIBILITY = 00000002,
	BIG_KNOCKBACK = 00000008, -- Used by Bowser, sets Mario's forward velocity to 40 on hit --

	-- INTERACT_GRABBABLE
	GRABS_MARIO = 00000004, -- Also makes the object heavy --
	HOLDABLE_NPC = 00000010, -- Allows the object to be gently dropped, and sets vertical speed to 0 when dropped with no forwards velocity --
	DROP_IMMEDIATELY = 00000040, -- This gets set by grabbable NPCs that talk to Mario to make him drop them after the dialog is finished --
	KICKABLE = 00000100,
	NOT_GRABBABLE = 00000200, -- Used by Heavy-Ho to allow it to throw Mario, without Mario being able to pick it up --

	-- INTERACT_DOOR
	STAR_DOOR = 00000020,

	--INTERACT_BOUNCE_TOP
	TWIRL_BOUNCE = 00000080,

	-- INTERACT_STAR_OR_KEY
	NO_EXIT = 00000400,
	GRAND_STAR = 00000800,

	-- INTERACT_TEXT
	SIGN = 00001000,
	NPC = 00004000,

	-- INTERACT_CLAM_OR_BUBBA
	EATS_MARIO = 00002000,
}
