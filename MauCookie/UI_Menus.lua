-- MauCookie menus, shown in place of the building rows like the original's
-- #menu: Statistics (general, special, prestige, owned upgrades,
-- achievements as crates), Options, Info and the guild board.

local _, NS = ...

local UI = NS.UI
local FONT, TITLE_FONT, WHITE = UI.FONT, UI.TITLE_FONT, UI.WHITE
local CRATE, FRAME = 48, 60
local LINE_H = 18
local BOARD_ROWS = 18

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

function UI:CreateMenus(f)
	local host = self.middle.Host
	local m = CreateFrame("Frame", nil, host)
	m:SetAllPoints()
	m:SetFrameLevel(host:GetFrameLevel() + 5)
	m:EnableMouse(true)
	m.Bg = m:CreateTexture(nil, "BACKGROUND")
	m.Bg:SetTexture(NS.Art("darkNoise"), "REPEAT", "REPEAT")
	m.Bg:SetHorizTile(true)
	m.Bg:SetVertTile(true)
	m.Bg:SetAllPoints()
	m.Bg:SetTexCoord(0, UI.MID_W / 512, 0, (host:GetHeight() or 500) / 512)
	m.Scroll = UI.Scroll(m, UI.MID_W, host:GetHeight() or 500)
	m.Scroll:SetAllPoints()
	m.Lines = {}
	m.Crates = {}
	m.Headers = {}
	m.Buttons = {}
	m:Hide()
	self.menuFrame = m
	self.menu = nil
	self.guildTab = "allTime"
end

-------------------------------------------------------------------------------
-- Pooled widgets on the menu's scroll child
-------------------------------------------------------------------------------

local function Header(self, i, text, y)
	local m = self.menuFrame
	local h = m.Headers[i]
	if not h then
		h = m.Scroll.Child:CreateFontString(nil, "OVERLAY")
		h:SetFont(TITLE_FONT, 18, "")
		h:SetShadowOffset(1, -1)
		h:SetTextColor(1, 1, 1)
		m.Headers[i] = h
	end
	h:SetText(text)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 16, -y)
	h:Show()
	return y + 28
end

local function Line(self, i, label, value, y, color)
	local m = self.menuFrame
	local l = m.Lines[i]
	if not l then
		l = CreateFrame("Frame", nil, m.Scroll.Child)
		l:SetSize(UI.MID_W - 32, LINE_H)
		l.Label = UI.Text(l, 12, "")
		l.Label:SetPoint("LEFT")
		l.Label:SetPoint("RIGHT", -4, 0)
		l.Label:SetWordWrap(false)
		l.Value = UI.Text(l, 12, "")
		l.Value:SetPoint("RIGHT")
		l.Value:SetJustifyH("RIGHT")
		l.Value:SetTextColor(1, 1, 1)
		l.Line = UI.Solid(l, "BACKGROUND", 1, 1, 1, 0.08)
		l.Line:SetPoint("BOTTOMLEFT")
		l.Line:SetPoint("BOTTOMRIGHT")
		l.Line:SetHeight(1)
		m.Lines[i] = l
	end
	l.Label:SetText(label)
	l.Value:SetText(value or "")
	if color then
		l.Label:SetTextColor(color[1], color[2], color[3])
	else
		l.Label:SetTextColor(0.75, 0.75, 0.75)
	end
	l:SetScript("OnEnter", nil)
	l:SetScript("OnLeave", nil)
	l:EnableMouse(false)
	l:ClearAllPoints()
	l:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 16, -y)
	l:Show()
	return y + LINE_H, l
end

local function Crate(self, i)
	local m = self.menuFrame
	local c = m.Crates[i]
	if c then
		return c
	end
	c = CreateFrame("Button", nil, m.Scroll.Child)
	c:SetSize(CRATE, CRATE)
	c.Frame = c:CreateTexture(nil, "BORDER")
	c.Frame:SetPoint("TOPLEFT", -6, 6)
	c.Frame:SetPoint("BOTTOMRIGHT", 6, -6)
	NS.SetSheetCell(c.Frame, "upgradeFrame", 60, 60, 0, 0)
	c.Shade = UI.Solid(c, "BACKGROUND", 0, 0, 0, 0.25)
	c.Shade:SetAllPoints()
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetAllPoints()
	c:SetScript("OnEnter", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 2, 0)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.upgrade then
			NS.Guard("tooltip", UI.UpgradeTooltip, UI, self.upgrade, "stats")
		elseif self.achievement then
			NS.Guard("tooltip", UI.AchievementTooltip, UI, self.achievement)
		end
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 0, 0)
		GameTooltip:Hide()
	end)
	m.Crates[i] = c
	return c
