-- MoneySystem.server.lua
-- Handles: collect money from pot, buy upgrades, trigger rebirth.
-- Communicates with PlayerBase via BindableFunction API.
-- Located in: ServerScriptService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared       = ReplicatedStorage:WaitForChild("Shared")
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local cfgU = GameConfig.Upgrades
local cfgR = GameConfig.Rebirth

-- ============================================================
-- PLAYER DATA (in-memory; DataManager will persist this)
-- ============================================================
-- Schema per player:
-- {
--   money        = 0,       -- wallet (spendable)
--   totalEarned  = 0,       -- lifetime total (rebirth trigger)
--   rebirthLevel = 0,
--   upgrades     = { damage=0, production=0, luck=0 }
-- }
local playerData = {}

-- ============================================================
-- BINDABLE API REFERENCES (from PlayerBase)
-- ============================================================
local baseAPI = ReplicatedStorage:WaitForChild("PlayerBaseAPI", 15)

local function callBaseAPI(fnName, ...)
	local bf = baseAPI and baseAPI:FindFirstChild(fnName)
	if bf then return bf:Invoke(...) end
	warn("[MoneySystem] PlayerBaseAPI missing: " .. fnName)
end

-- ============================================================
-- UTILITIES
-- ============================================================
local function getRebirthMultiplier(level)
	return cfgR.MultiplierBase ^ level   -- 1.1 ^ rebirthLevel
end

local function getUpgradeCost(currentLevel)
	return math.floor(cfgU.BaseCost * (cfgU.CostScaling ^ currentLevel))
end

local function getProdMultiplier(data)
	local rebirth  = getRebirthMultiplier(data.rebirthLevel)
	local upgrade  = 1 + (data.upgrades.production * cfgU.ProductionPerLevel)
	return rebirth * upgrade
end

local function pushUpdate(player)
	local data = playerData[player]
	if not data then return end
	local event = RemoteEvents.Get("UpdatePlayerData")
	if not event then return end

	local baseData = callBaseAPI("GetBaseData", player)

	-- Merge money info into base data for client
	local payload = {
		money         = data.money,
		totalEarned   = data.totalEarned,
		rebirthLevel  = data.rebirthLevel,
		upgrades      = data.upgrades,
		rebirthReady  = data.totalEarned >= cfgR.MoneyThreshold,
		upgradeCosts  = {
			damage     = getUpgradeCost(data.upgrades.damage),
			production = getUpgradeCost(data.upgrades.production),
			luck       = getUpgradeCost(data.upgrades.luck),
		},
		-- Base info
		baseId        = baseData and baseData.baseId,
		inventory     = baseData and baseData.inventory or {},
		slots         = baseData and baseData.slots or {},
		potMoney      = baseData and baseData.potMoney or 0,
	}
	event:FireClient(player, payload)
end

-- ============================================================
-- PLAYER INIT / CLEANUP
-- ============================================================
local function initPlayer(player)
	playerData[player] = {
		money        = 0,
		totalEarned  = 0,
		rebirthLevel = 0,
		upgrades     = { damage = 0, production = 0, luck = 0 },
	}
	-- DataManager will overwrite this with saved data if it exists
	print("[MoneySystem] Initialized data for " .. player.Name)
end

local function cleanupPlayer(player)
	playerData[player] = nil
end

-- Allow DataManager to inject loaded data
local loadAPI = Instance.new("BindableFunction")
loadAPI.Name   = "LoadPlayerData"
loadAPI.Parent = ReplicatedStorage
loadAPI.OnInvoke = function(player, savedData)
	if not playerData[player] then initPlayer(player) end
	local d = playerData[player]
	d.money        = savedData.money        or 0
	d.totalEarned  = savedData.totalEarned  or 0
	d.rebirthLevel = savedData.rebirthLevel or 0
	d.upgrades     = savedData.upgrades     or { damage=0, production=0, luck=0 }
	-- Push production multiplier to PlayerBase
	callBaseAPI("SetProductionMultiplier", player, getProdMultiplier(d))
	pushUpdate(player)
end

-- Allow DataManager to read data for saving
local saveAPI = Instance.new("BindableFunction")
saveAPI.Name   = "GetSaveData"
saveAPI.Parent = ReplicatedStorage
saveAPI.OnInvoke = function(player)
	return playerData[player]
end

-- ============================================================
-- COLLECT MONEY (client clicks collection pot)
-- ============================================================
RemoteEvents.Get("CollectMoney").OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local earned = callBaseAPI("CollectPot", player) or 0
	if earned <= 0 then return end

	data.money       += earned
	data.totalEarned += earned

	pushUpdate(player)
end)

-- ============================================================
-- BUY UPGRADE
-- client sends: upgradeName ("damage" | "production" | "luck")
-- ============================================================
RemoteEvents.Get("BuyUpgrade").OnServerEvent:Connect(function(player, upgradeName)
	local data = playerData[player]
	if not data then return end
	if not data.upgrades[upgradeName] then
		warn("[MoneySystem] Unknown upgrade: " .. tostring(upgradeName))
		return
	end

	local currentLevel = data.upgrades[upgradeName]
	local cost         = getUpgradeCost(currentLevel)

	if data.money < cost then return end  -- can't afford

	data.money                    -= cost
	data.upgrades[upgradeName]     = currentLevel + 1

	-- Apply production multiplier change to PlayerBase
	if upgradeName == "production" then
		callBaseAPI("SetProductionMultiplier", player, getProdMultiplier(data))
	end

	print(("[MoneySystem] %s bought %s upgrade → level %d (cost $%d)"):format(
		player.Name, upgradeName, currentLevel + 1, cost
	))

	pushUpdate(player)
end)

-- ============================================================
-- REBIRTH
-- ============================================================
RemoteEvents.Get("TriggerRebirth").OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	if data.totalEarned < cfgR.MoneyThreshold then
		warn("[MoneySystem] Rebirth blocked — not enough totalEarned: " .. player.Name)
		return
	end

	-- Increment rebirth
	data.rebirthLevel  += 1
	-- Reset economy
	data.money          = 0
	data.totalEarned    = 0
	data.upgrades       = { damage = 0, production = 0, luck = 0 }

	-- Reset base (guns + slots cleared)
	callBaseAPI("ResetBase", player)

	-- Recalculate production (now with higher rebirth multiplier)
	callBaseAPI("SetProductionMultiplier", player, getProdMultiplier(data))

	print(("[MoneySystem] %s rebirths! Level %d, multiplier x%.2f"):format(
		player.Name, data.rebirthLevel, getRebirthMultiplier(data.rebirthLevel)
	))

	pushUpdate(player)
end)

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	initPlayer(player)
end)

Players.PlayerRemoving:Connect(cleanupPlayer)

print("[MoneySystem] Ready.")
