-- MauPeggle board: everything you see inside the play field.
--
-- Pegs (circle and brick visuals from pools), the balls, the launcher
-- (a hub, three beads along the aim and the waiting ball), the aim guide
-- dots, the moving bucket, the fever bins, score popups, banners and the
-- flash.  The board frame takes the mouse: moving aims, a left click fires.
-- One OnUpdate advances the game (Game:Update) and then draws.  Positions
-- are board units from the top left, converted with SetPoint("CENTER",
-- frame, "TOPLEFT", x, -y).

local _, NS = ...

local Board = {}
NS.Board = Board

local P = NS.Physics
local W, H = P.W, P.H
Board.WIDTH, Board.HEIGHT = W, H

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local COLORS = {
	blue = { 0.25, 0.55, 1.0 },
	orange = { 1.0, 0.55, 0.12 },
	green = { 0.35, 0.9, 0.35 },
	purple = { 0.78, 0.4, 1.0 },
}
local GUIDE_DOTS = 60
local POP_TIME = 0.22
local VANISH_TIME = 0.18
local POPUP_TIME = 0.9
local BANNER_TIME = 1.3
local PEG_SOUND_GAP = 0.04
local BIN_COLORS = { { 0.3, 0.5, 1 }, { 0.7, 0.4, 1 }, { 1, 0.8, 0.2 }, { 0.7, 0.4, 1 }, { 0.3, 0.5, 1 } }

local function Circle(parent, layer, sublevel)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	tex:SetTexture(WHITE)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
	return tex
end

local function Place(region, x, y)
	region:SetPoint("CENTER", Board.frame, "TOPLEFT", x, -y)
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

