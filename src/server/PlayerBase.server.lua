-- PlayerBase.server.lua
-- Assigns players to bases, manages 8-slot grid, production tick, pot accumulation.
-- Located in: ServerScriptService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Shared       = ReplicatedStorage:WaitForChild("Shared")
local GunData      = require(Shared:WaitForChild("GunData"))
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local cfg = GameConfig.Base
local map = workspace:WaitForChild("Map")

-- ============================================================
-- STATE
-- ============================================================
local playerBases     = {}  -- [Player] = baseId (1-4)
local baseOwners      = {}  -- [baseId] = Player|nil
local slotData        = {}  -- [baseId][slotIndex] = gunDef|nil
local potMoney        = {}  -- [Player] = number (uncollected)
local playerInventory = {}  -- [Player] = { gunDef... }
local prodMultipliers = {}  -- [Player] = number (e.g. 1.0, 1.05...)

for i = 1, 4 do
	baseOwners[i] = nil
	slotData[i] = {}
	for j = 1, cfg.SlotCount do slotData[i][j] = nil end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getSlotPart(baseId, slotIndex)
	local folder = map:FindFirstChild("Base" .. baseId)
	return folder and folder:FindFirstChild("Slot" .. slotIndex)
end

local function getPotPart(baseId)
	local folder = map:FindFirstChild("Base" .. baseId)
	return folder and folder:FindFirstChild("CollectionPot")
end

local function updatePotDisplay(player)
	local baseId = playerBases[player]
	if not baseId then return end
	local pot = getPotPart(baseId)
	if not pot then return end

	local amount = potMoney[player] or 0

	local bb = pot:FindFirstChild("PotDisplay")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "PotDisplay"
		bb.Size = UDim2.new(0, 160, 0, 65)
		bb.StudsOffset = Vector3.new(0, 5, 0)
		bb.MaxDistance = 60
		bb.Parent = pot

		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 0.45
		bg.Parent = bb
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0.15, 0)

		local amt = Instance.new("TextLabel")
		amt.Name = "Amount"
		amt.Size = UDim2.new(1, 0, 0.55, 0)
		amt.BackgroundTransparency = 1
		amt.TextColor3 = Color3.fromRGB(255, 220, 50)
		amt.TextScaled = true
		amt.Font = Enum.Font.GothamBold
		amt.Parent = bg

		local hint = Instance.new("TextLabel")
		hint.Size = UDim2.new(1, 0, 0.45, 0)
		hint.Position = UDim2.new(0, 0, 0.55, 0)
		hint.BackgroundTransparency = 1
		hint.Text = "🪙 Click to collect"
		hint.TextColor3 = Color3.fromRGB(220, 220, 220)
		hint.TextScaled = true
		hint.Font = Enum.Font.Gotham
		hint.Parent = bg
	end

	local amtLabel = bb:FindFirstChild("Frame") and bb.Frame:FindFirstChild("Amount")
	if amtLabel then
		amtLabel.Text = GameConfig.FormatMoney(amount)
	end
end

local function createGunVisual(slotPart, gunDef)
	if slotPart:FindFirstChild("PlacedGun") then
		slotPart.PlacedGun:Destroy()
	end
	local rarity = GunData.Rarities[gunDef.rarity]

	local vis = Instance.new("Part")
	vis.Name       = "PlacedGun"
	vis.Size       = Vector3.new(1.2, 0.4, 2.4)
	vis.Color      = rarity.color
	vis.Material   = Enum.Material.SmoothPlastic
	vis.Anchored   = true
	vis.CanCollide = false
	vis.CFrame     = slotPart.CFrame * CFrame.new(0, 0.45, 0)
	vis.Parent     = slotPart

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 110, 0, 42)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 30
	bb.Parent = vis

	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, 0, 0.55, 0)
	nameL.BackgroundTransparency = 1
	nameL.Text = gunDef.name
	nameL.TextColor3 = rarity.color
	nameL.TextStrokeTransparency = 0.3
	nameL.TextScaled = true
	nameL.Font = Enum.Font.GothamBold
	nameL.Parent = bb

	local rateL = Instance.new("TextLabel")
	rateL.Size = UDim2.new(1, 0, 0.45, 0)
	rateL.Position = UDim2.new(0, 0, 0.55, 0)
	rateL.BackgroundTransparency = 1
	rateL.Text = string.format("$%d/s", gunDef.money)
	rateL.TextColor3 = Color3.fromRGB(180, 255, 140)
	rateL.TextStrokeTransparency = 0.4
	rateL.TextScaled = true
	rateL.Font = Enum.Font.Gotham
	rateL.Parent = bb

	slotPart.Color = rarity.color
