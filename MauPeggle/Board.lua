-- MauPeggle board: everything you see inside the play field.
--
-- Pegs (shaded circles and bevelled bricks from pools), the balls with a
-- trail, the launcher (hub, three beads along the aim and the waiting ball),
-- the aim guide dots, the moving bucket, the fever bins, hit rings, score
-- popups, banners and the flash, on a rock texture with a vignette.  The
-- board frame takes the mouse: moving aims, a left click fires.  One
-- OnUpdate advances the game (Game:Update) and then draws.  Positions are
-- board units from the top left, converted with SetPoint("CENTER", frame,
-- "TOPLEFT", x, -y).
--
-- Every round thing is a white square behind a round alpha mask (the
-- MauGuildMap pin trick); a sphere look comes from stacking an outline, the
-- body, a darker inner disc offset down-right and a white highlight up-left.

local _, NS = ...

local Board = {}
NS.Board = Board

local P = NS.Physics
local W, H = P.W, P.H
Board.WIDTH, Board.HEIGHT = W, H

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ROCK = "Interface\\FrameGeneral\\UI-Background-Rock"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local COLORS = {
	blue = { 0.28, 0.58, 1.0 },
	orange = { 1.0, 0.56, 0.12 },
	green = { 0.38, 0.92, 0.38 },
	purple = { 0.8, 0.42, 1.0 },
}
local OUTLINE = { 0.04, 0.04, 0.09 }
local GUIDE_DOTS = 60
local POP_TIME, VANISH_TIME, RING_TIME, BLAST_TIME = 0.22, 0.2, 0.3, 0.4
local POPUP_TIME, BANNER_TIME = 0.9, 1.3
local PEG_SOUND_GAP = 0.04
local TRAIL = { { 0.8, 0.32 }, { 0.64, 0.22 }, { 0.48, 0.14 }, { 0.34, 0.07 } }   -- size factor, alpha
local HISTORY = 8
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

local function Rect(parent, layer, sublevel)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	tex:SetTexture(WHITE)
	return tex
end

local function Place(region, x, y)
	region:SetPoint("CENTER", Board.frame, "TOPLEFT", x, -y)
end

-- Anchor a region to another with an offset in board units (y down).
local function Attach(region, to, dx, dy)
	region:ClearAllPoints()
	region:SetPoint("CENTER", to, "CENTER", dx or 0, -(dy or 0))
end

local function Gradient(tex, orientation, a, b)
	if tex.SetGradient and CreateColor then
		pcall(tex.SetGradient, tex, orientation, CreateColor(a[1], a[2], a[3], a[4]), CreateColor(b[1], b[2], b[3], b[4]))
	end
end

-- Outline + body + shade + shine: a shaded ball of diameter d.
local function Sphere(parent, d, layer, sublevel)
	local s = {}
	s.outline = Circle(parent, layer or "ARTWORK", (sublevel or 0))
	s.outline:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
	s.body = Circle(parent, layer or "ARTWORK", (sublevel or 0) + 1)
	s.shade = Circle(parent, layer or "ARTWORK", (sublevel or 0) + 2)
	s.shade:SetVertexColor(0, 0, 0, 0.28)
	s.shine = Circle(parent, "OVERLAY")
	s.shine:SetVertexColor(1, 1, 1, 0.55)
	s.d = d
	s.outline:SetSize(d + 3, d + 3)
	s.body:SetSize(d, d)
	s.shade:SetSize(d * 0.74, d * 0.74)
	s.shine:SetSize(d * 0.38, d * 0.38)
	Attach(s.outline, s.body, 0, 0)
	Attach(s.shade, s.body, d * 0.1, d * 0.1)
	Attach(s.shine, s.body, -d * 0.2, -d * 0.2)
	return s
end