function Board:Create(parent)
	if self.frame then
		return self.frame
	end
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(W, H)
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(0.04, 0.05, 0.1, 0.9)
	f:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.8)
	f:EnableMouse(true)
	self.frame = f

	local level = f:GetFrameLevel()
	local function Layer(offset)
		local layer = CreateFrame("Frame", nil, f)
		layer:SetAllPoints()
		layer:SetFrameLevel(level + offset)
		return layer
	end
	self.pegLayer = Layer(1)
	self.ballLayer = Layer(3)
	self.topLayer = Layer(4)

	self.flash = self.topLayer:CreateTexture(nil, "BACKGROUND")
	self.flash:SetAllPoints()
	self.flash:SetTexture(WHITE)
	self.flash:SetBlendMode("ADD")
	self.flash:SetVertexColor(1, 0.7, 0.3)
	self.flash:SetAlpha(0)
	self.flashT = 0

	self.circlePool, self.brickPool, self.ballPool = {}, {}, {}
	self.effects, self.popups, self.popupPool = {}, {}, {}
	self.banners = {}
	self.visuals = {}

	-- Launcher
	self.hub = Circle(self.topLayer, "ARTWORK")
	self.hub:SetSize(30, 30)
	self.hub:SetVertexColor(0.45, 0.45, 0.55, 1)
	Place(self.hub, P.LAUNCH_X, P.LAUNCH_Y)
	self.hubShine = Circle(self.topLayer, "OVERLAY")
	self.hubShine:SetSize(12, 12)
	self.hubShine:SetVertexColor(1, 1, 1, 0.35)
	Place(self.hubShine, P.LAUNCH_X - 5, P.LAUNCH_Y - 5)
	self.beads = {}
	for i = 1, 3 do
		local bead = Circle(self.topLayer, "ARTWORK")
		bead:SetSize(16 - i * 2, 16 - i * 2)
		bead:SetVertexColor(0.6, 0.6, 0.7, 1)
		self.beads[i] = bead
	end
	self.waiting = Circle(self.topLayer, "ARTWORK", 1)
	self.waiting:SetSize(P.BALL_R * 2, P.BALL_R * 2)
	self.waiting:SetVertexColor(1, 1, 1, 1)

	-- Aim guide
	self.dots = {}
	for i = 1, GUIDE_DOTS do
		local dot = Circle(self.topLayer, "ARTWORK")
		dot:SetSize(5, 5)
		dot:Hide()
		self.dots[i] = dot
	end

	-- Bucket
	self.bucketBody = self.topLayer:CreateTexture(nil, "ARTWORK")
	self.bucketBody:SetTexture(WHITE)
	self.bucketBody:SetVertexColor(0.55, 0.58, 0.7, 1)
	self.bucketBody:SetSize(72, 14)
	self.bucketLip = self.topLayer:CreateTexture(nil, "OVERLAY")
	self.bucketLip:SetTexture(WHITE)
	self.bucketLip:SetVertexColor(0.85, 0.88, 1, 1)
	self.bucketLip:SetSize(72, 2)
	self.rims = {}
	for i = 1, 2 do
		local rim = Circle(self.topLayer, "OVERLAY")
		rim:SetSize(P.RIM_R * 2, P.RIM_R * 2)
		rim:SetVertexColor(0.9, 0.9, 1, 1)
		self.rims[i] = rim
	end

	-- Fever bins
	self.bins = {}
	local binW = W / 5
	for i = 1, 5 do
		local bin = CreateFrame("Frame", nil, self.topLayer)
		bin:SetSize(binW - 2, 24)
		bin:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (i - 1) * binW + 1, 1)
		bin.Fill = bin:CreateTexture(nil, "ARTWORK")
		bin.Fill:SetTexture(WHITE)
		bin.Fill:SetAllPoints()
		local c = BIN_COLORS[i]
		bin.Fill:SetVertexColor(c[1], c[2], c[3], 0.7)
		bin.Text = bin:CreateFontString(nil, "OVERLAY")
		bin.Text:SetFont(FONT, 11, "OUTLINE")
		bin.Text:SetPoint("CENTER")
		bin.Text:SetText(NS.Commas(NS.Game.FEVER_BINS[i]))
		bin.flash = 0
		bin:Hide()
		self.bins[i] = bin
	end

	-- Banner text
	self.bannerText = self.topLayer:CreateFontString(nil, "OVERLAY")
	self.bannerText:SetFont(FONT, 26, "OUTLINE")
	Place(self.bannerText, W / 2, H * 0.42)
	self.bannerText:Hide()

	f:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			Board:Fire()
		end
	end)
	f:SetScript("OnUpdate", function(_, elapsed)
		NS.Guard("board", Board.OnUpdate, Board, elapsed)
	end)
	return f
end

-------------------------------------------------------------------------------
-- Pegs
-------------------------------------------------------------------------------

function Board:AcquireVisual(peg)
	local v
	if peg.kind == "brick" then
		v = table.remove(self.brickPool)
		if not v then
			v = { kind = "brick" }
			v.glow = self.pegLayer:CreateTexture(nil, "BACKGROUND")
			v.glow:SetTexture(WHITE)
			v.body = self.pegLayer:CreateTexture(nil, "ARTWORK")
			v.body:SetTexture(WHITE)
			v.bevel = self.pegLayer:CreateTexture(nil, "OVERLAY")
			v.bevel:SetTexture(WHITE)
			v.bevel:SetVertexColor(1, 1, 1, 0.3)
		end
		v.baseW, v.baseH = peg.w, peg.h
		v.glow:SetSize(peg.w + 10, peg.h + 10)
		v.body:SetSize(peg.w, peg.h)
		v.bevel:SetSize(math.max(2, peg.w - 4), math.max(2, math.floor(peg.h / 3)))
		v.bevel:ClearAllPoints()
		v.bevel:SetPoint("TOP", v.body, "TOP", 0, -2)
	else
		v = table.remove(self.circlePool)
		if not v then
			v = { kind = "circle" }
			v.glow = Circle(self.pegLayer, "BACKGROUND")
			v.body = Circle(self.pegLayer, "ARTWORK")
			v.shine = Circle(self.pegLayer, "OVERLAY")
			v.shine:SetVertexColor(1, 1, 1, 0.4)
		end
		local d = P.PEG_R * 2
		v.baseW, v.baseH = d, d
		v.glow:SetSize(d + 12, d + 12)
		v.body:SetSize(d, d)
		v.shine:SetSize(d * 0.4, d * 0.4)
		v.shine:ClearAllPoints()
		v.shine:SetPoint("CENTER", v.body, "CENTER", -d * 0.18, d * 0.18)
	end
	v.glow:ClearAllPoints()
	Place(v.glow, peg.x, peg.y)
	v.body:ClearAllPoints()
	Place(v.body, peg.x, peg.y)
	v.glow:Show()
	v.body:Show()
	if v.shine then v.shine:Show() end
	if v.bevel then v.bevel:Show() end
	v.peg = peg
	v.released = false
	return v