end

local function Button(self, i, text, width, onClick)
	local m = self.menuFrame
	local b = m.Buttons[i]
	if not b then
		b = UI.FancyButton(m.Scroll.Child, text, width, 22, nil)
		m.Buttons[i] = b
	end
	b:SetText(text)
	b:SetWidth(width)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", nil)
	b:SetScript("OnLeave", nil)
	b:SetEnabledLook(true)
	b:Show()
	return b
end

local function HideFrom(list, from)
	for i = from, #list do
		list[i]:Hide()
	end
end

-------------------------------------------------------------------------------
-- Opening and closing
-------------------------------------------------------------------------------

function UI:ToggleMenu(name)
	if name == "legacy" then
		self:ShowAscend(true)
		return
	end
	if self.menu == name then
		self.menu = nil
		self.menuFrame:Hide()
	else
		self.menu = name
		self.menuFrame:Show()
		if name == "guild" then
			NS.Comm:OnBoardOpened()
		end
		self.menuFrame.Scroll:SetVerticalScroll(0)
	end
	for key, b in pairs(self.middle.Bar.Buttons) do
		b.Label:SetTextColor(key == self.menu and 1 or 0.95, key == self.menu and 0.8 or 0.9, key == self.menu and 0.3 or 0.8)
	end
	self.rowsScroll:SetShown(self.menu == nil)
	self:RefreshMenus(true)
	self:RefreshRows(true)
end

function UI:RefreshMenus(force)
	if not self.menu or not self.menuFrame:IsShown() then
		return
	end
	if not force then
		self.menuAcc = (self.menuAcc or 0) + 1
		if self.menuAcc < 10 then
			return
		end
	end
	self.menuAcc = 0
	if self.menu == "stats" then
		self:RenderStats()
	elseif self.menu == "options" then
		if force then
			self:RenderOptions()
		end
	elseif self.menu == "info" then
		if force then
			self:RenderInfo()
		end
	elseif self.menu == "guild" then
		self:RenderGuild()
	end
end

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------