local function SphereScale(s, k)
	local d = s.d * k
	s.outline:SetSize(d + 3, d + 3)
	s.body:SetSize(d, d)
	s.shade:SetSize(d * 0.74, d * 0.74)
	s.shine:SetSize(d * 0.38, d * 0.38)
	Attach(s.shade, s.body, d * 0.1, d * 0.1)
	Attach(s.shine, s.body, -d * 0.2, -d * 0.2)
end

local function SphereShown(s, shown)
	s.outline:SetShown(shown)
	s.body:SetShown(shown)
	s.shade:SetShown(shown)
	s.shine:SetShown(shown)
end

local function SphereAlpha(s, a)
	s.outline:SetAlpha(a)
	s.body:SetAlpha(a)
	s.shade:SetAlpha(a)
	s.shine:SetAlpha(a)
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
	f:SetBackdrop({ bgFile = ROCK, edgeFile = WHITE, tile = true, tileSize = 128, edgeSize = 1 })
	f:SetBackdropColor(0.4, 0.42, 0.55, 1)
	f:SetBackdropBorderColor(0.5, 0.5, 0.64, 1)
	f:EnableMouse(true)
	self.frame = f

	local level = f:GetFrameLevel()
	local function Layer(offset)
		local layer = CreateFrame("Frame", nil, f)
		layer:SetAllPoints()
		layer:SetFrameLevel(level + offset)
		return layer
	end
	self.bgLayer = Layer(1)
	self.pegLayer = Layer(2)
	self.ballLayer = Layer(4)
	self.topLayer = Layer(5)

	-- Vignette: darker towards the edges, darkest at the bottom.
	local function Vignette(orientation, w, h, point, a, b)
		local tex = Rect(self.bgLayer, "BACKGROUND")
		tex:SetSize(w, h)
		tex:SetPoint(point, f, point, 0, 0)
		tex:SetVertexColor(0, 0, 0, 1)
		Gradient(tex, orientation, a, b)
		return tex
	end
	self.vignetteTop = Vignette("VERTICAL", W, 100, "TOP", { 0, 0, 0, 0 }, { 0, 0, 0, 0.5 })
	self.vignetteBottom = Vignette("VERTICAL", W, 130, "BOTTOM", { 0, 0, 0, 0.65 }, { 0, 0, 0, 0 })
	self.vignetteLeft = Vignette("HORIZONTAL", 70, H, "LEFT", { 0, 0, 0, 0.45 }, { 0, 0, 0, 0 })
	self.vignetteRight = Vignette("HORIZONTAL", 70, H, "RIGHT", { 0, 0, 0, 0 }, { 0, 0, 0, 0.45 })

	self.flash = Rect(self.topLayer, "BACKGROUND")
	self.flash:SetAllPoints()
	self.flash:SetBlendMode("ADD")
	self.flash:SetVertexColor(1, 0.7, 0.3)
	self.flash:SetAlpha(0)
	self.flashT = 0

	self.circlePool, self.brickPool, self.ballPool, self.ringPool = {}, {}, {}, {}
	self.effects, self.popups, self.popupPool = {}, {}, {}
	self.banners = {}
	self.visuals = {}

	-- Launcher
	self.hub = Sphere(self.topLayer, 32, "ARTWORK", 0)
	self.hub.body:SetVertexColor(0.5, 0.53, 0.66, 1)
	Place(self.hub.body, P.LAUNCH_X, P.LAUNCH_Y)
	self.beads = {}
	for i = 1, 3 do
		local bead = Sphere(self.topLayer, 16 - i * 2, "ARTWORK", 0)
		bead.body:SetVertexColor(0.62, 0.65, 0.78, 1)
		self.beads[i] = bead
	end
	self.waiting = Sphere(self.topLayer, P.BALL_R * 2, "ARTWORK", 4)
	self.waiting.body:SetVertexColor(0.95, 0.95, 1, 1)

	-- Aim guide
	self.dots = {}
	for i = 1, GUIDE_DOTS do
		local dot = Circle(self.topLayer, "ARTWORK")
		dot:SetSize(5, 5)
		dot:Hide()
		self.dots[i] = dot
	end

	-- Bucket
	self.bucketOutline = Rect(self.topLayer, "ARTWORK", 0)
	self.bucketOutline:SetSize(76, 18)
	self.bucketOutline:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
	self.bucketBody = Rect(self.topLayer, "ARTWORK", 1)
	self.bucketBody:SetSize(72, 14)
	self.bucketBody:SetVertexColor(0.5, 0.56, 0.74, 1)
	self.bucketShade = Rect(self.topLayer, "ARTWORK", 2)
	self.bucketShade:SetSize(72, 5)
	self.bucketShade:SetVertexColor(0, 0, 0, 0.3)
	self.bucketLip = Rect(self.topLayer, "OVERLAY")
	self.bucketLip:SetSize(72, 2)
	self.bucketLip:SetVertexColor(0.9, 0.93, 1, 1)
	self.rims = {}
	for i = 1, 2 do
		local rim = Sphere(self.topLayer, P.RIM_R * 2, "OVERLAY", 0)
		rim.body:SetVertexColor(0.85, 0.88, 1, 1)
		self.rims[i] = rim
	end

	-- Fever bins
	self.bins = {}
	local binW = W / 5
	for i = 1, 5 do
		local bin = CreateFrame("Frame", nil, self.topLayer)
		bin:SetSize(binW - 2, 24)
		bin:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (i - 1) * binW + 1, 1)
		bin.Outline = Rect(bin, "BACKGROUND")
		bin.Outline:SetPoint("TOPLEFT", -1, 1)
		bin.Outline:SetPoint("BOTTOMRIGHT", 1, -1)
		bin.Outline:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
		bin.Fill = Rect(bin, "ARTWORK")
		bin.Fill:SetAllPoints()
		local c = BIN_COLORS[i]
		bin.Fill:SetVertexColor(c[1], c[2], c[3], 0.75)
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
			v.glow = Rect(self.pegLayer, "BACKGROUND", 0)
			v.glow:SetBlendMode("ADD")
			v.outline = Rect(self.pegLayer, "BACKGROUND", 1)
			v.outline:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
			v.body = Rect(self.pegLayer, "ARTWORK", 0)
			v.shade = Rect(self.pegLayer, "ARTWORK", 1)
			v.shade:SetVertexColor(0, 0, 0, 0.25)
			v.bevel = Rect(self.pegLayer, "OVERLAY")
			v.bevel:SetVertexColor(1, 1, 1, 0.35)
		end
		v.baseW, v.baseH = peg.w, peg.h
		v.glow:SetSize(peg.w + 14, peg.h + 14)
		v.outline:SetSize(peg.w + 3, peg.h + 3)
		v.body:SetSize(peg.w, peg.h)
		v.shade:SetSize(math.max(2, peg.w - 2), math.max(2, math.floor(peg.h * 0.35)))
		v.bevel:SetSize(math.max(2, peg.w - 4), math.max(2, math.floor(peg.h * 0.3)))
		v.body:ClearAllPoints()
		Place(v.body, peg.x, peg.y)
		Attach(v.glow, v.body)
		Attach(v.outline, v.body)
		v.shade:ClearAllPoints()
		v.shade:SetPoint("BOTTOM", v.body, "BOTTOM", 0, 1)
		v.bevel:ClearAllPoints()
		v.bevel:SetPoint("TOP", v.body, "TOP", 0, -2)
		for _, tex in ipairs({ v.glow, v.outline, v.body, v.shade, v.bevel }) do
			tex:SetAlpha(1)
			tex:Show()
		end
	else
		v = table.remove(self.circlePool)
		if not v then
			v = { kind = "circle" }
			v.glow = Circle(self.pegLayer, "BACKGROUND", 0)
			v.glow:SetBlendMode("ADD")
			v.sphere = Sphere(self.pegLayer, P.PEG_R * 2, "ARTWORK", 0)
			v.body = v.sphere.body
		end
		local d = P.PEG_R * 2
		v.baseW, v.baseH = d, d
		v.glow:SetSize(d + 14, d + 14)
		v.body:ClearAllPoints()
		Place(v.body, peg.x, peg.y)
		Attach(v.glow, v.body)
		SphereScale(v.sphere, 1)
		SphereAlpha(v.sphere, 1)
		SphereShown(v.sphere, true)
		v.glow:SetAlpha(1)
		v.glow:Show()
	end
	v.peg = peg
	v.released = false
	v.phase = math.random() * 6.28
	return v
