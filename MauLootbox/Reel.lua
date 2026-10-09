-- MauLootbox reel: the slot machine window.
--
-- One column per item, side by side (wrapping into rows after maxColumns).
-- Each column is a strip of icons that scrolls upward behind a window
-- showing three rows, slows down and stops with the real item in the middle,
-- flashes, shows the name in its quality colour and reports the landing
-- (Loot.lua takes the item at that moment).  Columns start one after the
-- other: the second staggerFirst seconds after the first, the third
-- staggerFirst + staggerStep after the second, and so on.  Everything is
-- plain frames and textures driven by one OnUpdate; nothing here talks to
-- the loot API.

local _, NS = ...

local Reel = {}
NS.Reel = Reel

local ICON = 56           -- icon size
local ROW = 64            -- distance between rows
local VISIBLE_ROWS = 3
local COLUMN_WIDTH = 100
local COLUMN_HEIGHT = ROW * VISIBLE_ROWS + 44   -- view plus name and quantity
local COLUMN_GAP = 6
local HEADER_HEIGHT = 56
local FOOTER_HEIGHT = 52
local SIDE_PADDING = 18
local STRIP_MIN, STRIP_EXTRA = 16, 8   -- icons that pass by before the real one
local FLASH_TIME = 0.45

-- Spin and hold times per quality (seconds), scaled by the speed setting.
local SPIN_TIME = { [0] = 1.3, [1] = 1.5, [2] = 2.0, [3] = 2.6, [4] = 3.4, [5] = 4.2 }
local HOLD_TIME = { [0] = 0.7, [1] = 0.8, [2] = 1.0, [3] = 1.2, [4] = 1.5, [5] = 2.0 }

-- Icons that ship with every client, used to fill the reel between the real
-- items.
local FILLER_ICONS = {
	"Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Sword_04", "Interface\\Icons\\INV_Chest_Cloth_17",
	"Interface\\Icons\\INV_Misc_Food_15", "Interface\\Icons\\INV_Fabric_Linen_01", "Interface\\Icons\\INV_Misc_Herb_02",
	"Interface\\Icons\\INV_Ore_Copper_01", "Interface\\Icons\\INV_Misc_Gem_01", "Interface\\Icons\\INV_Shield_04",
	"Interface\\Icons\\INV_Boots_05", "Interface\\Icons\\INV_Helmet_08", "Interface\\Icons\\INV_Jewelry_Ring_03",
	"Interface\\Icons\\INV_Misc_Bone_01", "Interface\\Icons\\INV_Staff_08", "Interface\\Icons\\INV_Axe_02",
	"Interface\\Icons\\INV_Misc_Bandage_01", "Interface\\Icons\\INV_Drink_05", "Interface\\Icons\\INV_Scroll_03",
	"Interface\\Icons\\INV_Potion_51", "Interface\\Icons\\INV_Misc_Coin_02", "Interface\\Icons\\INV_Misc_QuestionMark",
}

local function EaseOutCubic(t)
	t = 1 - t
	return 1 - t * t * t
end

local function PlayKit(key)
	if not NS.GetSettings().sounds or not SOUNDKIT or not SOUNDKIT[key] then
		return nil
	end
	local _, handle = PlaySound(SOUNDKIT[key])
	return handle
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

