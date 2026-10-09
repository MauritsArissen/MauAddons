-- MauLootbox reel: the slot machine window.
--
-- One column of item icons scrolls upward behind a window that shows three
-- rows, slows down and stops with the real item in the middle, then flashes,
-- shows the name and quality colour and hands control back (Loot.lua takes
-- the item at that moment).  Everything is plain frames and textures driven
-- by OnUpdate; nothing here talks to the loot API.

local _, NS = ...

local Reel = {}
NS.Reel = Reel

local ICON = 56           -- icon size
local ROW = 64            -- distance between rows
local VISIBLE_ROWS = 3
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

	-- The window the strip scrolls behind.
	local view = CreateFrame("Frame", nil, f)
	f.View = view
	view:SetSize(ICON + 24, ROW * VISIBLE_ROWS)
	view:SetPoint("TOP", f.Counter, "BOTTOM", 0, -8)
	view:SetClipsChildren(true)

	view.Background = view:CreateTexture(nil, "BACKGROUND")
	view.Background:SetAllPoints()
	view.Background:SetColorTexture(0, 0, 0, 0.6)

	-- Icons for the rows that can be on screen at once (one spare above and below).
	f.Rows = {}
	for i = 1, VISIBLE_ROWS + 2 do
		local tex = view:CreateTexture(nil, "ARTWORK")
		tex:SetSize(ICON, ICON)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		f.Rows[i] = tex
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
	f.Border = view:CreateTexture(nil, "OVERLAY", nil, 2)
	f.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	f.Border:SetBlendMode("ADD")
	f.Border:SetSize(ICON * 1.72, ICON * 1.72)
	f.Border:SetPoint("CENTER")
	f.Border:SetVertexColor(1, 1, 1, 0.35)

	-- White flash on landing.
	f.Flash = view:CreateTexture(nil, "OVERLAY", nil, 3)
	f.Flash:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.Flash:SetBlendMode("ADD")
	f.Flash:SetSize(ICON, ICON)
	f.Flash:SetPoint("CENTER")
	f.Flash:SetAlpha(0)

	f.Name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.Name:SetPoint("TOP", view, "BOTTOM", 0, -8)
	f.Name:SetWidth(190)
	f.Name:SetWordWrap(false)

	f.Quantity = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.Quantity:SetPoint("TOP", f.Name, "BOTTOM", 0, -2)

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
-- Showing and spinning
-------------------------------------------------------------------------------

-- items: list of { texture, name, quantity, quality }; the reel runs through
-- them one by one.  onLanded(item) is called the moment an item lands,
-- onFinished() when the last hold is over.
function Reel:Begin(items, callbacks)
	local f = self:Create()
	self.items = items
	self.index = 0
	self.callbacks = callbacks or {}
	self.onSkip = self.callbacks.onSkip
	self.onClose = self.callbacks.onClose
	self.state = "idle"
	self:BuildPool(items)
	f.Name:SetText("")
	f.Quantity:SetText("")
	f.Border:SetVertexColor(1, 1, 1, 0.35)
	f.Flash:SetAlpha(0)
	for _, tex in ipairs(f.Rows) do
		tex:Hide()
	end
	self:ApplyScale()
	f:Show()
	self:Next()
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

function Reel:Next()
	self.index = self.index + 1
	local item = self.items[self.index]
	if not item then
		self.state = "idle"
		if self.callbacks.onFinished then
			self.callbacks.onFinished()
		end
		return
	end
	self:Spin(item)
end

