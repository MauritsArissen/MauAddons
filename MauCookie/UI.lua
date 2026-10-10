-- MauCookie window, laid out like the original: the left section with the
-- bakery name, the cookie counter band, the big cookie with its shine, the
-- buffs, the wrinklers, the milk and the Santa / dragon tabs; the middle
-- with the menu buttons, the news ticker and the building rows
-- (UI_Rows.lua) or a menu (UI_Menus.lua); the right column with the
-- upgrade crates and the building products (UI_Store.lua); the heavenly
-- tree over everything while ascending (UI_Ascend.lua).  Golden cookies,
-- reindeer and storm drops are buttons in a layer over the window.  All
-- art comes from the local Textures folder (see CLAUDE.md).

local _, NS = ...

local UI = {}
NS.UI = UI

UI.W, UI.H = 1000, 640
UI.TOP = 22
UI.LEFT_W = 300
UI.RIGHT_W = 318
UI.MID_X = 300
UI.MID_W = UI.W - UI.LEFT_W - UI.RIGHT_W
UI.CONTENT_H = UI.H - UI.TOP
UI.FONT = "Fonts\\FRIZQT__.TTF"
UI.TITLE_FONT = "Fonts\\MORPHEUS.TTF"
UI.WHITE = "Interface\\Buttons\\WHITE8X8"
UI.REFRESH_INTERVAL = 0.1

local W, H, TOP, LEFT_W, RIGHT_W, MID_X, MID_W, CONTENT_H = UI.W, UI.H, UI.TOP, UI.LEFT_W, UI.RIGHT_W, UI.MID_X, UI.MID_W, UI.CONTENT_H
local FONT, TITLE_FONT, WHITE = UI.FONT, UI.TITLE_FONT, UI.WHITE
local COOKIE_SIZE = 256
local MAX_FLOATS = 30
local MAX_NOTES = 6

-------------------------------------------------------------------------------
-- Art helpers (NS.ART from Art.lua: { w, h, textureW, textureH[, cols, frames] })
-------------------------------------------------------------------------------

local ART = NS.ART or {}

function NS.HasArt(key)
	return ART[key] ~= nil
end

-- Whole image from a padded texture.
function NS.SetArt(tex, key)
	local a = ART[key]
	tex:SetTexture(NS.Art(key))
	if a then
		tex:SetTexCoord(0, a[1] / a[3], 0, a[2] / a[4])
	else
		tex:SetTexCoord(0, 1, 0, 1)
	end
end

-- A 48 px cell of the icon sheet (tiles of 21 x 21 cells).
function NS.SetIcon(tex, cell)
	local info = ART.icons
	if not cell or not info then
		tex:SetTexture(WHITE)
		tex:SetVertexColor(0, 0, 0, 0)
		return
	end
	tex:SetVertexColor(1, 1, 1, 1)
	local per, size = info[3], info[4]
	local c, r = cell[1], cell[2]
	local tx, ty = math.floor(c / per), math.floor(r / per)
	tex:SetTexture(NS.ART_ROOT .. "icons_" .. tx .. "_" .. ty .. ".tga")
	local x = (c - tx * per) * size / 1024
	local y = (r - ty * per) * size / 1024
	tex:SetTexCoord(x, x + size / 1024, y, y + size / 1024)
end

-- Texture escape for tooltips: the icon sheet cell at the given size.
function NS.IconString(cell, size)
	local info = ART.icons
	if not cell or not info then
		return ""
	end
	size = size or 16
	local per, cs = info[3], info[4]
	local c, r = cell[1], cell[2]
	local tx, ty = math.floor(c / per), math.floor(r / per)
	local x = (c - tx * per) * cs
	local y = (r - ty * per) * cs
	return string.format("|T%sicons_%d_%d.tga:%d:%d:0:0:1024:1024:%d:%d:%d:%d|t", NS.ART_ROOT, tx, ty, size, size, x, x + cs, y, y + cs)
end

-- A 64 px cell of the buildings sheet (column 0 icon, 1 greyed, 2 and 3 for Business day).
function NS.SetBuildingIcon(tex, column, row)
	local a = ART.buildings
	tex:SetTexture(NS.Art("buildings"))
	if a then
		tex:SetTexCoord(column * 64 / a[3], (column + 1) * 64 / a[3], row * 64 / a[4], (row + 1) * 64 / a[4])
	end
end

-- Frame i (0-based) of a strip re-laid into a grid by the converter.
function NS.SetFrame(tex, key, i)
	local a = ART[key]
	tex:SetTexture(NS.Art(key))
	if a and a[5] then
		local cols = a[5]
		local fx, fy = i % cols, math.floor(i / cols)
		tex:SetTexCoord(fx * a[1] / a[3], (fx + 1) * a[1] / a[3], fy * a[2] / a[4], (fy + 1) * a[2] / a[4])
	end
end

-- A frame of a plain sheet (hearts, bunnies, familiars: 96 px cells).
function NS.SetSheetCell(tex, key, cellW, cellH, col, row)
	local a = ART[key]
	tex:SetTexture(NS.Art(key))
	if a then
		tex:SetTexCoord(col * cellW / a[3], (col + 1) * cellW / a[3], row * cellH / a[4], (row + 1) * cellH / a[4])
	end
end

-------------------------------------------------------------------------------
-- Widget helpers
-------------------------------------------------------------------------------

function UI.Text(parent, size, flags, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(FONT, size or 12, flags or "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH("LEFT")
	return fs
end

function UI.Tex(parent, layer, key)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	if key then
		NS.SetArt(tex, key)
	end
	return tex
end

function UI.Solid(parent, layer, r, g, b, a)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(WHITE)
	tex:SetVertexColor(r, g, b, a or 1)
	return tex
end

-- The original's small framed button (dark noise, pale border).
function UI.FancyButton(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height)
	b.Bg = UI.Solid(b, "BACKGROUND", 0.1, 0.08, 0.08, 0.95)
	b.Bg:SetAllPoints()
	b.Border = b:CreateTexture(nil, "BORDER")
	b.Border:SetTexture(WHITE)
	b.Border:SetVertexColor(0.85, 0.8, 0.55, 0.6)
	b.Border:SetPoint("TOPLEFT", -1, 1)
	b.Border:SetPoint("BOTTOMRIGHT", 1, -1)
	b.Bg:SetDrawLayer("BORDER", 1)
	b.Label = UI.Text(b, 12, "", "OVERLAY")
	b.Label:SetPoint("CENTER")
	b.Label:SetJustifyH("CENTER")
	b.Label:SetText(text)
	b.Label:SetTextColor(0.95, 0.9, 0.8)
	b:SetHighlightTexture(WHITE)
	b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	b:SetScript("OnClick", onClick)
	b.SetText = function(self, t)
		self.Label:SetText(t)
	end
	b.SetEnabledLook = function(self, enabled)
		self:SetEnabled(enabled)
		self.Label:SetTextColor(enabled and 0.95 or 0.5, enabled and 0.9 or 0.5, enabled and 0.8 or 0.5)
	end
	return b
end

function UI.SetTooltip(frame, builder)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local ok = NS.Guard("tooltip", builder, self)
		if ok then
			GameTooltip:Show()
		else
			GameTooltip:Hide()
		end
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- A plain scroll frame with wheel scrolling and a thin bar.
function UI.Scroll(parent, width, height)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	sf:SetSize(width, height)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(width, height)
	sf:SetScrollChild(child)
	sf.Child = child
	sf.Bar = UI.Solid(sf, "OVERLAY", 1, 1, 1, 0.25)
	sf.Bar:SetWidth(4)
	sf.Bar:SetPoint("TOPRIGHT", -2, 0)
	sf.Bar:SetHeight(20)
	sf.Bar:Hide()
	sf.UpdateBar = function(self)
		local range = math.max(0, self.Child:GetHeight() - self:GetHeight())
		if range <= 0 then
			self.Bar:Hide()
			self:SetVerticalScroll(0)
			return
		end
		self.Bar:Show()
		local frac = self:GetHeight() / self.Child:GetHeight()
		local barH = math.max(20, frac * self:GetHeight())
		self.Bar:SetHeight(barH)
		local scroll = math.min(self:GetVerticalScroll(), range)
		self:SetVerticalScroll(scroll)
		self.Bar:ClearAllPoints()
		self.Bar:SetPoint("TOPRIGHT", -2, -(scroll / range) * (self:GetHeight() - barH))
	end
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, self.Child:GetHeight() - self:GetHeight())
		local scroll = NS.Clamp(self:GetVerticalScroll() - delta * 60, 0, range)
		self:SetVerticalScroll(scroll)
		self:UpdateBar()
	end)
	sf.SetContentHeight = function(self, h)
		self.Child:SetHeight(math.max(h, 1))
		self:UpdateBar()
	end
	return sf
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------

