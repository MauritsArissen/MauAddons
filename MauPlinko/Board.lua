-- MauPlinko board: pegs, buckets and the balls bouncing between them.
--
-- The board is a fixed-size frame; Build(rows) spaces the pegs so that any
-- number of rows from 8 to 16 fills it.  Pegs form a triangle (row r has
-- r + 2 pegs), the ball starts above the top peg and after every bounce sits
-- exactly above a peg of the next row, half a spacing left or right of where
-- it was, so a ball that bounced right k times ends in bucket k.  The
-- animation moves a ball from peg to peg with a small hop and a gravity-like
-- fall; the path itself (the coin flips) comes from Game.lua.  One OnUpdate
-- drives every ball, the peg flashes, the bucket dips and the floating win
-- texts.  Nothing here changes chips.

local _, NS = ...

local Board = {}
NS.Board = Board

Board.WIDTH, Board.HEIGHT = 420, 430

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local FIRST_STEP, STEP, LAST_STEP = 0.22, 0.14, 0.2   -- seconds per segment at 100% speed
local PEG_FLASH = 0.3
local BUCKET_BOUNCE = 0.28
local FLOAT_TIME = 1.4
local BOARD_FLASH = 0.6
local PEG_SOUND_GAP = 0.05
local LAND_SOUND_GAP = 0.08
local PEG_R, PEG_G, PEG_B, PEG_A = 0.85, 0.87, 0.95, 0.95

-- Balls cycle through these so a swarm in auto mode is easy to follow.
local BALL_COLORS = {
	{ 1.00, 0.82, 0.25 }, { 1.00, 0.58, 0.18 }, { 0.40, 0.85, 1.00 },
	{ 0.62, 1.00, 0.45 }, { 1.00, 0.50, 0.75 }, { 0.85, 0.62, 1.00 },
}

-- A white square behind a round alpha mask: the same trick MauGuildMap uses
-- for its round pins, so it is known to work on this client.
local function Circle(parent, layer)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	tex:SetTexture(WHITE)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
	return tex
end

local function LandingSound(mult)
	if mult < 1 then
		return "IG_MAINMENU_OPTION_CHECKBOX_OFF"
	elseif mult < 3 then
		return "IG_BACKPACK_COIN_OK"
	elseif mult < 20 then
		return "UI_RAID_LOOT_TOAST_LESSER_ITEM_WON"
	elseif mult < 200 then
		return "UI_EPICLOOT_TOAST"
	end
	return "UI_LEGENDARY_LOOT_TOAST"
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

function Board:Create(parent)
	if self.frame then
		return self.frame
	end
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(Board.WIDTH, Board.HEIGHT)
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(0.03, 0.04, 0.08, 0.85)
	f:SetBackdropBorderColor(0.35, 0.35, 0.45, 0.8)
	self.frame = f

	local level = f:GetFrameLevel()
	local function Layer(offset)
		local layer = CreateFrame("Frame", nil, f)
		layer:SetAllPoints()
		layer:SetFrameLevel(level + offset)
		return layer
	end
	self.pegLayer = Layer(1)
	self.bucketLayer = Layer(2)
	self.ballLayer = Layer(4)
	self.fxLayer = Layer(5)

	-- Whole-board flash for the really big hits.
	self.flash = self.fxLayer:CreateTexture(nil, "BACKGROUND")
	self.flash:SetAllPoints()
	self.flash:SetTexture(WHITE)
	self.flash:SetBlendMode("ADD")
	self.flash:SetVertexColor(1, 0.85, 0.4)
	self.flash:SetAlpha(0)
	self.flashT = 0

	self.pegs, self.pegIndex, self.buckets = {}, {}, {}
	self.balls, self.ballPool = {}, {}
	self.pegFlashes = {}
	self.floats, self.floatPool = {}, {}

	f:SetScript("OnUpdate", function(_, elapsed)
		Board:OnUpdate(elapsed)
	end)
	return f
end

-------------------------------------------------------------------------------
-- Geometry, pegs and buckets
-------------------------------------------------------------------------------

