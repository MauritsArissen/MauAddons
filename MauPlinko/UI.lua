-- MauPlinko window: the frame around the board, the controls on the left
-- (bank, bet, risk, rows, drop, auto) and the side panel on the right with
-- the last drops, the statistics and the guild board.  The Refresh*
-- functions redraw from the saved state; nothing in here decides anything
-- about chips, that is Game.lua.

local _, NS = ...

local UI = {}
NS.UI = UI

local PAD, TITLE_H, CONTROLS_W, SIDE_W, GAP = 16, 30, 150, 170, 10
local HISTORY_ROWS = NS.HISTORY_SIZE
local LIST_ROWS = 17
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

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

-- A numeric edit box that applies its value when Enter is pressed or the
-- focus leaves, and forgets it on Escape.
local function NumberBox(parent, width, onCommit)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(width, 20)
	e:SetAutoFocus(false)
	e:SetNumeric(true)
	e:SetMaxLetters(9)
	e:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	e:SetScript("OnEscapePressed", function(self)
		self.cancelled = true
		self:ClearFocus()
	end)
	e:SetScript("OnEditFocusLost", function(self)
		if self.cancelled then
			self.cancelled = nil
		else
			onCommit(self:GetNumber())
		end
		UI:RefreshControls()
	end)
	return e
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

local function NetColor(n)
	if n > 0 then
		return 0.3, 1, 0.3
	elseif n < 0 then
		return 1, 0.4, 0.4
	end
	return 1, 1, 1
end

local function Ago(seconds)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return string.format("%d min ago", math.floor(seconds / 60))
	end
	return string.format("%d h ago", math.floor(seconds / 3600))
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

function UI:Create()
	if self.frame then
		return self.frame
	end
	local Board = NS.Board
	local width = PAD + CONTROLS_W + GAP + Board.WIDTH + GAP + SIDE_W + PAD
	local height = PAD + TITLE_H + Board.HEIGHT + PAD

	local f = CreateFrame("Frame", "MauPlinkoFrame", UIParent, "BackdropTemplate")
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
		MauPlinkoDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	f:Hide()

	f.Title = Label(f, "MauPlinko", "GameFontNormalLarge")
	f.Title:SetPoint("TOP", 0, -14)
	f.Title:SetJustifyH("CENTER")
	f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.Close:SetPoint("TOPRIGHT", -4, -4)
	f.Close:SetScript("OnClick", function()
		f:Hide()
	end)

	local top = -(PAD + TITLE_H)
	local board = Board:Create(f)
	board:SetPoint("TOPLEFT", PAD + CONTROLS_W + GAP, top)
	self:CreateControls(f, top)
	self:CreateSide(f, top)

	f:SetScript("OnShow", function()
		UI:OnShow()
	end)
	f:SetScript("OnHide", function()
		UI:OnHide()
	end)
	if UISpecialFrames then
		tinsert(UISpecialFrames, "MauPlinkoFrame")
	end
	self:ApplyPosition()
	self:ApplyScale()
	return f
end

