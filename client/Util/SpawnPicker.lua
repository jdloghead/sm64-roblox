--!strict
local WorldSpawns = {} :: {
	[SpawnLocation]: any,
}

local Players = game:GetService("Players")
local RNG = Random.new(os.time() * math.random())

local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function isSpawnAvailableFor(player: Player, obj: SpawnLocation): boolean
	local PlayerTeam, SpawnTeam = player.TeamColor, obj.TeamColor
	local SpawnNeutral, PlayerNeutral = obj.Neutral, player.Neutral

	-- Cannot spawn on nil spawns or disabled spawns
	if (not obj:IsDescendantOf(workspace)) or not obj.Enabled then
		return false
	end

	-- If the spawn is neutral, anyone can spawn there
	if SpawnNeutral then
		return true
	end

	-- If the player is neutral, they cannot spawn on a team spawn
	-- If the player and spawn are on different teams, they cannot spawn there
	if PlayerNeutral or (PlayerTeam ~= SpawnTeam) then
		return false
	end

	return true
end

local function getAcceptableSpawnsFor(player: Player): { SpawnLocation }
	local list = {} :: { SpawnLocation }

	for spawnLocation in WorldSpawns do
		if isSpawnAvailableFor(player, spawnLocation) then
			table.insert(list, spawnLocation)
		end
	end

	return list
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SpawnLocation detection
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function addSpawn(part: Instance)
	if (not part:IsA("SpawnLocation")) or WorldSpawns[part] then
		return
	end

	-- Add to list
	WorldSpawns[part] = true

	-- Destroyed check
	local connection
	connection = part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			WorldSpawns[part] = nil :: any
			connection:Disconnect()
			connection = nil :: any
			return
		end
	end)
end

for _, part in workspace:GetDescendants() do
	task.spawn(addSpawn, part)
end
workspace.DescendantAdded:Connect(addSpawn)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Init
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

return function(): SpawnLocation?
	local spawns = getAcceptableSpawnsFor(LocalPlayer)

	if #spawns > 0 then
		return spawns[RNG:NextInteger(1, #spawns)]
	end

	return nil
end