end

function Board:ReleaseVisual(v)
	if v.released then
		return
	end
	v.released = true
	v.glow:Hide()
	v.body:Hide()
	if v.shine then v.shine:Hide() end
	if v.bevel then v.bevel:Hide() end
	v.body:SetAlpha(1)
	v.glow:SetAlpha(1)
	v.peg = nil
	if v.kind == "brick" then
		table.insert(self.brickPool, v)
	else
		table.insert(self.circlePool, v)
	end
end

function Board:RecolorPeg(peg)
	local v = peg.visual
	if not v then
		return
	end
	local c = COLORS[peg.color] or COLORS.blue
	if peg.lit then
		v.body:SetVertexColor(c[1] + (1 - c[1]) * 0.55, c[2] + (1 - c[2]) * 0.55, c[3] + (1 - c[3]) * 0.55, 1)
		v.glow:SetVertexColor(c[1], c[2], c[3], 0.55)
	else
		v.body:SetVertexColor(c[1], c[2], c[3], 1)
		local faint = (peg.color == "orange" or peg.color == "green" or peg.color == "purple") and 0.18 or 0
		v.glow:SetVertexColor(c[1], c[2], c[3], faint)
	end
end

function Board:LoadLevel(game)
	for _, v in ipairs(self.visuals) do
		self:ReleaseVisual(v)
	end
	self.visuals = {}
	for _, peg in ipairs(game.pegs) do
		local v = self:AcquireVisual(peg)
		peg.visual = v
		table.insert(self.visuals, v)
		self:RecolorPeg(peg)
	end
	for _, ball in ipairs(game.activeBalls) do
		self:RemoveBall(ball)
	end
	self.effects = {}
	for _, fs in ipairs(self.popups) do
		fs:Hide()
		table.insert(self.popupPool, fs)
	end
	self.popups = {}
	self.banners = {}
	self.bannerText:Hide()
	for _, bin in ipairs(self.bins) do
		bin:Hide()
	end
	self.bucketBody:Show()
	self.bucketLip:Show()
	for _, rim in ipairs(self.rims) do
		rim:Show()
	end
	self.flashT = 0
	self.flash:SetAlpha(0)
	self.lastAim = nil
	self:HideGuide()
end

function Board:LightPeg(peg, value)
	self:RecolorPeg(peg)
	if peg.visual then
		table.insert(self.effects, { v = peg.visual, kind = "pop", t = 0 })
	end
	if NS.GetSettings().popups and value and value > 0 then
		local c = COLORS[peg.color] or COLORS.blue
		self:Popup("+" .. NS.Commas(value), peg.x, peg.y - 10, c[1] + 0.3, c[2] + 0.3, c[3] + 0.3)
	end
	local now = GetTime()
	if now - (self.lastPegSound or 0) >= PEG_SOUND_GAP then
		self.lastPegSound = now
		if peg.color == "orange" then
			NS.PlayKit("IG_BACKPACK_COIN_OK")
		elseif peg.color == "purple" then
			NS.PlayKit("IG_BACKPACK_COIN_SELECT")
		else
			NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
		end
	end
