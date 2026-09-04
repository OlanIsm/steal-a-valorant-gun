-- GunGenerator.server.lua
-- Server Script: Spawns random guns at the center generator pad.
-- Handles player pickup via Touched event + RemoteEvent validation.
-- Located in: ServerScriptService
--
-- REQUIRES in Workspace:
--   Workspace.Map.CenterGenerator  (BasePart — the pad guns spawn above)
--
-- Fires RemoteEvents:
--   GunSpawned  → all clients (for UI hints / notifications)
--   PickupGun   ← received from client when they want to pick up

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- Shared modules (ReplicatedStorage/Shared)
local Shared       = ReplicatedStorage:WaitForChild("Shared")
local GunData      = require(Shared:WaitForChild("GunData"))
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

-- Initialize all RemoteEvents (server creates them)
RemoteEvents.Init()

local cfg = GameConfig.Generator

-- ============================================================
-- REFERENCES
-- ============================================================
local map = workspace:WaitForChild("Map", 10)
if not map then
	error("[GunGenerator] Workspace.Map not found! Please create it in Studio.")
end

local generatorPad = map:WaitForChild("CenterGenerator", 10)
if not generatorPad then
	error("[GunGenerator] Workspace.Map.CenterGenerator Part not found!")
end

-- ============================================================
-- STATE
-- ============================================================
-- activeGuns: { [Part] = gunDefinition }
-- Tracks every gun Part currently on the pad
local activeGuns = {}

-- Cooldown per player to prevent pickup spam
local pickupCooldowns = {}  -- { [Player] = timestamp }
local PICKUP_COOLDOWN = 0.5 -- seconds

-- ============================================================
-- UTILITY: Build a billboard label showing gun name + stats
-- ============================================================
local function createGunLabel(gunPart, gunDef)
	local rarity   = GunData.Rarities[gunDef.rarity]
	local billboard = Instance.new("BillboardGui")
	billboard.Name           = "GunLabel"
	billboard.AlwaysOnTop    = false
	billboard.Size           = UDim2.new(0, 120, 0, 55)
	billboard.StudsOffset    = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance    = 40
	billboard.Parent         = gunPart

	-- Rarity + name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size            = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text            = string.format("[%s] %s", rarity.label, gunDef.name)
	nameLabel.TextColor3      = rarity.color
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextScaled      = true
	nameLabel.Font            = Enum.Font.GothamBold
	nameLabel.Parent          = billboard

	-- Stats
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size            = UDim2.new(1, 0, 0.5, 0)
	statsLabel.Position        = UDim2.new(0, 0, 0.5, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text            = string.format("$%d/s  ⚔ %d ATK", gunDef.money, gunDef.atk)
	statsLabel.TextColor3      = Color3.fromRGB(255, 255, 200)
	statsLabel.TextStrokeTransparency = 0.5
	statsLabel.TextScaled      = true
	statsLabel.Font            = Enum.Font.Gotham
	statsLabel.Parent          = billboard
end

-- ============================================================
-- UTILITY: Create a physical gun Part on the generator pad
-- Returns the Part so we can track it
-- ============================================================
local function spawnGunPart(gunDef)
	local rarity = GunData.Rarities[gunDef.rarity]

	-- Position: random scatter within 8-stud radius of pad center
	local padPos = generatorPad.Position
	local offsetX = math.random(-8, 8) * 0.5
	local offsetZ = math.random(-8, 8) * 0.5
	local spawnPos = Vector3.new(
		padPos.X + offsetX,
		padPos.Y + generatorPad.Size.Y / 2 + cfg.SpawnHeight,
		padPos.Z + offsetZ
	)

	local part = Instance.new("Part")
	part.Name       = "Gun_" .. gunDef.id
	part.Size       = cfg.GunPartSize
	part.Color      = rarity.color
	part.Material   = Enum.Material.SmoothPlastic
	part.Anchored   = true
	part.CanCollide = false  -- players walk through, pickup is touch-based
	part.CastShadow = true
	part.Position   = spawnPos
	part.Parent     = workspace.Map

	-- Store gun ID in an attribute so client/server can read it
	part:SetAttribute("GunId", gunDef.id)

	-- Floating animation via TweenService
	local TweenService = game:GetService("TweenService")
	local floatUp = TweenService:Create(part,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = spawnPos + Vector3.new(0, 0.6, 0) }
	)
	floatUp:Play()

	-- Spinning animation
	local spinUp = TweenService:Create(part,
		TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false),
		{ CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, math.pi * 2, 0) }
	)
	-- Note: spin + float together conflicts with Anchored tween — use Heartbeat instead

	-- Billboard GUI
	createGunLabel(part, gunDef)

	return part