end

local function clearSlotVisual(slotPart)
	if slotPart:FindFirstChild("PlacedGun") then slotPart.PlacedGun:Destroy() end
	slotPart.Color = Color3.fromRGB(153, 153, 153)
end

-- ============================================================
-- BASE ASSIGNMENT
-- ============================================================
local function assignBase(player)
	for i = 1, 4 do
		if not baseOwners[i] then
			baseOwners[i]     = player
			playerBases[player]    = i
			potMoney[player]       = 0
			playerInventory[player] = {}
			prodMultipliers[player] = 1.0
			slotData[i] = {}
			for j = 1, cfg.SlotCount do slotData[i][j] = nil end

			-- Owner label on platform
			local folder = map:FindFirstChild("Base" .. i)
			local platform = folder and folder:FindFirstChild("Platform")
			if platform then
				local bb = Instance.new("BillboardGui")
				bb.Name = "OwnerLabel"
				bb.Size = UDim2.new(0, 180, 0, 38)
				bb.StudsOffset = Vector3.new(0, 5, 0)
				bb.MaxDistance = 80
				bb.Parent = platform
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 1, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = "🔫 " .. player.Name .. "'s Base"
				lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
				lbl.TextStrokeTransparency = 0.3
				lbl.TextScaled = true
				lbl.Font = Enum.Font.GothamBold
				lbl.Parent = bb
			end

			updatePotDisplay(player)
			print(("[PlayerBase] %s → Base%d"):format(player.Name, i))
			return i
		end
	end
	warn("[PlayerBase] All 4 bases full! " .. player.Name .. " has no base.")
end

local function freeBase(player)
	local baseId = playerBases[player]
	if not baseId then return end

	for i = 1, cfg.SlotCount do
		slotData[baseId][i] = nil
		local sp = getSlotPart(baseId, i)
		if sp then clearSlotVisual(sp) end
	end

	local pot = getPotPart(baseId)
	if pot then
		local d = pot:FindFirstChild("PotDisplay")
		if d then d:Destroy() end
	end

	local folder = map:FindFirstChild("Base" .. baseId)
	local platform = folder and folder:FindFirstChild("Platform")
	if platform then
		local lbl = platform:FindFirstChild("OwnerLabel")
		if lbl then lbl:Destroy() end
	end

	baseOwners[baseId]      = nil
	playerBases[player]     = nil
	potMoney[player]        = nil
	playerInventory[player] = nil
	prodMultipliers[player] = nil
	print(("[PlayerBase] %s left, Base%d freed"):format(player.Name, baseId))
end

-- ============================================================
-- PUBLIC API (via BindableFunction)
-- ============================================================
local function placeGun(player, slotIndex, gunId)
	local baseId = playerBases[player]
	if not baseId then return false end
	if slotData[baseId][slotIndex] then return false end  -- occupied

	local inv = playerInventory[player]
	for i, gun in ipairs(inv) do
		if gun.id == gunId then
			table.remove(inv, i)
			slotData[baseId][slotIndex] = gun
			local sp = getSlotPart(baseId, slotIndex)
			if sp then createGunVisual(sp, gun) end
			return true
		end
	end
	return false  -- not in inventory
end