end

function Board:ReleaseVisual(v)
	if v.released then
		return
	end
	v.released = true
	v.glow:Hide()
	if v.kind == "brick" then
		v.outline:Hide()
		v.body:Hide()
		v.shade:Hide()
		v.bevel:Hide()
		table.insert(self.brickPool, v)
	else
		SphereShown(v.sphere, false)
		table.insert(self.circlePool, v)
	end
	v.peg = nil
end

local function SetVisualScale(v, k)
	if v.kind == "brick" then
		v.body:SetSize(v.baseW * k, v.baseH * k)
		v.outline:SetSize(v.baseW * k + 3, v.baseH * k + 3)
	else
		SphereScale(v.sphere, k)
	end
end

local function SetVisualAlpha(v, a)
	v.glow:SetAlpha(a)
	if v.kind == "brick" then
		v.outline:SetAlpha(a)
		v.body:SetAlpha(a)
		v.shade:SetAlpha(a)
		v.bevel:SetAlpha(a)
	else
		SphereAlpha(v.sphere, a)
	end
end

function Board:RecolorPeg(peg)
	local v = peg.visual
	if not v then
		return
	end
	local c = COLORS[peg.color] or COLORS.blue
	if peg.lit then
		v.body:SetVertexColor(c[1] + (1 - c[1]) * 0.5, c[2] + (1 - c[2]) * 0.5, c[3] + (1 - c[3]) * 0.5, 1)
		v.glow:SetVertexColor(c[1], c[2], c[3], 0.6)
	else
		v.body:SetVertexColor(c[1], c[2], c[3], 1)
		local faint = (peg.color == "green" or peg.color == "purple") and 0.22 or (peg.color == "orange" and 0.18 or 0)
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
	for _, e in ipairs(self.effects) do
		if e.kind == "ring" then
			e.tex:Hide()
			table.insert(self.ringPool, e.tex)
		end
	end
	self.effects = {}
	if self.blastRing then
		self.blastRing:Hide()
	end
	for _, fs in ipairs(self.popups) do
		fs:Hide()
		table.insert(self.popupPool, fs)
	end
	self.popups = {}
	self.banners = {}
	self.banner = nil
	self.bannerText:Hide()
	for _, bin in ipairs(self.bins) do
		bin:Hide()
	end
	self:SetBucketShown(true)
	self.flashT = 0
	self.flash:SetAlpha(0)
	self:HideGuide()