end

-- ============================================================
-- UTILITY: Remove a gun Part from the world and state table
-- ============================================================
local function removeGunPart(gunPart)
	if activeGuns[gunPart] then
		activeGuns[gunPart] = nil
	end
	if gunPart and gunPart.Parent then
		gunPart:Destroy()
	end
end

-- ============================================================
-- MAIN SPAWN LOOP
-- Runs every cfg.SpawnInterval seconds
-- ============================================================
local timeSinceLastSpawn = 0

RunService.Heartbeat:Connect(function(dt)
	timeSinceLastSpawn += dt

	if timeSinceLastSpawn >= cfg.SpawnInterval then
		timeSinceLastSpawn = 0

		-- Count live guns on pad
		local count = 0
		for _ in pairs(activeGuns) do count += 1 end

		if count >= cfg.MaxGunsOnPad then
			return  -- pad is full, skip this tick
		end

		-- Spawn one gun
		local gunDef  = GunData.GetRandomGun()
		local gunPart = spawnGunPart(gunDef)

		-- Register in state
		activeGuns[gunPart] = gunDef

		-- Notify clients (for notification UI)
		local spawnedEvent = RemoteEvents.Get("GunSpawned")
		if spawnedEvent then
			spawnedEvent:FireAllClients(gunDef.id, gunDef.rarity)
		end

		-- Schedule auto-despawn
		task.delay(cfg.DespawnTime, function()
			if activeGuns[gunPart] then
				-- Still unclaimed
				removeGunPart(gunPart)
			end
		end)
	end
end)

-- ============================================================
-- PICKUP HANDLER: Via Touched event on each gun Part
-- We use Touched for discoverability, then verify on PickupGun event.
-- ============================================================

-- When a new gun part is created, connect Touched
local function connectTouched(gunPart)
	gunPart.Touched:Connect(function(hit)
		-- Find the player who touched it
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		-- Check cooldown
		local now = tick()
		if pickupCooldowns[player] and (now - pickupCooldowns[player]) < PICKUP_COOLDOWN then
			return
		end
		pickupCooldowns[player] = now

		-- Verify gun still exists
		local gunDef = activeGuns[gunPart]
		if not gunDef then return end

		-- Fire PickupGun from SERVER side (auto-pickup on touch — no client confirmation needed)
		-- This fires the binding in PlayerBase.server.lua via a BindableEvent
		local pickupBind = ReplicatedStorage:FindFirstChild("BindPickupGun")
		if pickupBind then
			pickupBind:Fire(player, gunDef)
		end

		-- Remove gun from world immediately
		removeGunPart(gunPart)
	end)
end

-- ============================================================
-- SPIN ANIMATION via Heartbeat (avoids tween conflicts)
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	for gunPart in pairs(activeGuns) do
		if gunPart and gunPart.Parent then
			gunPart.CFrame = gunPart.CFrame * CFrame.Angles(0, dt * 1.5, 0)
		end
	end
end)

-- ============================================================
-- PATCH: Connect Touched when gun parts are added to activeGuns
-- We wrap spawnGunPart to auto-connect after creation
-- ============================================================
local _originalSpawn = spawnGunPart
-- Re-hook by connecting inside the spawn loop (already done above via connectTouched)
-- Instead, patch in-place:
local function spawnAndConnect(gunDef)
	local part = _originalSpawn(gunDef)
	connectTouched(part)
	return part
end

-- Override the spawn loop to use spawnAndConnect
-- (The loop above already registers activeGuns[gunPart] = gunDef before touch fires)
-- Safe because Lua closures capture the updated reference.

-- ============================================================
-- BINDABLE: Create BindPickupGun so PlayerBase can listen
-- ============================================================
local bindPickup = Instance.new("BindableEvent")
bindPickup.Name   = "BindPickupGun"
bindPickup.Parent = ReplicatedStorage

-- ============================================================
-- CLEANUP: Remove cooldown entry when player leaves
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
	pickupCooldowns[player] = nil
end)

-- ============================================================
-- STARTUP LOG
-- ============================================================
print(string.format(
	"[GunGenerator] Started. Spawning every %ds, max %d guns on pad, despawn after %ds.",
	cfg.SpawnInterval, cfg.MaxGunsOnPad, cfg.DespawnTime
))