function UI:Create()
	if self.frame then
		return self.frame
	end
	local f = CreateFrame("Frame", "MauCookieFrame", UIParent)
	self.frame = f
	f:SetSize(W, H)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	f.Bg = UI.Solid(f, "BACKGROUND", 0, 0, 0, 1)
	f.Bg:SetAllPoints()
	f.Edge = f:CreateTexture(nil, "BORDER")
	f.Edge:SetTexture(WHITE)
	f.Edge:SetVertexColor(0.25, 0.22, 0.2, 1)
	f.Edge:SetPoint("TOPLEFT", -1, 1)
	f.Edge:SetPoint("BOTTOMRIGHT", 1, -1)
	f.Bg:SetDrawLayer("BORDER", 1)

	-- Title bar: drag handle, name, close.
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(TOP)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relativePoint, x, y = f:GetPoint()
		MauCookieDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	bar.Bg = UI.Tex(bar, "BACKGROUND", "darkNoiseTopBar")
	bar.Bg:SetAllPoints()
	bar.Bg:SetHorizTile(true)
	bar.Bg:SetTexture(NS.Art("darkNoiseTopBar"), "REPEAT", "CLAMP")
	bar.Bg:SetTexCoord(0, W / 512, 0, TOP / 64)
	bar.Title = UI.Text(bar, 12, "")
	bar.Title:SetPoint("LEFT", 8, 0)
	bar.Title:SetText("MauCookie")
	bar.Title:SetTextColor(0.8, 0.75, 0.65)
	bar.Hint = UI.Text(bar, 10, "")
	bar.Hint:SetPoint("LEFT", bar.Title, "RIGHT", 10, 0)
	bar.Hint:SetTextColor(0.5, 0.5, 0.5)
	bar.Hint:SetText("drag here to move, /mck options for settings")
	bar.Close = CreateFrame("Button", nil, bar)
	bar.Close:SetSize(TOP, TOP)
	bar.Close:SetPoint("RIGHT")
	bar.Close.Label = UI.Text(bar.Close, 14, "")
	bar.Close.Label:SetPoint("CENTER")
	bar.Close.Label:SetText("x")
	bar.Close:SetHighlightTexture(WHITE)
	bar.Close:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
	bar.Close:SetScript("OnClick", function()
		f:Hide()
	end)
	self.bar = bar

	self:CreateLeft(f)
	self:CreateMiddle(f)
	self:CreateStore(f)
	self:CreateMenus(f)
	self:CreateShimmerLayer(f)
	-- Floating texts over the whole window.
	local floats = CreateFrame("Frame", nil, f)
	floats:SetPoint("TOPLEFT", 0, -TOP)
	floats:SetPoint("BOTTOMRIGHT")
	floats:SetFrameLevel(f:GetFrameLevel() + 45)
	self.floatLayer = floats
	self:CreateNotes(f)
	self:CreatePrompt(f)
	self:CreateAscend(f)

	f:SetScript("OnShow", function()
		UI:OnShow()
	end)
	f:SetScript("OnHide", function()
		GameTooltip:Hide()
		UI.autoOpened = nil
	end)
	f:SetScript("OnUpdate", function(_, elapsed)
		NS.Guard("window", UI.OnUpdate, UI, elapsed)
	end)
	if UISpecialFrames then
		tinsert(UISpecialFrames, "MauCookieFrame")
	end
	self:ApplyPosition()
	self:ApplyScale()
	return f
end

function UI:OnShow()
	self:RefreshBackground()
	self:Refresh(true)
	self:RefreshWrinklers()
	self:SyncShimmers()
	self:OnAscendChanged()
	if NS.Game.ticker == "" then
		NS.Game:NewTicker(true)
	end
	self:OnTicker()
end

-------------------------------------------------------------------------------
-- Left section
-------------------------------------------------------------------------------