end

function Board:RemovePeg(peg)
	local v = peg.visual
	if not v then
		return
	end
	peg.visual = nil
	-- Drop any pop effect still running on it.
	for i = #self.effects, 1, -1 do
		if self.effects[i].v == v then
			table.remove(self.effects, i)
		end
	end
	table.insert(self.effects, { v = v, kind = "vanish", t = 0 })
	local now = GetTime()
	if now - (self.lastClearSound or 0) >= 0.03 then
		self.lastClearSound = now
		NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_OFF")
	end
end

function Board:Blast(x, y, radius)
	local ring = self.blastRing
	if not ring then
		ring = Circle(self.topLayer, "ARTWORK")
		ring:SetVertexColor(0.6, 1, 0.6, 0.5)
		ring:SetBlendMode("ADD")
		self.blastRing = ring
	end
	ring:ClearAllPoints()
	Place(ring, x, y)
	ring:SetSize(10, 10)
	ring:Show()
	table.insert(self.effects, { kind = "blast", t = 0, radius = radius })
end

-------------------------------------------------------------------------------
-- Balls
-------------------------------------------------------------------------------

function Board:AddBall(ball)
	local v = table.remove(self.ballPool)
	if not v then
		v = CreateFrame("Frame", nil, self.ballLayer)
		v.glow = Circle(v, "BACKGROUND")
		v.glow:SetPoint("CENTER")
		v.glow:SetBlendMode("ADD")
		v.body = Circle(v, "ARTWORK")
		v.body:SetAllPoints()
		v.shine = Circle(v, "OVERLAY")
		v.shine:SetVertexColor(1, 1, 1, 0.6)
	end
	local d = P.BALL_R * 2
	v:SetSize(d, d)
	v.shine:SetSize(d * 0.4, d * 0.4)
	v.shine:ClearAllPoints()
	v.shine:SetPoint("CENTER", v, "CENTER", -d * 0.17, d * 0.17)
	if ball.fire then
		v.body:SetVertexColor(1, 0.45, 0.1, 1)
		v.glow:SetVertexColor(1, 0.4, 0.05, 0.6)
		v.glow:SetSize(d * 2.4, d * 2.4)
		v.glow:Show()
	else
		v.body:SetVertexColor(0.95, 0.95, 1, 1)
		v.glow:Hide()
	end
	v:ClearAllPoints()
	Place(v, ball.x, ball.y)
	v:Show()
	ball.visual = v
end

function Board:RemoveBall(ball)
	if ball.visual then
		ball.visual:Hide()
		table.insert(self.ballPool, ball.visual)
		ball.visual = nil
	end
end

-------------------------------------------------------------------------------
-- Aiming and the guide
-------------------------------------------------------------------------------

function Board:CursorOnBoard()
	local f = self.frame
	local scale = f:GetEffectiveScale()
	local left, top = f:GetLeft(), f:GetTop()
	if not left or not top then
		return nil
	end
	local cx, cy = GetCursorPosition()
	return cx / scale - left, top - cy / scale
end

function Board:HideGuide()
	for _, dot in ipairs(self.dots) do
		dot:Hide()
	end
	self.lastAim = nil
end

