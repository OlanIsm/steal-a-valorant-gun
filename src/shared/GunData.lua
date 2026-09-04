-- GunData.lua
-- ModuleScript: Defines all gun types, their stats, rarity, and spawn weights.
-- Located in: ReplicatedStorage/Shared

local GunData = {}

-- ============================================================
-- RARITY DEFINITIONS
-- ============================================================
GunData.Rarities = {
	Common    = { color = Color3.fromRGB(200, 200, 200), label = "Common",    tier = 1 },
	Uncommon  = { color = Color3.fromRGB(100, 200,  50), label = "Uncommon",  tier = 2 },
	Rare      = { color = Color3.fromRGB( 50, 120, 255), label = "Rare",      tier = 3 },
	Epic      = { color = Color3.fromRGB(160,  50, 255), label = "Epic",      tier = 4 },
	Legendary = { color = Color3.fromRGB(255, 200,   0), label = "Legendary", tier = 5 },
}

-- ============================================================
-- GUN DEFINITIONS
-- money     : dollars generated per second when placed on base
-- atk       : damage dealt to enemies
-- rarity    : key into GunData.Rarities
-- weight    : relative spawn weight (higher = more common)
-- ============================================================
GunData.Guns = {
	-- COMMON (4 guns) ----------------------------------------
	{
		id       = "glock",
		name     = "Glock",
		rarity   = "Common",
		money    = 5,
		atk      = 5,
		weight   = 40,   -- most common
	},
	{
		id       = "p250",
		name     = "P250",
		rarity   = "Common",
		money    = 7,
		atk      = 7,
		weight   = 30,
	},
	{
		id       = "shotgun",
		name     = "Shotgun",
		rarity   = "Common",
		money    = 8,
		atk      = 10,
		weight   = 20,
	},
	{
		id       = "smg",
		name     = "SMG",
		rarity   = "Common",
		money    = 10,
		atk      = 12,
		weight   = 10,
	},

	-- UNCOMMON (3 guns) ----------------------------------------
	{
		id       = "ak47",
		name     = "AK-47",
		rarity   = "Uncommon",
		money    = 18,
		atk      = 22,
		weight   = 8,
	},
	{
		id       = "m4a1",
		name     = "M4A1",
		rarity   = "Uncommon",
		money    = 22,
		atk      = 28,
		weight   = 5,
	},
	{
		id       = "ump45",
		name     = "UMP-45",
		rarity   = "Uncommon",
		money    = 25,
		atk      = 32,
		weight   = 3,
	},

	-- RARE (2 guns) --------------------------------------------
	{
		id       = "phantom",
		name     = "Phantom",
		rarity   = "Rare",
		money    = 45,
		atk      = 55,
		weight   = 2,
	},
	{
		id       = "vandal",
		name     = "Vandal",
		rarity   = "Rare",
		money    = 55,
		atk      = 65,
		weight   = 1,
	},

	-- EPIC (1 gun) ---------------------------------------------
	{
		id       = "operator",
		name     = "Operator",
		rarity   = "Epic",
		money    = 85,
		atk      = 90,
		weight   = 0.5,
	},

	-- LEGENDARY (1 gun) ----------------------------------------
	-- ~12x money of Glock (satisfies "10x stronger than Common" rule)
	{
		id       = "golden_gun",
		name     = "Golden Gun",
		rarity   = "Legendary",
		money    = 120,
		atk      = 120,
		weight   = 0.1,
	},
}

-- ============================================================
-- UTILITY: Build weighted spawn pool
-- Returns a flat list used by weighted random picker
-- ============================================================
local _spawnPool = nil

function GunData.GetSpawnPool()
	if _spawnPool then return _spawnPool end

	_spawnPool = {}
	for _, gun in ipairs(GunData.Guns) do
		-- Each 0.1 weight = 1 entry in pool (multiply by 10 for resolution)
		local entries = math.floor(gun.weight * 10)
		for _ = 1, entries do
			table.insert(_spawnPool, gun)
		end
	end
	return _spawnPool
end

-- ============================================================
-- UTILITY: Get a random gun using weighted probability
-- ============================================================
function GunData.GetRandomGun(luckBonus)
	luckBonus = luckBonus or 0  -- future: upgrades shift weights upward

	local pool = GunData.GetSpawnPool()
	local index = math.random(1, #pool)
	return pool[index]
end

-- ============================================================
-- UTILITY: Get gun definition by id
-- ============================================================
function GunData.GetById(id)
	for _, gun in ipairs(GunData.Guns) do
		if gun.id == id then
			return gun
		end
	end
	return nil
end

return GunData