function UI:CreateLeft(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(LEFT_W, CONTENT_H)
	p:SetPoint("TOPLEFT", 0, -TOP)
	p:SetClipsChildren(true)
	self.left = p

	p.Bg = p:CreateTexture(nil, "BACKGROUND")
	p.Bg:SetAllPoints()
	p.Bg:SetTexture(NS.Art("bgBlue"), "REPEAT", "REPEAT")
	p.Bg:SetHorizTile(true)
	p.Bg:SetVertTile(true)
	p.Bg:SetTexCoord(0, LEFT_W / 512, 0, CONTENT_H / 512)
	p.bgKey = "bgBlue"

	-- Milk, under everything else but above the background.
	p.Milk = p:CreateTexture(nil, "BORDER")
	p.Milk:SetTexture(NS.Art("milkPlain"), "REPEAT", "REPEAT")
	p.Milk:SetHorizTile(true)
	p.Milk:SetVertTile(true)
	p.Milk:SetPoint("BOTTOMLEFT")
	p.Milk:SetPoint("BOTTOMRIGHT")
	p.Milk:SetHeight(1)
	p.Milk:SetAlpha(0.9)
	p.milkKey = "milkPlain"
	p.milkOffset = 0
	p.milkHd = 0

	-- Bakery name.
	p.Name = p:CreateFontString(nil, "OVERLAY")
	p.Name:SetFont(TITLE_FONT, 20, "")
	p.Name:SetShadowOffset(1, -1)
	p.Name:SetPoint("TOP", 0, -14)
	p.Name:SetWidth(LEFT_W - 16)
	p.Name:SetJustifyH("CENTER")
	p.Name:SetText((NS.ShortName(UnitName("player")) or "Your") .. "'s bakery")

	-- The cookie counter band at 10%.
	local band = CreateFrame("Frame", nil, p)
	band:SetPoint("TOPLEFT", 0, -math.floor(CONTENT_H * 0.1))
	band:SetPoint("TOPRIGHT", 0, -math.floor(CONTENT_H * 0.1))
	band:SetHeight(58)
	band.Bg = UI.Solid(band, "BACKGROUND", 0, 0, 0, 0.4)
	band.Bg:SetAllPoints()
	band.Count = band:CreateFontString(nil, "OVERLAY")
	band.Count:SetFont(FONT, 22, "OUTLINE")
	band.Count:SetPoint("TOP", 0, -6)
	band.Count:SetWidth(LEFT_W - 8)
	band.Count:SetJustifyH("CENTER")
	band.Cps = band:CreateFontString(nil, "OVERLAY")
	band.Cps:SetFont(FONT, 12, "OUTLINE")
	band.Cps:SetPoint("TOP", band.Count, "BOTTOM", 0, -4)
	band.Cps:SetWidth(LEFT_W - 8)
	band.Cps:SetJustifyH("CENTER")
	p.Band = band

	-- The big cookie at 40%.
	local cookieY = math.floor(CONTENT_H * 0.4)
	local cookie = CreateFrame("Button", nil, p)
	cookie:SetSize(COOKIE_SIZE, COOKIE_SIZE)
	cookie:SetPoint("CENTER", p, "TOPLEFT", LEFT_W / 2, -cookieY)
	cookie:SetFrameLevel(p:GetFrameLevel() + 3)
	cookie.Shine = p:CreateTexture(nil, "ARTWORK", nil, -1)
	NS.SetArt(cookie.Shine, "shine")
	cookie.Shine:SetBlendMode("ADD")
	cookie.Shine:SetAlpha(0.6)
	cookie.Shine:SetPoint("CENTER", cookie, "CENTER")
	cookie.Shine:SetSize(300, 300)
	cookie.Shine2 = p:CreateTexture(nil, "ARTWORK", nil, -1)
	NS.SetArt(cookie.Shine2, "shine")
	cookie.Shine2:SetBlendMode("ADD")
	cookie.Shine2:SetAlpha(0.4)
	cookie.Shine2:SetPoint("CENTER", cookie, "CENTER")
	cookie.Shine2:SetSize(300, 300)
	cookie.Shadow = p:CreateTexture(nil, "ARTWORK", nil, 0)
	NS.SetArt(cookie.Shadow, "cookieShadow")
	cookie.Shadow:SetPoint("CENTER", cookie, "CENTER", 0, -12)
	cookie.Shadow:SetSize(COOKIE_SIZE * 1.15, COOKIE_SIZE * 1.15)
	cookie.Shadow:SetAlpha(0.5)
	cookie.Icon = cookie:CreateTexture(nil, "ARTWORK")
	NS.SetArt(cookie.Icon, "cookie")
	cookie.Icon:SetAllPoints()
	cookie:RegisterForClicks("LeftButtonDown")
	cookie:SetScript("OnClick", function()
		NS.Game:ClickCookie()
	end)
	cookie:SetScript("OnMouseDown", function(self)
		self.pressed = true
	end)
	cookie:SetScript("OnMouseUp", function(self)
		self.pressed = nil
	end)
	cookie:SetScript("OnEnter", function(self)
		self.hover = true
	end)
	cookie:SetScript("OnLeave", function(self)
		self.hover = nil
	end)
	cookie.size = 1
	p.Cookie = cookie
	p.cookieY = cookieY

	-- Floating +amount texts and wrinklers above the cookie.
	p.FloatLayer = CreateFrame("Frame", nil, p)
	p.FloatLayer:SetAllPoints()
	p.FloatLayer:SetFrameLevel(cookie:GetFrameLevel() + 2)
	self.floats, self.floatPool = {}, {}

	-- Wrinklers: fourteen square buttons rotated towards the cookie.
	p.WrinklerLayer = CreateFrame("Frame", nil, p)
	p.WrinklerLayer:SetAllPoints()
	p.WrinklerLayer:SetFrameLevel(cookie:GetFrameLevel() + 1)
	p.Wrinklers = {}
	for i = 1, 14 do
		local w = CreateFrame("Button", nil, p.WrinklerLayer)
		w:SetSize(230, 230)
		w.Icon = w:CreateTexture(nil, "ARTWORK")
		w.Icon:SetAllPoints()
		NS.SetArt(w.Icon, "wrinkler")
		w:RegisterForClicks("LeftButtonDown")
		w:SetScript("OnClick", function(self)
			if self.data then
				NS.Game:ClickWrinkler(self.data)
			end
		end)
		UI.SetTooltip(w, function(self)
			local me = self.data
			if not me then
				return
			end
			GameTooltip:SetText(me.type == 1 and "Shiny wrinkler" or "Wrinkler")
			if NS.Game:Has("Eye of the wrinkler") then
				GameTooltip:AddLine("Swallowed: " .. NS.Beautify(me.sucked) .. " cookies", 1, 1, 1)
			end
			GameTooltip:AddLine("Click it a few times to burst it and get the cookies it ate back, with interest.", 0.7, 0.7, 0.7, true)
		end)
		w:Hide()
		p.Wrinklers[i] = w
	end

	-- Buffs at the top right, 36 px crates with pie timers.
	p.Buffs = {}
	for i = 1, 12 do
		local b = CreateFrame("Frame", nil, p)
		b:SetSize(36, 36)
		b:SetPoint("TOPRIGHT", -10, -40 - (i - 1) * 42)
		b.Frame = b:CreateTexture(nil, "BORDER")
		b.Frame:SetPoint("TOPLEFT", -4, 4)
		b.Frame:SetPoint("BOTTOMRIGHT", 4, -4)
		NS.SetSheetCell(b.Frame, "upgradeFrame", 60, 60, 0, 0)
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetAllPoints()
		b.Pie = b:CreateTexture(nil, "OVERLAY")
		b.Pie:SetAllPoints()
		b.Pie:SetAlpha(0.5)
		b:EnableMouse(true)
		UI.SetTooltip(b, function(self)
			if self.buff then
				GameTooltip:SetText(self.buff.name)
				GameTooltip:AddLine(self.buff.desc, 1, 1, 1, true)
				GameTooltip:AddLine(NS.FormatDuration(self.buff.time) .. " left", 0.7, 0.7, 0.7)
			end
		end)
		b:Hide()
		p.Buffs[i] = b
	end

	-- Prestige line under the band.
	p.Prestige = UI.Text(p, 11, "OUTLINE")
	p.Prestige:SetPoint("TOP", band, "BOTTOM", 0, -2)
	p.Prestige:SetWidth(LEFT_W - 8)
	p.Prestige:SetJustifyH("CENTER")
	p.Prestige:SetTextColor(0.8, 0.85, 1)

	-- Santa / dragon tabs at the bottom left.
	p.Tabs = {}
	for i = 1, 2 do
		local t = CreateFrame("Button", nil, p)
		t:SetSize(48, 48)
		t.Icon = t:CreateTexture(nil, "ARTWORK")
		t.Icon:SetAllPoints()
		t:SetHighlightTexture(WHITE)
		t:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
		t:SetScript("OnClick", function(self)
			UI:ToggleSpecial(self.kind)
		end)
		UI.SetTooltip(t, function(self)
			GameTooltip:SetText(self.kind == "santa" and NS.Game:SantaName() or (NS.Game:DragonLevelInfo() or {}).name or "Dragon")
			GameTooltip:AddLine("Click to open.", 0.7, 0.7, 0.7)
		end)
		t:Hide()
		p.Tabs[i] = t
	end
	self:CreateSpecialPanel(p)
end

function UI:RefreshBackground()
	local p = self.left
	local S = NS.Game.save
	local key = "bgBlue"
	local bg = NS.BGS[(S.bgType or 0) + 1]
	if S.bgType and S.bgType > 0 and bg then
		key = bg.pic
	else
		if (S.elderWrath or 0) > 0 then
			key = "grandmas" .. math.min(3, S.elderWrath)
		elseif S.season == "christmas" then
			key = "bgSnowy"
		elseif S.season == "fools" then
			key = "bgMoney"
		end
	end
	if not NS.HasArt(key) then
		key = "bgBlue"
	end
	if p.bgKey ~= key then
		p.bgKey = key
		p.Bg:SetTexture(NS.Art(key), "REPEAT", "REPEAT")
		p.Bg:SetTexCoord(0, LEFT_W / 512, 0, CONTENT_H / 512)
	end
	local milk = NS.Game.milk or NS.MILK_RANKS[1]
	if (S.milkType or 0) > 0 and NS.MILKS[S.milkType + 1] then
		milk = NS.MILKS[S.milkType + 1]
	end
	local mkey = milk and milk.pic or "milkPlain"
	if not NS.HasArt(mkey) then
		mkey = "milkPlain"
	end
	if p.milkKey ~= mkey then
		p.milkKey = mkey
		p.Milk:SetTexture(NS.Art(mkey), "REPEAT", "REPEAT")
	end
end

function UI:RefreshWrinklers()
	local p = self.left
	if not p then
		return
	end
	local game = NS.Game
	local max = game:GetWrinklersMax()
	for i, w in ipairs(p.Wrinklers) do
		local me = game:Wrinklers()[i]
		if me and me.phase > 0 then
			w.data = me
			local key = me.type == 1 and "wrinklershiny" or (game.save.season == "christmas" and "wrinklerwinter" or "wrinkler")
			if w.key ~= key then
				w.key = key
				NS.SetArt(w.Icon, key)
			end
			w:Show()
		else
			w.data = nil
			w:Hide()
		end
	end
	p.wrinklerMax = max
end

-- Positions follow the original: r = id / max * 360, distance 128 * (2 - close).
function UI:UpdateWrinklers(t)
	local p = self.left
	local max = p.wrinklerMax or 10
	for i, w in ipairs(p.Wrinklers) do
		local me = w.data
		if me and w:IsShown() then
			local d = 128 * (2 - me.close) + math.cos(t * 1.5 + me.id) * 4
			local r = (me.id / max) * 360 + math.sin(t * 1.5 + me.id) * 4
			local rad = math.rad(r)
			local x = math.sin(rad) * d
			local y = math.cos(rad) * d
			w:ClearAllPoints()
			w:SetPoint("CENTER", p.Cookie, "CENTER", x, -y)
			-- The sprite points down (head at the bottom) in the sheet; face the cookie.
			w.Icon:SetRotation(math.rad(-r))
		end
	end
end

-------------------------------------------------------------------------------
-- Middle section: menu bar, ticker, rows / menus host
-------------------------------------------------------------------------------

UI.BAR_H = 44
UI.TICKER_H = 64

function UI:CreateMiddle(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(MID_W, CONTENT_H)
	p:SetPoint("TOPLEFT", MID_X, -TOP)
	p:SetClipsChildren(true)
	self.middle = p
	p.Bg = p:CreateTexture(nil, "BACKGROUND")
	p.Bg:SetAllPoints()
	p.Bg:SetTexture(NS.Art("darkNoise"), "REPEAT", "REPEAT")
	p.Bg:SetHorizTile(true)
	p.Bg:SetVertTile(true)
	p.Bg:SetTexCoord(0, MID_W / 512, 0, CONTENT_H / 512)
	p.Bg:SetVertexColor(0.55, 0.55, 0.55)

	-- Menu buttons.
	local bar = CreateFrame("Frame", nil, p)
	bar:SetPoint("TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", 0, 0)
	bar:SetHeight(self.BAR_H)
	p.Bar = bar
	local names = { { "Options", "options" }, { "Stats", "stats" }, { "Info", "info" }, { "Legacy", "legacy" }, { "Guild", "guild" } }
	bar.Buttons = {}
	local x = 8
	for _, def in ipairs(names) do
		local b = UI.FancyButton(bar, def[1], 64, 24, function()
			UI:ToggleMenu(def[2])
		end)
		b:SetPoint("LEFT", x, 0)
		b.menu = def[2]
		bar.Buttons[def[2]] = b
		x = x + 68
	end
	-- Sugar lump under the Stats button.
	local lump = CreateFrame("Button", nil, bar)
	lump:SetSize(40, 40)
	lump:SetPoint("LEFT", bar.Buttons.stats, "RIGHT", 2, -14)
	lump:SetFrameLevel(bar:GetFrameLevel() + 5)
	lump.Icon = lump:CreateTexture(nil, "ARTWORK")
	lump.Icon:SetAllPoints()
	lump.Icon2 = lump:CreateTexture(nil, "ARTWORK", nil, 1)
	lump.Icon2:SetAllPoints()
	lump.Count = UI.Text(lump, 12, "OUTLINE")
	lump.Count:SetPoint("LEFT", lump, "RIGHT", 2, 6)
	lump.Count:SetTextColor(0.4, 0.8, 1)
	lump:SetScript("OnClick", function()
		NS.Game:ClickLump()
		UI:Refresh(true)
	end)
	UI.SetTooltip(lump, function()
		GameTooltip:SetText("Sugar lump")
		for i, line in ipairs(NS.Game:LumpTooltipLines()) do
			GameTooltip:AddLine(line, i == 1 and 1 or 0.8, i == 1 and 1 or 0.8, i == 1 and 1 or 0.8, true)
		end
	end)
	lump:Hide()
	bar.Lump = lump

	-- The news ticker.
	local ticker = CreateFrame("Button", nil, p)
	ticker:SetPoint("TOPLEFT", 0, -self.BAR_H)
	ticker:SetPoint("TOPRIGHT", 0, -self.BAR_H)
	ticker:SetHeight(self.TICKER_H)
	ticker.Bg = ticker:CreateTexture(nil, "BACKGROUND")
	NS.SetArt(ticker.Bg, "shadedBorders")
	ticker.Bg:SetAllPoints()
	ticker.Bg:SetAlpha(0.7)
	ticker.Text = UI.Text(ticker, 13, "")
	ticker.Text:SetPoint("TOPLEFT", 16, -10)
	ticker.Text:SetPoint("BOTTOMRIGHT", -16, 10)
	ticker.Text:SetJustifyH("CENTER")
	ticker.Text:SetJustifyV("MIDDLE")
	ticker.Text:SetWordWrap(true)
	ticker.Text:SetTextColor(0.9, 0.9, 0.9)
	ticker.Icon = ticker:CreateTexture(nil, "ARTWORK")
	ticker.Icon:SetSize(24, 24)
	ticker.Icon:SetPoint("LEFT", 8, 0)
	NS.SetIcon(ticker.Icon, { 29, 8 })
	ticker.Icon:Hide()
	ticker:SetScript("OnClick", function()
		NS.Game:ClickTicker()
	end)
	ticker:SetHighlightTexture(WHITE)
	ticker:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
	p.Ticker = ticker

	-- Host for the building rows (UI_Rows.lua) and the menus (UI_Menus.lua).
	local host = CreateFrame("Frame", nil, p)
	host:SetPoint("TOPLEFT", 0, -(self.BAR_H + self.TICKER_H))
	host:SetPoint("BOTTOMRIGHT", 0, 0)
	p.Host = host
	self:CreateRows(host)
end

function UI:OnTicker()
	if not self.middle then
		return
	end
	local t = self.middle.Ticker
	local game = NS.Game
	t.Text:SetText(game.ticker or "")
	if game.tickerEffect then
		t.Text:SetTextColor(1, 0.9, 0.5)
		t.Icon:Show()
	else
		t.Text:SetTextColor(0.9, 0.9, 0.9)
		t.Icon:Hide()
	end
	t.fade = 0
end

-------------------------------------------------------------------------------
-- Shimmers: golden and wrath cookies, reindeer, storm drops
-------------------------------------------------------------------------------

function UI:CreateShimmerLayer(f)
	local layer = CreateFrame("Frame", nil, f)
	layer:SetPoint("TOPLEFT", 0, -TOP)
	layer:SetPoint("BOTTOMRIGHT", -RIGHT_W, 0)
	layer:SetFrameLevel(f:GetFrameLevel() + 40)
	self.shimmerLayer = layer
	self.shimmerButtons = {}
	self.shimmerPool = {}
end

local function ShimmerButton(self)
	local b = table.remove(self.shimmerPool)
	if b then
		return b
	end
	b = CreateFrame("Button", nil, self.shimmerLayer)
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetAllPoints()
	b.Glow = b:CreateTexture(nil, "BACKGROUND")
	NS.SetArt(b.Glow, "glint")
	b.Glow:SetBlendMode("ADD")
	b.Glow:SetPoint("CENTER")
	b.Glow:SetAlpha(0.4)
	b:RegisterForClicks("LeftButtonDown")
	b:SetScript("OnClick", function(self)
		if self.shimmer then
			NS.Game:PopShimmer(self.shimmer)
		end
	end)
	b:SetHighlightTexture(WHITE)
	b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
	return b
end

function UI:ShimmerLook(b, me)
	local S = NS.Game.save
	local size = 96 * (me.sizeMult or 1)
	b:SetSize(size, size)
	b.Glow:SetSize(size * 1.6, size * 1.6)
	b.Icon:SetVertexColor(1, 1, 1, 1)
	if me.type == "reindeer" then
		NS.SetArt(b.Icon, "reindeer")
		b:SetSize(167, 212)
		b.Glow:Hide()
		return
	end
	b.Glow:Show()
	local wrath = me.wrath and 1 or 0
	if S.season == "valentines" and NS.HasArt("hearts") then
		NS.SetSheetCell(b.Icon, "hearts", 96, 96, me.variant or 0, wrath)
	elseif S.season == "fools" and NS.HasArt("spamCookies") then
		NS.SetSheetCell(b.Icon, "spamCookies", 128, 128, (me.variant or 0) % 4, wrath)
	elseif S.season == "easter" and NS.HasArt("bunnies") then
		NS.SetSheetCell(b.Icon, "bunnies", 96, 96, (me.variant or 0) % 4, wrath)
	elseif S.season == "halloween" and NS.HasArt("familiars") then
		NS.SetSheetCell(b.Icon, "familiars", 96, 96, (me.variant or 0) % 4, wrath)
	elseif S.season == "christmas" and NS.HasArt("goldenWreath") then
		NS.SetArt(b.Icon, me.wrath and "wrathWreath" or "goldenWreath")
	else
		NS.SetArt(b.Icon, me.wrath and "wrath" or "golden")
	end
	if me.wrath then
		b.Glow:SetVertexColor(1, 0.3, 0.2)
	else
		b.Glow:SetVertexColor(1, 0.9, 0.5)
	end
end

function UI:OnShimmerAdded(me)
	if not self.frame then
		return
	end
	local b = ShimmerButton(self)
	b.shimmer = me
	me.variant = math.random(0, 7)
	local layer = self.shimmerLayer
	local lw, lh = layer:GetWidth(), layer:GetHeight()
	if me.type == "reindeer" then
		me.x = -100
		me.y = 128 + math.random() * math.max(0, lh - 256)
	else
		me.x = 64 + math.random() * math.max(0, lw - 128)
		me.y = 64 + math.random() * math.max(0, lh - 128)
	end
	self:ShimmerLook(b, me)
	b:ClearAllPoints()
	b:SetPoint("CENTER", layer, "TOPLEFT", me.x, -me.y)
	b:Show()
	self.shimmerButtons[me] = b
end

function UI:OnShimmerRemoved(me)
	local b = self.shimmerButtons[me]
	if b then
		b:Hide()
		b.shimmer = nil
		self.shimmerButtons[me] = nil
		table.insert(self.shimmerPool, b)
	end
end

function UI:SyncShimmers()
	if not self.frame then
		return
	end
	for me, b in pairs(self.shimmerButtons) do
		local alive = false
		for _, s in ipairs(NS.Game.shimmers) do
			if s == me then
				alive = true
			end
		end
		if not alive then
			self:OnShimmerRemoved(me)
		end
	end
	for _, me in ipairs(NS.Game.shimmers) do
		if not self.shimmerButtons[me] then
			self:OnShimmerAdded(me)
		end
	end
end

function UI:UpdateShimmers(dt)
	local layer = self.shimmerLayer
	local lw = layer:GetWidth()
	for me, b in pairs(self.shimmerButtons) do
		local frac = 1 - me.life / math.max(0.01, me.dur)
		if me.type == "reindeer" then
			me.x = -100 + frac * (lw + 200)
			b:ClearAllPoints()
			b:SetPoint("CENTER", layer, "TOPLEFT", me.x, -me.y + math.sin(frac * 40) * 6)
		else
			local curve = 1 - ((frac * 2 - 1) ^ 4)
			local size = 96 * (me.sizeMult or 1) * (0.6 + 0.4 * math.max(0, curve)) * (1 + 0.04 * math.sin(GetTime() * 6))
			b:SetSize(size, size)
			b:SetAlpha(math.max(0.2, curve))
			b.Icon:SetRotation(math.sin(GetTime() * 2 + me.id) * 0.1)
		end
	end
end

-------------------------------------------------------------------------------
-- Notifications (the original's notes, bottom of the middle section)
-------------------------------------------------------------------------------

function UI:CreateNotes(f)
	self.notes = {}
	self.noteQueue = {}
	for i = 1, MAX_NOTES do
		local n = CreateFrame("Button", nil, f)
		n:SetSize(MID_W - 32, 56)
		n:SetFrameLevel(f:GetFrameLevel() + 30)
		n.Bg = n:CreateTexture(nil, "BACKGROUND")
		NS.SetArt(n.Bg, "shadedBordersSoft")
		n.Bg:SetAllPoints()
		n.Fill = UI.Solid(n, "BACKGROUND", 0.05, 0.04, 0.04, 0.9)
		n.Fill:SetAllPoints()
		n.Fill:SetDrawLayer("BACKGROUND", -1)
		n.Icon = n:CreateTexture(nil, "ARTWORK")
		n.Icon:SetSize(44, 44)
		n.Icon:SetPoint("LEFT", 6, 0)
		n.Title = UI.Text(n, 13, "")
		n.Title:SetPoint("TOPLEFT", 58, -8)
		n.Title:SetPoint("RIGHT", -8, 0)
		n.Title:SetTextColor(1, 0.95, 0.8)
		n.Body = UI.Text(n, 11, "")
		n.Body:SetPoint("TOPLEFT", n.Title, "BOTTOMLEFT", 0, -2)
		n.Body:SetPoint("BOTTOMRIGHT", -8, 6)
		n.Body:SetJustifyV("TOP")
		n.Body:SetWordWrap(true)
		n.Body:SetTextColor(0.85, 0.85, 0.85)
		n:SetScript("OnClick", function(self)
			self.life = 0
		end)
		n.born = 0
		n.life = 0
		n:Hide()
		self.notes[i] = n
	end
end

function UI:Notify(title, text, icon, quick)
	if not self.frame then
		return
	end
	if not self.frame:IsShown() then
		-- Keep the important ones for when the window opens.
		if not quick and #self.noteQueue < MAX_NOTES then
			table.insert(self.noteQueue, { title, text, icon })
		end
		return
	end
	-- Find a free note, or recycle the oldest.
	local note
	for _, n in ipairs(self.notes) do
		if not n:IsShown() then
			note = n
			break
		end
	end
	if not note then
		note = self.notes[1]
		for _, n in ipairs(self.notes) do
			if n.born < note.born then
				note = n
			end
		end
	end
	note.Title:SetText(title or "")
	note.Body:SetText(text or "")
	if icon then
		NS.SetIcon(note.Icon, icon)
		note.Icon:Show()
	else
		note.Icon:Hide()
	end
	note.life = quick and 4 or 8
	note.born = GetTime()
	note:SetAlpha(1)
	note:Show()
	self:LayoutNotes()
end

function UI:LayoutNotes()
	local shown = {}
	for _, n in ipairs(self.notes) do
		if n:IsShown() then
			table.insert(shown, n)
		end
	end
	table.sort(shown, function(a, b)
		return a.born > b.born
	end)
	for i, n in ipairs(shown) do
		n:ClearAllPoints()
		n:SetPoint("BOTTOMLEFT", self.middle, "BOTTOMLEFT", 16, 8 + (i - 1) * 60)
	end
end

function UI:UpdateNotes(dt)
	local changed = false
	for _, n in ipairs(self.notes) do
		if n:IsShown() then
			n.life = n.life - dt
			if n.life <= 0 then
				n:Hide()
				changed = true
			elseif n.life < 1 then
				n:SetAlpha(n.life)
			end
		end
	end
	if changed then
		self:LayoutNotes()
	end
	if #self.noteQueue > 0 then
		local q = table.remove(self.noteQueue, 1)
		self:Notify(q[1], q[2], q[3])
	end
end

-------------------------------------------------------------------------------
-- Floating texts
-------------------------------------------------------------------------------

function UI:OnClick(amount)
	if not self.frame or not self.frame:IsShown() or not NS.GetSettings().popups then
		return
	end
	local p = self.left
	local scale = p:GetEffectiveScale()
	local left, bottom = p:GetLeft(), p:GetBottom()
	if not left then
		return
	end
	local cx, cy = GetCursorPosition()
	local x = NS.Clamp(cx / scale - left, 10, LEFT_W - 10)
	local y = NS.Clamp(cy / scale - bottom + 14, 10, CONTENT_H - 10)
	self:Float(p, "+" .. NS.Beautify(amount, 1), x + (math.random() - 0.5) * 20, y)
	p.Cookie.size = 0.95
end

-- A rising, fading text in a layer at window coordinates (x from left, y from bottom).
function UI:Float(parent, text, x, y, size)
	local fs = table.remove(self.floatPool)
	if not fs then
		fs = self.floatLayer:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 14, "OUTLINE")
	end
	fs:SetFont(FONT, size or 14, "OUTLINE")
	fs:SetText(text)
	fs:SetTextColor(1, 1, 1)
	fs.parent = parent
	fs.x, fs.y0, fs.t = x, y, 0
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", parent, "BOTTOMLEFT", fs.x, fs.y0)
	fs:SetAlpha(1)
	fs:Show()
	table.insert(self.floats, fs)
	if #self.floats > MAX_FLOATS then
		local old = table.remove(self.floats, 1)
		old:Hide()
		table.insert(self.floatPool, old)
	end
end

-- Storm drops and other popups at a shimmer's spot.
function UI:Popup(text, me)
	if not self.frame or not self.frame:IsShown() then
		return
	end
	local layer = self.shimmerLayer
	if me and me.x then
		self:Float(layer, text, me.x, layer:GetHeight() - me.y, 13)
	end
end

function UI:UpdateFloats(dt)
	for i = #self.floats, 1, -1 do
		local fs = self.floats[i]
		fs.t = fs.t + dt / 0.9
		if fs.t >= 1 then
			fs:Hide()
			table.remove(self.floats, i)
			table.insert(self.floatPool, fs)
		else
			fs:SetPoint("CENTER", fs.parent, "BOTTOMLEFT", fs.x, fs.y0 + 40 * fs.t)
			fs:SetAlpha(fs.t < 0.5 and 1 or (1 - (fs.t - 0.5) * 2))
		end
	end
end

-------------------------------------------------------------------------------
-- Prompt: an in-window dialog with a title, text, an optional crate grid
-- and up to three buttons.
-------------------------------------------------------------------------------

function UI:CreatePrompt(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(420, 200)
	p:SetPoint("CENTER", f, "CENTER", -RIGHT_W / 2, 0)
	p:SetFrameLevel(f:GetFrameLevel() + 60)
	p:EnableMouse(true)
	p.Shade = UI.Solid(f, "OVERLAY", 0, 0, 0, 0.6)
	p.Shade:SetAllPoints(f)
	p.Shade:Hide()
	p.Bg = p:CreateTexture(nil, "BACKGROUND")
	p.Bg:SetTexture(NS.Art("darkNoise"), "REPEAT", "REPEAT")
	p.Bg:SetHorizTile(true)
	p.Bg:SetVertTile(true)
	p.Bg:SetAllPoints()
	p.Border = p:CreateTexture(nil, "BORDER")
	p.Border:SetTexture(WHITE)
	p.Border:SetVertexColor(0.89, 0.87, 0.28, 0.9)
	p.Border:SetPoint("TOPLEFT", -1, 1)
	p.Border:SetPoint("BOTTOMRIGHT", 1, -1)
	p.Bg:SetDrawLayer("BORDER", 1)
	p.Title = p:CreateFontString(nil, "OVERLAY")
	p.Title:SetFont(TITLE_FONT, 18, "")
	p.Title:SetShadowOffset(1, -1)
	p.Title:SetPoint("TOP", 0, -10)
	p.Body = UI.Text(p, 12, "")
	p.Body:SetPoint("TOPLEFT", 16, -38)
	p.Body:SetPoint("TOPRIGHT", -16, -38)
	p.Body:SetJustifyH("CENTER")
	p.Body:SetWordWrap(true)
	p.Body:SetSpacing(2)
	p.Grid = CreateFrame("Frame", nil, p)
	p.Grid:SetPoint("TOPLEFT", 16, -70)
	p.Grid:SetPoint("TOPRIGHT", -16, -70)
	p.Grid:SetHeight(1)
	p.Grid.Crates = {}
	p.Selected = UI.Text(p, 12, "")
	p.Selected:SetPoint("TOP", p.Grid, "BOTTOM", 0, -4)
	p.Selected:SetJustifyH("CENTER")
	p.Selected:SetTextColor(1, 0.9, 0.6)
	p.Buttons = {}
	for i = 1, 3 do
		local b = UI.FancyButton(p, "", 110, 24, function(self)
			if self.action then
				local action = self.action
				UI:ClosePrompt()
				action()
			else
				UI:ClosePrompt()
			end
		end)
		b:Hide()
		p.Buttons[i] = b
	end
	p:Hide()
	self.prompt = p
end

-- buttons: { { "Yes", function }, { "No" } }; grid: list of { icon, name, onPick } with selected flag
function UI:Prompt(title, text, buttons, grid, gridInfo)
	local p = self.prompt
	p.Title:SetText(title or "")
	p.Body:SetText(text or "")
	local bodyH = p.Body:GetStringHeight() + 12
	for _, c in ipairs(p.Grid.Crates) do
		c:Hide()
	end
	local gridH = 0
	p.Selected:SetText("")
	if grid and #grid > 0 then
		local per = 6
		local size = 60
		local cols = math.min(per, #grid)
		local gw = cols * size
		for i, item in ipairs(grid) do
			local c = p.Grid.Crates[i]
			if not c then
				c = CreateFrame("Button", nil, p.Grid)
				c:SetSize(48, 48)
				c.Frame = c:CreateTexture(nil, "BORDER")
				c.Frame:SetPoint("TOPLEFT", -6, 6)
				c.Frame:SetPoint("BOTTOMRIGHT", 6, -6)
				c.Icon = c:CreateTexture(nil, "ARTWORK")
				c.Icon:SetAllPoints()
				c:SetScript("OnClick", function(self)
					if self.item and self.item.onPick then
						self.item.onPick(self.item)
					end
					for _, o in ipairs(p.Grid.Crates) do
						if o.item then
							o.item.selected = (o == self)
							NS.SetSheetCell(o.Frame, "upgradeFrame", 60, 60, o.item.selected and 1 or 0, 0)
						end
					end
					p.Selected:SetText(self.item and self.item.name or "")
				end)
				UI.SetTooltip(c, function(self)
					if self.item then
						GameTooltip:SetText(self.item.name)
						if self.item.desc then
							GameTooltip:AddLine(self.item.desc, 1, 1, 1, true)
						end
					end
				end)
				p.Grid.Crates[i] = c
			end
			c.item = item
			NS.SetIcon(c.Icon, item.icon)
			NS.SetSheetCell(c.Frame, "upgradeFrame", 60, 60, item.selected and 1 or 0, 0)
			local col, row = (i - 1) % per, math.floor((i - 1) / per)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", p.Grid, "TOP", -gw / 2 + col * size + 6, -row * size - 6)
			c:Show()
			if item.selected then
				p.Selected:SetText(item.name)
			end
		end
		gridH = math.ceil(#grid / per) * size + 22
		p.Grid:ClearAllPoints()
		p.Grid:SetPoint("TOPLEFT", 16, -(38 + bodyH))
		p.Grid:SetPoint("TOPRIGHT", -16, -(38 + bodyH))
		p.Grid:SetHeight(gridH - 22)
		if gridInfo then
			p.Selected:SetText(gridInfo)
		end
	end
	local n = 0
	for i, b in ipairs(p.Buttons) do
		local def = buttons and buttons[i]
		if def then
			b:SetText(def[1])
			b.action = def[2]
			b:Show()
			n = n + 1
		else
			b:Hide()
		end
	end
	local totalW = n * 118
	for i = 1, n do
		local b = p.Buttons[i]
		b:ClearAllPoints()
		b:SetPoint("BOTTOM", p, "BOTTOM", -totalW / 2 + (i - 1) * 118 + 59, 12)
	end
	p:SetHeight(38 + bodyH + gridH + 48)
	p.Shade:Show()
	p:Show()
	self.prompt.open = true
end

function UI:ClosePrompt()
	local p = self.prompt
	p:Hide()
	p.Shade:Hide()
	p.open = nil
	GameTooltip:Hide()
end

-- Two-step confirmation used by sugar lump spending (the original asks).
function UI:ConfirmLumps(n, what, action)
	self:Prompt("Spend sugar lumps", string.format("Do you want to spend %d sugar lump%s to %s?", n, n == 1 and "" or "s", what), { { "Yes", action }, { "No" } })
end

-------------------------------------------------------------------------------
-- Selectors (milk, background, golden cookie sound)
-------------------------------------------------------------------------------

function UI:OpenSelector(u)
	local game = NS.Game
	local S = game.save
	local grid = {}
	if u.name == "Milk selector" then
		for i, m in ipairs(NS.MILKS) do
			local ok = true
			if m.type == 1 and not game:Has("Fanciful dairy selection") then ok = false end
			if m.rank and m.rank > math.floor(game:AchievementsOwned() / 25) then ok = false end
			if ok then
				table.insert(grid, { icon = m.icon, name = m.name, selected = (S.milkType or 0) == m.index, onPick = function()
					S.milkType = m.index
					UI:RefreshBackground()
				end })
			end
		end
	elseif u.name == "Background selector" then
		for _, bg in ipairs(NS.BGS) do
			local ok = true
			if bg.order >= 4.9 and not game:Has("Distinguished wallpaper assortment") then ok = false end
			if ok then
				table.insert(grid, { icon = bg.icon, name = bg.name, selected = (S.bgType or 0) == bg.index, onPick = function()
					S.bgType = bg.index
					UI:RefreshBackground()
				end })
			end
		end
	elseif u.name == "Golden cookie sound selector" then
		for i, c in ipairs(NS.CHIMES) do
			table.insert(grid, { icon = c.icon, name = c.name, selected = (S.chimeType or 0) == i - 1, onPick = function()
				S.chimeType = i - 1
			end })
		end
	else
		return
	end
	self:Prompt(u.name, u.desc, { { "Close" } }, grid)
end

-------------------------------------------------------------------------------
-- Santa and dragon
-------------------------------------------------------------------------------

function UI:CreateSpecialPanel(p)
	local s = CreateFrame("Frame", nil, p)
	s:SetSize(LEFT_W - 24, 230)
	s:SetPoint("BOTTOM", 0, 90)
	s:SetFrameLevel(p:GetFrameLevel() + 6)
	s:EnableMouse(true)
	s.Bg = s:CreateTexture(nil, "BACKGROUND")
	s.Bg:SetTexture(NS.Art("darkNoise"), "REPEAT", "REPEAT")
	s.Bg:SetHorizTile(true)
	s.Bg:SetVertTile(true)
	s.Bg:SetAllPoints()
	s.Border = s:CreateTexture(nil, "BORDER")
	s.Border:SetTexture(WHITE)
	s.Border:SetVertexColor(0.89, 0.87, 0.28, 0.8)
	s.Border:SetPoint("TOPLEFT", -1, 1)
	s.Border:SetPoint("BOTTOMRIGHT", 1, -1)
	s.Bg:SetDrawLayer("BORDER", 1)
	s.Pic = CreateFrame("Button", nil, s)
	s.Pic:SetSize(96, 96)
	s.Pic:SetPoint("TOP", 0, -8)
	s.Pic.Icon = s.Pic:CreateTexture(nil, "ARTWORK")
	s.Pic.Icon:SetAllPoints()
	s.Pic:SetScript("OnClick", function()
		if UI.specialTab == "dragon" then
			NS.Game:PetDragon()
		end
	end)
	s.Title = s:CreateFontString(nil, "OVERLAY")
	s.Title:SetFont(TITLE_FONT, 15, "")
	s.Title:SetShadowOffset(1, -1)
	s.Title:SetPoint("TOP", s.Pic, "BOTTOM", 0, -4)
	s.Title:SetWidth(LEFT_W - 40)
	s.Title:SetJustifyH("CENTER")
	s.Action = UI.FancyButton(s, "", 200, 24, function()
		if UI.specialTab == "santa" then
			NS.Game:UpgradeSanta()
		else
			NS.Game:UpgradeDragon()
		end
		UI:RefreshSpecial()
	end)
	s.Action:SetPoint("TOP", s.Title, "BOTTOM", 0, -6)
	s.Cost = UI.Text(s, 11, "")
	s.Cost:SetPoint("TOP", s.Action, "BOTTOM", 0, -4)
	s.Cost:SetWidth(LEFT_W - 40)
	s.Cost:SetJustifyH("CENTER")
	s.Cost:SetWordWrap(true)
	s.Cost:SetTextColor(0.8, 0.8, 0.8)
	s.Auras = {}
	for i = 1, 2 do
		local a = CreateFrame("Button", nil, s)
		a:SetSize(48, 48)
		a.Frame = a:CreateTexture(nil, "BORDER")
		a.Frame:SetPoint("TOPLEFT", -6, 6)
		a.Frame:SetPoint("BOTTOMRIGHT", 6, -6)
		NS.SetSheetCell(a.Frame, "upgradeFrame", 60, 60, 0, 0)
		a.Icon = a:CreateTexture(nil, "ARTWORK")
		a.Icon:SetAllPoints()
		a.slot = i
		a:SetScript("OnClick", function(self)
			UI:PickAura(self.slot)
		end)
		UI.SetTooltip(a, function(self)
			local S = NS.Game.save
			local id = self.slot == 2 and (S.dragonAura2 or 0) or (S.dragonAura or 0)
			local aura = NS.DRAGON_AURAS[id]
			GameTooltip:SetText(aura and aura.name or "No aura")
			GameTooltip:AddLine(aura and aura.desc or "", 1, 1, 1, true)
			GameTooltip:AddLine("Click to change the dragon's " .. (self.slot == 2 and "secondary " or "") .. "aura.", 0.7, 0.7, 0.7, true)
		end)
		a:Hide()
		s.Auras[i] = a
	end
	s.Auras[1]:SetPoint("BOTTOM", -32, 10)
	s.Auras[2]:SetPoint("BOTTOM", 32, 10)
	s.Close = UI.FancyButton(s, "x", 20, 20, function()
		UI:ToggleSpecial(nil)
	end)
	s.Close:SetPoint("TOPRIGHT", -4, -4)
	s:Hide()
	p.Special = s
end

function UI:ToggleSpecial(kind)
	if kind == nil or self.specialTab == kind then
		self.specialTab = nil
		self.left.Special:Hide()
	else
		self.specialTab = kind
		self.left.Special:Show()
	end
	self:RefreshSpecial()
end

function UI:RefreshSpecial()
	local p = self.left
	local game = NS.Game
	local S = game.save
	local tabs = game:SpecialTabs()
	for i, t in ipairs(p.Tabs) do
		local kind = tabs[i]
		if kind then
			t.kind = kind
			local selected = self.specialTab == kind
			local size = selected and 72 or 48
			t:SetSize(size, size)
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", 12 + (selected and 0 or 12), 12 + (i - 1) * 64)
			if kind == "santa" then
				NS.SetFrame(t.Icon, "santa", S.santaLevel or 0)
			else
				local info = game:DragonLevelInfo()
				NS.SetFrame(t.Icon, "dragon", info and info.pic or 0)
			end
			t:Show()
		else
			t.kind = nil
			t:Hide()
		end
	end
	if self.specialTab and not tContains(tabs, self.specialTab) then
		self.specialTab = nil
		p.Special:Hide()
	end
	local s = p.Special
	if not s:IsShown() then
		return
	end
	if self.specialTab == "santa" then
		NS.SetFrame(s.Pic.Icon, "santa", S.santaLevel or 0)
		s.Title:SetText(game:SantaName())
		if (S.santaLevel or 0) < 14 then
			s.Action:SetText("Evolve")
			s.Action:SetEnabledLook(S.cookies > game:SantaCost())
			s.Cost:SetText("Cost: " .. NS.Beautify(game:SantaCost()) .. " cookies")
		else
			s.Action:SetText("Fully evolved")
			s.Action:SetEnabledLook(false)
			s.Cost:SetText("Santa has reached his final form.")
		end
		s.Auras[1]:Hide()
		s.Auras[2]:Hide()
	else
		local info = game:DragonLevelInfo()
		NS.SetFrame(s.Pic.Icon, "dragon", info and info.pic or 0)
		s.Title:SetText(info and info.name or "Dragon")
		local kind = game:DragonCost()
		if kind == "done" then
			s.Action:SetText("Your dragon is fully trained.")
			s.Action:SetEnabledLook(false)
			s.Cost:SetText("")
		else
			s.Action:SetText(info and info.action or "Train")
			s.Action:SetEnabledLook(game:DragonCanBuy())
			s.Cost:SetText("Cost: " .. game:DragonCostText())
		end
		if (S.dragonLevel or 0) >= 5 then
			local a1 = NS.DRAGON_AURAS[S.dragonAura or 0]
			NS.SetIcon(s.Auras[1].Icon, a1 and a1.pic or { 0, 7 })
			s.Auras[1]:Show()
			if game:CanUseSecondAura() then
				local a2 = NS.DRAGON_AURAS[S.dragonAura2 or 0]
				NS.SetIcon(s.Auras[2].Icon, a2 and a2.pic or { 0, 7 })
				s.Auras[2]:Show()
				s.Auras[1]:ClearAllPoints()
				s.Auras[1]:SetPoint("BOTTOM", -32, 10)
			else
				s.Auras[2]:Hide()
				s.Auras[1]:ClearAllPoints()
				s.Auras[1]:SetPoint("BOTTOM", 0, 10)
			end
		else
			s.Auras[1]:Hide()
			s.Auras[2]:Hide()
		end
	end
end

function UI:PickAura(slot)
	local game = NS.Game
	local S = game.save
	local current = slot == 2 and (S.dragonAura2 or 0) or (S.dragonAura or 0)
	local other = slot == 2 and (S.dragonAura or 0) or (S.dragonAura2 or 0)
	local grid = {}
	local chosen = current
	for _, aura in ipairs(game:KnownAuras()) do
		if aura.id == 0 or aura.id ~= other then
			table.insert(grid, { icon = aura.pic, name = aura.name, desc = aura.desc, selected = aura.id == current, onPick = function()
				chosen = aura.id
			end })
		end
	end
	local highest = game:HighestBuilding()
	local costText = highest and ("The cost of switching your aura is one " .. highest.single .. ". This will affect your CpS!") or "Switching your aura is free because you own no buildings."
	self:Prompt(slot == 2 and "Set your dragon's secondary aura" or "Set your dragon's aura", costText, {
		{ "Confirm", function()
			game:SetDragonAura(chosen, slot)
			UI:RefreshSpecial()
		end },
		{ "Cancel" },
	}, grid)
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function UI:RefreshLeft()
	local game, S = NS.Game, NS.Game.save
	local p = self.left
	local band = p.Band
	local cookies = math.floor(S.cookies)
	band.Count:SetText(NS.Beautify(cookies) .. (cookies == 1 and " cookie" or " cookies"))
	local cps = game.cps or 0
	local sucked = game.cpsSucked or 0
	band.Cps:SetText("per second: " .. NS.Beautify(cps, 1))
	if sucked > 0 then
		band.Cps:SetTextColor(1, 0.3, 0.3)
	else
		band.Cps:SetTextColor(1, 1, 1)
	end
	if (S.prestige or 0) > 0 then
		p.Prestige:SetText(string.format("prestige level %s", NS.Beautify(S.prestige)))
	else
		p.Prestige:SetText("")
	end
	-- Buffs.
	local list = game:Buffs()
	for i, b in ipairs(p.Buffs) do
		local buff = list[i]
		if buff and buff.time > 0 then
			b.buff = buff
			NS.SetIcon(b.Icon, buff.icon)
			local T = (1 - buff.time / math.max(0.01, buff.maxTime)) * 144 % 144
			local fx, fy = math.floor(T % 18), math.floor(T / 18)
			NS.SetSheetCell(b.Pie, "pieFill", 48, 48, fx, fy)
			b:Show()
		else
			b.buff = nil
			b:Hide()
		end
	end
	-- Lumps.
	local lump = self.middle.Bar.Lump
	if game:CanLumps() and (S.lumpsTotal or -1) > -1 then
		local icon, icon2, opacity = game:LumpIcons()
		NS.SetIcon(lump.Icon, icon)
		NS.SetIcon(lump.Icon2, icon2)
		lump.Icon2:SetAlpha(opacity)
		lump.Count:SetText(tostring(S.lumps or 0))
		lump:Show()
	else
		lump:Hide()
	end
	self:RefreshSpecial()
end

function UI:Refresh(force)
	local f = self.frame
	if not f or not f:IsShown() then
		return
	end
	local game = NS.Game
	self:RefreshLeft()
	if game.storeDirty or force then
		game.storeDirty = false
		self:RebuildStore()
	end
	self:RefreshStore()
	self:RefreshRows(force)
	self:RefreshMenus(force)
	if NS.Minigames then
		self.minigameAcc = (self.minigameAcc or 0) + 1
		if force or self.minigameAcc >= 10 then
			self.minigameAcc = 0
			NS.Minigames:Refresh()
		end
	end
	if self.ascend and self.ascend:IsShown() then
		self:RefreshAscend()
	end
end

-- LibGraph's line trick: a solid texture with rotated texcoords, from
-- (sx, sy) to (ex, ey) relative to C's centre, w pixels thick.
function UI.DrawLine(T, C, sx, sy, ex, ey, w)
	local dx, dy = ex - sx, ey - sy
	local cx, cy = (sx + ex) / 2, (sy + ey) / 2
	if dx < 0 then
		dx, dy = -dx, -dy
	end
	local l = math.sqrt(dx * dx + dy * dy)
	if l == 0 then
		T:Hide()
		return
	end
	local s, c = -dy / l, dx / l
	local sc = s * c
	local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
	if dy >= 0 then
		Bwid = ((l * c) - (w * s)) / 2
		Bhgt = ((w * c) - (l * s)) / 2
		BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
		BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
		TRy = BRx
	else
		Bwid = ((l * c) + (w * s)) / 2
		Bhgt = ((w * c) + (l * s)) / 2
		BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
		BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
		TRx = TLy
	end
	T:ClearAllPoints()
	T:SetPoint("BOTTOMLEFT", C, "CENTER", cx - Bwid, cy - Bhgt)
	T:SetPoint("TOPRIGHT", C, "CENTER", cx + Bwid, cy + Bhgt)
	T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
	T:Show()
end

function UI:OnBuffsChanged()
	if self.frame and self.frame:IsShown() then
		self:RefreshLeft()
	end
end

function UI:OnWrathChanged()
	if self.frame and self.frame:IsShown() then
		self:RefreshBackground()
		self:RefreshRows(true)
	end
end

function UI:OnSeasonChanged()
	if self.frame and self.frame:IsShown() then
		self:RefreshBackground()
		for me, b in pairs(self.shimmerButtons) do
			self:ShimmerLook(b, me)
		end
		self:RefreshRows(true)
		self:RebuildStore()
	end
end

function UI:OnLumpsEnabled()
	self:Refresh(true)
end

function UI:OnReset()
	if self.frame then
		self:RefreshWrinklers()
		self:SyncShimmers()
		self:RefreshBackground()
		self:Refresh(true)
	end
end

function UI:OnUpdate(dt)
	local game = NS.Game
	self.acc = (self.acc or 0) + dt
	if self.acc >= self.REFRESH_INTERVAL then
		self.acc = 0
		self:Refresh(false)
	end
	local t = GetTime()
	local p = self.left
	-- The cookie's wobble and the shine.
	local cookie = p.Cookie
	local target = cookie.pressed and 0.96 or (cookie.hover and 1.03 or 1)
	cookie.size = cookie.size + (target - cookie.size) * math.min(1, dt * 12)
	cookie:SetSize(COOKIE_SIZE * cookie.size, COOKIE_SIZE * cookie.size)
	cookie.Shine:SetRotation(t * 0.25)
	cookie.Shine2:SetRotation(-t * 0.18)
	-- Milk level and waves.
	local milkH = math.min(1, game.milkProgress or 0) * 0.35
	p.milkHd = p.milkHd + (milkH - p.milkHd) * math.min(1, dt * 0.6)
	local height = math.max(1, p.milkHd * CONTENT_H)
	p.Milk:SetHeight(height)
	p.milkOffset = (p.milkOffset + dt * 0.02) % 1
	p.Milk:SetTexCoord(p.milkOffset, p.milkOffset + LEFT_W / 256, 0, height / 256)
	self:UpdateWrinklers(t)
	self:UpdateShimmers(dt)
	self:UpdateFloats(dt)
	self:UpdateNotes(dt)
	if self.UpdateAscend and self.ascend and self.ascend:IsShown() then
		self:UpdateAscend(dt)
	end
end

-------------------------------------------------------------------------------
-- Show, hide, position
-------------------------------------------------------------------------------

function UI:ApplyPosition()
	local f = self.frame
	if not f then
		return
	end
	f:ClearAllPoints()
	local pos = MauCookieDB and MauCookieDB.position
	if pos and pos.point then
		f:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
	else
		f:SetPoint("CENTER")
	end
end

function UI:ApplyScale()
	if self.frame then
		self.frame:SetScale((NS.GetSettings().scale or 100) / 100)
	end
end

function UI:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

function UI:Show()
	self:Create()
	self.frame:Show()
end

function UI:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function UI:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

function UI:OnGuildDataChanged()
	if self.frame and self.frame:IsShown() and self.menu == "guild" then
		self:RefreshMenus(true)
	end
end
