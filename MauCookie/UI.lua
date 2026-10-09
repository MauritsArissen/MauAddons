-- MauCookie window: the cookie on the left, the store in the middle, the
-- upgrades on the right, overlays for statistics and achievements, and the
-- golden cookie that pops up anywhere in the window.

local _, NS = ...

local UI = {}
NS.UI = UI

local PAD, TITLE_H = 16, 28
local LEFT_W, STORE_W, RIGHT_W, GAP = 230, 300, 178, 10
local PANEL_H = 480
local COOKIE_SIZE = 170
local ROW_H = 32
local UPGRADE_SIZE, UPGRADE_GAP, UPGRADE_COLS = 36, 4, 4
local MAX_UPGRADES = 28
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FALLBACK_COOKIE = "Interface\\Icons\\INV_Misc_Food_19"
local REFRESH_INTERVAL = 0.1

local function Label(parent, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	return fs
end

local function Button(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function Tooltip(frame, title, body)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if body then
			GameTooltip:AddLine(body, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function RoundIcon(parent, layer)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
	return tex
end

local function CookieIcon()
	local icon
	if C_Item and C_Item.GetItemIconByID then
		icon = C_Item.GetItemIconByID(17197)   -- Gingerbread Cookie
	end
	return icon or FALLBACK_COOKIE
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

function UI:Create()
	if self.frame then
		return self.frame
	end
	local width = PAD + LEFT_W + GAP + STORE_W + GAP + RIGHT_W + PAD
	local height = PAD + TITLE_H + PANEL_H + PAD
	local f = CreateFrame("Frame", "MauCookieFrame", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(width, height)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relativePoint, x, y = f:GetPoint()
		MauCookieDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	f:Hide()

	f.Title = Label(f, "MauCookie", "GameFontNormalLarge")
	f.Title:SetPoint("TOP", 0, -14)
	f.Title:SetJustifyH("CENTER")
	f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.Close:SetPoint("TOPRIGHT", -4, -4)
	f.Close:SetScript("OnClick", function()
		f:Hide()
	end)

	local top = -(PAD + TITLE_H)
	self:CreateLeft(f, top)
	self:CreateStore(f, top)
	self:CreateRight(f, top)
	self:CreateOverlays(f, top)
	self:CreateGolden(f)

	f:SetScript("OnShow", function()
		UI:Refresh(true)
	end)
	f:SetScript("OnHide", function()
		GameTooltip:Hide()
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

-------------------------------------------------------------------------------
-- Left: the cookie
-------------------------------------------------------------------------------

function UI:CreateLeft(f, top)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(LEFT_W, PANEL_H)
	p:SetPoint("TOPLEFT", PAD, top)
	self.left = p

	p.Count = Label(p, "", "GameFontNormalLarge")
	p.Count:SetPoint("TOP", 0, -4)
	p.Count:SetJustifyH("CENTER")
	p.Count:SetWidth(LEFT_W)
	p.Cps = Label(p, "", "GameFontHighlightSmall")
	p.Cps:SetPoint("TOP", 0, -26)
	p.Cps:SetJustifyH("CENTER")
	p.Cps:SetWidth(LEFT_W)

	local cookie = CreateFrame("Button", nil, p)
	cookie:SetSize(COOKIE_SIZE, COOKIE_SIZE)
	cookie:SetPoint("TOP", 0, -56)
	cookie.Glow = RoundIcon(cookie, "BACKGROUND")
	cookie.Glow:SetTexture(WHITE)
	cookie.Glow:SetBlendMode("ADD")
	cookie.Glow:SetVertexColor(1, 0.8, 0.4, 0.18)
	cookie.Glow:SetPoint("CENTER")
	cookie.Glow:SetSize(COOKIE_SIZE + 30, COOKIE_SIZE + 30)
	cookie.Icon = RoundIcon(cookie, "ARTWORK")
	cookie.Icon:SetAllPoints()
	cookie.Icon:SetTexture(CookieIcon())
	cookie.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cookie.Highlight = RoundIcon(cookie, "HIGHLIGHT")
	cookie.Highlight:SetTexture(WHITE)
	cookie.Highlight:SetAllPoints()
	cookie.Highlight:SetVertexColor(1, 1, 1, 0.12)
	cookie:RegisterForClicks("LeftButtonDown")
	cookie:SetScript("OnClick", function()
		NS.Game:Click()
	end)
	cookie:SetScript("OnMouseDown", function(self)
		self:SetSize(COOKIE_SIZE - 10, COOKIE_SIZE - 10)
	end)
	cookie:SetScript("OnMouseUp", function(self)
		self:SetSize(COOKIE_SIZE, COOKIE_SIZE)
	end)
	Tooltip(cookie, "The cookie", "Click it. Shift-click and ctrl-click work too, and a key can be bound to clicking under Options > Key Bindings > AddOns.")
	p.Cookie = cookie

	p.Buff = Label(p, "", "GameFontHighlight")
	p.Buff:SetPoint("TOP", cookie, "BOTTOM", 0, -12)
	p.Buff:SetJustifyH("CENTER")
	p.Buff:SetWidth(LEFT_W)
	p.Buff:SetTextColor(1, 0.85, 0.3)
	p.Buff2 = Label(p, "", "GameFontHighlightSmall")
	p.Buff2:SetPoint("TOP", p.Buff, "BOTTOM", 0, -4)
	p.Buff2:SetJustifyH("CENTER")
	p.Buff2:SetWidth(LEFT_W)
	p.Buff2:SetTextColor(0.7, 0.9, 1)

	p.Banner = p:CreateFontString(nil, "OVERLAY")
	p.Banner:SetFont(FONT, 15, "OUTLINE")
	p.Banner:SetPoint("BOTTOM", 0, 46)
	p.Banner:SetWidth(LEFT_W)
	p.Banner:SetJustifyH("CENTER")
	p.Banner:SetWordWrap(true)
	p.Banner:Hide()

	p.Baked = Label(p, "", "GameFontDisableSmall")
	p.Baked:SetPoint("BOTTOM", 0, 20)
	p.Baked:SetJustifyH("CENTER")
	p.Baked:SetWidth(LEFT_W)
	p.Hint = Label(p, "", "GameFontDisableSmall")
	p.Hint:SetPoint("BOTTOM", 0, 4)
	p.Hint:SetJustifyH("CENTER")
	p.Hint:SetWidth(LEFT_W)

	self.floats, self.floatPool = {}, {}
	self.banners = {}
end

-------------------------------------------------------------------------------
-- Middle: the store
-------------------------------------------------------------------------------

function UI:CreateStore(f, top)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(STORE_W, PANEL_H)
	p:SetPoint("TOPLEFT", PAD + LEFT_W + GAP, top)
	self.store = p
	p.Header = Label(p, "Store", "GameFontNormal")
	p.Header:SetPoint("TOPLEFT", 4, 0)
	p.HeaderHint = Label(p, "click: buy 1, shift: buy 10", "GameFontDisableSmall")
	p.HeaderHint:SetPoint("TOPRIGHT", -4, -2)
	p.HeaderHint:SetJustifyH("RIGHT")
	p.Rows = {}
	for i, b in ipairs(NS.BUILDINGS) do
		local row = CreateFrame("Button", nil, p)
		row:SetSize(STORE_W, ROW_H - 2)
		row:SetPoint("TOPLEFT", 0, -22 - (i - 1) * ROW_H)
		row.Bg = row:CreateTexture(nil, "BACKGROUND")
		row.Bg:SetTexture(WHITE)
		row.Bg:SetAllPoints()
		row.Bg:SetVertexColor(1, 1, 1, 0.05)
		row:SetHighlightTexture(WHITE)
		row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(26, 26)
		row.Icon:SetPoint("LEFT", 3, 0)
		row.Icon:SetTexture(b.iconPath)
		row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		row.Name = Label(row, b.name, "GameFontNormal")
		row.Name:SetPoint("TOPLEFT", 36, -2)
		row.Price = Label(row, "", "GameFontHighlightSmall")
		row.Price:SetPoint("BOTTOMLEFT", 36, 2)
		row.Owned = Label(row, "", "GameFontNormalLarge")
		row.Owned:SetPoint("RIGHT", -8, 0)
		row.Owned:SetJustifyH("RIGHT")
		row.Owned:SetTextColor(0.55, 0.55, 0.6)
		row.building = b
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self)
			NS.Game:Buy(self.building, IsShiftKeyDown() and 10 or 1)
		end)
		row:SetScript("OnEnter", function(self)
			UI:BuildingTooltip(self)
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		row:Hide()
		p.Rows[i] = row
	end
end

function UI:BuildingTooltip(row)
	local game, b = NS.Game, row.building
	local owned = game:Count(b.id)
	local each = game:BuildingCps(b)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(b.name)
	GameTooltip:AddLine(b.desc, 1, 1, 1, true)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("Price", NS.Beautify(game:Price(b)), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Price for 10", NS.Beautify(game:PriceFor(b, 10)), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Each produces", NS.BeautifyRate(each) .. " per second", 0.8, 0.8, 0.8, 1, 1, 1)
	if owned > 0 then
		local total = game:Cps(false)
		local share = total > 0 and (owned * each / total * 100) or 0
		GameTooltip:AddDoubleLine(string.format("Your %d produce", owned), string.format("%s per second (%.1f%%)", NS.BeautifyRate(owned * each), share), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Right: upgrades and buttons
-------------------------------------------------------------------------------

function UI:CreateRight(f, top)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(RIGHT_W, PANEL_H)
	p:SetPoint("TOPLEFT", PAD + LEFT_W + GAP + STORE_W + GAP, top)
	self.right = p
	p.Header = Label(p, "Upgrades", "GameFontNormal")
	p.Header:SetPoint("TOPLEFT", 4, 0)
	p.Slots = {}
	for i = 1, MAX_UPGRADES do
		local slot = CreateFrame("Button", nil, p)
		slot:SetSize(UPGRADE_SIZE, UPGRADE_SIZE)
		local col, row = (i - 1) % UPGRADE_COLS, math.floor((i - 1) / UPGRADE_COLS)
		slot:SetPoint("TOPLEFT", 4 + col * (UPGRADE_SIZE + UPGRADE_GAP), -22 - row * (UPGRADE_SIZE + UPGRADE_GAP))
		slot.Border = slot:CreateTexture(nil, "BACKGROUND")
		slot.Border:SetTexture(WHITE)
		slot.Border:SetAllPoints()
		slot.Icon = slot:CreateTexture(nil, "ARTWORK")
		slot.Icon:SetPoint("TOPLEFT", 2, -2)
		slot.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
		slot.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		slot:SetHighlightTexture(WHITE)
		slot:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
		slot:RegisterForClicks("LeftButtonUp")
		slot:SetScript("OnClick", function(self)
			if self.upgrade then
				NS.Game:BuyUpgrade(self.upgrade)
			end
		end)
		slot:SetScript("OnEnter", function(self)
			local u = self.upgrade
			if not u then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(u.name)
			GameTooltip:AddLine(u.desc, 1, 1, 1, true)
			local affordable = NS.Game.save.cookies >= u.cost
			GameTooltip:AddDoubleLine("Price", NS.Beautify(u.cost), 0.8, 0.8, 0.8, affordable and 0.4 or 1, affordable and 1 or 0.4, 0.4)
			GameTooltip:Show()
		end)
		slot:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		slot:Hide()
		p.Slots[i] = slot
	end
	p.More = Label(p, "", "GameFontDisableSmall")
	p.More:SetPoint("TOPLEFT", 4, -22 - math.ceil(MAX_UPGRADES / UPGRADE_COLS) * (UPGRADE_SIZE + UPGRADE_GAP))
	p.Empty = Label(p, "Nothing to buy yet. Upgrades show up as you own more buildings and bake more cookies.", "GameFontDisableSmall")
	p.Empty:SetPoint("TOPLEFT", 4, -24)
	p.Empty:SetWidth(RIGHT_W - 8)
	p.Empty:SetWordWrap(true)

	p.Stats = Button(p, "Stats", 84, 20, function()
		UI:ShowStats()
	end)
	p.Stats:SetPoint("BOTTOMLEFT", 0, 0)
	p.Achievements = Button(p, "Feats", 84, 20, function()
		UI:ShowAchievements()
	end)
	p.Achievements:SetPoint("BOTTOMRIGHT", 0, 0)
	Tooltip(p.Achievements, "Achievements", "Every achievement adds 1% to production.")
	p.Options = Label(p, "/mck options", "GameFontDisableSmall")
	p.Options:SetPoint("BOTTOM", 0, 26)
	p.Options:SetJustifyH("CENTER")
	p.Options:SetWidth(RIGHT_W)
end

-------------------------------------------------------------------------------
-- Overlays over the store and upgrades
-------------------------------------------------------------------------------

local function Overlay(f, top)
	local o = CreateFrame("Frame", nil, f, "BackdropTemplate")
	o:SetSize(STORE_W + GAP + RIGHT_W, PANEL_H)
	o:SetPoint("TOPLEFT", PAD + LEFT_W + GAP, top)
	o:SetFrameLevel(f:GetFrameLevel() + 10)
	o:EnableMouse(true)
	o:SetBackdrop({ bgFile = WHITE })
	o:SetBackdropColor(0.03, 0.03, 0.05, 0.96)
	o:Hide()
	return o
end

function UI:CreateOverlays(f, top)
	local s = Overlay(f, top)
	self.stats = s
	s.Title = Label(s, "Statistics", "GameFontNormalLarge")
	s.Title:SetPoint("TOPLEFT", 12, -8)
	s.Rows = {}
	for i = 1, 14 do
		local row = CreateFrame("Frame", nil, s)
		row:SetSize(STORE_W + GAP + RIGHT_W - 24, 19)
		row:SetPoint("TOPLEFT", 12, -36 - (i - 1) * 19)
		row.Label = Label(row, "", "GameFontNormal")
		row.Label:SetPoint("LEFT")
		row.Value = Label(row, "", "GameFontHighlight")
		row.Value:SetPoint("RIGHT")
		row.Value:SetJustifyH("RIGHT")
		s.Rows[i] = row
	end
	s.Close = Button(s, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	s.Close:SetPoint("BOTTOMRIGHT", -12, 10)
	s.Wipe = Button(s, "Wipe save", 90, 22, function(self)
		if self.armed then
			self.armed = nil
			self:SetText("Wipe save")
			UI:HideOverlays()
			NS.Game:Wipe()
		else
			self.armed = true
			self:SetText("Sure?")
			C_Timer.After(4, function()
				if self.armed then
					self.armed = nil
					self:SetText("Wipe save")
				end
			end)
		end
	end)
	s.Wipe:SetPoint("BOTTOMLEFT", 12, 10)
	Tooltip(s.Wipe, "Wipe save", "Starts the bakery over from zero. Click twice.")

	local a = Overlay(f, top)
	self.achievements = a
	a.Title = Label(a, "Achievements", "GameFontNormalLarge")
	a.Title:SetPoint("TOPLEFT", 12, -8)
	a.Summary = Label(a, "", "GameFontHighlightSmall")
	a.Summary:SetPoint("LEFT", a.Title, "RIGHT", 12, 0)
	a.Rows = {}
	local perColumn = 22
	local colW = (STORE_W + GAP + RIGHT_W - 24) / 2
	for i, ach in ipairs(NS.ACHIEVEMENTS) do
		local row = CreateFrame("Frame", nil, a)
		row:SetSize(colW - 6, 17)
		local col, r = math.floor((i - 1) / perColumn), (i - 1) % perColumn
		row:SetPoint("TOPLEFT", 12 + col * colW, -34 - r * 17)
		row.Name = Label(row, ach.name, "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT")
		row.Name:SetWidth(colW - 10)
		row.Name:SetWordWrap(false)
		row.ach = ach
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.ach.name)
			GameTooltip:AddLine(self.ach.desc, 1, 1, 1, true)
			GameTooltip:AddLine(NS.Game.save.achievements[self.ach.id] and "Unlocked. Production +1%." or "Locked.", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		a.Rows[i] = row
	end
	a.Close = Button(a, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	a.Close:SetPoint("BOTTOMRIGHT", -12, 10)
end

function UI:HideOverlays()
	self.stats:Hide()
	self.achievements:Hide()
	GameTooltip:Hide()
end

function UI:ShowStats()
	self:HideOverlays()
	self:RefreshStats()
	self.stats:Show()
end

function UI:ShowAchievements()
	self:HideOverlays()
	self:RefreshAchievements()
	self.achievements:Show()
end

function UI:RefreshStats()
	local s = self.stats
	local game, save = NS.Game, NS.Game.save
	local unlocked = game:AchievementsUnlocked()
	local lines = {
		{ "Cookies in bank", NS.Beautify(save.cookies) },
		{ "Cookies baked, all time", NS.Beautify(save.baked) },
		{ "Cookies per second", NS.BeautifyRate(game:Cps(true)) },
		{ "Cookies per click", NS.BeautifyRate(game:ClickPower()) },
		{ "Cookie clicks", NS.Commas(save.clicks) },
		{ "Handmade cookies", NS.Beautify(save.handmade) },
		{ "Buildings owned", NS.Commas(game:TotalBuildings()) },
		{ "Upgrades bought", string.format("%d of %d", game:UpgradesBought(), #NS.UPGRADES) },
		{ "Achievements", string.format("%d of %d (production +%d%%)", unlocked, #NS.ACHIEVEMENTS, unlocked) },
		{ "Golden cookies clicked", NS.Commas(save.golden) },
		{ "Flavour bonus", string.format("+%d%%", game:CountKind("flavour") * 2) },
		{ "Running since", date("%Y-%m-%d", save.started) },
		{ "Time with the bakery open", NS.FormatDuration(save.playTime) },
	}
	for i, row in ipairs(s.Rows) do
		local line = lines[i]
		if line then
			row.Label:SetText(line[1])
			row.Value:SetText(line[2])
			row:Show()
		else
			row:Hide()
		end
	end
end

function UI:RefreshAchievements()
	local a = self.achievements
	local save = NS.Game.save
	local unlocked = 0
	for _, row in ipairs(a.Rows) do
		if save.achievements[row.ach.id] then
			unlocked = unlocked + 1
			row.Name:SetTextColor(1, 0.82, 0)
		else
			row.Name:SetTextColor(0.45, 0.45, 0.5)
		end
	end
	a.Summary:SetText(string.format("%d of %d unlocked, production +%d%%", unlocked, #NS.ACHIEVEMENTS, unlocked))
end

-------------------------------------------------------------------------------
-- Golden cookie
-------------------------------------------------------------------------------

function UI:CreateGolden(f)
	local g = CreateFrame("Button", nil, f)
	g:SetSize(56, 56)
	g:SetFrameLevel(f:GetFrameLevel() + 20)
	g.Glow = RoundIcon(g, "BACKGROUND")
	g.Glow:SetTexture(WHITE)
	g.Glow:SetBlendMode("ADD")
	g.Glow:SetVertexColor(1, 0.85, 0.3, 0.5)
	g.Glow:SetPoint("CENTER")
	g.Glow:SetSize(84, 84)
	g.Icon = RoundIcon(g, "ARTWORK")
	g.Icon:SetAllPoints()
	g.Icon:SetTexture(CookieIcon())
	g.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	g.Icon:SetVertexColor(1, 0.9, 0.45)
	g:RegisterForClicks("LeftButtonDown")
	g:SetScript("OnClick", function()
		NS.Game:ClickGolden()
	end)
	Tooltip(g, "Golden cookie", "Quick, click it!")
	g:Hide()
	self.golden = g
end

function UI:ShowGolden()
	local f, g = self.frame, self.golden
	if not f then
		return
	end
	local margin = 50
	local x = margin + math.random() * (f:GetWidth() - 2 * margin)
	local y = margin + 20 + math.random() * (f:GetHeight() - 2 * margin - 20)
	g:ClearAllPoints()
	g:SetPoint("CENTER", f, "TOPLEFT", x, -y)
	g.t = 0
	g:Show()
	NS.PlayKit("UI_GARRISON_TOAST_FOLLOWER_GAINED")
end

function UI:HideGolden()
	if self.golden then
		self.golden:Hide()
	end
end

-------------------------------------------------------------------------------
-- Feedback
-------------------------------------------------------------------------------

-- "+N" at the mouse, drifting up.
function UI:OnClick(power)
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
	local y = NS.Clamp(cy / scale - bottom, 10, PANEL_H - 10)
	local fs = table.remove(self.floatPool)
	if not fs then
		fs = p:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 13, "OUTLINE")
	end
	fs:SetText("+" .. NS.BeautifyRate(power, true))
	fs:SetTextColor(1, 1, 1)
	fs.x, fs.y0, fs.t = x + (math.random() - 0.5) * 20, y, 0
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", p, "BOTTOMLEFT", fs.x, fs.y0)
	fs:SetAlpha(1)
	fs:Show()
	table.insert(self.floats, fs)
	if #self.floats > 30 then
		local old = table.remove(self.floats, 1)
		old:Hide()
		table.insert(self.floatPool, old)
	end
end

function UI:Banner(text)
	if self.banners then
		table.insert(self.banners, text)
	end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function UI:Refresh(force)
	local f = self.frame
	if not f or not f:IsShown() then
		return
	end
	local game, save = NS.Game, NS.Game.save
	local left = self.left
	left.Count:SetText(NS.Beautify(save.cookies) .. " cookies")
	left.Cps:SetText("per second: " .. NS.BeautifyRate(game:Cps(true)))
	left.Baked:SetText("baked all time: " .. NS.Beautify(save.baked))
	left.Hint:SetText(string.format("per click: %s", NS.BeautifyRate(game:ClickPower())))

	local frenzy, clickFrenzy = game:BuffLeft("frenzy"), game:BuffLeft("clickFrenzy")
	left.Buff:SetText(frenzy > 0 and string.format("Frenzy x%d: %d s", game.FRENZY_MULT, math.ceil(frenzy)) or "")
	left.Buff2:SetText(clickFrenzy > 0 and string.format("Click frenzy x%d: %d s", game.CLICK_FRENZY_MULT, math.ceil(clickFrenzy)) or "")

	-- Store
	local cookies = save.cookies
	for _, row in ipairs(self.store.Rows) do
		local b = row.building
		if game:IsRevealed(b) then
			local price = game:Price(b)
			local owned = game:Count(b.id)
			row.Price:SetText(NS.Beautify(price, true))
			row.Owned:SetText(owned > 0 and tostring(owned) or "")
			if cookies >= price then
				row.Name:SetTextColor(1, 0.82, 0)
				row.Price:SetTextColor(0.45, 1, 0.45)
				row.Icon:SetDesaturated(false)
			else
				row.Name:SetTextColor(0.55, 0.5, 0.4)
				row.Price:SetTextColor(1, 0.45, 0.45)
				row.Icon:SetDesaturated(true)
			end
			row:Show()
		else
			row:Hide()
		end
	end

	-- Upgrades: the list only changes with purchases and unlocks.
	local right = self.right
	if force or self.upgradeVersion ~= game.version or (GetTime() - (self.upgradeScan or 0)) > 2 then
		self.upgradeVersion = game.version
		self.upgradeScan = GetTime()
		self.available = game:AvailableUpgrades()
	end
	local list = self.available or {}
	for i, slot in ipairs(right.Slots) do
		local u = list[i]
		slot.upgrade = u
		if u then
			slot.Icon:SetTexture(u.iconPath)
			if cookies >= u.cost then
				slot.Border:SetVertexColor(0.3, 0.9, 0.3, 1)
				slot.Icon:SetDesaturated(false)
			else
				slot.Border:SetVertexColor(0.3, 0.3, 0.35, 1)
				slot.Icon:SetDesaturated(true)
			end
			slot:Show()
		else
			slot:Hide()
		end
	end
	right.More:SetText(#list > MAX_UPGRADES and string.format("and %d more", #list - MAX_UPGRADES) or "")
	right.Empty:SetShown(#list == 0)

	if self.stats:IsShown() then
		self:RefreshStats()
	end
	if self.achievements:IsShown() and force then
		self:RefreshAchievements()
	end
end

function UI:OnUpdate(dt)
	self.acc = (self.acc or 0) + dt
	if self.acc >= REFRESH_INTERVAL then
		self.acc = 0
		self:Refresh(false)
	end

	-- Floats
	for i = #self.floats, 1, -1 do
		local fs = self.floats[i]
		fs.t = fs.t + dt / 0.8
		if fs.t >= 1 then
			fs:Hide()
			table.remove(self.floats, i)
			table.insert(self.floatPool, fs)
		else
			fs:SetPoint("CENTER", self.left, "BOTTOMLEFT", fs.x, fs.y0 + 34 * fs.t)
			fs:SetAlpha(fs.t < 0.5 and 1 or (1 - (fs.t - 0.5) * 2))
		end
	end

	-- Banner
	local p = self.left
	if not self.bannerT and #self.banners > 0 then
		p.Banner:SetText(table.remove(self.banners, 1))
		p.Banner:SetTextColor(1, 0.85, 0.3)
		p.Banner:SetAlpha(1)
		p.Banner:Show()
		self.bannerT = 0
	end
	if self.bannerT then
		self.bannerT = self.bannerT + dt
		local q = self.bannerT / 2.4
		if q >= 1 then
			p.Banner:Hide()
			self.bannerT = nil
		elseif q > 0.7 then
			p.Banner:SetAlpha((1 - q) / 0.3)
		end
	end

	-- Golden cookie pulse
	local g = self.golden
	if g:IsShown() then
		g.t = (g.t or 0) + dt
		local size = 54 + 6 * math.sin(g.t * 5)
		g:SetSize(size, size)
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