function UI:CreateControls(f, top)
	local Game = NS.Game
	local c = CreateFrame("Frame", nil, f)
	c:SetSize(CONTROLS_W, NS.Board.HEIGHT)
	c:SetPoint("TOPLEFT", PAD, top)
	self.controls = c

	c.BalanceLabel = Label(c, "CHIPS")
	c.BalanceLabel:SetPoint("TOPLEFT", 0, 0)
	c.BalanceLabel:SetTextColor(0.62, 0.62, 0.66)
	c.Balance = Label(c, "", "GameFontNormalLarge")
	c.Balance:SetPoint("TOPLEFT", 0, -14)
	c.TopUp = Button(c, "Top up", 64, 20, function()
		Game:TopUp()
	end)
	c.TopUp:SetPoint("TOPRIGHT", 0, -12)
	Tooltip(c.TopUp, "Top up", string.format("Puts %s chips in the bank. Only here when you cannot afford the minimum bet of %d. Top-ups are counted in the statistics.", NS.Commas(NS.TOP_UP), NS.MIN_BET))
	c.TopUp:Hide()

	local line = c:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetVertexColor(1, 1, 1, 0.12)
	line:SetSize(CONTROLS_W, 1)
	line:SetPoint("TOPLEFT", 0, -44)

	c.BetLabel = Label(c, "Bet")
	c.BetLabel:SetPoint("TOPLEFT", 0, -54)
	c.Bet = NumberBox(c, CONTROLS_W - 8, function(value)
		Game:SetBet(value)
	end)
	c.Bet:SetPoint("TOPLEFT", 8, -68)
	Tooltip(c.Bet, "Bet", string.format("Chips per ball, at least %d. Enter applies it.", NS.MIN_BET))
	local quick = {
		{ "1/2", 34, "Half the bet", function() Game:SetBet(Game:State().bet / 2) end },
		{ "x2", 34, "Double the bet", function() Game:SetBet(Game:State().bet * 2) end },
		{ "Min", 34, "The minimum bet", function() Game:SetBet(NS.MIN_BET) end },
		{ "Max", 36, "Everything in the bank", function() Game:SetBet(Game:MaxBet()) end },
	}
	local x = 0
	for _, q in ipairs(quick) do
		local b = Button(c, q[1], q[2], 18, q[4])
		b:SetPoint("TOPLEFT", x, -92)
		Tooltip(b, q[3])
		x = x + q[2] + 4
	end

	c.RiskLabel = Label(c, "Risk")
	c.RiskLabel:SetPoint("TOPLEFT", 0, -118)
	c.RiskButtons = {}
	local riskHelp = {
		low = "Small swings: most buckets pay about the bet, the edges a few times it.",
		medium = "The middle pays less than the bet, the edges pay tens of times it.",
		high = "The middle loses most of the bet, the edges pay hundreds of times it, up to 1000x on 16 rows.",
	}
	local riskWidth = { low = 44, medium = 58, high = 44 }
	x = 0
	for _, risk in ipairs(NS.RISKS) do
		local b = Button(c, NS.RISK_LABELS[risk], riskWidth[risk], 20, function()
			Game:SetRisk(risk)
		end)
		b:SetPoint("TOPLEFT", x, -132)
		Tooltip(b, NS.RISK_LABELS[risk] .. " risk", riskHelp[risk])
		c.RiskButtons[risk] = b
		x = x + riskWidth[risk] + 2
	end

	c.RowsLabel = Label(c, "Rows")
	c.RowsLabel:SetPoint("TOPLEFT", 0, -160)
	local rowsHelp = "8 to 16 rows. More rows: more buckets, bigger multipliers at the edges, rarer edges. Rows and risk lock while balls are falling."
	c.RowsMinus = Button(c, "-", 24, 20, function()
		Game:SetRows(Game:State().rows - 1)
	end)
	c.RowsMinus:SetPoint("TOPLEFT", 0, -174)
	Tooltip(c.RowsMinus, "Fewer rows", rowsHelp)
	c.RowsPlus = Button(c, "+", 24, 20, function()
		Game:SetRows(Game:State().rows + 1)
	end)
	c.RowsPlus:SetPoint("TOPLEFT", CONTROLS_W - 24, -174)
	Tooltip(c.RowsPlus, "More rows", rowsHelp)
	c.RowsValue = Label(c, "", "GameFontHighlight")
	c.RowsValue:SetPoint("TOP", c, "TOP", 0, -177)
	c.RowsValue:SetJustifyH("CENTER")

	c.Drop = Button(c, "Drop", CONTROLS_W, 32, function()
		Game:Drop()
	end)
	c.Drop:SetPoint("TOPLEFT", 0, -204)
	c.Drop:SetNormalFontObject(GameFontNormalLarge)
	c.Drop:SetHighlightFontObject(GameFontHighlightLarge)
	c.Drop:SetDisabledFontObject(GameFontDisableLarge or GameFontDisable)
	c.Flight = Label(c, "", "GameFontDisableSmall")
	c.Flight:SetPoint("TOPLEFT", 0, -240)

	c.AutoLabel = Label(c, "Auto drop")
	c.AutoLabel:SetPoint("TOPLEFT", 0, -258)
	c.AutoCount = NumberBox(c, 56, function(value)
		Game:State().autoCount = math.max(0, math.floor(value))
	end)
	c.AutoCount:SetPoint("TOPLEFT", 8, -272)
	Tooltip(c.AutoCount, "Number of balls", "How many balls Start drops one after the other. 0 keeps going until you press Stop or run out of chips.")
	c.Auto = Button(c, "Start", 78, 20, function()
		Game:ToggleAuto()
	end)
	c.Auto:SetPoint("TOPLEFT", CONTROLS_W - 78, -272)
	c.AutoHint = Label(c, "balls, 0 = until stopped", "GameFontDisableSmall")
	c.AutoHint:SetPoint("TOPLEFT", 0, -296)

	c.Rtp = Label(c, "", "GameFontDisableSmall")
	c.Rtp:SetPoint("BOTTOMLEFT", 0, 16)
	c.Note = Label(c, "Chips are pretend. No gold involved.", "GameFontDisableSmall")
	c.Note:SetPoint("BOTTOMLEFT", 0, 2)
