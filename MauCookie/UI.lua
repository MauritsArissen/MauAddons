-- MauCookie window: the cookie on the left (on the blue background, with
-- the rotating shine, the milk and the wrinklers), the store in the middle
-- with buy/sell modes, the upgrades on the right, overlays for statistics,
-- achievements, heaven and the guild board, the golden or wrath cookie and
-- the cookie storm drops anywhere in the window, and the news ticker.

local _, NS = ...

local UI = {}
NS.UI = UI

local PAD, TITLE_H = 16, 46
local LEFT_W, STORE_W, RIGHT_W, GAP = 230, 300, 178, 10
local PANEL_H = 560
local COOKIE_SIZE = 170
local ROW_H = 26
local UPGRADE_SIZE, UPGRADE_GAP, UPGRADE_COLS = 36, 4, 4
local MAX_UPGRADES = 40
local BOARD_ROWS = 16
local MILK_H = 50
local WRINKLER_SLOTS = 12
local MAX_DROPS = 24
local TICKER_INTERVAL = 25
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local REFRESH_INTERVAL = 0.1
local AMOUNTS = { 1, 10, 100 }

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

local function SetSelected(button, selected)
	if selected then
		button:LockHighlight()
		button:SetNormalFontObject(GameFontHighlight)
	else
		button:UnlockHighlight()
		button:SetNormalFontObject(GameFontNormal)
	end
end