end

function Board:SetBucketShown(shown)
	self.bucketOutline:SetShown(shown)
	self.bucketBody:SetShown(shown)
	self.bucketShade:SetShown(shown)
	self.bucketLip:SetShown(shown)
	for _, rim in ipairs(self.rims) do
		SphereShown(rim, shown)
	end
end

function Board:Ring(x, y, r, g, b, size)
	local tex = table.remove(self.ringPool)
	if not tex then
		tex = Circle(self.topLayer, "ARTWORK", 2)
		tex:SetBlendMode("ADD")
	end
	tex:SetVertexColor(r, g, b, 0.7)
	tex:SetSize(size, size)
	tex:ClearAllPoints()
	Place(tex, x, y)
	tex:Show()
	table.insert(self.effects, { kind = "ring", tex = tex, t = 0, size = size })
end

function Board:LightPeg(peg, value)
	self:RecolorPeg(peg)
	local c = COLORS[peg.color] or COLORS.blue
	if peg.visual then
		table.insert(self.effects, { v = peg.visual, kind = "pop", t = 0 })
	end
	self:Ring(peg.x, peg.y, c[1] + 0.3, c[2] + 0.3, c[3] + 0.3, (peg.kind == "brick") and math.max(peg.w, peg.h) or P.PEG_R * 2)
	if NS.GetSettings().popups and value and value > 0 then
		self:Popup("+" .. NS.Commas(value), peg.x, peg.y - 10, c[1] + 0.3, c[2] + 0.3, c[3] + 0.3, value >= 1000 and 13 or 11)
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
		ring = Circle(self.topLayer, "ARTWORK", 3)
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
		v.sphere = Sphere(v, P.BALL_R * 2, "ARTWORK", 0)
		v.sphere.body:SetAllPoints(v)
		v.trail = {}
		for i = 1, #TRAIL do
			local ghost = Circle(self.ballLayer, "BACKGROUND")
			ghost:Hide()
			v.trail[i] = ghost
		end
	end
	local d = P.BALL_R * 2
	v:SetSize(d, d)
	SphereScale(v.sphere, 1)
	SphereShown(v.sphere, true)
	local r, g, b = 0.95, 0.95, 1
	if ball.fire then
		r, g, b = 1, 0.45, 0.1
		v.glow:SetVertexColor(1, 0.4, 0.05, 0.6)
		v.glow:SetSize(d * 2.4, d * 2.4)
		v.glow:Show()
	else
		v.glow:Hide()
	end
	v.sphere.body:SetVertexColor(r, g, b, 1)
	for i, ghost in ipairs(v.trail) do
		ghost:SetSize(d * TRAIL[i][1], d * TRAIL[i][1])
		ghost:SetVertexColor(r, g, b, TRAIL[i][2])
		ghost:Hide()
	end
	v.hist = {}
	v:ClearAllPoints()
	Place(v, ball.x, ball.y)
	v:Show()
	ball.visual = v