end

function UI:CreateSide(f, top)
	local s = CreateFrame("Frame", nil, f)
	s:SetSize(SIDE_W, NS.Board.HEIGHT)
	s:SetPoint("TOPLEFT", PAD + CONTROLS_W + GAP + NS.Board.WIDTH + GAP, top)
	self.side = s

	s.tabs = {}
	local tabs = { { "history", "Last drops", 66 }, { "stats", "Stats", 48 }, { "guild", "Guild", 48 } }
	local x = 0
	for _, def in ipairs(tabs) do
		local key = def[1]
		local b = Button(s, def[2], def[3], 20, function()
			UI:SelectTab(key)
		end)
		b:SetPoint("TOPLEFT", x, 0)
		s.tabs[key] = b
		x = x + def[3] + 4
	end
	s.panels = {
		history = self:CreateHistory(s),
		stats = self:CreateStats(s),
		guild = self:CreateGuild(s),
	}
	self.tab = self.tab or "history"
end

local function Panel(parent)
	local p = CreateFrame("Frame", nil, parent)
	p:SetPoint("TOPLEFT", 0, -28)
	p:SetPoint("BOTTOMRIGHT", 0, 0)
	p:Hide()
	return p
end

function UI:CreateHistory(parent)
	local p = Panel(parent)
	p.rows = {}
	for i = 1, HISTORY_ROWS do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(SIDE_W, 20)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
		row.Swatch = row:CreateTexture(nil, "ARTWORK")
		row.Swatch:SetTexture(WHITE)
		row.Swatch:SetSize(50, 18)
		row.Swatch:SetPoint("LEFT")
		row.Mult = row:CreateFontString(nil, "OVERLAY")
		row.Mult:SetFont(FONT, 11, "")
		row.Mult:SetPoint("CENTER", row.Swatch, "CENTER", 0, 0)
		row.Mult:SetTextColor(0.14, 0.07, 0.02)
		row.Bet = Label(row, "", "GameFontDisableSmall")
		row.Bet:SetPoint("LEFT", row.Swatch, "RIGHT", 6, 0)
		row.Net = Label(row, "", "GameFontHighlightSmall")
		row.Net:SetPoint("RIGHT", -2, 0)
		row.Net:SetJustifyH("RIGHT")
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			local e = self.entry
			if not e then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(string.format("%sx", NS.FormatMult(e.m)), NS.TierColor(e.m))
			GameTooltip:AddDoubleLine("Bet", NS.Commas(e.bet), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Paid", NS.Commas(e.win), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Board", string.format("%d rows, %s risk", e.rows, (NS.RISK_LABELS[e.risk] or e.risk):lower()), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		p.rows[i] = row
	end
	p.Empty = Label(p, "Drop a ball and it shows up here.", "GameFontDisableSmall")
	p.Empty:SetPoint("TOPLEFT", 0, -4)
	p.Empty:SetWidth(SIDE_W)
	p.Empty:SetWordWrap(true)
	return p
end

function UI:CreateStats(parent)
	local p = Panel(parent)
	p.rows = {}
	for i = 1, LIST_ROWS do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(SIDE_W, 17)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * 17)
		row.Label = Label(row, "", "GameFontNormalSmall")
		row.Label:SetPoint("LEFT")
		row.Value = Label(row, "", "GameFontHighlightSmall")
		row.Value:SetPoint("RIGHT", -2, 0)
		row.Value:SetJustifyH("RIGHT")
		p.rows[i] = row
	end
	p.ResetStats = Button(p, "Reset stats", 82, 20, function(self)
		UI:Confirm(self, "Reset stats", function()
			NS.Game:ResetStats()
		end)
	end)
	p.ResetStats:SetPoint("BOTTOMLEFT", 0, 0)
	Tooltip(p.ResetStats, "Reset statistics", "Clears the all-time and session statistics and the last drops. The bank stays. Click twice.")
	p.ResetBank = Button(p, "Reset bank", 82, 20, function(self)
		UI:Confirm(self, "Reset bank", function()
			NS.Game:ResetBank()
		end)
	end)
	p.ResetBank:SetPoint("BOTTOMRIGHT", 0, 0)
	Tooltip(p.ResetBank, "Reset bank", string.format("Sets the bank back to %s chips and the top-up count to zero. Click twice.", NS.Commas(NS.START_BALANCE)))
	return p
