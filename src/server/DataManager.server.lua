-- DataManager.server.lua
-- Loads and saves player data via DataStore.
-- Located in: ServerScriptService

local Players        = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared     = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local cfgDS   = GameConfig.DataStore
local store   = DataStoreService:GetDataStore(cfgDS.Name)

-- ============================================================
-- BindableFunction references (set by MoneySystem)
-- ============================================================
local loadPlayerData = ReplicatedStorage:WaitForChild("LoadPlayerData", 15)
local getSaveData    = ReplicatedStorage:WaitForChild("GetSaveData",    15)

-- ============================================================
-- DEFAULT DATA (new player template)
-- ============================================================
local DEFAULT_DATA = {
	money        = 0,
	totalEarned  = 0,
	rebirthLevel = 0,
	upgrades     = { damage = 0, production = 0, luck = 0 },
}

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

-- ============================================================
-- LOAD
-- ============================================================
local function loadData(player)
	local key = "player_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	local data
	if ok and result then
		-- Merge with defaults (handles new fields added in updates)
		data = deepCopy(DEFAULT_DATA)
		for k, v in pairs(result) do
			if type(v) == "table" then
				data[k] = data[k] or {}
				for k2, v2 in pairs(v) do data[k][k2] = v2 end
			else
				data[k] = v
			end
		end
		print(("[DataManager] Loaded data for %s (rebirth %d, $%d)"):format(
			player.Name, data.rebirthLevel, data.money
		))
	else
		data = deepCopy(DEFAULT_DATA)
		if not ok then
			warn("[DataManager] Load failed for " .. player.Name .. ": " .. tostring(result))
		else
			print("[DataManager] New player: " .. player.Name)
		end
	end

	-- Push to MoneySystem
	if loadPlayerData then
		loadPlayerData:Invoke(player, data)
	end
end

-- ============================================================
-- SAVE
-- ============================================================
local function saveData(player)
	local data = getSaveData and getSaveData:Invoke(player)
	if not data then return end

	local key = "player_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, {
			money        = data.money,
			totalEarned  = data.totalEarned,
			rebirthLevel = data.rebirthLevel,
			upgrades     = data.upgrades,
		})
	end)

	if ok then
		print(("[DataManager] Saved data for %s"):format(player.Name))
	else
		warn(("[DataManager] Save failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

-- ============================================================
-- AUTO-SAVE LOOP
-- ============================================================
task.spawn(function()
	while true do
		task.wait(cfgDS.AutoSaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	task.wait(2)  -- wait for MoneySystem & PlayerBase to init first
	loadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
end)

-- ============================================================
-- GRACEFUL SHUTDOWN (server close)
-- ============================================================
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

print(("[DataManager] Ready. Store: %s, auto-save every %ds"):format(
	cfgDS.Name, cfgDS.AutoSaveInterval
))
