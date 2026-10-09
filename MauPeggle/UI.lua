-- MauPeggle window: the frame around the board, the status lines above it,
-- the buttons below it and the overlays on the board: level result, level
-- select, power picker, guild board.

local _, NS = ...

local UI = {}
NS.UI = UI

local PAD, TITLE_H, HEADER_H, FOOTER_H = 16, 28, 38, 28
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local LEVEL_BUTTONS = 30
local BOARD_ROWS = 14

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
	local Board = NS.Board
	local width = PAD + Board.WIDTH + PAD
	local height = PAD + TITLE_H + HEADER_H + Board.HEIGHT + 6 + FOOTER_H + PAD

	local f = CreateFrame("Frame", "MauPeggleFrame", UIParent, "BackdropTemplate")
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
		MauPeggleDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	f:Hide()

	f.Title = Label(f, "MauPeggle", "GameFontNormalLarge")
	f.Title:SetPoint("TOP", 0, -14)
	f.Title:SetJustifyH("CENTER")
	f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.Close:SetPoint("TOPRIGHT", -4, -4)
	f.Close:SetScript("OnClick", function()
		f:Hide()
	end)

	-- Header
	local headerTop = -(PAD + TITLE_H)
	f.LevelText = Label(f, "", "GameFontNormal")
	f.LevelText:SetPoint("TOPLEFT", PAD, headerTop)
	f.ScoreText = Label(f, "", "GameFontNormalLarge")
	f.ScoreText:SetPoint("TOPRIGHT", -PAD, headerTop + 2)
	f.ScoreText:SetJustifyH("RIGHT")
	local line2 = headerTop - 20
	f.BallsText = Label(f, "", "GameFontHighlightSmall")
	f.BallsText:SetPoint("TOPLEFT", PAD, line2)
	f.OrangeText = Label(f, "", "GameFontHighlightSmall")
	f.OrangeText:SetPoint("TOPLEFT", PAD + 80, line2)
	f.OrangeText:SetTextColor(1, 0.6, 0.2)
	f.MultText = Label(f, "", "GameFontHighlightSmall")
	f.MultText:SetPoint("TOPLEFT", PAD + 210, line2)
	f.MultText:SetTextColor(1, 0.82, 0.2)
	f.ShotText = Label(f, "", "GameFontHighlightSmall")
	f.ShotText:SetPoint("TOPLEFT", PAD + 262, line2)
	f.PowerText = Label(f, "", "GameFontHighlightSmall")
	f.PowerText:SetPoint("TOPRIGHT", -PAD, line2)
	f.PowerText:SetJustifyH("RIGHT")
	f.PowerText:SetTextColor(0.5, 1, 0.5)

	-- Board
	local board = Board:Create(f)
	board:SetPoint("TOPLEFT", PAD, headerTop - HEADER_H)

	-- Footer
	local footerY = PAD + 2
	f.PowerButton = Button(f, "", 150, 20, function()
		UI:ShowPowers()
	end)
	f.PowerButton:SetPoint("BOTTOMLEFT", PAD, footerY)
	f.PowerButton:SetScript("OnEnter", function(self)
		local info = NS.POWER_INFO[NS.Game.power]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(info and info.name or "Power")
		GameTooltip:AddLine(info and info.desc or "", 1, 1, 1, true)
		GameTooltip:AddLine("Click to choose the power for the green pegs.", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
	end)
	f.PowerButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.LevelsButton = Button(f, "Levels", 62, 20, function()
		UI:ShowLevels()
	end)
	f.LevelsButton:SetPoint("LEFT", f.PowerButton, "RIGHT", 5, 0)
	f.GuildButton = Button(f, "Guild", 62, 20, function()
		UI:ShowGuild()
	end)
	f.GuildButton:SetPoint("LEFT", f.LevelsButton, "RIGHT", 5, 0)
	Tooltip(f.GuildButton, "Guild board", "Best scores and progress of guild members who use MauPeggle.")
	f.RestartButton = Button(f, "Restart", 62, 20, function()
		UI:HideOverlays()
		NS.Game:Restart()
	end)
	f.RestartButton:SetPoint("LEFT", f.GuildButton, "RIGHT", 5, 0)
	Tooltip(f.RestartButton, "Restart the level", "Starts this level over with ten balls. The score so far is lost.")
	f.Hint = Label(f, "Aim with the mouse, click to shoot", "GameFontDisableSmall")
	f.Hint:SetPoint("BOTTOMRIGHT", -PAD, footerY + 4)
	f.Hint:SetJustifyH("RIGHT")

	self:CreateOverlays(board)

	f:SetScript("OnShow", function()
		UI:OnShow()
	end)
	f:SetScript("OnHide", function()
		GameTooltip:Hide()
	end)
	if UISpecialFrames then
		tinsert(UISpecialFrames, "MauPeggleFrame")
	end
	self:ApplyPosition()
	self:ApplyScale()
	return f
end

-------------------------------------------------------------------------------
-- Overlays on the board
-------------------------------------------------------------------------------

local function Overlay(board)
	local o = CreateFrame("Frame", nil, board, "BackdropTemplate")
	o:SetAllPoints()
	o:SetFrameLevel(board:GetFrameLevel() + 10)
	o:EnableMouse(true)
	o:SetBackdrop({ bgFile = WHITE })
	o:SetBackdropColor(0, 0, 0, 0.86)
	o:Hide()
	return o
end

local function OverlayTitle(o, text, size)
	o.Title = o:CreateFontString(nil, "OVERLAY")
	o.Title:SetFont(FONT, size or 22, "OUTLINE")
	o.Title:SetPoint("TOP", 0, -22)
	o.Title:SetText(text or "")
	return o.Title
end

function UI:CreateOverlays(board)
	self:CreateResult(board)
	self:CreateLevels(board)
	self:CreatePowers(board)
	self:CreateGuild(board)
end

function UI:CreateResult(board)
	local r = Overlay(board)
	self.result = r
	OverlayTitle(r, "", 28)
	r.Title:ClearAllPoints()
	r.Title:SetPoint("TOP", 0, -66)
	r.Lines = {}
	for i = 1, 7 do
		local fs = Label(r, "", "GameFontHighlight")
		fs:SetPoint("TOP", 0, -112 - (i - 1) * 22)
		fs:SetJustifyH("CENTER")
		r.Lines[i] = fs
	end
	r.Primary = Button(r, "Next level", 110, 24, function()
		UI:HideOverlays()
		if NS.Game.state == "won" then
			NS.Game:NextLevel()
		else
			NS.Game:Restart()
		end
	end)
	r.Primary:SetPoint("BOTTOM", -62, 70)
	r.Secondary = Button(r, "Levels", 110, 24, function()
		UI:ShowLevels()
	end)
	r.Secondary:SetPoint("BOTTOM", 62, 70)
	r.Replay = Button(r, "Play again", 110, 24, function()
		UI:HideOverlays()
		NS.Game:Restart()
	end)
	r.Replay:SetPoint("BOTTOM", -62, 40)
	r.Guild = Button(r, "Guild board", 110, 24, function()
		UI:ShowGuild()
	end)
	r.Guild:SetPoint("BOTTOM", 62, 40)
end

function UI:CreateLevels(board)
	local l = Overlay(board)
	self.levels = l
	OverlayTitle(l, "Levels")
	l.Buttons = {}
	local perRow, bw, bh, gapX, gapY = 6, 76, 24, 8, 8
	local gridW = perRow * bw + (perRow - 1) * gapX
	for i = 1, LEVEL_BUTTONS do
		local b = Button(l, tostring(i), bw, bh, function()
			if NS.Game:IsUnlocked(i) then
				UI:HideOverlays()
				NS.Game:StartLevel(i)
			end
		end)
		local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
		b:SetPoint("TOPLEFT", (NS.Board.WIDTH - gridW) / 2 + col * (bw + gapX), -56 - row * (bh + gapY))
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format("%d. %s", i, NS.Levels.Name(i)))
			local best = MauPeggleDB.progress.best[i]
			if best then
				GameTooltip:AddLine("Your best: " .. NS.Commas(best), 1, 0.82, 0)
			end
			local info = NS.POWER_INFO[NS.Levels.DefaultPower(i)]
			GameTooltip:AddLine("Power: " .. (info and info.name or "?"), 0.5, 1, 0.5)
			if not NS.Game:IsUnlocked(i) then
				GameTooltip:AddLine("Clear the level before it to unlock.", 0.6, 0.6, 0.6)
			end
			local top = NS.Comm:LevelBoard(i)
			if #top > 0 then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Guild", 0.8, 0.8, 0.8)
				for rank = 1, math.min(3, #top) do
					local e = top[rank]
					local cr, cg, cb = NS.ClassColor(e.class)
					GameTooltip:AddDoubleLine(string.format("%d. %s%s", rank, e.name, e.me and " (you)" or ""), NS.Commas(e.score), cr, cg, cb, 1, 1, 1)
				end
			end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		l.Buttons[i] = b
	end
	l.Stats = Label(l, "", "GameFontDisableSmall")
	l.Stats:SetPoint("BOTTOM", 0, 58)
	l.Stats:SetWidth(NS.Board.WIDTH - 40)
	l.Stats:SetJustifyH("CENTER")
	l.Stats:SetWordWrap(true)
	l.Note = Label(l, "Twelve designed boards, then uncharted ones for as long as you like. Orange, green and purple pegs are placed anew every time. Hover a level for its guild top three.", "GameFontDisableSmall")
	l.Note:SetPoint("BOTTOM", 0, 36)
	l.Note:SetWidth(NS.Board.WIDTH - 40)
	l.Note:SetJustifyH("CENTER")
	l.Note:SetWordWrap(true)
	l.Close = Button(l, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	l.Close:SetPoint("BOTTOM", 0, 8)
end

function UI:CreatePowers(board)
	local p = Overlay(board)
	self.powers = p
	OverlayTitle(p, "Choose a power")
	p.Rows = {}
	for i, key in ipairs(NS.POWERS) do
		local info = NS.POWER_INFO[key]
		local row = {}
		row.Button = Button(p, info.name, 118, 24, function()
			NS.Game:SetPower(key)
			UI:RefreshPowers()
		end)
		row.Button:SetPoint("TOPLEFT", 36, -56 - (i - 1) * 42)
		row.Desc = Label(p, info.desc, "GameFontHighlightSmall")
		row.Desc:SetPoint("LEFT", row.Button, "RIGHT", 12, 0)
		row.Desc:SetWidth(NS.Board.WIDTH - 36 - 118 - 12 - 30)
		row.Desc:SetWordWrap(true)
		p.Rows[key] = row
	end
	p.Keep = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
	p.Keep:SetSize(26, 26)
	p.Keep:SetPoint("BOTTOMLEFT", 32, 36)
	p.Keep:SetScript("OnClick", function(self)
		NS.GetSettings().powerMode = self:GetChecked() and "chosen" or "level"
		UI:RefreshPowers()
	end)
	p.KeepLabel = Label(p, "Keep my pick for every level. Off: each level starts with its own power, as in the original's adventure.", "GameFontHighlightSmall")
	p.KeepLabel:SetPoint("LEFT", p.Keep, "RIGHT", 4, 0)
	p.KeepLabel:SetWidth(NS.Board.WIDTH - 32 - 30 - 110)
	p.KeepLabel:SetWordWrap(true)
	p.LevelNote = Label(p, "", "GameFontDisableSmall")
	p.LevelNote:SetPoint("BOTTOMLEFT", 36, 12)
	p.Close = Button(p, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	p.Close:SetPoint("BOTTOMRIGHT", -30, 10)
end

function UI:CreateGuild(board)
	local g = Overlay(board)
	self.guild = g
	OverlayTitle(g, "Guild board")
	g.TabLevel = Button(g, "This level", 100, 22, function()
		UI.guildTab = "level"
		UI:RefreshGuild()
	end)
	g.TabLevel:SetPoint("TOP", -54, -50)
	g.TabProgress = Button(g, "Progress", 100, 22, function()
		UI.guildTab = "progress"
		UI:RefreshGuild()
	end)
	g.TabProgress:SetPoint("TOP", 54, -50)
	g.Head = Label(g, "", "GameFontDisableSmall")
	g.Head:SetPoint("TOPLEFT", 30, -80)
	g.Head:SetWidth(NS.Board.WIDTH - 60)
	g.Rows = {}
	local x0 = 30
	for i = 1, BOARD_ROWS do
		local row = CreateFrame("Frame", nil, g)
		row:SetSize(NS.Board.WIDTH - 60, 17)
		row:SetPoint("TOPLEFT", x0, -96 - (i - 1) * 17)
		row.Rank = Label(row, "", "GameFontDisableSmall")
		row.Rank:SetPoint("LEFT", 0, 0)
		row.Rank:SetWidth(26)
		row.Name = Label(row, "", "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT", 28, 0)
		row.Name:SetWidth(150)
		row.Name:SetWordWrap(false)
		row.A = Label(row, "", "GameFontHighlightSmall")
		row.A:SetPoint("LEFT", 190, 0)
		row.A:SetWidth(120)
		row.B = Label(row, "", "GameFontHighlightSmall")
		row.B:SetPoint("LEFT", 320, 0)
		row.B:SetWidth(110)
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
			if e.score then
				GameTooltip:AddDoubleLine("This level", NS.Commas(e.score), 0.8, 0.8, 0.8, 1, 1, 1)
			end
			if e.cleared then
				GameTooltip:AddDoubleLine("Levels cleared", tostring(e.cleared), 0.8, 0.8, 0.8, 1, 1, 1)
				GameTooltip:AddDoubleLine("Total", NS.Commas(e.total), 0.8, 0.8, 0.8, 1, 1, 1)
			end
			GameTooltip:AddDoubleLine("Status", e.online and (e.addon and "online, playing with the addon" or "online") or "offline", 0.8, 0.8, 0.8, 1, 1, 1)
			if e.ts and e.ts > 0 then
				GameTooltip:AddLine("Record updated " .. Ago(NS.Now() - e.ts), 0.5, 0.5, 0.5)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		g.Rows[i] = row
	end
	g.Empty = Label(g, "", "GameFontDisableSmall")
	g.Empty:SetPoint("TOPLEFT", 30, -100)
	g.Empty:SetWidth(NS.Board.WIDTH - 60)
	g.Empty:SetWordWrap(true)
	g.Note = Label(g, "", "GameFontDisableSmall")
	g.Note:SetPoint("BOTTOM", 0, 36)
	g.Note:SetWidth(NS.Board.WIDTH - 60)
	g.Note:SetJustifyH("CENTER")
	g.Note:SetWordWrap(true)
	g.Close = Button(g, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	g.Close:SetPoint("BOTTOM", 0, 8)
	self.guildTab = "level"
end

function UI:HideOverlays()
	self.result:Hide()
	self.levels:Hide()
	self.powers:Hide()
	self.guild:Hide()
	GameTooltip:Hide()
end

function UI:ShowLevels()
	self:HideOverlays()
	local l = self.levels
	local progress = MauPeggleDB.progress
	for i, b in ipairs(l.Buttons) do
		b:SetEnabled(i <= progress.unlocked)
		local best = progress.best[i]
		b:SetText(best and string.format("%d |cffffd100*|r", i) or tostring(i))
	end
	local s = MauPeggleDB.stats
	l.Stats:SetText(string.format("Cleared %d  |  Shots %s  |  Pegs %s  |  Fevers %d  |  Free balls %d  |  Best shot %s  |  Best level %s  |  Total %s",
		s.levelsCleared, NS.Commas(s.shots), NS.Commas(s.pegs), s.fevers, s.freeBalls, NS.Commas(s.bestShot), NS.Commas(s.bestLevel), NS.Commas(progress.total)))
	l:Show()
end

function UI:ShowPowers()
	self:HideOverlays()
	self:RefreshPowers()
	self.powers:Show()
end

function UI:RefreshPowers()
	local p = self.powers
	local game = NS.Game
	local settings = NS.GetSettings()
	for key, row in pairs(p.Rows) do
		SetSelected(row.Button, key == game.power)
	end
	p.Keep:SetChecked(settings.powerMode == "chosen")
	local info = NS.POWER_INFO[game.levelPower]
	p.LevelNote:SetText(info and ("This level's own power: " .. info.name) or "")
	self:RefreshStatus()
end

function UI:ShowGuild()
	self:HideOverlays()
	NS.Comm:OnBoardOpened()
	self:RefreshGuild()
	self.guild:Show()
end

function UI:RefreshGuild()
	local g = self.guild
	if not g then
		return
	end
	local game = NS.Game
	local tab = self.guildTab or "level"
	SetSelected(g.TabLevel, tab == "level")
	SetSelected(g.TabProgress, tab == "progress")
	local list, empty
	if not IsInGuild() then
		list = {}
		g.Head:SetText("")
		empty = "You are not in a guild. The board shows guild members who use MauPeggle."
	elseif tab == "level" then
		list = (game.level and NS.Comm:LevelBoard(game.level)) or {}
		g.Head:SetText(string.format("Best scores on level %d: %s", game.level or 0, game.levelName or ""))
		if #list == 0 then
			empty = "Nobody in the guild has cleared this level yet."
		end
	else
		list = NS.Comm:ProgressBoard()
		g.Head:SetText("Highest level cleared, then total score")
		if #list == 0 then
			empty = "Nothing known yet. Guild members who use MauPeggle show up here once they clear a level; scores are kept and passed on, so you also see people who are offline."
		end
	end
	for i, row in ipairs(g.Rows) do
		local e = list[i]
		row.entry = e
		if e then
			row.Rank:SetText(i .. ".")
			row.Name:SetText(e.name .. (e.me and " (you)" or ""))
			row.Name:SetTextColor(NS.ClassColor(e.class))
			if tab == "level" then
				row.A:SetText(NS.Commas(e.score))
				row.B:SetText("")
			else
				row.A:SetText(e.cleared > 0 and string.format("Level %d", e.cleared) or "-")
				row.B:SetText(NS.Commas(e.total))
			end
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
	g.Empty:SetText(empty or "")
	g.Empty:SetShown(empty ~= nil)
	if #list > BOARD_ROWS then
		g.Note:SetText(string.format("%d more not shown. ", #list - BOARD_ROWS) .. (NS.GetSettings().shareScores and "Scores travel over the guild addon channel and are kept locally." or "Sharing is off in the options: you keep what you have, nothing is sent."))
	else
		g.Note:SetText(NS.GetSettings().shareScores and "Scores travel over the guild addon channel and are kept locally, so offline members stay on the board." or "Sharing is off in the options: you keep what you have, nothing is sent.")
	end
end

function UI:OnGuildDataChanged()
	if self.guild and self.guild:IsShown() then
		self:RefreshGuild()
	end
end

function UI:ShowResult(won)
	self:HideOverlays()
	local r = self.result
	local game = NS.Game
	for _, fs in ipairs(r.Lines) do
		fs:SetText("")
	end
	if won then
		r.Title:SetText("Level cleared!")
		r.Title:SetTextColor(1, 0.85, 0.3)
		r.Lines[1]:SetText("Pegs: " .. NS.Commas(game.score))
		r.Lines[2]:SetText("Fever bin: " .. NS.Commas(game.feverBonus))
		r.Lines[3]:SetText(string.format("Balls left: %d x %s = %s", game.balls, NS.Commas(game.BALL_BONUS), NS.Commas(game.ballBonus)))
		r.Lines[4]:SetText("|cffffd100Total: " .. NS.Commas(game.levelTotal) .. "|r")
		r.Lines[5]:SetText(game.newBest and "|cff60ff60New best for this level!|r" or ("Your best: " .. NS.Commas(MauPeggleDB.progress.best[game.level] or 0)))
		if game.guildRank and game.guildCount and game.guildCount > 1 then
			r.Lines[6]:SetText(string.format("Guild: #%d of %d on this level", game.guildRank, game.guildCount))
		end
		r.Primary:SetText("Next level")
		r.Replay:Show()
	else
		r.Title:SetText("Out of balls")
		r.Title:SetTextColor(1, 0.4, 0.4)
		r.Lines[1]:SetText(string.format("%d orange peg%s left", game.oranges, game.oranges == 1 and "" or "s"))
		r.Lines[2]:SetText("Score: " .. NS.Commas(game.score))
		r.Lines[3]:SetText("The orange pegs are placed anew every try.")
		r.Primary:SetText("Try again")
		r.Replay:Hide()
	end
	r:Show()
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function UI:RefreshStatus()
	local f = self.frame
	if not f then
		return
	end
	local game = NS.Game
	if game.state == "idle" then
		f.LevelText:SetText("")
		f.ScoreText:SetText("")
		f.BallsText:SetText("")
		f.OrangeText:SetText("")
		f.MultText:SetText("")
		f.ShotText:SetText("")
		f.PowerText:SetText("")
		return
	end
	f.LevelText:SetText(string.format("Level %d: %s", game.level, game.levelName))
	f.ScoreText:SetText(NS.Commas(game.score + game.feverBonus))
	f.BallsText:SetText(string.format("Balls: %d", game.balls))
	f.OrangeText:SetText(string.format("%d orange left", game.oranges))
	f.MultText:SetText(string.format("x%d", game:Multiplier()))
	f.ShotText:SetText(game.shotScore > 0 and ("Shot: " .. NS.Commas(game.shotScore)) or "")
	local info = NS.POWER_INFO[game.power]
	local status = ""
	if game.nextFire then
		status = "Fireball ready"
	elseif game.guideShots > 0 then
		status = string.format("Super Guide: %d shot%s", game.guideShots, game.guideShots == 1 and "" or "s")
	end
	f.PowerText:SetText(status)
	f.PowerButton:SetText("Power: " .. (info and info.name or "?"))
end

function UI:RefreshAll()
	self:RefreshStatus()
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
	local p = MauPeggleDB and MauPeggleDB.position
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
	local game = NS.Game
	if game.state == "idle" then
		local progress = MauPeggleDB.progress
		game:StartLevel(progress.last or progress.unlocked or 1)
	end
	self:RefreshAll()
end
