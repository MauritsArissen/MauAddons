-- MauPlinko rules and bank.
--
-- Everything that changes chips happens here: the bet leaves the bank when a
-- ball is dropped, the win arrives when the board reports the landing.  The
-- path of a ball is decided here at the drop, one coin flip per row, and only
-- animated by the board.  Also here: statistics (all time in the saved
-- variables, this session in memory), the result history, auto mode, top-ups
-- and resets.

local _, NS = ...

local Game = {}
NS.Game = Game

Game.inFlight = 0

function Game:Start()
	self.session = NS.NewStats()
end

function Game:State()
	return MauPlinkoDB.game
end

function Game:Bank()
	return MauPlinkoDB.bank
end

function Game:Stats()
	return MauPlinkoDB.stats
end

function Game:Balance()
	return MauPlinkoDB.bank.balance
end

function Game:IsBroke()
	return self:Balance() < NS.MIN_BET
end

function Game:MaxBet()
	return math.max(NS.MIN_BET, math.min(NS.MAX_BET, math.floor(self:Balance())))
end

function Game:SetBet(value)
	value = math.floor((tonumber(value) or NS.MIN_BET) + 0.5)
	value = math.max(NS.MIN_BET, math.min(self:MaxBet(), value))
	self:State().bet = value
	NS.UI:RefreshControls()
	return value
end

-- Rows and risk stay fixed while balls are in the air: the balls were paid
-- for on the board they were dropped on.
function Game:CanChangeBoard()
	return self.inFlight == 0
end

function Game:SetRisk(risk)
	if not NS.TABLES[risk] or not self:CanChangeBoard() then
		return
	end
	self:State().risk = risk
	NS.Board:SetMultipliers(risk)
	NS.UI:RefreshControls()
end

function Game:SetRows(rows)
	rows = math.max(NS.MIN_ROWS, math.min(NS.MAX_ROWS, rows))
	if not self:CanChangeBoard() or rows == self:State().rows then
		return
	end
	self:State().rows = rows
	NS.Board:Build(rows, self:State().risk)
	NS.UI:RefreshControls()
end

-------------------------------------------------------------------------------
-- Dropping and landing
-------------------------------------------------------------------------------

function Game:Drop()
	local state, bank = self:State(), self:Bank()
	if self.inFlight >= NS.MAX_BALLS then
		return false, "full"
	end
	if bank.balance < NS.MIN_BET then
		NS.UI:RefreshControls()
		return false, "broke"
	end
	if state.bet > bank.balance then
		self:SetBet(bank.balance)
		NS.Print("Bet lowered to %s, that is all you have left.", NS.Commas(state.bet))
	end
	local bet = state.bet
	bank.balance = bank.balance - bet

	local rows = state.rows
	local bits, bucket = {}, 0
	for r = 1, rows do
		local right = math.random(0, 1)
		bits[r] = right
		bucket = bucket + right
	end
	local mults = NS.GetMultipliers(state.risk, rows)
	local ball = {
		bet = bet,
		rows = rows,
		risk = state.risk,
		bits = bits,
		bucket = bucket,
		mult = mults[bucket + 1] or 0,
	}
	self.inFlight = self.inFlight + 1
	NS.Board:Launch(ball)
	NS.UI:RefreshBalance()
	NS.UI:RefreshControls()
	return true
end

-- Key binding and /mpk drop: opens the board first if it is closed.
function Game:DropFromBinding()
	if not NS.UI:IsShown() then
		NS.UI:Show()
	end
	self:Drop()
end

-- Reported by the board when a ball lands (animated) or is settled without
-- animation because the window closed or the player logs out.
function Game:OnLanded(ball, animated)
	local win = NS.Round(ball.bet * ball.mult)
	ball.win = win
	local bank = self:Bank()
	bank.balance = bank.balance + win
	self.inFlight = math.max(0, self.inFlight - 1)
	self:Record(self:Stats(), ball, win)
	self:Record(self.session, ball, win)
	self:AddHistory(ball)
	if animated then
		NS.Board:Celebrate(ball, win)
	end
	self:MaybeAnnounce(ball, win)
	NS.Comm:OnScoreChanged()
	NS.UI:RefreshAll()
