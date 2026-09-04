-- RemoteEvents.lua
-- ModuleScript: Central registry for all RemoteEvents and RemoteFunctions.
-- Run once on both server and client to get references to the same objects.
-- Located in: ReplicatedStorage/Shared

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

-- ============================================================
-- EVENT DEFINITIONS
-- Name : human-readable key used in code
-- dir  : "C2S" = Client → Server, "S2C" = Server → Client
-- ============================================================
local EVENT_LIST = {
	-- Gun interactions
	{ name = "PickupGun",      dir = "C2S" },  -- client touched gun → server removes & gives to player
	{ name = "PlaceGun",       dir = "C2S" },  -- client selects slot → server places gun
	{ name = "RemoveGun",      dir = "C2S" },  -- client removes gun from slot (to inventory/drop)

	-- Economy
	{ name = "CollectMoney",   dir = "C2S" },  -- client clicks collection pot → server credits money
	{ name = "BuyUpgrade",     dir = "C2S" },  -- client buys upgrade tree level
	{ name = "TriggerRebirth", dir = "C2S" },  -- client triggers rebirth

	-- Server → Client pushes
	{ name = "UpdatePlayerData", dir = "S2C" }, -- push full player state to client (money, rate, etc.)
	{ name = "GunSpawned",       dir = "S2C" }, -- notify all clients a gun appeared (for UI hints)
	{ name = "EnemySpawned",     dir = "S2C" }, -- notify clients enemy appeared
	{ name = "EnemyDefeated",    dir = "S2C" }, -- notify clients enemy was defeated
}

-- ============================================================
-- SETUP: Create or find RemoteEvent folder in ReplicatedStorage
-- Server calls this to CREATE events.
-- Client calls this to FIND events (they already exist by then).
-- ============================================================
local _folder = nil

local function getOrCreateFolder()
	if _folder then return _folder end

	local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RemoteEvents"
		folder.Parent = ReplicatedStorage
	end
	_folder = folder
	return folder
end

-- ============================================================
-- Called by Server only — creates all RemoteEvent instances
-- ============================================================
function RemoteEvents.Init()
	local folder = getOrCreateFolder()

	for _, def in ipairs(EVENT_LIST) do
		if not folder:FindFirstChild(def.name) then
			local event = Instance.new("RemoteEvent")
			event.Name = def.name
			event.Parent = folder
		end
	end

	print("[RemoteEvents] All events initialized.")
end

-- ============================================================
-- Get a RemoteEvent by name (safe, waits up to 5s)
-- Usage: RemoteEvents.Get("PickupGun")
-- ============================================================
function RemoteEvents.Get(name)
	local folder = getOrCreateFolder()
	local event = folder:FindFirstChild(name)
	if not event then
		-- Client may call before server finishes — wait briefly
		event = folder:WaitForChild(name, 5)
	end
	if not event then
		warn("[RemoteEvents] Event not found: " .. tostring(name))
	end
	return event
end

return RemoteEvents