local function Confirm(button, label, action)
	if button.armed then
		button.armed = nil
		button:SetText(label)
		action()
		return
	end
	button.armed = true
	button:SetText("Sure?")
	C_Timer.After(4, function()
		if button.armed then
			button.armed = nil
			button:SetText(label)
		end
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

local function Tiled(parent, key, layer)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetAllPoints()
	tex:SetTexture(NS.Art(key), "REPEAT", "REPEAT")
	tex:SetHorizTile(true)
	tex:SetVertTile(true)
	return tex
end

local function SetCell(tex, cell)
	local inset = NS.ICON_INSET
	tex:SetTexture(NS.Icon(cell))
	tex:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

local function Ago(seconds)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return string.format("%d min ago", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%d h ago", math.floor(seconds / 3600))
	end
	return string.format("%d days ago", math.floor(seconds / 86400))
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
	f.Ticker = Label(f, "", "GameFontHighlightSmall")
	f.Ticker:SetPoint("TOP", 0, -32)
	f.Ticker:SetWidth(width - 80)
	f.Ticker:SetJustifyH("CENTER")
	f.Ticker:SetTextColor(0.85, 0.85, 0.9)
	self.tickerT = TICKER_INTERVAL

	local top = -(PAD + TITLE_H)
	self:CreateLeft(f, top)
	self:CreateStore(f, top)
	self:CreateRight(f, top)
	self:CreateOverlays(f, top)
	self:CreateGolden(f)
	self:CreateDrops(f)
	self:ApplyArt()

	f:SetScript("OnShow", function()
		UI:Refresh(true)
		UI:RefreshWrinklers()
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

function UI:ApplyArt()
	if not self.frame then
		return
	end
	local cookie = self.left.Cookie
	cookie.Icon:SetTexture(NS.Art("cookie"))
	cookie.Icon:SetTexCoord(0, 1, 0, 1)
	for _, row in ipairs(self.store.Rows) do
		row.iconKey = nil
	end
end

-------------------------------------------------------------------------------
-- Left: the cookie, the wrinklers
-------------------------------------------------------------------------------

function UI:CreateLeft(f, top)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(LEFT_W, PANEL_H)
	p:SetPoint("TOPLEFT", PAD, top)
	self.left = p
	p.Bg = Tiled(p, "bgBlue", "BACKGROUND")

	p.Count = Label(p, "", "GameFontNormalLarge")
	p.Count:SetPoint("TOP", 0, -6)
	p.Count:SetJustifyH("CENTER")
	p.Count:SetWidth(LEFT_W)
	p.Cps = Label(p, "", "GameFontHighlightSmall")
	p.Cps:SetPoint("TOP", 0, -28)
	p.Cps:SetJustifyH("CENTER")
	p.Cps:SetWidth(LEFT_W)

	local cookie = CreateFrame("Button", nil, p)
	cookie:SetSize(COOKIE_SIZE, COOKIE_SIZE)
	cookie:SetPoint("TOP", 0, -62)
	cookie.Shine = cookie:CreateTexture(nil, "BACKGROUND")
	cookie.Shine:SetTexture(NS.Art("shine"))
	cookie.Shine:SetBlendMode("ADD")
	cookie.Shine:SetAlpha(0.55)
	cookie.Shine:SetPoint("CENTER")
	cookie.Shine:SetSize(COOKIE_SIZE * 1.9, COOKIE_SIZE * 1.9)
	cookie.Icon = RoundIcon(cookie, "ARTWORK")
	cookie.Icon:SetAllPoints()
	cookie.Highlight = RoundIcon(cookie, "HIGHLIGHT")
	cookie.Highlight:SetTexture(WHITE)
	cookie.Highlight:SetAllPoints()
	cookie.Highlight:SetVertexColor(1, 1, 1, 0.1)
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
	Tooltip(cookie, "The cookie", "Click it. A key can be bound to clicking under Options > Key Bindings > AddOns.")
	p.Cookie = cookie

	p.FloatLayer = CreateFrame("Frame", nil, p)
	p.FloatLayer:SetAllPoints()
	p.FloatLayer:SetFrameLevel(cookie:GetFrameLevel() + 2)

	-- Wrinklers in an arc under the cookie, heads towards it.
	p.Wrinklers = {}
	local radius = COOKIE_SIZE / 2 + 24
	for slot = 1, WRINKLER_SLOTS do
		local w = CreateFrame("Button", nil, p.FloatLayer)
		w:SetSize(30, 60)
		local angle = math.rad(200 + (slot - 1) * (140 / (WRINKLER_SLOTS - 1)))
		w:SetPoint("CENTER", cookie, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
		w.Icon = w:CreateTexture(nil, "ARTWORK")
		w.Icon:SetAllPoints()
		w.Icon:SetTexture(NS.Art("wrinkler"))
		w.Icon:SetTexCoord(14 / 128, 114 / 128, 28 / 256, 228 / 256)
		w:SetHighlightTexture(WHITE)
		w:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
		w:RegisterForClicks("LeftButtonDown")
		w:SetScript("OnClick", function(self)
			if self.index then
				NS.Game:ClickWrinkler(self.index)
			end
		end)
		w:SetScript("OnEnter", function(self)
			local data = self.index and NS.Game:Wrinklers()[self.index]
			if not data then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(data.shiny and "Shiny wrinkler" or "Wrinkler")
			GameTooltip:AddLine(string.format("Has eaten %s cookies. Click it %d more time%s to burst it and get them back with interest.", NS.Beautify(data.sucked), data.hp, data.hp == 1 and "" or "s"), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		w:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		w:Hide()
		p.Wrinklers[slot] = w
	end

	p.Buff = Label(p, "", "GameFontHighlightSmall")
	p.Buff:SetPoint("TOP", cookie, "BOTTOM", 0, -58)
	p.Buff:SetJustifyH("CENTER")
	p.Buff:SetWidth(LEFT_W)
	p.Buff:SetWordWrap(true)
	p.Buff:SetTextColor(1, 0.85, 0.3)

	p.Milk = p:CreateTexture(nil, "BORDER")
	p.Milk:SetTexture(NS.Art("milk"), "REPEAT", "REPEAT")
	p.Milk:SetHorizTile(true)
	p.Milk:SetPoint("BOTTOMLEFT")
	p.Milk:SetPoint("BOTTOMRIGHT")
	p.Milk:SetHeight(MILK_H)
	p.Milk:SetAlpha(0.9)
	p.milkOffset = 0

	p.Banner = p:CreateFontString(nil, "OVERLAY")
	p.Banner:SetFont(FONT, 15, "OUTLINE")
	p.Banner:SetPoint("BOTTOM", 0, MILK_H + 60)
	p.Banner:SetWidth(LEFT_W)
	p.Banner:SetJustifyH("CENTER")
	p.Banner:SetWordWrap(true)
	p.Banner:Hide()

	p.Prestige = Label(p, "", "GameFontHighlightSmall")
	p.Prestige:SetPoint("BOTTOM", 0, MILK_H + 34)
	p.Prestige:SetJustifyH("CENTER")
	p.Prestige:SetWidth(LEFT_W)
	p.Baked = Label(p, "", "GameFontHighlightSmall")
	p.Baked:SetPoint("BOTTOM", 0, MILK_H + 20)
	p.Baked:SetJustifyH("CENTER")
	p.Baked:SetWidth(LEFT_W)
	p.Hint = Label(p, "", "GameFontHighlightSmall")
	p.Hint:SetPoint("BOTTOM", 0, MILK_H + 6)
	p.Hint:SetJustifyH("CENTER")
	p.Hint:SetWidth(LEFT_W)
	for _, fs in ipairs({ p.Prestige, p.Baked, p.Hint }) do
		fs:SetTextColor(0.8, 0.85, 1)
	end

	self.floats, self.floatPool = {}, {}
	self.banners = {}
end

function UI:RefreshWrinklers()
	local p = self.left
	if not p then
		return
	end
	for _, w in ipairs(p.Wrinklers) do
		w.index = nil
		w:Hide()
	end
	for index, data in ipairs(NS.Game:Wrinklers()) do
		local w = p.Wrinklers[data.slot]
		if w then
			w.index = index
			w.Icon:SetTexture(NS.Art(data.shiny and "wrinklershiny" or "wrinkler"))
			w:Show()
		end
	end
end

-------------------------------------------------------------------------------
-- Middle: the store
-------------------------------------------------------------------------------

function UI:CreateStore(f, top)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(STORE_W, PANEL_H)
	p:SetPoint("TOPLEFT", PAD + LEFT_W + GAP, top)
	self.store = p
	p.Bg = Tiled(p, "storeTile", "BACKGROUND")
	self.mode, self.amount = "buy", 1

	p.BuyMode = Button(p, "Buy", 44, 18, function()
		UI.mode = "buy"
		UI:Refresh(true)
	end)
	p.BuyMode:SetPoint("TOPLEFT", 2, -2)
	p.SellMode = Button(p, "Sell", 44, 18, function()
		UI.mode = "sell"
		UI:Refresh(true)
	end)
	p.SellMode:SetPoint("LEFT", p.BuyMode, "RIGHT", 2, 0)
	Tooltip(p.SellMode, "Sell mode", "Selling gives back a quarter of the current price.")
	p.Amounts = {}
	for i, amount in ipairs(AMOUNTS) do
		local b = Button(p, tostring(amount), 30, 18, function()
			UI.amount = amount
			UI:Refresh(true)
		end)
		b:SetPoint("TOPRIGHT", -2 - (#AMOUNTS - i) * 32, -2)
		p.Amounts[i] = b
	end

	p.Rows = {}
	for i, b in ipairs(NS.BUILDINGS) do
		local row = CreateFrame("Button", nil, p)
		row:SetSize(STORE_W, ROW_H - 1)
		row:SetPoint("TOPLEFT", 0, -22 - (i - 1) * ROW_H)
		row.Bg = row:CreateTexture(nil, "BACKGROUND")
		row.Bg:SetTexture(WHITE)
		row.Bg:SetAllPoints()
		row.Bg:SetVertexColor(0, 0, 0, 0.35)
		row:SetHighlightTexture(WHITE)
		row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(22, 22)
		row.Icon:SetPoint("LEFT", 3, 0)
		row.Name = Label(row, b.name, "GameFontNormalSmall")
		row.Name:SetPoint("TOPLEFT", 30, -1)
		row.Price = Label(row, "", "GameFontHighlightSmall")
		row.Price:SetPoint("BOTTOMLEFT", 30, 1)
		row.Owned = Label(row, "", "GameFontNormal")
		row.Owned:SetPoint("RIGHT", -8, 0)
		row.Owned:SetJustifyH("RIGHT")
		row.Owned:SetTextColor(0.7, 0.7, 0.75)
		row.building = b
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self)
			if UI.mode == "sell" then
				NS.Game:Sell(self.building, UI.amount)
			else
				NS.Game:Buy(self.building, UI.amount)
			end
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
	GameTooltip:AddDoubleLine("Price for " .. self.amount, NS.Beautify(game:PriceFor(b, self.amount)), 0.8, 0.8, 0.8, 1, 1, 1)
	if owned > 0 then
		GameTooltip:AddDoubleLine("Sells for", NS.Beautify(game:SellPriceFor(b, 1)) .. " each", 0.8, 0.8, 0.8, 1, 1, 1)
	end
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
	p.Bg = Tiled(p, "storeTile", "BACKGROUND")
	p.Header = Label(p, "Upgrades", "GameFontNormal")
	p.Header:SetPoint("TOPLEFT", 4, -2)
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
			local game = NS.Game
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(game:UpgradeName(u))
			GameTooltip:AddLine(u.desc, 1, 1, 1, true)
			local cost = game:UpgradeCost(u)
			local affordable = game.save.cookies >= cost
			GameTooltip:AddDoubleLine("Price", NS.Beautify(cost), 0.8, 0.8, 0.8, affordable and 0.4 or 1, affordable and 1 or 0.4, 0.4)
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

	p.Stats = Button(p, "Stats", 86, 20, function()
		UI:ShowStats()
	end)
	p.Stats:SetPoint("BOTTOMLEFT", 0, 24)
	p.Achievements = Button(p, "Feats", 86, 20, function()
		UI:ShowAchievements()
	end)
	p.Achievements:SetPoint("BOTTOMRIGHT", 0, 24)
	Tooltip(p.Achievements, "Achievements", "Every achievement adds 1% to production and 4% milk for the kittens.")
	p.Heaven = Button(p, "Heaven", 86, 20, function()
		UI:ShowHeaven()
	end)
	p.Heaven:SetPoint("BOTTOMLEFT", 0, 0)
	Tooltip(p.Heaven, "Heaven", "Ascend for heavenly chips and spend them on upgrades that last forever.")
	p.Guild = Button(p, "Guild", 86, 20, function()
		UI:ShowGuild()
	end)
	p.Guild:SetPoint("BOTTOMRIGHT", 0, 0)
	Tooltip(p.Guild, "Guild board", "Bakeries of guild members who use MauCookie.")
	p.Options = Label(p, "/mck options", "GameFontDisableSmall")
	p.Options:SetPoint("BOTTOM", 0, 48)
	p.Options:SetJustifyH("CENTER")
	p.Options:SetWidth(RIGHT_W)
end

-------------------------------------------------------------------------------
-- Overlays over the store and upgrades
-------------------------------------------------------------------------------

local OVERLAY_W = STORE_W + GAP + RIGHT_W

local function Overlay(f, top)
	local o = CreateFrame("Frame", nil, f, "BackdropTemplate")
	o:SetSize(OVERLAY_W, PANEL_H)
	o:SetPoint("TOPLEFT", PAD + LEFT_W + GAP, top)
	o:SetFrameLevel(f:GetFrameLevel() + 10)
	o:EnableMouse(true)
	o:SetBackdrop({ bgFile = WHITE })
	o:SetBackdropColor(0.03, 0.03, 0.05, 0.96)
	o:Hide()
	return o
end

function UI:CreateOverlays(f, top)
	self:CreateStats(f, top)
	self:CreateAchievements(f, top)
	self:CreateHeaven(f, top)
	self:CreateGuild(f, top)
end

function UI:CreateStats(f, top)
	local s = Overlay(f, top)
	self.stats = s
	s.Title = Label(s, "Statistics", "GameFontNormalLarge")
	s.Title:SetPoint("TOPLEFT", 12, -8)
	s.Rows = {}
	for i = 1, 24 do
		local row = CreateFrame("Frame", nil, s)
		row:SetSize(OVERLAY_W - 24, 19)
		row:SetPoint("TOPLEFT", 12, -36 - (i - 1) * 19)
		row.Label = Label(row, "", "GameFontNormalSmall")
		row.Label:SetPoint("LEFT")
		row.Value = Label(row, "", "GameFontHighlightSmall")
		row.Value:SetPoint("RIGHT")
		row.Value:SetJustifyH("RIGHT")
		s.Rows[i] = row
	end
	s.Close = Button(s, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	s.Close:SetPoint("BOTTOMRIGHT", -12, 10)
	s.Wipe = Button(s, "Wipe save", 90, 22, function(self)
		Confirm(self, "Wipe save", function()
			UI:HideOverlays()
			NS.Game:Wipe()
		end)
	end)
	s.Wipe:SetPoint("BOTTOMLEFT", 12, 10)
	Tooltip(s.Wipe, "Wipe save", "Starts the bakery over from zero: cookies, buildings, upgrades, achievements, prestige and heavenly upgrades. Click twice.")
end

function UI:CreateAchievements(f, top)
	local a = Overlay(f, top)
	self.achievements = a
	a.Title = Label(a, "Achievements", "GameFontNormalLarge")
	a.Title:SetPoint("TOPLEFT", 12, -8)
	a.Summary = Label(a, "", "GameFontHighlightSmall")
	a.Summary:SetPoint("LEFT", a.Title, "RIGHT", 12, 0)
	a.Rows = {}
	local perColumn = 32
	local colW = (OVERLAY_W - 24) / 2
	for i, ach in ipairs(NS.ACHIEVEMENTS) do
		local row = CreateFrame("Frame", nil, a)
		row:SetSize(colW - 6, 16)
		local col, r = math.floor((i - 1) / perColumn), (i - 1) % perColumn
		row:SetPoint("TOPLEFT", 12 + col * colW, -34 - r * 16)
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
			GameTooltip:AddLine(NS.Game.save.achievements[self.ach.id] and "Unlocked. Production +1%, milk +4%." or "Locked.", 0.6, 0.6, 0.6)
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
	a.Close:SetPoint("TOPRIGHT", -12, -8)
end

function UI:CreateHeaven(f, top)
	local h = Overlay(f, top)
	self.heaven = h
	h.Title = Label(h, "Heaven", "GameFontNormalLarge")
	h.Title:SetPoint("TOPLEFT", 12, -8)
	h.Chips = Label(h, "", "GameFontHighlight")
	h.Chips:SetPoint("TOPLEFT", 12, -34)
	h.Preview = Label(h, "", "GameFontHighlightSmall")
	h.Preview:SetPoint("TOPLEFT", 12, -54)
	h.Preview:SetWidth(OVERLAY_W - 24)
	h.Preview:SetWordWrap(true)
	h.Ascend = Button(h, "Ascend", 110, 24, function(self)
		Confirm(self, "Ascend", function()
			NS.Game:Ascend()
			UI:RefreshHeaven()
		end)
	end)
	h.Ascend:SetPoint("TOPLEFT", 12, -96)
	Tooltip(h.Ascend, "Ascend", "Trades every cookie, building and upgrade for heavenly chips: one prestige level per chip, each level +1% production forever. Achievements and heavenly upgrades stay. Click twice.")
	h.ShopTitle = Label(h, "Heavenly upgrades (hover for details)", "GameFontNormal")
	h.ShopTitle:SetPoint("TOPLEFT", 12, -132)
	h.Rows = {}
	local perColumn = math.ceil(#NS.HEAVENLY / 2)
	local colW = (OVERLAY_W - 24) / 2
	for i, item in ipairs(NS.HEAVENLY) do
		local row = CreateFrame("Frame", nil, h)
		row:SetSize(colW - 6, 28)
		local col, r = math.floor((i - 1) / perColumn), (i - 1) % perColumn
		row:SetPoint("TOPLEFT", 12 + col * colW, -150 - r * 30)
		row.Bg = row:CreateTexture(nil, "BACKGROUND")
		row.Bg:SetTexture(WHITE)
		row.Bg:SetAllPoints()
		row.Bg:SetVertexColor(1, 1, 1, 0.04)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(22, 22)
		row.Icon:SetPoint("LEFT", 3, 0)
		SetCell(row.Icon, item.icon)
		row.Name = Label(row, item.name, "GameFontNormalSmall")
		row.Name:SetPoint("TOPLEFT", 30, -2)
		row.Name:SetWidth(colW - 100)
		row.Name:SetWordWrap(false)
		row.Cost = Label(row, string.format("%d chip%s", item.cost, item.cost == 1 and "" or "s"), "GameFontDisableSmall")
		row.Cost:SetPoint("BOTTOMLEFT", 30, 2)
		row.Buy = Button(row, "Buy", 54, 20, function()
			NS.Game:BuyHeavenly(item)
			UI:RefreshHeaven()
		end)
		row.Buy:SetPoint("RIGHT", -3, 0)
		row.item = item
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.item.name)
			GameTooltip:AddLine(self.item.desc, 1, 1, 1, true)
			GameTooltip:AddLine(NS.Game:HasHeavenly(self.item.id) and "Owned." or string.format("%d heavenly chips.", self.item.cost), 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		h.Rows[i] = row
	end
	h.Close = Button(h, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	h.Close:SetPoint("BOTTOMRIGHT", -12, 10)
end

function UI:CreateGuild(f, top)
	local g = Overlay(f, top)
	self.guild = g
	g.Title = Label(g, "Guild board", "GameFontNormalLarge")
	g.Title:SetPoint("TOPLEFT", 12, -8)
	g.Tabs = {}
	local x = 12
	for _, board in ipairs(NS.BOARDS) do
		local key = board.key
		local b = Button(g, board.name, 88, 20, function()
			UI.guildTab = key
			UI:RefreshGuild()
		end)
		b:SetPoint("TOPLEFT", x, -34)
		g.Tabs[key] = b
		x = x + 92
	end
	g.Head = Label(g, "", "GameFontDisableSmall")
	g.Head:SetPoint("TOPLEFT", 12, -60)
	g.Rows = {}
	for i = 1, BOARD_ROWS do
		local row = CreateFrame("Frame", nil, g)
		row:SetSize(OVERLAY_W - 24, 17)
		row:SetPoint("TOPLEFT", 12, -76 - (i - 1) * 17)
		row.Rank = Label(row, "", "GameFontDisableSmall")
		row.Rank:SetPoint("LEFT")
		row.Rank:SetWidth(26)
		row.Name = Label(row, "", "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT", 28, 0)
		row.Name:SetWidth(150)
		row.Name:SetWordWrap(false)
		row.Value = Label(row, "", "GameFontHighlightSmall")
		row.Value:SetPoint("LEFT", 186, 0)
		row.Value:SetWidth(150)
		row.Extra = Label(row, "", "GameFontDisableSmall")
		row.Extra:SetPoint("LEFT", 340, 0)
		row.Extra:SetWidth(80)
		row.Online = Label(row, "", "GameFontHighlightSmall")
		row.Online:SetPoint("RIGHT", -2, 0)
		row.Online:SetJustifyH("RIGHT")
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			local e = self.entry
			if not e then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(e.name, NS.ClassColor(e.class))
			GameTooltip:AddDoubleLine("Cookies, all runs", NS.Beautify(e.allTime or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Cookies this run", NS.Beautify(e.run or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Per second", NS.BeautifyRate(e.cps or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Prestige", tostring(math.floor(e.prestige or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Ascensions", tostring(math.floor(e.ascensions or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Buildings", NS.Commas(e.buildings or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Achievements", tostring(math.floor(e.feats or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Golden cookies", NS.Commas(e.golden or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Status", e.online and (e.addon and "online, bakery running" or "online") or "offline", 0.8, 0.8, 0.8, 1, 1, 1)
			if e.ts and e.ts > 0 then
				GameTooltip:AddLine("Snapshot " .. Ago(NS.Now() - e.ts), 0.5, 0.5, 0.5)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		g.Rows[i] = row
	end
	g.Empty = Label(g, "", "GameFontDisableSmall")
	g.Empty:SetPoint("TOPLEFT", 12, -80)
	g.Empty:SetWidth(OVERLAY_W - 24)
	g.Empty:SetWordWrap(true)
	g.Note = Label(g, "", "GameFontDisableSmall")
	g.Note:SetPoint("BOTTOMLEFT", 12, 40)
	g.Note:SetWidth(OVERLAY_W - 24)
	g.Note:SetWordWrap(true)
	g.Close = Button(g, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	g.Close:SetPoint("BOTTOMRIGHT", -12, 10)
	self.guildTab = "allTime"
end

function UI:HideOverlays()
	self.stats:Hide()
	self.achievements:Hide()
	self.heaven:Hide()
	self.guild:Hide()
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

function UI:ShowHeaven()
	self:HideOverlays()
	self:RefreshHeaven()
	self.heaven:Show()
end

function UI:ShowGuild()
	self:HideOverlays()
	NS.Comm:OnBoardOpened()
	self:RefreshGuild()
	self.guild:Show()
end

function UI:RefreshStats()
	local s = self.stats
	local game, save = NS.Game, NS.Game.save
	local unlocked = game:AchievementsUnlocked()
	local stageNames = { [0] = "quiet", "awakened", "displeased", "angered" }
	local stage = game:Stage()
	local stageText = stageNames[stage]
	if game:RawStage() > 0 and game:IsPledged() then
		stageText = string.format("pledged, %s left", NS.FormatDuration((save.pledgeUntil or 0) - save.playTime))
	elseif save.covenant then
		stageText = "covenant"
	end
	local research = "-"
	for _, r in ipairs(NS.RESEARCH) do
		if not game:HasUpgrade(r.id) and r.order > 0 and game:HasUpgrade(NS.RESEARCH[r.order].id) then
			local left = (save.researchReadyAt or 0) - save.playTime
			research = left > 0 and (r.name .. " in " .. NS.FormatDuration(left)) or (r.name .. " available")
			break
		end
	end
	local wrinklers = #game:Wrinklers()
	local lines = {
		{ "Cookies in bank", NS.Beautify(save.cookies) },
		{ "Cookies baked this run", NS.Beautify(save.baked) },
		{ "Cookies baked, all runs", NS.Beautify(game:AllTime()) },
		{ "Cookies per second", NS.BeautifyRate(game:Cps(true)) },
		{ "Cookies per click", NS.BeautifyRate(game:ClickPower()) },
		{ "Cookie clicks", NS.Commas(save.clicks) },
		{ "Handmade cookies", NS.Beautify(save.handmade) },
		{ "Buildings owned (sold)", string.format("%s (%s)", NS.Commas(game:TotalBuildings()), NS.Commas(save.sold or 0)) },
		{ "Upgrades bought", string.format("%d of %d", game:UpgradesBought(), #NS.UPGRADES) },
		{ "Achievements", string.format("%d of %d (production +%d%%)", unlocked, #NS.ACHIEVEMENTS, unlocked) },
		{ "Milk", string.format("%d%% (kittens: production x%.2f)", game:Milk() * 100, game:KittenMult()) },
		{ "Golden cookies clicked", NS.Commas(save.golden) .. (save.goldenSwitch and " (switch on)" or "") },
		{ "Grandmapocalypse", stageText },
		{ "Wrinklers", string.format("%d of %d, eating %d%%", wrinklers, game:MaxWrinklers(), wrinklers * 5) },
		{ "Elder pledges", NS.Commas(save.pledges or 0) },
		{ "Next research", research },
		{ "Prestige level", string.format("%d (production +%d%%)", save.prestige or 0, math.floor((save.prestige or 0) * game:PrestigePower())) },
		{ "Heavenly chips to spend", NS.Commas(save.chips or 0) },
		{ "Ascensions", NS.Commas(save.ascensions or 0) },
		{ "Running since", date("%Y-%m-%d", save.started) },
		{ "Time with the bakery running", NS.FormatDuration(save.playTime) },
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
	a.Summary:SetText(string.format("%d of %d unlocked, production +%d%%, milk %d%%", unlocked, #NS.ACHIEVEMENTS, unlocked, unlocked * 4))
end

function UI:RefreshHeaven()
	local h = self.heaven
	if not h then
		return
	end
	local game, save = NS.Game, NS.Game.save
	local gain, level = game:AscendPreview()
	h.Chips:SetText(string.format("Prestige level %d (production +%d%%). %s heavenly chip%s to spend.", save.prestige or 0, math.floor((save.prestige or 0) * game:PrestigePower()), NS.Commas(save.chips or 0), (save.chips or 0) == 1 and "" or "s"))
	if gain > 0 then
		h.Preview:SetText(string.format("Ascending now gives %d chip%s and takes you to prestige level %d. Cookies, buildings and upgrades reset; achievements and heavenly upgrades stay.", gain, gain == 1 and "" or "s", level))
	else
		h.Preview:SetText(string.format("Bake %s more cookies (all runs together) for the next heavenly chip. Prestige level is the cube root of all cookies ever baked divided by %s.", NS.Beautify(game:CookiesToNextChip()), NS.Beautify(NS.PRESTIGE_BASE)))
	end
	h.Ascend:SetEnabled(gain > 0)
	for _, row in ipairs(h.Rows) do
		local owned = game:HasHeavenly(row.item.id)
		if owned then
			row.Buy:SetText("Owned")
			row.Buy:SetEnabled(false)
			row.Name:SetTextColor(1, 0.82, 0)
		else
			row.Buy:SetText("Buy")
			row.Buy:SetEnabled((save.chips or 0) >= row.item.cost)
			row.Name:SetTextColor(1, 1, 1)
		end
	end
end

function UI:RefreshGuild()
	local g = self.guild
	if not g then
		return
	end
	local tab = self.guildTab or "allTime"
	local board
	for _, def in ipairs(NS.BOARDS) do
		SetSelected(g.Tabs[def.key], def.key == tab)
		if def.key == tab then
			board = def
		end
	end
	local list, empty = {}, nil
	if not IsInGuild() then
		empty = "You are not in a guild. The board shows guild members who use MauCookie."
	else
		list = NS.Comm:Board(tab)
		if #list <= 1 then
			empty = "Nobody else in the guild has shown up yet. Bakeries of guild members who use MauCookie appear here; snapshots are kept and passed on, so you also see people who are offline."
		end
	end
	g.Head:SetText(board and ("By " .. board.label) or "")
	for i, row in ipairs(g.Rows) do
		local e = list[i]
		row.entry = e
		if e then
			row.Rank:SetText(i .. ".")
			row.Name:SetText(e.name .. (e.me and " (you)" or ""))
			row.Name:SetTextColor(NS.ClassColor(e.class))
			local value = e.value or 0
			if tab == "cps" then
				row.Value:SetText(NS.BeautifyRate(value) .. " per second")
			elseif tab == "prestige" then
				row.Value:SetText(string.format("level %d", math.floor(value)))
			elseif tab == "feats" then
				row.Value:SetText(string.format("%d of %d", math.floor(value), #NS.ACHIEVEMENTS))
			else
				row.Value:SetText(NS.Beautify(value))
			end
			row.Extra:SetText(string.format("prestige %d", math.floor(e.prestige or 0)))
			if e.online then
				row.Online:SetText(e.addon and "|cff60ff60online|r" or "|cffa0d0a0online|r")
			else
				row.Online:SetText("|cff707070offline|r")
			end
			row:Show()
		else
			row:Hide()
		end
	end
	g.Empty:ClearAllPoints()
	g.Empty:SetPoint("TOPLEFT", 12, -80 - math.min(#list, BOARD_ROWS) * 17)
	g.Empty:SetText(empty or "")
	g.Empty:SetShown(empty ~= nil)
	if NS.GetSettings().shareScores then
		g.Note:SetText("Snapshots travel over the guild addon channel and are kept locally. Yours goes out when something changes, at most once a minute. Hover a name for everything.")
	else
		g.Note:SetText("Sharing is off in the options: you keep what you have, nothing is sent.")
	end
end

function UI:OnGuildDataChanged()
	if self.guild and self.guild:IsShown() then
		self:RefreshGuild()
	end
end

-------------------------------------------------------------------------------
-- Golden cookie and storm drops
-------------------------------------------------------------------------------

local function CookieButton(f, size, onClick)
	local g = CreateFrame("Button", nil, f)
	g:SetSize(size, size)
	g:SetFrameLevel(f:GetFrameLevel() + 20)
	g.Glow = RoundIcon(g, "BACKGROUND")
	g.Glow:SetTexture(WHITE)
	g.Glow:SetBlendMode("ADD")
	g.Glow:SetVertexColor(1, 0.85, 0.3, 0.5)
	g.Glow:SetPoint("CENTER")
	g.Glow:SetSize(size * 1.5, size * 1.5)
	g.Icon = g:CreateTexture(nil, "ARTWORK")
	g.Icon:SetAllPoints()
	g.Icon:SetTexture(NS.Art("golden"))
	g:RegisterForClicks("LeftButtonDown")
	g:SetScript("OnClick", onClick)
	g:Hide()
	return g
end

local function RandomSpot(f, margin)
	local x = margin + math.random() * (f:GetWidth() - 2 * margin)
	local y = margin + 30 + math.random() * (f:GetHeight() - 2 * margin - 30)
	return x, y
end

function UI:CreateGolden(f)
	local g = CookieButton(f, 56, function()
		NS.Game:ClickGolden()
	end)
	g:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.wrath and "Wrath cookie" or "Golden cookie")
		GameTooltip:AddLine(self.wrath and "The grandmas' doing. It might still be worth it." or "Quick, click it!", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	g:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.golden = g
end

function UI:ShowGolden(wrath)
	local f, g = self.frame, self.golden
	if not f then
		return
	end
	g.wrath = wrath
	g.Icon:SetTexture(NS.Art(wrath and "wrath" or "golden"))
	if wrath then
		g.Glow:SetVertexColor(1, 0.2, 0.1, 0.5)
	else
		g.Glow:SetVertexColor(1, 0.85, 0.3, 0.5)
	end
	local x, y = RandomSpot(f, 50)
	g:ClearAllPoints()
	g:SetPoint("CENTER", f, "TOPLEFT", x, -y)
	g.t = 0
	g:Show()
	NS.PlayKit(wrath and "IG_CREATURE_AGGRO_SELECT" or "UI_GARRISON_TOAST_FOLLOWER_GAINED")
end

function UI:HideGolden()
	if self.golden then
		self.golden:Hide()
	end
end

function UI:CreateDrops(f)
	self.drops = {}
	for i = 1, MAX_DROPS do
		local d = CookieButton(f, 34, function(self)
			if self.value then
				NS.Game:ClickDrop(self.value)
				self.value = nil
				self:Hide()
			end
		end)
		d.Glow:SetVertexColor(1, 0.85, 0.3, 0.35)
		self.drops[i] = d
	end
end

function UI:SpawnDrop(value, life)
	local f = self.frame
	if not f then
		return
	end
	for _, d in ipairs(self.drops) do
		if not d:IsShown() then
			local x, y = RandomSpot(f, 36)
			d:ClearAllPoints()
			d:SetPoint("CENTER", f, "TOPLEFT", x, -y)
			d.value = value
			d.left = life
			d:Show()
			return
		end
	end
end

-------------------------------------------------------------------------------
-- Feedback
-------------------------------------------------------------------------------

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
	local y = NS.Clamp(cy / scale - bottom + 14, 10, PANEL_H - 10)
	local fs = table.remove(self.floatPool)
	if not fs then
		fs = p.FloatLayer:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 14, "OUTLINE")
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

local BUFF_LABELS = {
	frenzy = "Frenzy x7", clickFrenzy = "Click frenzy x777", clot = "Clot x0.5", elderFrenzy = "Elder frenzy x666",
	cursed = "Cursed finger", special = "Building special",
}

function UI:Refresh(force)
	local f = self.frame
	if not f or not f:IsShown() then
		return
	end
	local game, save = NS.Game, NS.Game.save
	local left = self.left
	left.Count:SetText(NS.Beautify(save.cookies) .. " cookies")
	local wrinklers = #game:Wrinklers()
	left.Cps:SetText("per second: " .. NS.BeautifyRate(game:Cps(true)) .. (wrinklers > 0 and string.format(" (%d%% being eaten)", wrinklers * 5) or ""))
	left.Baked:SetText("baked this run: " .. NS.Beautify(save.baked))
	left.Hint:SetText(string.format("per click: %s", NS.BeautifyRate(game:ClickPower())))
	if (save.prestige or 0) > 0 or (save.ascensions or 0) > 0 then
		left.Prestige:SetText(string.format("prestige %d, all runs: %s", save.prestige or 0, NS.Beautify(game:AllTime())))
	else
		left.Prestige:SetText("")
	end

	local buffLines = {}
	for key, label in pairs(BUFF_LABELS) do
		local left_ = game:BuffLeft(key)
		if left_ > 0 then
			local buff = game.buffs[key]
			local text = label
			if key == "special" and buff then
				local b = NS.BUILDING_BY_ID[buff.building]
				text = string.format("%s special x%d", b and b.name or "Building", math.floor(buff.mult))
			end
			table.insert(buffLines, string.format("%s: %d s", text, math.ceil(left_)))
		end
	end
	table.sort(buffLines)
	left.Buff:SetText(table.concat(buffLines, "\n"))

	local store = self.store
	SetSelected(store.BuyMode, self.mode == "buy")
	SetSelected(store.SellMode, self.mode == "sell")
	for i, amount in ipairs(AMOUNTS) do
		SetSelected(store.Amounts[i], self.amount == amount)
	end
	local cookies = save.cookies
	local stage = game:Stage()
	for _, row in ipairs(store.Rows) do
		local b = row.building
		if game:IsRevealed(b) then
			local owned = game:Count(b.id)
			local iconKey = "building_" .. b.id
			if b.id == "grandma" and stage > 0 then
				iconKey = "grandma_" .. stage
			end
			if row.iconKey ~= iconKey then
				row.iconKey = iconKey
				row.Icon:SetTexture(NS.Art(iconKey))
				row.Icon:SetTexCoord(0, 1, 0, 1)
			end
			row.Owned:SetText(owned > 0 and tostring(owned) or "")
			if self.mode == "sell" then
				local n = math.min(self.amount, owned)
				row.Price:SetText(n > 0 and ("sell " .. n .. " for " .. NS.Beautify(game:SellPriceFor(b, n), true)) or "none to sell")
				if n > 0 then
					row.Name:SetTextColor(1, 0.7, 0.3)
					row.Price:SetTextColor(1, 0.8, 0.4)
					row.Icon:SetDesaturated(false)
				else
					row.Name:SetTextColor(0.6, 0.55, 0.45)
					row.Price:SetTextColor(0.6, 0.55, 0.45)
					row.Icon:SetDesaturated(true)
				end
			else
				local price = game:PriceFor(b, self.amount)
				row.Price:SetText(NS.Beautify(price, true))
				if cookies >= price then
					row.Name:SetTextColor(1, 0.82, 0)
					row.Price:SetTextColor(0.45, 1, 0.45)
					row.Icon:SetDesaturated(false)
				else
					row.Name:SetTextColor(0.6, 0.55, 0.45)
					row.Price:SetTextColor(1, 0.45, 0.45)
					row.Icon:SetDesaturated(true)
				end
			end
			row:Show()
		else
			row:Hide()
		end
	end

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
			if u.icon then
				SetCell(slot.Icon, u.icon)
			else
				slot.Icon:SetTexture(NS.Art("building_" .. (u.building or "cursor")))
				slot.Icon:SetTexCoord(0, 1, 0, 1)
			end
			if cookies >= game:UpgradeCost(u) then
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
	if force then
		if self.achievements:IsShown() then
			self:RefreshAchievements()
		end
		if self.heaven:IsShown() then
			self:RefreshHeaven()
		end
	end
end

function UI:OnUpdate(dt)
	self.acc = (self.acc or 0) + dt
	if self.acc >= REFRESH_INTERVAL then
		self.acc = 0
		self:Refresh(false)
	end

	local p = self.left
	p.Cookie.Shine:SetRotation(GetTime() * 0.25)
	p.milkOffset = (p.milkOffset + dt * 0.03) % 1
	p.Milk:SetTexCoord(p.milkOffset, p.milkOffset + LEFT_W / 256, 0, MILK_H / 256)

	self.tickerT = self.tickerT + dt
	if self.tickerT >= TICKER_INTERVAL then
		self.tickerT = 0
		self.frame.Ticker:SetText(NS.Game:TickerLine())
	end

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

	local g = self.golden
	if g:IsShown() then
		g.t = (g.t or 0) + dt
		local size = 54 + 6 * math.sin(g.t * 5)
		g:SetSize(size, size)
	end
	for _, d in ipairs(self.drops) do
		if d:IsShown() then
			d.left = (d.left or 0) - dt
			if d.left <= 0 then
				d.value = nil
				d:Hide()
			else
				d:SetAlpha(math.min(1, d.left))
			end
		end
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