-- Lays out `rows` rows of pegs and rows + 1 buckets.  Positions are measured
-- from the top centre of the board (x right, y down as negative).
function Board:Build(rows, risk)
	self.rows = rows
	local s = math.min((Board.WIDTH - 24) / (rows + 2), (Board.HEIGHT - 60) / (rows + 1.6))
	local rowH = s * 0.9
	local pegR = math.max(2.2, s * 0.11)
	local ballR = math.max(4.5, s * 0.27)
	local bucketH = math.max(18, math.min(28, s * 0.75))
	local bucketGap = rowH * 0.75
	local startPad = rowH
	local contentH = startPad + (rows - 1) * rowH + bucketGap + bucketH
	local firstPegY = -((Board.HEIGHT - contentH) / 2) - startPad

	local g = { s = s, rowH = rowH, pegR = pegR, ballR = ballR, bucketH = bucketH, pegY = {} }
	for r = 1, rows do
		g.pegY[r] = firstPegY - (r - 1) * rowH
	end
	g.startY = firstPegY + startPad * 0.9
	g.bucketTop = g.pegY[rows] - bucketGap
	g.bucketY = g.bucketTop - bucketH / 2
	self.g = g

	-- Pegs: row r has r + 2 of them, centred.
	local n = 0
	self.pegIndex = {}
	for r = 1, rows do
		local count = r + 2
		self.pegIndex[r] = {}
		for j = 0, count - 1 do
			n = n + 1
			local peg = self.pegs[n]
			if not peg then
				peg = Circle(self.pegLayer, "ARTWORK")
				self.pegs[n] = peg
			end
			peg.flash = 0
			peg.flashing = nil
			peg.baseSize = pegR * 2
			peg:SetSize(pegR * 2, pegR * 2)
			peg:ClearAllPoints()
			peg:SetPoint("CENTER", self.frame, "TOP", (j - (count - 1) / 2) * s, g.pegY[r])
			peg:SetVertexColor(PEG_R, PEG_G, PEG_B, PEG_A)
			peg:Show()
			self.pegIndex[r][j] = peg
		end
	end
	for i = n + 1, #self.pegs do
		self.pegs[i]:Hide()
	end
	self.pegFlashes = {}

	-- Buckets: one per possible landing, half a spacing offset from the last
	-- peg row so their edges sit under the pegs.
	for k = 0, rows do
		local b = self.buckets[k + 1]
		if not b then
			b = self:CreateBucket()
			self.buckets[k + 1] = b
		end
		b.k = k
		b.bounce = 0
		b.baseX = (k - rows / 2) * s
		b:SetSize(math.max(8, s - 3), bucketH)
		b:ClearAllPoints()
		b:SetPoint("CENTER", self.frame, "TOP", b.baseX, g.bucketY)
		local cr, cg, cb = NS.BucketColor(rows, k)
		b.r, b.g, b.b = cr, cg, cb
		b.Fill:SetVertexColor(cr, cg, cb)
		b.Shade:SetVertexColor(cr * 0.55, cg * 0.55, cb * 0.55)
		b.Text:SetFont(FONT, math.max(7, math.min(13, s * 0.4)), "")
		b:Show()
	end
	for i = rows + 2, #self.buckets do
		self.buckets[i]:Hide()
	end

	self:SetMultipliers(risk)
end