function Board:UpdateAim()
	local game = NS.Game
	local angle = self.aimAngle or 0
	if self.frame:IsMouseOver() then
		local x, y = self:CursorOnBoard()
		if x then
			local dx, dy = x - P.LAUNCH_X, y - P.LAUNCH_Y
			if dy < 20 then
				dy = 20
			end
			angle = NS.Clamp(math.atan2(dx, dy), -P.MAX_ANGLE, P.MAX_ANGLE)
			self.aimAngle = angle
		end
	end

	-- Launcher beads and the waiting ball along the aim.
	local dx, dy = P.Direction(angle)
	for i, bead in ipairs(self.beads) do
		local dist = 10 + i * 7
		bead:ClearAllPoints()
		Place(bead, P.LAUNCH_X + dx * dist, P.LAUNCH_Y + dy * dist)
	end
	self.waiting:ClearAllPoints()
	Place(self.waiting, P.LAUNCH_X + dx * P.MUZZLE, P.LAUNCH_Y + dy * P.MUZZLE)
	self.waiting:SetShown(game.state == "aim" and game.balls > 0)
	if game.nextFire then
		self.waiting:SetVertexColor(1, 0.45, 0.1, 1)
	else
		self.waiting:SetVertexColor(1, 1, 1, 1)
	end

	-- Guide dots, recomputed only when the aim moved.
	if game.state ~= "aim" or game.balls <= 0 then
		if self.lastAim then
			self:HideGuide()
		end
		return
	end
	local super = game.guideShots > 0
	local key = angle * 1000 + (super and 1 or 0)
	if self.lastAim == key then
		return
	end
	self.lastAim = key
	local maxTime = super and 2.2 or 0.7
	local points = P.Predict(P.LAUNCH_X + dx * P.MUZZLE, P.LAUNCH_Y + dy * P.MUZZLE, dx * P.LAUNCH_SPEED, dy * P.LAUNCH_SPEED, game.pegs, maxTime, super, 0.035)
	local n = math.min(#points, GUIDE_DOTS)
	for i, dot in ipairs(self.dots) do
		local pt = points[i]
		if i <= n and pt then
			dot:ClearAllPoints()
			Place(dot, pt.x, pt.y)
			local fade = 1 - (i - 1) / math.max(1, n) * 0.7
			if super then
				dot:SetVertexColor(1, 0.9, 0.4, fade)
			else
				dot:SetVertexColor(1, 1, 1, fade)
			end
			dot:Show()
		else
			dot:Hide()
		end
	end
end

function Board:Fire()
	local game = NS.Game
	if game.state == "won" or game.state == "lost" or game.state == "idle" then
		return
	end
	if game:Fire(self.aimAngle or 0) then
		self:HideGuide()
	end
end

-------------------------------------------------------------------------------
-- Effects, popups, banners, fever
-------------------------------------------------------------------------------

function Board:Popup(text, x, y, r, g, b)
	local fs = table.remove(self.popupPool)
	if not fs then
		fs = self.topLayer:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 11, "OUTLINE")
	end
	fs:SetText(text)
	fs:SetTextColor(math.min(1, r), math.min(1, g), math.min(1, b))
	fs.x, fs.y0, fs.t = x, y, 0
	fs:ClearAllPoints()
	Place(fs, x, y)
	fs:SetAlpha(1)
	fs:Show()
	table.insert(self.popups, fs)
end

-- Banners queue up and show one after the other.
function Board:Banner(text, r, g, b, duration)
	table.insert(self.banners, { text = text, r = r or 1, g = g or 1, b = b or 1, duration = duration or BANNER_TIME })
end

function Board:FeverStart()
	self.bucketBody:Hide()
	self.bucketLip:Hide()
	for _, rim in ipairs(self.rims) do
		rim:Hide()
	end
	for _, bin in ipairs(self.bins) do
		bin.flash = 0
		bin:Show()
	end
	self.flashT = 1
end

function Board:FeverEnd()
	-- Bins stay until the next level loads.
end

function Board:BinHit(zone)
	local bin = self.bins[zone]
	if bin then
		bin.flash = 1
	end
	self.flashT = 0.6
end

-------------------------------------------------------------------------------
-- Per frame
-------------------------------------------------------------------------------