function Reel:Create()
	if self.frame then
		return self.frame
	end
	local f = CreateFrame("Frame", "MauLootboxFrame", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(220, 320)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relativePoint, x, y = f:GetPoint()
		MauLootboxDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	f:Hide()

	f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.Title:SetPoint("TOP", 0, -18)
	f.Title:SetText("Loot")

	f.Counter = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.Counter:SetPoint("TOP", f.Title, "BOTTOM", 0, -2)

	f.Skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.Skip:SetSize(90, 22)
	f.Skip:SetPoint("BOTTOM", 0, 16)
	f.Skip:SetText("Take all")
	f.Skip:SetScript("OnClick", function()
		if Reel.onSkip then
			Reel.onSkip()
		end
	end)

	f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.Close:SetPoint("TOPRIGHT", -4, -4)
	f.Close:SetScript("OnClick", function()
		if Reel.onClose then
			Reel.onClose()
		end
	end)

	f:SetScript("OnUpdate", function(_, elapsed)
		Reel:OnUpdate(elapsed)
	end)

	self.columns = {}
	self:ApplyPosition()
	self:ApplyScale()
	return f
end

function Reel:ApplyPosition()
	local f = self.frame
	if not f then
		return
	end
	f:ClearAllPoints()
	local p = MauLootboxDB and MauLootboxDB.position
	if p and p.point then
		f:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
	end
end

function Reel:ApplyScale()
	if self.frame then
		self.frame:SetScale((NS.GetSettings().scale or 100) / 100)
	end
end

-------------------------------------------------------------------------------
-- Columns
-------------------------------------------------------------------------------

local function CreateColumn(parent)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(COLUMN_WIDTH, COLUMN_HEIGHT)

	-- The window the strip scrolls behind.
	local view = CreateFrame("Frame", nil, c)
	c.View = view
	view:SetSize(ICON + 24, ROW * VISIBLE_ROWS)
	view:SetPoint("TOP")
	view:SetClipsChildren(true)

	view.Background = view:CreateTexture(nil, "BACKGROUND")
	view.Background:SetAllPoints()
	view.Background:SetColorTexture(0, 0, 0, 0.6)

	-- Icons for the rows that can be on screen at once (one spare above and below).
	c.Rows = {}
	for i = 1, VISIBLE_ROWS + 2 do
		local tex = view:CreateTexture(nil, "ARTWORK")
		tex:SetSize(ICON, ICON)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		c.Rows[i] = tex
	end

	-- Dim the rows above and below the middle.
	view.ShadeTop = view:CreateTexture(nil, "OVERLAY")
	view.ShadeTop:SetPoint("TOPLEFT")
	view.ShadeTop:SetPoint("TOPRIGHT")
	view.ShadeTop:SetHeight(ROW)
	view.ShadeTop:SetColorTexture(0, 0, 0, 0.55)
	view.ShadeBottom = view:CreateTexture(nil, "OVERLAY")
	view.ShadeBottom:SetPoint("BOTTOMLEFT")
	view.ShadeBottom:SetPoint("BOTTOMRIGHT")
	view.ShadeBottom:SetHeight(ROW)
	view.ShadeBottom:SetColorTexture(0, 0, 0, 0.55)

	-- Frame around the middle row, tinted with the item quality on landing.
	c.Border = view:CreateTexture(nil, "OVERLAY", nil, 2)
	c.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	c.Border:SetBlendMode("ADD")
	c.Border:SetSize(ICON * 1.72, ICON * 1.72)
	c.Border:SetPoint("CENTER")
	c.Border:SetVertexColor(1, 1, 1, 0.35)

	-- White flash on landing.
	c.Flash = view:CreateTexture(nil, "OVERLAY", nil, 3)
	c.Flash:SetTexture("Interface\\Buttons\\WHITE8X8")
	c.Flash:SetBlendMode("ADD")
	c.Flash:SetSize(ICON, ICON)
	c.Flash:SetPoint("CENTER")
	c.Flash:SetAlpha(0)

	c.Name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	c.Name:SetPoint("TOP", view, "BOTTOM", 0, -6)
	c.Name:SetWidth(COLUMN_WIDTH - 4)
	c.Name:SetWordWrap(false)

	c.Quantity = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.Quantity:SetPoint("TOP", c.Name, "BOTTOM", 0, -2)

	return c
end

function Reel:GetColumn(index)
	local c = self.columns[index]
	if not c then
		c = CreateColumn(self.frame)
		self.columns[index] = c
	end
	return c
end

local function ResetColumn(c)
	c.state = "waiting"
	c.elapsed = 0
	c.strip = nil
	c.Name:SetText("")
	c.Quantity:SetText("")
	c.Border:SetVertexColor(1, 1, 1, 0.35)
	c.Flash:SetAlpha(0)
	for _, tex in ipairs(c.Rows) do
		tex:Hide()
	end
end

-- Place count columns in a grid and size the window around them.
function Reel:Layout(count)
	local f = self.frame
	local perRow = math.max(1, math.min(count, NS.GetSettings().maxColumns or 6))
	local rows = math.ceil(count / perRow)
	local width = SIDE_PADDING * 2 + perRow * COLUMN_WIDTH + (perRow - 1) * COLUMN_GAP
	local height = HEADER_HEIGHT + rows * COLUMN_HEIGHT + (rows - 1) * COLUMN_GAP + FOOTER_HEIGHT
	f:SetSize(width, height)
	for i = 1, count do
		local c = self:GetColumn(i)
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PADDING + col * (COLUMN_WIDTH + COLUMN_GAP), -(HEADER_HEIGHT + row * (COLUMN_HEIGHT + COLUMN_GAP)))
		c:Show()
	end
	for i = count + 1, #self.columns do
		self.columns[i]:Hide()
	end