end

function Board:RemoveBall(ball)
	local v = ball.visual
	if v then
		v:Hide()
		for _, ghost in ipairs(v.trail) do
			ghost:Hide()
		end
		table.insert(self.ballPool, v)
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

	local dx, dy = P.Direction(angle)
	for i, bead in ipairs(self.beads) do
		local dist = 10 + i * 7
		bead.body:ClearAllPoints()
		Place(bead.body, P.LAUNCH_X + dx * dist, P.LAUNCH_Y + dy * dist)
	end
	self.waiting.body:ClearAllPoints()
	Place(self.waiting.body, P.LAUNCH_X + dx * P.MUZZLE, P.LAUNCH_Y + dy * P.MUZZLE)
	SphereShown(self.waiting, game.state == "aim" and game.balls > 0)
	if game.nextFire then
		self.waiting.body:SetVertexColor(1, 0.45, 0.1, 1)
	else
		self.waiting.body:SetVertexColor(0.95, 0.95, 1, 1)
	end

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

function Board:Popup(text, x, y, r, g, b, size)
	local fs = table.remove(self.popupPool)
	if not fs then
		fs = self.topLayer:CreateFontString(nil, "OVERLAY")
	end
	fs:SetFont(FONT, size or 11, "OUTLINE")
	fs:SetText(text)
	fs:SetTextColor(math.min(1, r), math.min(1, g), math.min(1, b))
	fs.x, fs.y0, fs.t = x, y, 0
	fs:ClearAllPoints()
	Place(fs, x, y)
	fs:SetAlpha(1)
	fs:Show()
	table.insert(self.popups, fs)
end