local function removeFromSlot(player, slotIndex)
	local baseId = playerBases[player]
	if not baseId then return false end
	local gun = slotData[baseId][slotIndex]
	if not gun then return false end
	slotData[baseId][slotIndex] = nil
	table.insert(playerInventory[player], gun)
	local sp = getSlotPart(baseId, slotIndex)
	if sp then clearSlotVisual(sp) end
	return true
end

local function collectPot(player)
	local amount = potMoney[player] or 0
	potMoney[player] = 0
	updatePotDisplay(player)
	return amount
end

local function getBaseData(player)
	local baseId = playerBases[player]
	return {
		baseId    = baseId,
		inventory = playerInventory[player] or {},
		slots     = baseId and slotData[baseId] or {},
		potMoney  = potMoney[player] or 0,
	}
end

local function setProductionMultiplier(player, mult)
	prodMultipliers[player] = mult
end

local function resetBase(player)
	local baseId = playerBases[player]
	if not baseId then return end
	for i = 1, cfg.SlotCount do
		slotData[baseId][i] = nil
		local sp = getSlotPart(baseId, i)
		if sp then clearSlotVisual(sp) end
	end
	playerInventory[player] = {}
	potMoney[player] = 0
	updatePotDisplay(player)
end

-- Expose via BindableFunction folder
local apiFolder = Instance.new("Folder")
apiFolder.Name   = "PlayerBaseAPI"
apiFolder.Parent = ReplicatedStorage

local function makeAPI(name, fn)
	local bf = Instance.new("BindableFunction")
	bf.Name     = name
	bf.OnInvoke = fn
	bf.Parent   = apiFolder
end
makeAPI("PlaceGun",               placeGun)
makeAPI("RemoveFromSlot",         removeFromSlot)
makeAPI("CollectPot",             collectPot)
makeAPI("GetBaseData",            getBaseData)
makeAPI("SetProductionMultiplier",setProductionMultiplier)
makeAPI("ResetBase",              resetBase)

-- ============================================================
-- GUN PICKUP (from GunGenerator BindableEvent)
-- ============================================================
local bindPickup = ReplicatedStorage:WaitForChild("BindPickupGun", 10)
if bindPickup then
	bindPickup.Event:Connect(function(player, gunDef)
		if not playerInventory[player] then return end
		table.insert(playerInventory[player], gunDef)
		print(("[PlayerBase] %s picked up %s (%s)"):format(player.Name, gunDef.name, gunDef.rarity))
		local ev = RemoteEvents.Get("UpdatePlayerData")
		if ev then ev:FireClient(player, getBaseData(player)) end
	end)
end

-- ============================================================
-- REMOTE EVENTS from client
-- ============================================================
RemoteEvents.Get("PlaceGun").OnServerEvent:Connect(function(player, slotIndex, gunId)
	placeGun(player, slotIndex, gunId)
	RemoteEvents.Get("UpdatePlayerData"):FireClient(player, getBaseData(player))
end)

RemoteEvents.Get("RemoveGun").OnServerEvent:Connect(function(player, slotIndex)
	removeFromSlot(player, slotIndex)
	RemoteEvents.Get("UpdatePlayerData"):FireClient(player, getBaseData(player))
end)

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		if not playerBases[player] then assignBase(player) end
	end)
end)

Players.PlayerRemoving:Connect(freeBase)

-- ============================================================
-- PRODUCTION TICK (1 second loop)
-- ============================================================
local tickAccum = 0
RunService.Heartbeat:Connect(function(dt)
	tickAccum += dt
	if tickAccum < cfg.ProductionTick then return end
	tickAccum = 0

	for player, baseId in pairs(playerBases) do
		local mult   = prodMultipliers[player] or 1.0
		local earned = 0
		for _, gun in pairs(slotData[baseId]) do
			if gun then earned += gun.money * mult end
		end
		if earned > 0 then
			potMoney[player] = (potMoney[player] or 0) + earned
			updatePotDisplay(player)
		end
	end
end)

print("[PlayerBase] Ready.")