end

-- Seconds after the first column at which column i starts.
local function StartDelay(index, settings)
	local first = settings.staggerFirst or 0.2
	local step = settings.staggerStep or 0.1
	local delay = 0
	for k = 2, index do
		delay = delay + first + (k - 2) * step
	end
	return delay
end

-------------------------------------------------------------------------------
-- Showing and spinning
-------------------------------------------------------------------------------

-- items: list of { texture, name, quantity, quality }.  onLanded(item) is
-- called the moment a column lands, onFinished() when every column has
-- landed and held.
function Reel:Begin(items, callbacks)
	local f = self:Create()
	local settings = NS.GetSettings()
	self.items = items
	self.callbacks = callbacks or {}
	self.onSkip = self.callbacks.onSkip
	self.onClose = self.callbacks.onClose
	self:HideLeftovers()
	self:BuildPool(items)
	self:Layout(#items)
	for i, item in ipairs(items) do
		local c = self:GetColumn(i)
		ResetColumn(c)
		c.item = item
		c.startAt = StartDelay(i, settings)
	end
	self.active = #items
	self.clock = 0
	self.landed = 0
	self.state = "running"
	f.Counter:SetText(#items == 1 and "1 item" or (#items .. " items"))
	self:ApplyScale()
	f:Show()
	self:OnUpdate(0)
end

function Reel:BuildPool(items)
	local pool = {}
	for _, icon in ipairs(FILLER_ICONS) do
		pool[#pool + 1] = icon
	end
	for _, item in ipairs(items) do
		if item.texture then
			pool[#pool + 1] = item.texture
		end
	end
	self.pool = pool
end

function Reel:StartColumn(c)
	local settings = NS.GetSettings()
	local item = c.item
	local quality = item.quality or 1
	local speed = (settings.speed or 100) / 100

	-- The strip: filler icons, the real item last.
	local strip = {}
	local length = STRIP_MIN + math.random(0, STRIP_EXTRA)
	for i = 1, length - 1 do
		strip[i] = self.pool[math.random(#self.pool)]
	end
	strip[length] = item.texture or FILLER_ICONS[#FILLER_ICONS]
	c.strip = strip
	c.duration = (SPIN_TIME[quality] or SPIN_TIME[1]) * speed
	c.hold = (HOLD_TIME[quality] or HOLD_TIME[1]) * speed
	c.elapsed = 0
	c.state = "spinning"

	if not self.loopHandle then
		PlayKit("UI_BONUS_LOOT_ROLL_START")
		self.loopHandle = PlayKit("UI_BONUS_LOOT_ROLL_LOOP")
	end
	self:RenderColumn(c, 0)
end

-- Draw a column's strip with its position (in rows) at the middle of the window.
function Reel:RenderColumn(c, position)
	local strip = c.strip
	local base = math.floor(position)
	local frac = position - base
	local rowIndex = 0
	for k = -2, 2 do
		rowIndex = rowIndex + 1
		local tex = c.Rows[rowIndex]
		local stripIndex = base + k + 1
		if stripIndex >= 1 and stripIndex <= #strip then
			tex:SetTexture(strip[stripIndex])
			tex:ClearAllPoints()
			-- Items yet to come are below the middle; the strip moves up.
			tex:SetPoint("CENTER", c.View, "CENTER", 0, -(k - frac) * ROW)
			tex:Show()
		else
			tex:Hide()
		end
	end
end

function Reel:StopLoop()
	if self.loopHandle then
		StopSound(self.loopHandle)
		self.loopHandle = nil
	end
end

function Reel:LandColumn(c)
	local item = c.item
	local r, g, b = NS.QualityColor(item.quality)
	if c.strip then
		self:RenderColumn(c, #c.strip - 1)
	else
		-- Never started (Take all pressed early): just show the item.
		c.strip = { item.texture or FILLER_ICONS[#FILLER_ICONS] }
		self:RenderColumn(c, 0)
	end
	c.Border:SetVertexColor(r, g, b, 1)
	c.Flash:SetAlpha(0.9)
	c.Name:SetText(item.name or "")
	c.Name:SetTextColor(r, g, b)
	if (item.quantity or 1) > 1 then
		c.Quantity:SetText("x" .. item.quantity)
	else
		c.Quantity:SetText(NS.QualityName(item.quality))
	end
	c.state = "holding"
	c.elapsed = 0
	c.hold = c.hold or HOLD_TIME[item.quality or 1] or HOLD_TIME[1]

	self.landed = self.landed + 1
	if self.landed >= self.active then
		self:StopLoop()
	end
	local quality = item.quality or 1
	if quality >= 5 then
		PlayKit("UI_LEGENDARY_LOOT_TOAST")
	elseif quality >= 4 then
		PlayKit("UI_EPICLOOT_TOAST")
	elseif quality >= 2 then
		PlayKit("UI_RAID_LOOT_TOAST_LESSER_ITEM_WON")
	else
		PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
	end
	if self.callbacks.onLanded then
		self.callbacks.onLanded(item)
	end
end

function Reel:CheckFinished()
	for i = 1, self.active do
		if self.columns[i].state ~= "done" then
			return
		end
	end
	self.state = "idle"
	self:StopLoop()
	if self.callbacks.onFinished then
		self.callbacks.onFinished()
	end
end

function Reel:OnUpdate(elapsed)
	if self.state ~= "running" then
		return
	end
	self.clock = self.clock + elapsed
	for i = 1, self.active do
		local c = self.columns[i]
		if c.state == "waiting" and self.clock >= c.startAt then
			self:StartColumn(c)
		end
		if c.state == "spinning" then
			c.elapsed = c.elapsed + elapsed
			local t = math.min(c.elapsed / c.duration, 1)
			self:RenderColumn(c, EaseOutCubic(t) * (#c.strip - 1))
			if t >= 1 then
				self:LandColumn(c)
			end
		elseif c.state == "holding" then
			c.elapsed = c.elapsed + elapsed
			c.Flash:SetAlpha(math.max(0, 0.9 * (1 - c.elapsed / FLASH_TIME)))
			if c.elapsed >= c.hold then
				c.state = "done"
				self:CheckFinished()
			end
		end
	end
end

-- Stop everything, for example when the loot window closed under us.
function Reel:Abort()
	self.state = "idle"
	self.items = nil
	self.active = 0
	self:StopLoop()
	if self.frame then
		self.frame:Hide()
	end
end

-- Jump to the end: every column that has not landed lands right now.
function Reel:FinishNow()
	if self.state ~= "running" then
		return
	end
	for i = 1, self.active do
		local c = self.columns[i]
		if c.state == "waiting" or c.state == "spinning" then
			self:LandColumn(c)
		end
		c.state = "done"
	end
	self.state = "idle"
	self:StopLoop()
	if self.callbacks.onFinished then
		self.callbacks.onFinished()
	end
end

-------------------------------------------------------------------------------
-- Leftovers: items that could not be taken (bags full, not ours to take)
-------------------------------------------------------------------------------

function Reel:ShowLeftovers(entries, onTake)
	local f = self:Create()
	self.state = "idle"
	for _, c in ipairs(self.columns) do
		c:Hide()
	end
	local size = ICON * 0.7
	f:SetSize(SIDE_PADDING * 2 + 200, HEADER_HEIGHT + 20 + #entries * (size + 4) + FOOTER_HEIGHT)
	f.Counter:SetText("Still on the corpse, click to take")

	f.Leftovers = f.Leftovers or {}
	for _, button in ipairs(f.Leftovers) do
		button:Hide()
	end
	for i, entry in ipairs(entries) do
		local button = f.Leftovers[i]
		if not button then
			button = CreateFrame("Button", nil, f)
			button:SetSize(200, size)
			button.Icon = button:CreateTexture(nil, "ARTWORK")
			button.Icon:SetSize(size, size)
			button.Icon:SetPoint("LEFT")
			button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			button.Text:SetPoint("LEFT", button.Icon, "RIGHT", 6, 0)
			button.Text:SetPoint("RIGHT")
			button.Text:SetJustifyH("LEFT")
			button.Text:SetWordWrap(false)
			button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			f.Leftovers[i] = button
		end
		button:ClearAllPoints()
		button:SetPoint("TOP", f, "TOP", 0, -(HEADER_HEIGHT + 10 + (i - 1) * (size + 4)))
		button.Icon:SetTexture(entry.texture)
		local r, g, b = NS.QualityColor(entry.quality)
		button.Text:SetText(entry.name or "?")
		button.Text:SetTextColor(r, g, b)
		button:SetScript("OnClick", function()
			onTake(entry)
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(entry.name or "?", r, g, b)
			GameTooltip:AddLine(entry.reason or "", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", GameTooltip_Hide)
		button:Show()
	end
	f:Show()
end

function Reel:HideLeftovers()
	local f = self.frame
	if f and f.Leftovers then
		for _, button in ipairs(f.Leftovers) do
			button:Hide()
		end
	end
end
