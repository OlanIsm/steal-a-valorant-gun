-- BaseGrid.client.lua
-- Inventory panel + ClickDetectors on slots & CollectionPot.
-- Located in: StarterPlayerScripts/Client

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared       = ReplicatedStorage:WaitForChild("Shared")
local GunData      = require(Shared:WaitForChild("GunData"))
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local map = workspace:WaitForChild("Map")

-- Wait for UIController to create the ScreenGui
local gui = playerGui:WaitForChild("GunTycoonHUD", 10)
if not gui then
	warn("[BaseGrid] GunTycoonHUD not found — UIController may not have loaded yet.")
	return
end

-- ============================================================
-- STATE
-- ============================================================
local currentData    = nil
local selectedGunId  = nil
local connectedBase  = nil
local clickConns     = {}

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function frame(parent, name, size, pos, color, alpha)
	local f = Instance.new("Frame")
	f.Name = name; f.Size = size; f.Position = pos
	f.BackgroundColor3 = color or Color3.fromRGB(10,10,20)
	f.BackgroundTransparency = alpha or 0.2
	f.BorderSizePixel = 0; f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	return f
end

local function label(parent, text, size, pos, color, xAlign)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos or UDim2.new(0,0,0,0)
	l.BackgroundTransparency = 1; l.Text = text
	l.TextColor3 = color or Color3.new(1,1,1)
	l.TextScaled = true; l.Font = Enum.Font.GothamBold
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.Parent = parent; return l
end

-- ============================================================
-- INVENTORY PANEL (bottom right)
-- ============================================================
local invPanel = frame(gui, "InventoryPanel",
	UDim2.new(0,225,0,295), UDim2.new(1,-237,0.5,-148),
	Color3.fromRGB(10,10,20), 0.15)

label(invPanel, "🎒 INVENTORY",
	UDim2.new(1,0,0.09,0), UDim2.new(0,0,0,4),
	Color3.fromRGB(255,200,50))

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "InvScroll"
scroll.Size = UDim2.new(1,-8,0.87,0)
scroll.Position = UDim2.new(0,4,0.11,0)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = invPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scroll

-- SELECTED GUN label (below inv panel)
local selLabel = label(gui, "No gun selected",
	UDim2.new(0,225,0,28), UDim2.new(1,-237,0.5,152),
	Color3.fromRGB(180,180,180))

-- ============================================================
-- REFRESH INVENTORY LIST
-- ============================================================
local invBtns = {}

local function refreshInventory(data)
	for _, b in ipairs(invBtns) do b:Destroy() end
	invBtns = {}

	if not data or not data.inventory then return end
	if #data.inventory == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1,0,0,36)
		empty.BackgroundTransparency = 1
		empty.Text = "Pick up guns from the generator!"
		empty.TextColor3 = Color3.fromRGB(140,140,140)
		empty.TextScaled = true; empty.Font = Enum.Font.Gotham
		empty.Parent = scroll
		table.insert(invBtns, empty)
		return
	end

	for i, gun in ipairs(data.inventory) do
		local rarity = GunData.Rarities[gun.rarity]
		local clr    = rarity and rarity.color or Color3.new(1,1,1)

		local btn = Instance.new("TextButton")
		btn.Name = "InvBtn"..i
		btn.Size = UDim2.new(1,-4,0,42)
		btn.BackgroundColor3 = Color3.fromRGB(28,28,44)
		btn.BorderSizePixel = 0
		btn.Text = string.format("[%s] %s  $%d/s ⚔%d", gun.rarity, gun.name, gun.money, gun.atk)
		btn.TextColor3 = clr
		btn.TextScaled = true; btn.Font = Enum.Font.Gotham
		btn.Parent = scroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		-- Left colour strip
		local strip = Instance.new("Frame")
		strip.Size = UDim2.new(0,4,1,0)
		strip.BackgroundColor3 = clr
		strip.BorderSizePixel = 0
		strip.Parent = btn
		Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			selectedGunId = gun.id
			selLabel.Text = "🔫 Selected: " .. gun.name
			selLabel.TextColor3 = clr
			for _, ob in ipairs(invBtns) do
				if ob:IsA("TextButton") then
					ob.BackgroundColor3 = Color3.fromRGB(28,28,44)
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(55,55,90)
		end)

		table.insert(invBtns, btn)
	end
end

-- ============================================================
-- CLICK DETECTORS on world parts
-- ============================================================
local function disconnectAll()
	for _, c in ipairs(clickConns) do c:Disconnect() end
	clickConns = {}
end

local function getOrAddCD(part, name, distance)
	local cd = part:FindFirstChild(name)
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.Name = name; cd.MaxActivationDistance = distance or 20
		cd.Parent = part
	end
	return cd
end

local function connectToBase(baseId)
	if connectedBase == baseId then return end
	disconnectAll()
	connectedBase = baseId

	local folder = map:FindFirstChild("Base" .. baseId)
	if not folder then return end

	-- SLOTS
	for i = 1, 8 do
		local slotPart = folder:FindFirstChild("Slot" .. i)
		if not slotPart then continue end

		local cd = getOrAddCD(slotPart, "SlotCD", 20)
		local idx = i
		local conn = cd.MouseClick:Connect(function(who)
			if who ~= player then return end
			local data = currentData
			if not data then return end

			local occupied = data.slots and data.slots[idx]
			if occupied then
				-- Remove gun → back to inventory
				RemoteEvents.Get("RemoveGun"):FireServer(idx)
			elseif selectedGunId then
				-- Place selected gun
				RemoteEvents.Get("PlaceGun"):FireServer(idx, selectedGunId)
				selectedGunId = nil
				selLabel.Text = "No gun selected"
				selLabel.TextColor3 = Color3.fromRGB(180,180,180)
			end
		end)
		table.insert(clickConns, conn)
	end

	-- COLLECTION POT
	local pot = folder:FindFirstChild("CollectionPot")
	if pot then
		local cd = getOrAddCD(pot, "PotCD", 25)
		local conn = cd.MouseClick:Connect(function(who)
			if who ~= player then return end
			RemoteEvents.Get("CollectMoney"):FireServer()
			-- Small tween feedback on pot
			TweenService:Create(pot, TweenInfo.new(0.1),
				{ Size = pot.Size + Vector3.new(0.5,0.5,0.5) }):Play()
			task.delay(0.15, function()
				TweenService:Create(pot, TweenInfo.new(0.1),
					{ Size = pot.Size - Vector3.new(0.5,0.5,0.5) }):Play()
			end)
		end)
		table.insert(clickConns, conn)
	end

	print("[BaseGrid] Connected to Base" .. baseId)
end

-- ============================================================
-- LISTEN TO SERVER UPDATES
-- ============================================================
RemoteEvents.Get("UpdatePlayerData").OnClientEvent:Connect(function(data)
	currentData = data
	refreshInventory(data)
	if data.baseId then
		connectToBase(data.baseId)
	end
end)

print("[BaseGrid] Ready.")
