-- MauPeggle window: the frame around the board, the status lines above it,
-- the buttons below it and the overlays (level select, level result).

local _, NS = ...

local UI = {}
NS.UI = UI

local PAD, TITLE_H, HEADER_H, FOOTER_H = 16, 28, 38, 28
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local LEVEL_BUTTONS = 30

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
	f.PowerButton = Button(f, "", 156, 20, function()
		local game = NS.Game
		local index = 1
		for i, key in ipairs(NS.POWERS) do
			if key == game.power then
				index = i
			end
		end
		game:SetPower(NS.POWERS[index % #NS.POWERS + 1])
	end)
	f.PowerButton:SetPoint("BOTTOMLEFT", PAD, footerY)
	f.PowerButton:SetScript("OnEnter", function(self)
		local info = NS.POWER_INFO[NS.Game.power]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(info and info.name or "Power")
		GameTooltip:AddLine(info and info.desc or "", 1, 1, 1, true)
		GameTooltip:AddLine("Click to pick another power for this level's green pegs.", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
	end)
	f.PowerButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.LevelsButton = Button(f, "Levels", 64, 20, function()
		UI:ShowLevels()
	end)
	f.LevelsButton:SetPoint("LEFT", f.PowerButton, "RIGHT", 6, 0)
	f.RestartButton = Button(f, "Restart", 64, 20, function()
		UI:HideOverlays()
		NS.Game:Restart()
	end)
	f.RestartButton:SetPoint("LEFT", f.LevelsButton, "RIGHT", 6, 0)
	Tooltip(f.RestartButton, "Restart the level", "Starts this level over with ten balls. The score so far is lost.")
	f.Hint = Label(f, "Aim with the mouse over the board, click to shoot.", "GameFontDisableSmall")
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
	o:SetBackdropColor(0, 0, 0, 0.84)
	o:Hide()
	return o
end

function UI:CreateOverlays(board)
	-- Result
	local r = Overlay(board)
	self.result = r
	r.Title = r:CreateFontString(nil, "OVERLAY")
	r.Title:SetFont(FONT, 28, "OUTLINE")
	r.Title:SetPoint("TOP", 0, -70)
	r.Lines = {}
	for i = 1, 6 do
		local fs = Label(r, "", "GameFontHighlight")
		fs:SetPoint("TOP", 0, -118 - (i - 1) * 22)
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
	r.Replay:SetPoint("BOTTOM", 0, 40)

	-- Level select
	local l = Overlay(board)
	self.levels = l
	l.Title = l:CreateFontString(nil, "OVERLAY")
	l.Title:SetFont(FONT, 22, "OUTLINE")
	l.Title:SetPoint("TOP", 0, -24)
	l.Title:SetText("Levels")
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
		b:SetPoint("TOPLEFT", (NS.Board.WIDTH - gridW) / 2 + col * (bw + gapX), -60 - row * (bh + gapY))
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format("%d. %s", i, NS.Levels.Name(i)))
			local best = MauPeggleDB.progress.best[i]
			if best then
				GameTooltip:AddLine("Best: " .. NS.Commas(best), 1, 0.82, 0)
			end
			local info = NS.POWER_INFO[NS.Levels.DefaultPower(i)]
			GameTooltip:AddLine("Power: " .. (info and info.name or "?"), 0.5, 1, 0.5)
			if not NS.Game:IsUnlocked(i) then
				GameTooltip:AddLine("Clear the level before it to unlock.", 0.6, 0.6, 0.6)
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
	l.Note = Label(l, "Twelve designed boards, then uncharted ones for as long as you like. Orange, green and purple pegs are placed anew every time.", "GameFontDisableSmall")
	l.Note:SetPoint("BOTTOM", 0, 36)
	l.Note:SetWidth(NS.Board.WIDTH - 40)
	l.Note:SetJustifyH("CENTER")
	l.Note:SetWordWrap(true)
	l.Close = Button(l, "Close", 90, 22, function()
		UI:HideOverlays()
	end)
	l.Close:SetPoint("BOTTOM", 0, 8)
end

function UI:HideOverlays()
	self.result:Hide()
	self.levels:Hide()
end

function UI:ShowLevels()
	self.result:Hide()
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

function UI:ShowResult(won)
	self.levels:Hide()
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
		r.Lines[5]:SetText(game.newBest and "|cff60ff60New best for this level!|r" or ("Best: " .. NS.Commas(MauPeggleDB.progress.best[game.level] or 0)))
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
