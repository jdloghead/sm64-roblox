--!strict
--stylua: ignore

-- https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/object_list_processor.h#L28

--[[
 * Every object is categorized into an object list, which controls the order
 * they are processed and which objects they can collide with.
]]
return {
	PLAYER 		= 0,  -- Mario

	DESTRUCTIVE = 2,  -- Things that can be used to destroy other objects,
					  -- like bob-omb and corkboxes

	GENACTOR 	= 4,  -- General actors. Most normal 'enemies' or actors are
					  -- on this list. MIPS, bullet bill, bully, etc)

	PUSHABLE 	= 5,  -- Pushable actors. This is a group of octors which
					  -- can push eachother around as well as their árent
					  -- objects. (goombas, koopas, spinies)

	LEVEL 		= 6,  -- Level objects. General level objects such as heart, star

	DEFAULT 	= 8,  -- Default objects. Objects that didnt start with a 00
				 	  -- command are put here, so this is treated as a default.

	SURFACE 	= 9,  -- Surface objects. Objects that specifically have surface
					  -- collision and not object collision. (thwomp, whomp, etc)

	POLELIKE 	= 10, -- Polelike objects. Objects that attract or otherwise
					  -- "cling" Mario similar to a pole action. (hoot, whirlpool, trees/poles, etc)
	SPAWNER 	= 11, -- spawnmers

	UNIMPORTANT = 12, -- Unimportant objects. Objects that will not
					  -- load if there are not enough object slots: they will also
					  -- be manually unloaded to make room for slots if the list
					  -- gets exhausted.
}

-- I wanna be a human being, not a human doing
-- I couldn't keep that pace up if I tried
-- The source of my intention really isn't crime prevention
-- My intention is prevention of the lie, yeah
-- Welcome to that Scatman's World