function Board:Banner(text, r, g, b, duration)
	table.insert(self.banners, { text = text, r = r or 1, g = g or 1, b = b or 1, duration = duration or BANNER_TIME })
end

function Board:FeverStart()
	self:SetBucketShown(false)
	for _, bin in ipairs(self.bins) do
		bin.flash = 0
		bin:Show()
	end
	self.flashT = 1
end

function Board:FeverEnd()
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
	local now = GetTime()

	-- Balls and their trails
	for _, ball in ipairs(game.activeBalls) do
		local v = ball.visual
		if v then
			v:ClearAllPoints()
			Place(v, ball.x, ball.y)
			table.insert(v.hist, 1, { ball.x, ball.y })
			if #v.hist > HISTORY then
				table.remove(v.hist)
			end
			for i, ghost in ipairs(v.trail) do
				local pt = v.hist[i * 2]
				if pt then
					ghost:ClearAllPoints()
					Place(ghost, pt[1], pt[2])
					ghost:Show()
				else
					ghost:Hide()
				end
			end
			if ball.fire then
				v.glow:SetAlpha(0.5 + 0.2 * math.sin(now * 18))
			end
		end
	end

	-- Bucket
	local bucket = game.bucket
	if bucket and self.bucketBody:IsShown() then
		self.bucketOutline:ClearAllPoints()
		Place(self.bucketOutline, bucket.x, bucket.y + 7)
		self.bucketBody:ClearAllPoints()
		Place(self.bucketBody, bucket.x, bucket.y + 7)
		self.bucketShade:ClearAllPoints()
		Place(self.bucketShade, bucket.x, bucket.y + 11.5)
		self.bucketLip:ClearAllPoints()
		Place(self.bucketLip, bucket.x, bucket.y)
		self.rims[1].body:ClearAllPoints()
		Place(self.rims[1].body, bucket.x - bucket.half, bucket.y)
		self.rims[2].body:ClearAllPoints()
		Place(self.rims[2].body, bucket.x + bucket.half, bucket.y)
	end

	-- Orange pegs breathe so the objective stands out.
	for _, v in ipairs(self.visuals) do
		local peg = v.peg
		if peg and peg.color == "orange" and not peg.lit then
			local c = COLORS.orange
			v.glow:SetVertexColor(c[1], c[2], c[3], 0.18 + 0.1 * math.sin(now * 3 + v.phase))
		end
	end

	-- Effects
	for i = #self.effects, 1, -1 do
		local e = self.effects[i]
		e.t = e.t + dt
		if e.kind == "pop" then
			local p = e.t / POP_TIME
			if p >= 1 then
				SetVisualScale(e.v, 1)
				table.remove(self.effects, i)
			else
				SetVisualScale(e.v, 1 + 0.4 * math.sin(math.pi * p))
			end
		elseif e.kind == "vanish" then
			local p = e.t / VANISH_TIME
			if p >= 1 then
				SetVisualScale(e.v, 1)
				SetVisualAlpha(e.v, 1)
				self:ReleaseVisual(e.v)
				table.remove(self.effects, i)
			else
				SetVisualScale(e.v, 1 + 0.5 * p)
				SetVisualAlpha(e.v, 1 - p)
			end
		elseif e.kind == "ring" then
			local p = e.t / RING_TIME
			if p >= 1 then
				e.tex:Hide()
				table.insert(self.ringPool, e.tex)
				table.remove(self.effects, i)
			else
				local size = e.size * (1 + 2 * p)
				e.tex:SetSize(size, size)
				e.tex:SetAlpha(0.7 * (1 - p))
			end
		elseif e.kind == "blast" then
			local p = e.t / BLAST_TIME
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
			bin.Fill:SetAlpha(0.75 + 0.25 * bin.flash)
		end
	end

	-- Flash
	if self.flashT > 0 then
		self.flashT = math.max(0, self.flashT - dt / 0.8)
		self.flash:SetAlpha(0.4 * self.flashT)
	end
end
