-- MapSetup.server.lua
-- Generates all map geometry at server start (runs once).
-- Creates: MapFloor, CenterGenerator, Base1-Base4 (Platform, Slot1-8, CollectionPot)
-- This approach is more reliable than defining Parts in project.json.
-- Located in: ServerScriptService

local RunService = game:GetService("RunService")

-- Only run once on server
if not RunService:IsServer() then return end

-- ============================================================
-- CLEANUP existing Map if present (from old Rojo sync artifacts)
-- ============================================================
local existingMap = workspace:FindFirstChild("Map")
if existingMap then existingMap:Destroy() end

-- ============================================================
-- ROOT FOLDER
-- ============================================================
local mapFolder = Instance.new("Folder")
mapFolder.Name = "Map"
mapFolder.Parent = workspace

-- ============================================================
-- HELPERS
-- ============================================================
local function makePart(parent, name, size, position, color, material, topSurface)
	local p = Instance.new("Part")
	p.Name         = name
	p.Size         = size
	p.Position     = position
	p.Color        = color
	p.Material     = material or Enum.Material.SmoothPlastic
	p.TopSurface   = topSurface or Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored     = true
	p.CanCollide   = true
	p.CastShadow   = true
	p.Parent       = parent
	return p
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color      = color
	light.Brightness = brightness
	light.Range      = range
	light.Enabled    = true
	light.Parent     = parent
end