end

function UI:CreateGuild(parent)
	local p = Panel(parent)
	p.rows = {}
	for i = 1, LIST_ROWS do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(SIDE_W, 17)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * 17)
		row.Rank = Label(row, "", "GameFontDisableSmall")
		row.Rank:SetPoint("LEFT")
		row.Rank:SetWidth(18)
		row.Name = Label(row, "", "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT", 18, 0)
		row.Name:SetWidth(100)
		row.Name:SetWordWrap(false)
		row.Value = Label(row, "", "GameFontHighlightSmall")
		row.Value:SetPoint("RIGHT", -2, 0)
		row.Value:SetJustifyH("RIGHT")
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			local e = self.entry
			if not e then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(e.name, NS.ClassColor(e.class))
			GameTooltip:AddDoubleLine("Best hit", e.bestMult > 0 and (NS.FormatMult(e.bestMult) .. "x") or "-", 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Biggest win", NS.Commas(e.bestWin), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Drops", NS.Commas(e.drops), 0.8, 0.8, 0.8, 1, 1, 1)
			local nr, ng, nb = NetColor(e.net)
			GameTooltip:AddDoubleLine("Net", NS.Signed(e.net), 0.8, 0.8, 0.8, nr, ng, nb)
			if e.seen then
				GameTooltip:AddLine("Updated " .. Ago(GetTime() - e.seen), 0.5, 0.5, 0.5)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		p.rows[i] = row
	end
	p.Empty = Label(p, "", "GameFontDisableSmall")
	p.Empty:SetPoint("TOPLEFT", 0, -4)
	p.Empty:SetWidth(SIDE_W)
	p.Empty:SetWordWrap(true)
	p.Note = Label(p, "", "GameFontDisableSmall")
	p.Note:SetPoint("BOTTOMLEFT", 0, 0)
	p.Note:SetWidth(SIDE_W)
	p.Note:SetWordWrap(true)
	return p
end

