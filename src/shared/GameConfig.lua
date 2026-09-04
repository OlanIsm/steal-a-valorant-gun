-- GameConfig.lua
-- ModuleScript: All tunable constants in one place.
-- Located in: ReplicatedStorage/Shared

local GameConfig = {}

-- ============================================================
-- GUN GENERATOR
-- ============================================================
GameConfig.Generator = {
	SpawnInterval    = 4,      -- seconds between each new gun spawning
	MaxGunsOnPad     = 5,      -- max guns allowed on the generator pad at once
	DespawnTime      = 30,     -- seconds before an unclaimed gun disappears
	SpawnHeight      = 2,      -- studs above the generator Part's position
	GunPartSize      = Vector3.new(1.5, 0.5, 3),  -- visual size of each gun Part
}

-- ============================================================
-- BASE & PRODUCTION
-- ============================================================
GameConfig.Base = {
	SlotCount        = 8,       -- slots per player base
	ProductionTick   = 1,       -- server loop tick in seconds (1 = every 1 sec)
	SlotSize         = Vector3.new(4, 0.3, 4),  -- visual size of each base slot
}

-- ============================================================
-- UPGRADES
-- ============================================================
GameConfig.Upgrades = {
	BaseCost         = 100,     -- cost of level 1 for each upgrade tree
	CostScaling      = 2.5,     -- each level costs 2.5x more
	DamagePerLevel   = 0.10,    -- +10% ATK damage per level
	ProductionPerLevel = 0.05,  -- +5% money/sec per level
	LuckPerLevel     = 0.05,    -- +5% shift toward higher rarity per level
}

-- ============================================================
-- REBIRTH
-- ============================================================
GameConfig.Rebirth = {
	MoneyThreshold   = 1000000,  -- $1,000,000 total collected to unlock rebirth
	MultiplierBase   = 1.10,     -- 1.1 ^ rebirthLevel
	StarterGuns      = 3,        -- how many Common guns to give on rebirth
}

-- ============================================================
-- COMBAT
-- ============================================================
GameConfig.Combat = {
	SpawnInterval    = 60,       -- seconds between enemy spawns
	BaseHealth       = 500,      -- enemy HP (fixed, not scaled)
	BonusMoneyDrop   = 500,      -- flat bonus money on kill
	RareDropChance   = 0.10,     -- 10% chance to drop a Rare+ gun on kill
}

-- ============================================================
-- DATASTORE
-- ============================================================
GameConfig.DataStore = {
	Name             = "GunTycoonV1",   -- change version string to wipe all data
	AutoSaveInterval = 60,              -- auto-save every 60 seconds
}

-- ============================================================
-- FORMATTING UTILITY
-- ============================================================
function GameConfig.FormatMoney(amount)
	if amount >= 1_000_000_000 then
		return string.format("$%.1fB", amount / 1_000_000_000)
	elseif amount >= 1_000_000 then
		return string.format("$%.1fM", amount / 1_000_000)
	elseif amount >= 1_000 then
		return string.format("$%.1fK", amount / 1_000)
	else
		return string.format("$%d", amount)
	end
end

return GameConfig
