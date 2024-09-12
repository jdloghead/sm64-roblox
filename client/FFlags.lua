--!strict

local FFLAGS = {
	-----------------------CHEAT-----------------------
	-- Walk on every single slope angle.
	FLOOR_NEVER_SLIPPERY = false,
	-- God mode, atleast health wise.
	DEGREELESSNESS_MODE = false,
	---------------------------------------------------

	-----------------------PHYSICS-----------------------
	-- Use inertia velocity for airborne (Mario only).
	-- This is (technically) ported from Rovertronic's hack BTCM.
	-- https://github.com/rovertronic/BTCM-Public-Repo/blob/master/src/game/platform_displacement.c#L185
	USE_INERTIA = true,

	-- If it should always apply uncapped +Y displacement no matter what.
	-- Otherwise, stick to the ground (until the target has gone airborne).
	-- This requires USE_INERTIA for better behavior.
	DISPLACE_POS_Y = false,
	-----------------------------------------------------

	-----------------------COLLISION-----------------------
	-- fixes wallcucking, by picking the best wall depending on Mario's
	-- face angle. (See: https://youtu.be/TSCzC-WECw8?t=42)
	FIX_WALLCUCKING = true,

	-- instead of quarter-step with no verification, it will be a single step,
	-- then fire a ray between old position and next position to avoid clipping
	-- and other weird geometry things (See: https://youtu.be/TSCzC-WECw8?t=90)
	CONTINUOUS_INSTEAD_OF_QSTEP = true,

	-- the StationaryGroundStep function does not check for wall collisions in
	-- certain conds. if you have weird geometry or pushing walls, keep this on
	SGS_ALWAYS_PERFORMS_STEPS = true,
	------------------------------------------------------

	-----------------------GAMEPLAY-----------------------
	-- If Mario should spawn on SpawnLocations respectively.
	USE_SPAWNLOCATIONS = false,

	-- From SM64Plus (https://github.com/MorsGames/sm64plus/blob/master/src/game/mario_actions_airborne.c#L1290)
	-- Makes Mario do wall sliding (instead of timer with bonking), as seen in the modern games.
	WALL_SLIDING = true,

	-- From HackerSM64 (https://github.com/HackerN64/HackerSM64/blob/master/src/game/mario_actions_automatic.c#L295)
	-- Better hangable ceil controls.
	-- 	* Fast hanging transition
	-- 	* Slow down on sharp turns to avoid falling off
	-- 	* Move at 16 units of speed (depending on joystick magnitude)
	-- 	* Only fall down if pressing A or B instead of having to let go of A (and hold it down all the time)
	BETTER_HANGING = true,

	-- Makes Mario turn faster and slow down when doing sharp-ish turns. Only applies
	-- when Mario is in Action.WALKING and slow enough.
	FAST_TURNING = true,
	-----------------------------------------------------

	-----------------------UPDATE-----------------------
	-- Automatically calls onReset() when mario is considered to be in a dead state.
	AUTO_RESET_ON_DEAD = true,

	-- If the update() delta timer is past this number, cap there.
	-- Default is the 10FPS Interval.
	DELTA_MAX = 1 / 10,
	----------------------------------------------------

	-----------------------VISUAL-----------------------
	-- If the rendered character shouldn't have the position interpolated between frames.
	NO_CHAR_INTERP = false,
	----------------------------------------------------

	-----------------------DEBUG-----------------------
	-- Don't show debug long raycasts that hit nothing.
	RAY_DBG_IGNORE_LONG_NIL = false,

	-- Disable debug mode in-game (becomes studio only).
	DEBUG_OFF_INGAME = false,
	---------------------------------------------------
}

-- return table.freeze(FFLAGS)
return FFLAGS