function Reel:Spin(item)
	local f = self.frame
	local settings = NS.GetSettings()
	local quality = item.quality or 1
	local speed = (settings.speed or 100) / 100

	-- The strip: filler icons, the real item last.
	local strip = {}
	local length = STRIP_MIN + math.random(0, STRIP_EXTRA)
	for i = 1, length - 1 do
		strip[i] = self.pool[math.random(#self.pool)]
	end
	strip[length] = item.texture or FILLER_ICONS[#FILLER_ICONS]
	self.strip = strip
	self.current = item
	self.duration = (SPIN_TIME[quality] or SPIN_TIME[1]) * speed
	self.hold = (HOLD_TIME[quality] or HOLD_TIME[1]) * speed
	self.elapsed = 0
	self.state = "spinning"
	self.lastRow = nil

	f.Counter:SetText(string.format("%d of %d", self.index, #self.items))
	f.Name:SetText("")
	f.Quantity:SetText("")
	f.Border:SetVertexColor(1, 1, 1, 0.35)
	f.Flash:SetAlpha(0)

	if self.loopHandle then
		StopSound(self.loopHandle)
		self.loopHandle = nil
	end
	PlayKit("UI_BONUS_LOOT_ROLL_START")
	self.loopHandle = PlayKit("UI_BONUS_LOOT_ROLL_LOOP")
	self:Render(0)
end

-- Draw the strip with its position (in rows) at the middle of the window.
function Reel:Render(position)
	local f = self.frame
	local strip = self.strip
	local base = math.floor(position)
	local frac = position - base
	local rowIndex = 0
	for k = -2, 2 do
		rowIndex = rowIndex + 1
		local tex = f.Rows[rowIndex]
		local stripIndex = base + k + 1
		if stripIndex >= 1 and stripIndex <= #strip then
			tex:SetTexture(strip[stripIndex])
			tex:ClearAllPoints()
			-- Items yet to come are below the middle; the strip moves up.
			tex:SetPoint("CENTER", f.View, "CENTER", 0, -(k - frac) * ROW)
			tex:Show()
		else
			tex:Hide()
		end
	end
end

function Reel:Land()
	local f = self.frame
	local item = self.current
	local r, g, b = NS.QualityColor(item.quality)
	self:Render(#self.strip - 1)
	f.Border:SetVertexColor(r, g, b, 1)
	f.Flash:SetAlpha(0.9)
	f.Name:SetText(item.name or "")
	f.Name:SetTextColor(r, g, b)
	if (item.quantity or 1) > 1 then
		f.Quantity:SetText("x" .. item.quantity)
	else
		f.Quantity:SetText(NS.QualityName(item.quality))
	end
	if self.loopHandle then
		StopSound(self.loopHandle)
		self.loopHandle = nil
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
	self.state = "holding"
	self.elapsed = 0
	if self.callbacks.onLanded then
		self.callbacks.onLanded(item)
	end
end

function Reel:OnUpdate(elapsed)
	if self.state == "spinning" then
		self.elapsed = self.elapsed + elapsed
		local t = math.min(self.elapsed / self.duration, 1)
		local position = EaseOutCubic(t) * (#self.strip - 1)
		self:Render(position)
		if t >= 1 then
			self:Land()
		end
	elseif self.state == "holding" then
		self.elapsed = self.elapsed + elapsed
		local f = self.frame
		f.Flash:SetAlpha(math.max(0, 0.9 * (1 - self.elapsed / FLASH_TIME)))
		if self.elapsed >= self.hold then
			self:Next()
		end
	end
end

-- Stop everything, for example when the loot window closed under us.
function Reel:Abort()
	self.state = "idle"
	self.items = nil
	if self.loopHandle then
		StopSound(self.loopHandle)
		self.loopHandle = nil
	end
	if self.frame then
		self.frame:Hide()
	end
end

-- Jump to the end: every remaining item counts as landed right now.
function Reel:FinishNow()
	if not self.items then
		return
	end
	if self.loopHandle then
		StopSound(self.loopHandle)
		self.loopHandle = nil
	end
	local from = self.index
	if self.state == "holding" then
		from = self.index + 1
	end
	for i = from, #self.items do
		if self.callbacks.onLanded then
			self.callbacks.onLanded(self.items[i])
		end
	end
	self.index = #self.items
	self.state = "idle"
	if self.callbacks.onFinished then
		self.callbacks.onFinished()
	end
end

-------------------------------------------------------------------------------
-- Leftovers: items that could not be taken (bags full, not ours to take)
-------------------------------------------------------------------------------

function Reel:ShowLeftovers(entries, onTake)
	local f = self:Create()
	f.Counter:SetText("Still on the corpse")
	f.Name:SetText("Click an item to take it")
	f.Name:SetTextColor(0.8, 0.8, 0.8)
	f.Quantity:SetText("")
	for _, tex in ipairs(f.Rows) do
		tex:Hide()
	end
	f.Border:SetVertexColor(1, 1, 1, 0)
	f.Flash:SetAlpha(0)

	f.Leftovers = f.Leftovers or {}
	for i, button in ipairs(f.Leftovers) do
		button:Hide()
	end
	for i, entry in ipairs(entries) do
		local button = f.Leftovers[i]
		if not button then
			button = CreateFrame("Button", nil, f.View)
			button:SetSize(ICON * 0.7, ICON * 0.7)
			button.Icon = button:CreateTexture(nil, "ARTWORK")
			button.Icon:SetAllPoints()
			button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			f.Leftovers[i] = button
		end
		button:ClearAllPoints()
		button:SetPoint("TOP", f.View, "TOP", 0, -6 - (i - 1) * (ICON * 0.7 + 4))
		button.Icon:SetTexture(entry.texture)
		button:SetScript("OnClick", function()
			onTake(entry)
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local r, g, b = NS.QualityColor(entry.quality)
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