function Board:OnUpdate(dt)
	if dt > 0.1 then
		dt = 0.1
	end
	local game = NS.Game
	game:Update(dt)
	self:UpdateAim()

	-- Balls
	for _, ball in ipairs(game.activeBalls) do
		if ball.visual then
			ball.visual:ClearAllPoints()
			Place(ball.visual, ball.x, ball.y)
			if ball.fire then
				local pulse = 0.5 + 0.2 * math.sin(GetTime() * 18)
				ball.visual.glow:SetAlpha(pulse)
			end
		end
	end

	-- Bucket
	local bucket = game.bucket
	if bucket and self.bucketBody:IsShown() then
		self.bucketBody:ClearAllPoints()
		Place(self.bucketBody, bucket.x, bucket.y + 7)
		self.bucketLip:ClearAllPoints()
		Place(self.bucketLip, bucket.x, bucket.y)
		self.rims[1]:ClearAllPoints()
		Place(self.rims[1], bucket.x - bucket.half, bucket.y)
		self.rims[2]:ClearAllPoints()
		Place(self.rims[2], bucket.x + bucket.half, bucket.y)
	end

	-- Peg effects
	for i = #self.effects, 1, -1 do
		local e = self.effects[i]
		e.t = e.t + dt
		if e.kind == "pop" then
			local p = e.t / POP_TIME
			if p >= 1 then
				e.v.body:SetSize(e.v.baseW, e.v.baseH)
				table.remove(self.effects, i)
			else
				local s = 1 + 0.4 * math.sin(math.pi * p)
				e.v.body:SetSize(e.v.baseW * s, e.v.baseH * s)
			end
		elseif e.kind == "vanish" then
			local p = e.t / VANISH_TIME
			if p >= 1 then
				e.v.body:SetSize(e.v.baseW, e.v.baseH)
				self:ReleaseVisual(e.v)
				table.remove(self.effects, i)
			else
				local s = 1 + 0.5 * p
				e.v.body:SetSize(e.v.baseW * s, e.v.baseH * s)
				e.v.body:SetAlpha(1 - p)
				e.v.glow:SetAlpha(1 - p)
			end
		elseif e.kind == "blast" then
			local p = e.t / 0.4
			if p >= 1 then
				self.blastRing:Hide()
				table.remove(self.effects, i)
			else
				local d = e.radius * 2 * p
				self.blastRing:SetSize(d, d)
				self.blastRing:SetAlpha(0.6 * (1 - p))
			end
		end
	end

	-- Popups
	for i = #self.popups, 1, -1 do
		local fs = self.popups[i]
		fs.t = fs.t + dt / POPUP_TIME
		if fs.t >= 1 then
			fs:Hide()
			table.remove(self.popups, i)
			table.insert(self.popupPool, fs)
		else
			fs:ClearAllPoints()
			Place(fs, fs.x, fs.y0 - 24 * fs.t)
			fs:SetAlpha(fs.t < 0.5 and 1 or (1 - (fs.t - 0.5) * 2))
		end
	end

	-- Banner
	local banner = self.banner
	if not banner and #self.banners > 0 then
		banner = table.remove(self.banners, 1)
		banner.t = 0
		self.banner = banner
		self.bannerText:SetText(banner.text)
		self.bannerText:SetTextColor(banner.r, banner.g, banner.b)
		self.bannerText:Show()
	end
	if banner then
		banner.t = banner.t + dt
		local p = banner.t / banner.duration
		if p >= 1 then
			self.bannerText:Hide()
			self.banner = nil
		else
			local alpha = 1
			if p < 0.1 then
				alpha = p / 0.1
			elseif p > 0.75 then
				alpha = (1 - p) / 0.25
			end
			self.bannerText:SetAlpha(alpha)
			self.bannerText:ClearAllPoints()
			Place(self.bannerText, W / 2, H * 0.42 - 10 * p)
		end
	end

	-- Bins
	for _, bin in ipairs(self.bins) do
		if bin:IsShown() and bin.flash > 0 then
			bin.flash = math.max(0, bin.flash - dt / 0.6)
			bin.Fill:SetAlpha(0.7 + 0.3 * bin.flash)
		end
	end

	-- Flash
	if self.flashT > 0 then
		self.flashT = math.max(0, self.flashT - dt / 0.8)
		self.flash:SetAlpha(0.4 * self.flashT)
	end
end
