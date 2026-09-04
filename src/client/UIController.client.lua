-- UIController.client.lua
-- HUD: money, rate, rebirth, upgrades, gun-spawn notifications.
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

-- ============================================================
-- GUI FACTORY HELPERS
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

local function label(parent, text, size, pos, color, font, xAlign)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos or UDim2.new(0,0,0,0)
	l.BackgroundTransparency = 1; l.Text = text
	l.TextColor3 = color or Color3.fromRGB(255,255,255)
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBold
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.Parent = parent; return l
end

local function button(parent, name, text, size, pos, bg)
	local b = Instance.new("TextButton")
	b.Name = name; b.Size = size; b.Position = pos
	b.BackgroundColor3 = bg or Color3.fromRGB(50,120,255)
	b.BorderSizePixel = 0
	b.Text = text; b.TextColor3 = Color3.new(1,1,1)
	b.TextScaled = true; b.Font = Enum.Font.GothamBold
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "GunTycoonHUD"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- TOP LEFT — money + rate
local tlPanel = frame(gui, "TopLeft",
	UDim2.new(0,200,0,78), UDim2.new(0,12,0,12))
local moneyLbl = label(tlPanel, "$0",
	UDim2.new(1,-10,0.52,0), UDim2.new(0,8,0,2),
	Color3.fromRGB(255,220,50))
local rateLbl = label(tlPanel, "$0/sec",
	UDim2.new(1,-10,0.38,0), UDim2.new(0,8,0.54,0),
	Color3.fromRGB(160,255,130), Enum.Font.Gotham)

-- TOP RIGHT — rebirth info
local trPanel = frame(gui, "TopRight",
	UDim2.new(0,200,0,78), UDim2.new(1,-212,0,12))
local rebirthLbl = label(trPanel, "⟳ Rebirth Lv.0",
	UDim2.new(1,-10,0.45,0), UDim2.new(0,8,0,2),
	Color3.fromRGB(200,100,255))
local multLbl = label(trPanel, "x1.00 mult",
	UDim2.new(1,-10,0.38,0), UDim2.new(0,8,0.52,0),
	Color3.fromRGB(190,160,255), Enum.Font.Gotham)

local rebirthBtn = button(gui, "RebirthBtn", "🔁 REBIRTH",
	UDim2.new(0,180,0,38), UDim2.new(1,-192,0,98),
	Color3.fromRGB(140,40,220))
rebirthBtn.Visible = false

-- BOTTOM LEFT — upgrades
local upgPanel = frame(gui, "Upgrades",
	UDim2.new(0,200,0,168), UDim2.new(0,12,1,-180))
label(upgPanel, "⚡ UPGRADES",
	UDim2.new(1,0,0.16,0), UDim2.new(0,0,0,4),
	Color3.fromRGB(255,200,50), Enum.Font.GothamBold, Enum.TextXAlignment.Center)

local UPGRADE_DEFS = {
	{ key="damage",     txt="⚔ Damage",     clr=Color3.fromRGB(220,60,60)  },
	{ key="production", txt="💰 Production", clr=Color3.fromRGB(50,180,80)  },
	{ key="luck",       txt="🍀 Luck",       clr=Color3.fromRGB(50,120,255) },
}
local upgBtns = {}
for i, d in ipairs(UPGRADE_DEFS) do
	local yPos = 0.16 + (i-1)*0.27
	local b = button(upgPanel, d.key.."Btn",
		d.txt.."\nLv.0 — $100",
		UDim2.new(1,-16,0.24,0), UDim2.new(0,8,yPos,0), d.clr)
	upgBtns[d.key] = b
	local baseClr = d.clr
	b.MouseButton1Click:Connect(function()
		RemoteEvents.Get("BuyUpgrade"):FireServer(d.key)
	end)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), {
			BackgroundColor3 = baseClr:Lerp(Color3.new(1,1,1), 0.2)
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = baseClr }):Play()
	end)
end

-- NOTIFICATION — top centre slide-in
local notifFrame = frame(gui, "Notif",
	UDim2.new(0,280,0,46), UDim2.new(0.5,-140,0,-60),
	Color3.fromRGB(15,15,25), 0.1)
local notifLbl = label(notifFrame, "", UDim2.new(1,-10,1,0),
	UDim2.new(0,5,0,0), Color3.new(1,1,1), Enum.Font.GothamBold,
	Enum.TextXAlignment.Center)

local notifQueue, notifBusy = {}, false
local function showNotif(text, color)
	table.insert(notifQueue, { text=text, color=color })
	if notifBusy then return end
	notifBusy = true
	task.spawn(function()
		while #notifQueue > 0 do
			local item = table.remove(notifQueue, 1)
			notifLbl.Text = item.text
			notifLbl.TextColor3 = item.color or Color3.new(1,1,1)
			TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back),
				{ Position = UDim2.new(0.5,-140,0,10) }):Play()
			task.wait(2.5)
			TweenService:Create(notifFrame, TweenInfo.new(0.25),
				{ Position = UDim2.new(0.5,-140,0,-60) }):Play()
			task.wait(0.3)
		end
		notifBusy = false
	end)
end

-- ============================================================
-- UPDATE HUD
-- ============================================================
local function updateHUD(data)
	if not data then return end

	moneyLbl.Text = GameConfig.FormatMoney(data.money or 0)

	local rate = 0
	if data.slots then
		for _, gun in pairs(data.slots) do
			if gun then rate += (gun.money or 0) end
		end
	end
	rateLbl.Text = GameConfig.FormatMoney(rate) .. "/sec"

	local mult = 1.1 ^ (data.rebirthLevel or 0)
	rebirthLbl.Text = "⟳ Rebirth Lv." .. (data.rebirthLevel or 0)
	multLbl.Text    = string.format("x%.2f mult", mult)
	rebirthBtn.Visible = data.rebirthReady == true

	if data.upgrades and data.upgradeCosts then
		for _, d in ipairs(UPGRADE_DEFS) do
			local b = upgBtns[d.key]
			if b then
				local lv   = data.upgrades[d.key] or 0
				local cost = data.upgradeCosts[d.key] or 0
				b.Text = d.txt .. "\nLv."..lv.." — "..GameConfig.FormatMoney(cost)
				b.BackgroundTransparency = (data.money >= cost) and 0 or 0.45
			end
		end
	end
end

RemoteEvents.Get("UpdatePlayerData").OnClientEvent:Connect(updateHUD)

RemoteEvents.Get("GunSpawned").OnClientEvent:Connect(function(gunId, rarity)
	local rd = GunData.Rarities[rarity]
	local gd = GunData.GetById(gunId)
	local clr = rd and rd.color or Color3.new(1,1,1)
	local nm  = gd and gd.name or gunId
	showNotif(("🔫 [%s] %s spawned!"):format(rarity, nm), clr)
end)

rebirthBtn.MouseButton1Click:Connect(function()
	RemoteEvents.Get("TriggerRebirth"):FireServer()
end)

print("[UIController] HUD ready.")