function Board:CreateBucket()
	local b = CreateFrame("Frame", nil, self.bucketLayer)
	b.Fill = b:CreateTexture(nil, "ARTWORK")
	b.Fill:SetTexture(WHITE)
	b.Fill:SetAllPoints()
	b.Shade = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.Shade:SetTexture(WHITE)
	b.Shade:SetPoint("BOTTOMLEFT")
	b.Shade:SetPoint("BOTTOMRIGHT")
	b.Shade:SetHeight(3)
	b.Text = b:CreateFontString(nil, "OVERLAY")
	b.Text:SetPoint("CENTER", 0, 1)
	b.Text:SetTextColor(0.14, 0.07, 0.02)
	b:EnableMouse(true)
	b:SetScript("OnEnter", function(self)
		Board:ShowBucketTooltip(self)
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return b
end

function Board:SetMultipliers(risk)
	self.risk = risk
	local rows = self.rows
	if not rows then
		return
	end
	local mults = NS.GetMultipliers(risk, rows)
	local suffix = self.g.s >= 34 and "x" or ""
	for k = 0, rows do
		local b = self.buckets[k + 1]
		b.mult = mults[k + 1] or 0
		b.Text:SetText(NS.FormatMult(b.mult) .. suffix)
	end
end

function Board:ShowBucketTooltip(bucket)
	local rows = self.rows
	if not rows or not bucket.mult then
		return
	end
	GameTooltip:SetOwner(bucket, "ANCHOR_TOP")
	GameTooltip:SetText(string.format("Pays %sx", NS.FormatMult(bucket.mult)), 1, 0.82, 0)
	GameTooltip:AddDoubleLine("Chance", NS.FormatPercent(NS.BucketProbability(rows, bucket.k)), 0.8, 0.8, 0.8, 1, 1, 1)
	local hist = MauPlinkoDB.stats.hist[rows]
	local count, total = (hist and hist[bucket.k]) or 0, 0
	if hist then
		for _, landings in pairs(hist) do
			total = total + landings
		end
	end
	local landed = "never yet"
	if total > 0 then
		landed = string.format("%s of %s (%s)", NS.Commas(count), NS.Commas(total), NS.FormatPercent(count / total))
	end
	GameTooltip:AddDoubleLine("Landed here", landed, 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Table return", string.format("%.1f%%", NS.RTP(self.risk, rows) * 100), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Balls
-------------------------------------------------------------------------------

function Board:AcquireBall()
	local v = table.remove(self.ballPool)
	if not v then
		v = CreateFrame("Frame", nil, self.ballLayer)
		v.Body = Circle(v, "ARTWORK")
		v.Body:SetAllPoints()
		v.Shine = Circle(v, "OVERLAY")
		v.Shine:SetVertexColor(1, 1, 1, 0.55)
	end
	local d = self.g.ballR * 2
	v:SetSize(d, d)
	v.Shine:SetSize(d * 0.42, d * 0.42)
	v.Shine:ClearAllPoints()
	v.Shine:SetPoint("CENTER", v, "CENTER", -d * 0.17, d * 0.17)
	self.colorIndex = (self.colorIndex or 0) % #BALL_COLORS + 1
	local c = BALL_COLORS[self.colorIndex]
	v.Body:SetVertexColor(c[1], c[2], c[3], 1)
	v:Show()
	return v
end

function Board:ReleaseBall(ball)
	if ball.visual then
		ball.visual:Hide()
		table.insert(self.ballPool, ball.visual)
		ball.visual = nil
	end
end

function Board:PlaceBall(ball, x, y)
	ball.visual:SetPoint("CENTER", self.frame, "TOP", x, y)
end

-- Works out where the ball touches each peg and starts the animation.
function Board:Launch(ball)
	local g, rows = self.g, self.rows
	local nodes = {}
	nodes[0] = { x = 0, y = g.startY }
	local right = 0
	for r = 1, rows do
		-- After r - 1 bounces the ball is above peg number right + 1 of row r.
		nodes[r] = {
			x = (right - (r - 1) / 2) * g.s,
			y = g.pegY[r] + g.pegR + g.ballR * 0.8,
			row = r,
			index = right + 1,
		}
		right = right + ball.bits[r]
	end
	nodes[rows + 1] = { x = (right - rows / 2) * g.s, y = g.bucketY + g.bucketH * 0.1 }
	ball.nodes = nodes
	ball.seg = 0
	ball.t = 0
	ball.visual = self:AcquireBall()
	ball.visual:ClearAllPoints()
	self:PlaceBall(ball, nodes[0].x, nodes[0].y)
	table.insert(self.balls, ball)
end

function Board:OnUpdate(dt)
	if dt > 0.1 then
		dt = 0.1
	end
	local g = self.g
	if not g then
		return
	end
	local speed = (NS.GetSettings().speed or 100) / 100

	-- Balls
	for i = #self.balls, 1, -1 do
		local ball = self.balls[i]
		local landed = false
		local remaining = dt * speed
		while remaining > 0 and not landed do
			local segTime = STEP
			if ball.seg == 0 then
				segTime = FIRST_STEP
			elseif ball.seg == ball.rows then
				segTime = LAST_STEP
			end
			local need = (1 - ball.t) * segTime
			if remaining >= need then
				remaining = remaining - need
				ball.seg = ball.seg + 1
				ball.t = 0
				if ball.seg <= ball.rows then
					local node = ball.nodes[ball.seg]
					self:FlashPeg(node.row, node.index)
					self:PegSound()
				else
					landed = true
				end
			else
				ball.t = ball.t + remaining / segTime
				remaining = 0
			end
		end
		if landed then
			table.remove(self.balls, i)
			self:Land(ball)
		else
			local a, b = ball.nodes[ball.seg], ball.nodes[ball.seg + 1]
			local t = ball.t
			local hop = (ball.seg >= 1) and g.rowH * 0.3 or 0
			local x = a.x + (b.x - a.x) * t
			local y = a.y + (b.y - a.y) * t * t + hop * math.sin(math.pi * t)
			self:PlaceBall(ball, x, y)
		end
	end

	-- Peg flashes: bigger and golden on the hit, back to normal over PEG_FLASH.
	for i = #self.pegFlashes, 1, -1 do
		local peg = self.pegFlashes[i]
		peg.flash = peg.flash - dt / PEG_FLASH
		if peg.flash <= 0 then
			peg.flash = 0
			peg.flashing = nil
			table.remove(self.pegFlashes, i)
			peg:SetSize(peg.baseSize, peg.baseSize)
			peg:SetVertexColor(PEG_R, PEG_G, PEG_B, PEG_A)
		else
			local f = peg.flash
			local size = peg.baseSize * (1 + 0.9 * f)
			peg:SetSize(size, size)
			peg:SetVertexColor(1, PEG_G + (0.85 - PEG_G) * f, PEG_B + (0.3 - PEG_B) * f, 1)
		end
	end

	-- Bucket dips
	if self.rows then
		for k = 0, self.rows do
			local b = self.buckets[k + 1]
			if b.bounce > 0 then
				b.bounce = math.max(0, b.bounce - dt / BUCKET_BOUNCE)
				b:SetPoint("CENTER", self.frame, "TOP", b.baseX, g.bucketY - 8 * b.bounce)
				local lift = 0.5 * b.bounce
				b.Fill:SetVertexColor(b.r + (1 - b.r) * lift, b.g + (1 - b.g) * lift, b.b + (1 - b.b) * lift)
			end
		end
	end

	-- Floating win texts
	for i = #self.floats, 1, -1 do
		local fs = self.floats[i]
		fs.t = fs.t + dt / FLOAT_TIME
		if fs.t >= 1 then
			fs:Hide()
			table.remove(self.floats, i)
			table.insert(self.floatPool, fs)
		else
			local p = fs.t
			fs:SetPoint("CENTER", self.frame, "TOP", fs.x, fs.y0 + 45 * p)
			fs:SetAlpha(p < 0.5 and 1 or (1 - (p - 0.5) * 2))
		end
	end

	-- Board flash
	if self.flashT > 0 then
		self.flashT = math.max(0, self.flashT - dt / BOARD_FLASH)
		self.flash:SetAlpha(0.35 * self.flashT)
	end
end

function Board:Land(ball)
	local bucket = self.buckets[ball.bucket + 1]
	if bucket then
		bucket.bounce = 1
	end
	self:ReleaseBall(ball)
	NS.Game:OnLanded(ball, true)
end

-- Sound and floating text for an animated landing.
function Board:Celebrate(ball, win)
	local now = GetTime()
	if now - (self.lastLandSound or 0) >= LAND_SOUND_GAP then
		self.lastLandSound = now
		NS.PlayKit(LandingSound(ball.mult))
	end
	if ball.mult >= 5 then
		local node = ball.nodes[ball.rows + 1]
		local limit = Board.WIDTH / 2 - 60
		local x = math.max(-limit, math.min(limit, node.x))
		local r, g, b = NS.TierColor(ball.mult)
		local size = 15
		if ball.mult >= 100 then
			size = 26
		elseif ball.mult >= 20 then
			size = 20
		end
		self:Float(string.format("%sx  +%s", NS.FormatMult(ball.mult), NS.Commas(win)), x, self.g.bucketTop + 30, r, g, b, size)
	end
	if ball.mult >= 100 then
		self.flashT = 1
	end
end

function Board:Float(text, x, y, r, g, b, size)
	local fs = table.remove(self.floatPool)
	if not fs then
		fs = self.fxLayer:CreateFontString(nil, "OVERLAY")
	end
	fs:SetFont(FONT, size, "OUTLINE")
	fs:SetText(text)
	fs:SetTextColor(r, g, b)
	fs.x, fs.y0, fs.t = x, y, 0
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", self.frame, "TOP", x, y)
	fs:SetAlpha(1)
	fs:Show()
	table.insert(self.floats, fs)
end

function Board:FlashPeg(row, index)
	local peg = self.pegIndex[row] and self.pegIndex[row][index]
	if not peg then
		return
	end
	peg.flash = 1
	if not peg.flashing then
		peg.flashing = true
		table.insert(self.pegFlashes, peg)
	end
end

function Board:PegSound()
	if not NS.GetSettings().pegSounds then
		return
	end
	local now = GetTime()
	if now - (self.lastPegSound or 0) < PEG_SOUND_GAP then
		return
	end
	self.lastPegSound = now
	NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
end

-- Every ball in the air lands at once, without animation (window closed,
-- logging out).  The game pays them out.
function Board:SettleAll()
	if not self.frame then
		return -- never opened this session
	end
	for i = #self.floats, 1, -1 do
		local fs = self.floats[i]
		fs:Hide()
		table.insert(self.floatPool, fs)
		self.floats[i] = nil
	end
	if #self.balls == 0 then
		return
	end
	local balls = self.balls
	self.balls = {}
	for _, ball in ipairs(balls) do
		self:ReleaseBall(ball)
		NS.Game:OnLanded(ball, false)
	end
end