local function addBillboard(parent, size, studOffset, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(0, size.X, 0, size.Y)
	bb.StudsOffset  = studOffset
	bb.MaxDistance  = maxDist
	bb.AlwaysOnTop  = false
	bb.Parent       = parent
	return bb
end

local function addTextLabel(parent, text, color, font, relSize, relPos)
	local l = Instance.new("TextLabel")
	l.Size                   = relSize or UDim2.new(1,0,1,0)
	l.Position               = relPos  or UDim2.new(0,0,0,0)
	l.BackgroundTransparency = 1
	l.Text                   = text
	l.TextColor3             = color or Color3.new(1,1,1)
	l.TextStrokeTransparency = 0.4
	l.TextScaled             = true
	l.Font                   = font or Enum.Font.GothamBold
	l.TextXAlignment         = Enum.TextXAlignment.Center
	l.Parent                 = parent
	return l
end

-- ============================================================
-- MAP FLOOR  (bright Lego blue, stud surface)
-- ============================================================
local mapFloor = makePart(mapFolder, "MapFloor",
	Vector3.new(340, 0.5, 340),
	Vector3.new(0, 0.25, 0),
	Color3.fromRGB(4, 175, 236),
	Enum.Material.SmoothPlastic,
	Enum.SurfaceType.Studs
)
mapFloor.Locked = true

-- ============================================================
-- CENTER GENERATOR  (glowing orange pad)
-- ============================================================
local generator = makePart(mapFolder, "CenterGenerator",
	Vector3.new(28, 1, 28),
	Vector3.new(0, 1.0, 0),
	Color3.fromRGB(255, 160, 34),
	Enum.Material.Neon,
	Enum.SurfaceType.Studs
)
addPointLight(generator, Color3.fromRGB(255, 160, 0), 5, 45)

-- Generator label
local genBB = addBillboard(generator, Vector2.new(200, 48), Vector3.new(0, 3, 0), 80)
addTextLabel(genBB, "🔫 GUN GENERATOR", Color3.fromRGB(255, 220, 50), Enum.Font.GothamBold)

-- ============================================================
-- BASE BUILDER
-- Each base: Platform (52×52) + 8 Slots (2×4 grid) + CollectionPot
-- ============================================================

-- Base positions (center of each platform)
local BASE_POSITIONS = {
	Vector3.new(-120, 1.0, -120),  -- Base1 NW
	Vector3.new( 120, 1.0, -120),  -- Base2 NE
	Vector3.new(-120, 1.0,  120),  -- Base3 SW
	Vector3.new( 120, 1.0,  120),  -- Base4 SE
}

-- Slot offsets relative to base center (2 columns × 4 rows)
local SLOT_OFFSETS = {
	Vector3.new(-7, 0.75, -10.5),
	Vector3.new( 7, 0.75, -10.5),
	Vector3.new(-7, 0.75,  -3.5),
	Vector3.new( 7, 0.75,  -3.5),
	Vector3.new(-7, 0.75,   3.5),
	Vector3.new( 7, 0.75,   3.5),
	Vector3.new(-7, 0.75,  10.5),
	Vector3.new( 7, 0.75,  10.5),
}

local PLATFORM_COLOR = Color3.fromRGB(245, 205, 48)   -- bright yellow
local SLOT_COLOR     = Color3.fromRGB(150, 150, 160)  -- grey (empty slot)
local POT_COLOR      = Color3.fromRGB(255, 215, 0)    -- gold

for baseId, baseCenter in ipairs(BASE_POSITIONS) do
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. baseId
	baseFolder:SetAttribute("BaseId", baseId)
	baseFolder.Parent = mapFolder

	-- Platform
	local platform = makePart(baseFolder, "Platform",
		Vector3.new(52, 1, 52),
		baseCenter,
		PLATFORM_COLOR, Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)
	platform:SetAttribute("BaseId", baseId)

	-- Slots (1–8)
	for i, offset in ipairs(SLOT_OFFSETS) do
		local slotPos = baseCenter + offset
		local slot = makePart(baseFolder, "Slot" .. i,
			Vector3.new(4, 0.5, 4),
			slotPos,
			SLOT_COLOR, Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)
		slot:SetAttribute("BaseId", baseId)
		slot:SetAttribute("SlotIndex", i)

		-- Slot number label
		local bb = addBillboard(slot, Vector2.new(60, 28), Vector3.new(0, 1.2, 0), 20)
		addTextLabel(bb, tostring(i), Color3.fromRGB(220, 220, 220), Enum.Font.Gotham)
	end

	-- Collection Pot (cylinder shape via WedgePart workaround: use Part with Cylinder)
	local potPos = baseCenter + Vector3.new(0, 2.5, 0)
	local pot    = makePart(baseFolder, "CollectionPot",
		Vector3.new(5, 4, 5),
		potPos,
		POT_COLOR, Enum.Material.Neon, Enum.SurfaceType.Smooth)
	pot:SetAttribute("BaseId", baseId)
	addPointLight(pot, Color3.fromRGB(255, 220, 80), 3, 22)

	-- Pot billboard (shows amount — updated by PlayerBase script)
	local potBB = addBillboard(pot, Vector2.new(160, 65), Vector3.new(0, 4, 0), 60)
	local potBG = Instance.new("Frame")
	potBG.Name = "Frame"
	potBG.Size = UDim2.new(1,0,1,0)
	potBG.BackgroundColor3 = Color3.fromRGB(0,0,0)
	potBG.BackgroundTransparency = 0.45
	potBG.BorderSizePixel = 0
	potBG.Parent = potBB
	Instance.new("UICorner", potBG).CornerRadius = UDim.new(0.12, 0)

	local amtLabel = Instance.new("TextLabel")
	amtLabel.Name = "Amount"
	amtLabel.Size = UDim2.new(1,0,0.55,0)
	amtLabel.BackgroundTransparency = 1
	amtLabel.Text = "$0"
	amtLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	amtLabel.TextScaled = true
	amtLabel.Font = Enum.Font.GothamBold
	amtLabel.Parent = potBG

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1,0,0.45,0)
	hintLabel.Position = UDim2.new(0,0,0.55,0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "🪙 Click to collect"
	hintLabel.TextColor3 = Color3.fromRGB(220,220,220)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.Parent = potBG

	print(("[MapSetup] Base%d created at (%d, %d, %d)"):format(
		baseId, baseCenter.X, baseCenter.Y, baseCenter.Z
	))
end

-- ============================================================
-- PATHS between generator and bases (diagonal flat strips)
-- ============================================================
local PATH_COLOR = Color3.fromRGB(200, 175, 80)
local PATH_DATA = {
	{ center = Vector3.new(-60, 0.55, -60), size = Vector3.new(8, 0.2, 152), angle =  45 },
	{ center = Vector3.new( 60, 0.55, -60), size = Vector3.new(8, 0.2, 152), angle = -45 },
	{ center = Vector3.new(-60, 0.55,  60), size = Vector3.new(8, 0.2, 152), angle = -45 },
	{ center = Vector3.new( 60, 0.55,  60), size = Vector3.new(8, 0.2, 152), angle =  45 },
}

for i, pd in ipairs(PATH_DATA) do
	local path = Instance.new("Part")
	path.Name         = "Path" .. i
	path.Size         = pd.size
	path.Color        = PATH_COLOR
	path.Material     = Enum.Material.SmoothPlastic
	path.TopSurface   = Enum.SurfaceType.Studs
	path.BottomSurface = Enum.SurfaceType.Smooth
	path.Anchored     = true
	path.CanCollide   = true
	path.Locked       = true
	path.CFrame       = CFrame.new(pd.center) * CFrame.Angles(0, math.rad(pd.angle), 0)
	path.Parent       = mapFolder
end

print("[MapSetup] Map fully generated. 4 bases, 32 slots, 1 generator.")
