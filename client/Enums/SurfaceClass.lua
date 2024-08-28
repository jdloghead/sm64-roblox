--!strict

return {
	DEFAULT = 0x0000, -- Environment default
	BURNING = 0x0001, -- Lava / Frostbite (in SL), but is used mostly for lava

	HANGABLE = 0x0005, -- Ceiling that Mario can climb on

	SLOW = 0x0009, -- Slow down Mario, unused
	DEATH_PLANE = 0x000A, -- Death floor

	WATER = 0x000D, -- Water, has no action, used on some waterboxes below
	FLOWING_WATER = 0x000E, -- Water (flowing), has parameters

	VERY_SLIPPERY = 0x0013, -- Very slippery, mostly used for slides
	SLIPPERY = 0x0014, -- Slippery
	NOT_SLIPPERY = 0x0015, -- Non-slippery, climbable

	SHALLOW_QUICKSAND = 0x0021, -- Shallow quicksand (depth of 10 units)
	DEEP_QUICKSAND = 0x0022, -- Quicksand (lethal, slow, depth of 160 units)
	INSTANT_QUICKSAND = 0x0023, -- Quicksand (lethal, instant)
	DEEP_MOVING_QUICKSAND = 0x0024, -- Moving quicksand (flowing, depth of 160 units)
	SHALLOW_MOVING_QUICKSAND = 0x0025, -- Moving quicksand(flowing, depth of 25 units)
	QUICKSAND = 0x0026, -- Moving quicksand (60 units)
	MOVING_QUICKSAND = 0x0027, -- Moving quicksand (flowing, depth of 60 units)
	INSTANT_MOVING_QUICKSAND = 0x002D, -- Quicksand (lethal, flowing)

	HORIZONTAL_WIND = 0x002C, -- Horizontal wind, has parameters
	VERTICAL_WIND = 0x0038, -- Death at bottom with vertical wind
}