end

function Game:Record(stats, ball, win)
	if not stats then
		return
	end
	stats.drops = stats.drops + 1
	stats.wagered = stats.wagered + ball.bet
	stats.returned = stats.returned + win
	if ball.mult > stats.bestMult then
		stats.bestMult = ball.mult
		stats.bestMultRows = ball.rows
		stats.bestMultRisk = ball.risk
	end
	if win > stats.bestWin then
		stats.bestWin = win
		stats.bestWinBet = ball.bet
		stats.bestWinMult = ball.mult
	end
	stats.hist[ball.rows] = stats.hist[ball.rows] or {}
	local h = stats.hist[ball.rows]
	h[ball.bucket] = (h[ball.bucket] or 0) + 1
end

function Game:AddHistory(ball)
	local history = MauPlinkoDB.history
	table.insert(history, 1, {
		m = ball.mult, win = ball.win, bet = ball.bet,
		k = ball.bucket, rows = ball.rows, risk = ball.risk,
	})
	for i = #history, NS.HISTORY_SIZE + 1, -1 do
		table.remove(history, i)
	end
end

-- Pay out every ball still in the air without animation.
function Game:SettleAll()
	self:StopAuto()
	NS.Board:SettleAll()
end

-------------------------------------------------------------------------------
-- Auto mode: a ball every autoDelay seconds until the count is reached, the
-- chips run out or Stop is pressed.  A count of 0 runs until stopped.
-------------------------------------------------------------------------------

function Game:IsAutoRunning()
	return self.autoTicker ~= nil
end

function Game:StartAuto()
	if self.autoTicker then
		return
	end
	local count = self:State().autoCount or 0
	self.autoLeft = count > 0 and count or math.huge
	self.autoTicker = C_Timer.NewTicker(NS.GetSettings().autoDelay, function()
		Game:AutoTick()
	end)
	self:AutoTick()
	NS.UI:RefreshControls()
end

function Game:AutoTick()
	if not self.autoTicker then
		return
	end
	local ok, reason = self:Drop()
	if not ok then
		if reason == "full" then
			return -- wait for balls to land
		end
		self:StopAuto()
		return
	end
	self.autoLeft = self.autoLeft - 1
	if self.autoLeft <= 0 then
		self:StopAuto()
	end
end

function Game:StopAuto()
	if self.autoTicker then
		self.autoTicker:Cancel()
		self.autoTicker = nil
		NS.UI:RefreshControls()
	end
end

function Game:ToggleAuto()
	if self.autoTicker then
		self:StopAuto()
	else
		self:StartAuto()
	end
end

-------------------------------------------------------------------------------
-- Bank
-------------------------------------------------------------------------------

function Game:TopUp()
	if not self:IsBroke() then
		return
	end
	local bank = self:Bank()
	bank.balance = bank.balance + NS.TOP_UP
	bank.topUps = (bank.topUps or 0) + 1
	NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
	NS.Print("Topped up with %s chips (top-up number %d).", NS.Commas(NS.TOP_UP), bank.topUps)
	NS.UI:RefreshAll()
end

function Game:ResetStats()
	MauPlinkoDB.stats = NS.NewStats()
	self.session = NS.NewStats()
	MauPlinkoDB.history = {}
	NS.Comm:OnScoreChanged()
	NS.UI:RefreshAll()
end

function Game:ResetBank()
	local bank = self:Bank()
	bank.balance = NS.START_BALANCE
	bank.topUps = 0
	NS.UI:RefreshAll()
end

-- Optional line in guild chat for a hit at or above the configured
-- multiplier.  Guild chat does not need a hardware event.
function Game:MaybeAnnounce(ball, win)
	local s = NS.GetSettings()
	if not s.announceGuild or ball.mult < s.announceFrom or not IsInGuild() then
		return
	end
	local msg = string.format("MauPlinko: I just hit %sx on %d rows (%s risk) for %s chips!",
		NS.FormatMult(ball.mult), ball.rows, (NS.RISK_LABELS[ball.risk] or ball.risk):lower(), NS.Commas(win))
	pcall(SendChatMessage, msg, "GUILD")
end