function UI:SelectTab(tab)
	self.tab = tab
	local s = self.side
	for key, button in pairs(s.tabs) do
		SetSelected(button, key == tab)
	end
	for key, panel in pairs(s.panels) do
		panel:SetShown(key == tab)
	end
	self:RefreshSide()
end

-- Two clicks within four seconds for the destructive buttons.
function UI:Confirm(button, label, action)
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

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function UI:RefreshAll()
	if not self.frame then
		return
	end
	self:RefreshBalance()
	self:RefreshControls()
	self:RefreshSide()
end

function UI:RefreshBalance()
	if not self.frame then
		return
	end
	self.controls.Balance:SetText(NS.Commas(NS.Game:Balance()))
end

function UI:RefreshControls()
	if not self.frame then
		return
	end
	local Game = NS.Game
	local c, state = self.controls, Game:State()
	if not c.Bet:HasFocus() then
		c.Bet:SetNumber(state.bet)
	end
	if not c.AutoCount:HasFocus() then
		c.AutoCount:SetNumber(state.autoCount or 0)
	end
	local canChange = Game:CanChangeBoard()
	for risk, button in pairs(c.RiskButtons) do
		SetSelected(button, risk == state.risk)
		button:SetEnabled(canChange)
	end
	c.RowsValue:SetText(tostring(state.rows))
	c.RowsMinus:SetEnabled(canChange and state.rows > NS.MIN_ROWS)
	c.RowsPlus:SetEnabled(canChange and state.rows < NS.MAX_ROWS)
	local broke = Game:IsBroke()
	c.Drop:SetEnabled(not broke and Game.inFlight < NS.MAX_BALLS)
	c.TopUp:SetShown(broke)
	c.Auto:SetText(Game:IsAutoRunning() and "Stop" or "Start")
	c.Auto:SetEnabled(not broke or Game:IsAutoRunning())
	c.Flight:SetText(Game.inFlight > 0 and string.format("%d in the air", Game.inFlight) or "")
	c.Rtp:SetText(string.format("Return to player %.1f%%", NS.RTP(state.risk, state.rows) * 100))
end

function UI:RefreshSide()
	if not self.frame or not self.frame:IsShown() then
		return
	end
	if self.tab == "stats" then
		self:RefreshStats()
	elseif self.tab == "guild" then
		self:RefreshGuild()
	else
		self:RefreshHistory()
	end
end