function UI:RenderStats()
	local game, S = NS.Game, NS.Game.save
	local m = self.menuFrame
	local y = 12
	local li, hi, ci, bi = 0, 0, 0, 0
	local function L(label, value, color)
		li = li + 1
		y = Line(self, li, label, value, y, color)
	end
	local function Hd(text)
		hi = hi + 1
		y = Header(self, hi, text, y)
	end
	Hd("Statistics")
	local gm = game.globalMult or 1
	bi = bi + 1
	local close = Button(self, bi, "Close", 70, function()
		UI:ToggleMenu("stats")
	end)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", m.Scroll.Child, "TOPRIGHT", -24, -10)
	y = y + 4
	Hd("General")
	L("Cookies in bank", NS.Beautify(S.cookies))
	L("Cookies baked (this ascension)", NS.Beautify(S.earned))
	L("Cookies baked (all time)", NS.Beautify(game:AllTime()))
	L("Cookies forfeited by ascending", NS.Beautify(S.reset or 0))
	L("Legacy started", date("%Y-%m-%d", S.fullDate or time()) .. string.format(" (%d ascension%s)", S.resets or 0, (S.resets or 0) == 1 and "" or "s"))
	L("Run started", NS.FormatDuration(S.runTime or 0) .. " of bakery time ago")
	L("Buildings owned", NS.Commas(game:BuildingsOwned()))
	L("Cookies per second", NS.Beautify(game.cps or 0, 1) .. string.format("  (multiplier: %s%%)", NS.Beautify(math.floor(gm * 100))))
	L("Raw cookies per second", NS.Beautify(game.rawCps or 0, 1) .. " (highest this ascension: " .. NS.Beautify(S.cpsHighest or 0, 1) .. ")")
	if (game.cpsSucked or 0) > 0 then
		L("Withered", string.format("%d%% of your CpS is being eaten by wrinklers", math.floor(game.cpsSucked * 100)))
	end
	L("Cookies per click", NS.Beautify(game.mouse or 0, 1))
	L("Cookie clicks", NS.Commas(S.clicks))
	L("Hand-made cookies", NS.Beautify(S.handmade))
	L("Golden cookie clicks", NS.Commas(S.goldenClicks or 0) .. string.format(" (all time: %s, missed: %s)", NS.Commas(S.goldenClicks or 0), NS.Commas(S.missedGolden or 0)))
	L("Wrinklers popped", NS.Commas(S.wrinklersPopped or 0))
	L("Cookies sucked by wrinklers", NS.Beautify(S.cookiesSucked or 0))
	if game:CanLumps() then
		L("Sugar lumps", string.format("%s (harvested %s)", NS.Commas(math.max(0, S.lumps or 0)), NS.Commas(math.max(0, S.lumpsTotal or 0))))
	end
	if (S.reindeerClicked or 0) > 0 then
		L("Reindeer found", NS.Commas(S.reindeerClicked))
	end
	L("Buildings sold", NS.Commas(S.sold or 0))
	L("Time with the bakery running", NS.FormatDuration(S.playTime or 0))
	y = y + 8
	Hd("Special")
	local wrathNames = { [0] = "Appeased", "Awoken", "Displeased", "Angered" }
	local stage = wrathNames[math.min(3, S.elderWrath or 0)]
	if game:Has("Elder Covenant") then
		stage = "Covenant"
	elseif (S.pledgeT or 0) > 0 then
		stage = "Pledged, " .. NS.FormatDuration(S.pledgeT) .. " left"
	end
	L("Grandmatriarchs status", stage)
	L("Elder pledges made", NS.Commas(S.pledges or 0))
	if S.nextResearch and (S.researchT or 0) > 0 then
		L("Research", S.nextResearch .. " in " .. NS.FormatDuration(S.researchT))
	end
	if S.season ~= "" and NS.SEASONS[S.season] then
		L("Season", NS.SEASONS[S.season].name .. (game:Has("Eternal seasons") and "" or (", " .. NS.FormatDuration(S.seasonT or 0) .. " left")))
	end
	if game:Has("A festive hat") then
		L("Santa level", string.format("%d/14 (%s)", S.santaLevel or 0, game:SantaName()))
	end
	if game:Has("A crumbly egg") then
		local info = game:DragonLevelInfo()
		L("Dragon", string.format("%s (level %d/%d)", info and info.name or "", S.dragonLevel or 0, #NS.DRAGON_LEVELS - 1))
	end
	y = y + 8
	Hd("Prestige")
	L("Prestige level", NS.Beautify(S.prestige or 0) .. string.format(" (+%s%% CpS at full heavenly power)", NS.Beautify(S.prestige or 0)))
	L("Heavenly chips", NS.Beautify(S.chips or 0) .. " to spend, " .. NS.Beautify(S.chipsSpent or 0) .. " spent")
	L("Heavenly multiplier", string.format("%d%% of your prestige level is unlocked", math.floor(game:GetHeavenlyMultiplier() * 100)))
	y = y + 8
	-- Owned upgrades.
	local owned = {}
	for _, u in ipairs(NS.UPGRADES) do
		if S.up[u.name] and u.pool ~= "prestige" and u.pool ~= "debug" then
			table.insert(owned, u)
		end
	end
	table.sort(owned, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.index < b.index
	end)
	Hd(string.format("Upgrades unlocked: %d/%d", #owned, #NS.UPGRADES - #NS.PRESTIGE_UPGRADES - 13))
	local per = math.floor((UI.MID_W - 32) / FRAME)
	for i, u in ipairs(owned) do
		ci = ci + 1
		local c = Crate(self, ci)
		c.upgrade, c.achievement = u, nil
		NS.SetIcon(c.Icon, u.icon)
		c.Icon:SetDesaturated(false)
		c:SetAlpha(1)
		local col, row = (i - 1) % per, math.floor((i - 1) / per)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 22 + col * FRAME, -(y + 6 + row * FRAME))
		c:Show()
	end
	y = y + math.ceil(#owned / per) * FRAME + 12
	-- Achievements.
	local normal, shadow = game:AchievementsOwned(), game:ShadowOwned()
	Hd(string.format("Achievements unlocked: %d/%d%s", normal, NS.NORMAL_ACHIEVEMENTS, shadow > 0 and string.format(" (+%d shadow)", shadow) or ""))
	li = li + 1
	y = Line(self, li, "Milk", string.format("%s (%d%%)", game.milk and game.milk.name or "Plain milk", math.floor((game.milkProgress or 0) * 100)), y)
	li = li + 1
	y = Line(self, li, "Each achievement is +4% milk; kittens turn milk into cookies.", "", y)
	local idx = 0
	local shadowStarted = false
	for _, a in ipairs(NS.ACHIEVEMENT_LIST) do
		if a.pool == "shadow" and not shadowStarted then
			shadowStarted = true
			y = y + math.ceil(idx / per) * FRAME + 8
			idx = 0
			Hd("Shadow achievements")
			li = li + 1
			y = Line(self, li, "These are feats that are either unfair or difficult to attain. They do not give milk.", "", y)
		end
		idx = idx + 1
		ci = ci + 1
		local c = Crate(self, ci)
		c.upgrade, c.achievement = nil, a
		NS.SetIcon(c.Icon, a.icon)
		local won = S.ach[a.name]
		c.Icon:SetDesaturated(not won)
		c:SetAlpha(won and 1 or 0.35)
		local col, row = (idx - 1) % per, math.floor((idx - 1) / per)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 22 + col * FRAME, -(y + 6 + row * FRAME))
		c:Show()
	end
	y = y + math.ceil(idx / per) * FRAME + 16
	HideFrom(m.Lines, li + 1)
	HideFrom(m.Headers, hi + 1)
	HideFrom(m.Crates, ci + 1)
	HideFrom(m.Buttons, bi + 1)
	m.Scroll:SetContentHeight(y)
end

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------

local OPTIONS = {
	{ "sounds", "Sounds", "Clicks, purchases, golden cookies, achievements." },
	{ "popups", "Click popups", "A small +cookies text where you click the cookie." },
	{ "particles", "Fancy graphics", "Wobbling cookie, animated milk and shine." },
	{ "shortNumbers", "Short numbers", "1.5M instead of 1.5 million." },
	{ "autoOpenTaxi", "Open the bakery on a flight path", "When you take a flight path the bakery opens by itself." },
	{ "autoOpenFlying", "Open the bakery when flying", "When you take off on a flying mount the bakery opens by itself." },
	{ "autoClose", "Close it again when the flight ends", "Only when the bakery opened itself for the flight." },
	{ "minimapButton", "Minimap button", "The cookie on the minimap: click to open, drag to move." },
	{ "shareScores", "Share my bakery with the guild", "A snapshot of your bakery goes to guild members who use MauCookie, and you keep and pass on theirs." },
}

function UI:RenderOptions()
	local m = self.menuFrame
	local settings = NS.GetSettings()
	local y = 12
	local li, hi, bi = 0, 0, 0
	hi = hi + 1
	y = Header(self, hi, "Options", y)
	bi = bi + 1
	local close = Button(self, bi, "Close", 70, function()
		UI:ToggleMenu("options")
	end)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", m.Scroll.Child, "TOPRIGHT", -24, -10)
	y = y + 4
	for _, opt in ipairs(OPTIONS) do
		local key = opt[1]
		li = li + 1
		local lineY, l = Line(self, li, opt[2], "", y, { 0.9, 0.9, 0.9 })
		bi = bi + 1
		local b = Button(self, bi, settings[key] and "ON" or "OFF", 50, function()
			settings[key] = not settings[key]
			NS.Options:OnChanged(key)
			UI:RenderOptions()
		end)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", l, "RIGHT", 0, 0)
		b.Label:SetTextColor(settings[key] and 0.4 or 0.8, settings[key] and 1 or 0.4, 0.4)
		l:EnableMouse(true)
		UI.SetTooltip(l, function()
			GameTooltip:SetText(opt[2])
			GameTooltip:AddLine(opt[3], 1, 1, 1, true)
		end)
		y = lineY + 6
	end
	y = y + 6
	li = li + 1
	local sy, sl = Line(self, li, "Window size", string.format("%d%%", settings.scale), y, { 0.9, 0.9, 0.9 })
	bi = bi + 1
	local minus = Button(self, bi, "-", 24, function()
		settings.scale = NS.Clamp(settings.scale - 5, NS.RANGES.scale[1], NS.RANGES.scale[2])
		UI:ApplyScale()
		UI:RenderOptions()
	end)
	minus:ClearAllPoints()
	minus:SetPoint("RIGHT", sl, "RIGHT", -70, 0)
	bi = bi + 1
	local plus = Button(self, bi, "+", 24, function()
		settings.scale = NS.Clamp(settings.scale + 5, NS.RANGES.scale[1], NS.RANGES.scale[2])
		UI:ApplyScale()
		UI:RenderOptions()
	end)
	plus:ClearAllPoints()
	plus:SetPoint("RIGHT", sl, "RIGHT", -44, 0)
	y = sy + 14
	hi = hi + 1
	y = Header(self, hi, "Save", y)
	li = li + 1
	y = Line(self, li, "Everything is saved with your account; the bakery only runs while you are logged in.", "", y)
	bi = bi + 1
	local wipe = Button(self, bi, "Wipe save", 110, function()
		UI:Prompt("Wipe save", "Do you REALLY want to wipe your save? You will lose your progress, your achievements and your heavenly chips!", {
			{ "Yes!", function()
				UI:Prompt("Wipe save", "Whoah now, are you really, really sure? This cannot be undone.", {
					{ "Do it!", function()
						NS.Game:Wipe()
						UI:ToggleMenu("options")
					end },
					{ "No" },
				})
			end },
			{ "No" },
		})
	end)
	wipe:ClearAllPoints()
	wipe:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 16, -(y + 6))
	bi = bi + 1
	local panel = Button(self, bi, "Game settings panel", 150, function()
		NS.Options:Open()
	end)
	panel:ClearAllPoints()
	panel:SetPoint("LEFT", wipe, "RIGHT", 8, 0)
	y = y + 40
	HideFrom(m.Lines, li + 1)
	HideFrom(m.Headers, hi + 1)
	HideFrom(m.Crates, 1)
	HideFrom(m.Buttons, bi + 1)
	m.Scroll:SetContentHeight(y)
end

-------------------------------------------------------------------------------
-- Info
-------------------------------------------------------------------------------

local INFO = {
	"Cookie Clicker is a game by Orteil and Opti (DashNet). MauCookie is a port of it to World of Warcraft, made for playing during flights and raids.",
	"Click the big cookie to make cookies. Spend them on buildings that make cookies for you. Buy upgrades to make everything more efficient. Click golden cookies when they show up.",
	"Achievements give milk; kittens turn milk into cookies. Once you have baked a trillion cookies, the Legacy button lets you ascend: your cookies turn into prestige levels and heavenly chips to spend on permanent upgrades.",
	"Sugar lumps appear once you have baked a billion cookies in total; they ripen over real time and buy building levels. Level 1 of a building unlocks its minigame.",
	"The bakery only runs while you are logged in. Research, pledges, seasons and buffs count bakery time; sugar lumps and the Century egg count real time, like the original.",
	"The news ticker may hold fortunes once you own the Fortune cookies heavenly upgrade: click a fortune to claim it.",
	"The guild board (Guild button) shows the bakeries of guild members who use MauCookie; snapshots travel over the guild addon channel.",
}

function UI:RenderInfo()
	local m = self.menuFrame
	local y = 12
	local hi, bi = 1, 1
	y = Header(self, 1, "Info", y)
	local close = Button(self, 1, "Close", 70, function()
		UI:ToggleMenu("info")
	end)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", m.Scroll.Child, "TOPRIGHT", -24, -10)
	if not m.InfoText then
		m.InfoText = UI.Text(m.Scroll.Child, 12, "")
		m.InfoText:SetWidth(UI.MID_W - 40)
		m.InfoText:SetWordWrap(true)
		m.InfoText:SetSpacing(3)
		m.InfoText:SetTextColor(0.85, 0.85, 0.85)
	end
	m.InfoText:SetText(table.concat(INFO, "\n\n"))
	m.InfoText:ClearAllPoints()
	m.InfoText:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", 16, -y)
	m.InfoText:Show()
	y = y + m.InfoText:GetStringHeight() + 24
	HideFrom(m.Lines, 1)
	HideFrom(m.Headers, hi + 1)
	HideFrom(m.Crates, 1)
	HideFrom(m.Buttons, bi + 1)
	m.Scroll:SetContentHeight(y)
	self.infoShown = true
end

-------------------------------------------------------------------------------
-- Guild board
-------------------------------------------------------------------------------

function UI:RenderGuild()
	local m = self.menuFrame
	if m.InfoText then
		m.InfoText:Hide()
	end
	local y = 12
	local li, hi, bi = 0, 0, 0
	hi = hi + 1
	y = Header(self, hi, "Guild board", y)
	bi = bi + 1
	local close = Button(self, bi, "Close", 70, function()
		UI:ToggleMenu("guild")
	end)
	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", m.Scroll.Child, "TOPRIGHT", -24, -10)
	local x = 16
	local board
	for _, def in ipairs(NS.BOARDS) do
		bi = bi + 1
		local b = Button(self, bi, def.name, 68, function()
			UI.guildTab = def.key
			UI:RenderGuild()
		end)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", m.Scroll.Child, "TOPLEFT", x, -y)
		b.Label:SetTextColor(def.key == self.guildTab and 1 or 0.7, def.key == self.guildTab and 0.85 or 0.7, def.key == self.guildTab and 0.4 or 0.7)
		x = x + 72
		if def.key == self.guildTab then
			board = def
		end
	end
	y = y + 30
	local list, empty = {}, nil
	if not IsInGuild() then
		empty = "You are not in a guild. The board shows guild members who use MauCookie."
	else
		list = NS.Comm:Board(self.guildTab)
		if #list <= 1 then
			empty = "Nobody else in the guild has shown up yet. Bakeries of guild members who use MauCookie appear here; snapshots are kept and passed on, so you also see people who are offline."
		end
	end
	li = li + 1
	y = Line(self, li, board and ("By " .. board.label) or "", "", y)
	for i, e in ipairs(list) do
		if i > BOARD_ROWS then
			break
		end
		local value = e.value or 0
		local text
		if self.guildTab == "cps" then
			text = NS.Beautify(value, 1) .. " per second"
		elseif self.guildTab == "prestige" then
			text = string.format("level %d", math.floor(value))
		elseif self.guildTab == "feats" then
			text = string.format("%d of %d", math.floor(value), NS.NORMAL_ACHIEVEMENTS)
		else
			text = NS.Beautify(value)
		end
		local status = e.online and (e.addon and "|cff60ff60online|r" or "|cffa0d0a0online|r") or "|cff707070offline|r"
		li = li + 1
		local ly, l = Line(self, li, string.format("%d. %s%s", i, e.name, e.me and " (you)" or ""), text .. "  " .. status, y)
		l.Label:SetTextColor(NS.ClassColor(e.class))
		l.entry = e
		l:EnableMouse(true)
		UI.SetTooltip(l, function(self)
			local en = self.entry
			GameTooltip:SetText(en.name, NS.ClassColor(en.class))
			GameTooltip:AddDoubleLine("Cookies, all runs", NS.Beautify(en.allTime or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Cookies this run", NS.Beautify(en.run or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Per second", NS.Beautify(en.cps or 0, 1), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Prestige", tostring(math.floor(en.prestige or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Ascensions", tostring(math.floor(en.ascensions or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Buildings", NS.Commas(en.buildings or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Achievements", tostring(math.floor(en.feats or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Golden cookies", NS.Commas(en.golden or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			if en.ts and en.ts > 0 then
				GameTooltip:AddLine("Snapshot " .. Ago(NS.Now() - en.ts), 0.5, 0.5, 0.5)
			end
		end)
		y = ly
	end
	if empty then
		li = li + 1
		y = Line(self, li, empty, "", y)
	end
	y = y + 10
	li = li + 1
	y = Line(self, li, NS.GetSettings().shareScores and "Snapshots go out when something changes, at most once a minute." or "Sharing is off in the options: you keep what you have, nothing is sent.", "", y)
	y = y + 16
	HideFrom(m.Lines, li + 1)
	HideFrom(m.Headers, hi + 1)
	HideFrom(m.Crates, 1)
	HideFrom(m.Buttons, bi + 1)
	m.Scroll:SetContentHeight(y)
end