function UI:RefreshHistory()
	local p = self.side.panels.history
	local history = MauPlinkoDB.history
	for i, row in ipairs(p.rows) do
		local e = history[i]
		row.entry = e
		if e then
			row.Swatch:SetVertexColor(NS.BucketColor(e.rows, e.k))
			row.Mult:SetText(NS.FormatMult(e.m) .. "x")
			row.Bet:SetText("bet " .. NS.Commas(e.bet))
			local net = e.win - e.bet
			row.Net:SetText(NS.Signed(net))
			row.Net:SetTextColor(NetColor(net))
			row:Show()
		else
			row:Hide()
		end
	end
	p.Empty:SetShown(#history == 0)
end

function UI:RefreshStats()
	local p = self.side.panels.stats
	local st, se, bank = MauPlinkoDB.stats, NS.Game.session or NS.NewStats(), MauPlinkoDB.bank
	local function Best(s)
		if s.bestMult <= 0 then
			return "-"
		end
		return NS.FormatMult(s.bestMult) .. "x"
	end
	local function BestWhere(s)
		if s.bestMult <= 0 then
			return ""
		end
		return string.format("%d rows, %s risk", s.bestMultRows or 0, (NS.RISK_LABELS[s.bestMultRisk] or ""):lower())
	end
	local allNet, sessionNet = st.returned - st.wagered, se.returned - se.wagered
	local lines = {
		{ "All time", "", header = true },
		{ "Drops", NS.Commas(st.drops) },
		{ "Wagered", NS.Commas(st.wagered) },
		{ "Returned", NS.Commas(st.returned) },
		{ "Net", NS.Signed(allNet), color = { NetColor(allNet) } },
		{ "Return rate", st.wagered > 0 and string.format("%.1f%%", st.returned / st.wagered * 100) or "-" },
		{ "Best hit", Best(st) },
		{ "", BestWhere(st), dim = true },
		{ "Biggest win", st.bestWin > 0 and NS.Commas(st.bestWin) or "-" },
		{ "Top-ups", NS.Commas(bank.topUps or 0) },
		{ "", "" },
		{ "This session", "", header = true },
		{ "Drops", NS.Commas(se.drops) },
		{ "Net", NS.Signed(sessionNet), color = { NetColor(sessionNet) } },
		{ "Best hit", Best(se) },
		{ "", BestWhere(se), dim = true },
		{ "Biggest win", se.bestWin > 0 and NS.Commas(se.bestWin) or "-" },
	}
	for i, row in ipairs(p.rows) do
		local line = lines[i]
		if line then
			row.Label:SetFontObject(line.header and GameFontNormal or GameFontNormalSmall)
			row.Label:SetText(line[1])
			if line.header then
				row.Label:SetTextColor(1, 0.82, 0)
			else
				row.Label:SetTextColor(0.75, 0.75, 0.78)
			end
			row.Value:SetText(line[2])
			if line.color then
				row.Value:SetTextColor(line.color[1], line.color[2], line.color[3])
			elseif line.dim then
				row.Value:SetTextColor(0.55, 0.55, 0.58)
			else
				row.Value:SetTextColor(1, 1, 1)
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

function UI:RefreshGuild()
	if not self.frame or not self.frame:IsShown() or self.tab ~= "guild" then
		return
	end
	local p = self.side.panels.guild
	local inGuild = IsInGuild()
	local list = inGuild and NS.Comm:SortedScores() or {}
	local shown = 0
	for i, row in ipairs(p.rows) do
		local e = list[i]
		row.entry = e
		if e then
			shown = shown + 1
			row.Rank:SetText(i .. ".")
			row.Name:SetText(e.name .. (e.me and " (you)" or ""))
			row.Name:SetTextColor(NS.ClassColor(e.class))
			row.Value:SetText(e.bestMult > 0 and (NS.FormatMult(e.bestMult) .. "x") or "-")
			row.Value:SetTextColor(NS.TierColor(e.bestMult))
			row:Show()
		else
			row:Hide()
		end
	end
	local empty
	if not inGuild then
		empty = "You are not in a guild. Scores are shared with guild members who use MauPlinko."
	elseif #list <= 1 then
		empty = "Nobody else in the guild has reported a score yet. Guild members who use MauPlinko show up here as soon as they have dropped a ball."
	end
	p.Empty:ClearAllPoints()
	p.Empty:SetPoint("TOPLEFT", 0, -(shown * 17 + 6))
	p.Empty:SetText(empty or "")
	p.Empty:SetShown(empty ~= nil)
	if NS.GetSettings().shareScores then
		p.Note:SetText("Hover a name for drops, net and biggest win.")
	else
		p.Note:SetText("Score sharing is off in the options: you see others, they do not see you.")
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
	local p = MauPlinkoDB and MauPlinkoDB.position
	if p and p.point then
		f:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
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

function UI:OnShow()
	local state = NS.Game:State()
	local Board = NS.Board
	if not Board.g or Board.rows ~= state.rows then
		Board:Build(state.rows, state.risk)
	elseif Board.risk ~= state.risk then
		Board:SetMultipliers(state.risk)
	end
	self:SelectTab(self.tab or "history")
	self:RefreshAll()
	NS.Comm:Ask()
end

-- Closing the window pays out whatever is still falling and stops auto mode.
function UI:OnHide()
	NS.Game:StopAuto()
	NS.Board:SettleAll()
	GameTooltip:Hide()
end
