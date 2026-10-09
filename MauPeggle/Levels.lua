-- MauPeggle levels: the peg layouts.
--
-- Twelve designed boards, then endless procedural ones.  A layout is a list
-- of pegs { kind = "circle", x, y } or { kind = "brick", x, y, w, h } on the
-- W x H board (Physics.lua).  Builders draw with lines, arcs, rings, rows and
-- scatter, and Finish() drops anything out of bounds or too close to an
-- earlier peg (a ball must fit between any two).  Layouts are deterministic:
-- the same level always looks the same; which pegs are orange, green and
-- purple is decided by Game.lua when the level starts.

local _, NS = ...

local Levels = {}
NS.Levels = Levels

local P = NS.Physics
local W = P.W
local R = P.PEG_R
local MIN_X, MAX_X = 20, 540
local MIN_Y, MAX_Y = 78, 352
local GAP = 2 * R + 6     -- minimum distance between two circle centres

-- Small deterministic generator (Park-Miller), so a level looks the same
-- every time without touching the game's math.random.
local function Rng(seed)
	local state = seed % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end
Levels.Rng = Rng

local function Overlaps(a, b)
	if a.kind == "circle" and b.kind == "circle" then
		local dx, dy = a.x - b.x, a.y - b.y
		return dx * dx + dy * dy < GAP * GAP
	end
	if a.kind == "brick" and b.kind == "brick" then
		return math.abs(a.x - b.x) < (a.w + b.w) / 2 + 6 and math.abs(a.y - b.y) < (a.h + b.h) / 2 + 6
	end
	local c, k = a, b
	if a.kind == "brick" then
		c, k = b, a
	end
	local cx = NS.Clamp(c.x, k.x - k.w / 2, k.x + k.w / 2)
	local cy = NS.Clamp(c.y, k.y - k.h / 2, k.y + k.h / 2)
	local dx, dy = c.x - cx, c.y - cy
	return dx * dx + dy * dy < GAP * GAP
end

-------------------------------------------------------------------------------
-- Builder
-------------------------------------------------------------------------------

local Builder = {}
Builder.__index = Builder

local function NewBuilder(rng)
	return setmetatable({ pegs = {}, rng = rng }, Builder)
end

function Builder:Circle(x, y)
	table.insert(self.pegs, { kind = "circle", x = x, y = y })
end

function Builder:Brick(x, y, w, h)
	table.insert(self.pegs, { kind = "brick", x = x, y = y, w = w, h = h })
end

function Builder:Line(x0, y0, x1, y1, spacing)
	local dx, dy = x1 - x0, y1 - y0
	local len = math.sqrt(dx * dx + dy * dy)
	local n = math.max(1, math.floor(len / spacing + 0.5))
	for i = 0, n do
		local t = i / n
		self:Circle(x0 + dx * t, y0 + dy * t)
	end
end

function Builder:Row(y, x0, x1, step)
	for x = x0, x1, step do
		self:Circle(x, y)
	end
end

-- Angles in degrees, 0 = right, 90 = down.
function Builder:Arc(cx, cy, r, a0, a1, spacing)
	local len = r * math.abs(a1 - a0) * math.pi / 180
	local n = math.max(1, math.floor(len / spacing + 0.5))
	for i = 0, n do
		local a = (a0 + (a1 - a0) * i / n) * math.pi / 180
		self:Circle(cx + r * math.cos(a), cy + r * math.sin(a))
	end
end

function Builder:Ring(cx, cy, r, count, offsetDeg)
	for i = 0, count - 1 do
		local a = ((offsetDeg or 0) + 360 * i / count) * math.pi / 180
		self:Circle(cx + r * math.cos(a), cy + r * math.sin(a))
	end
end

function Builder:Fits(peg)
	for _, other in ipairs(self.pegs) do
		if Overlaps(peg, other) then
			return false
		end
	end
	return true
end

function Builder:Scatter(count, bricks)
	local rng = self.rng
	local placed, tries = 0, 0
	while placed < bricks and tries < 2000 do
		tries = tries + 1
		local vertical = rng() < 0.5
		local peg = {
			kind = "brick",
			x = MIN_X + 30 + rng() * (MAX_X - MIN_X - 60),
			y = MIN_Y + 20 + rng() * (MAX_Y - MIN_Y - 40),
			w = vertical and 12 or 40,
			h = vertical and 40 or 12,
		}
		if self:Fits(peg) then
			table.insert(self.pegs, peg)
			placed = placed + 1
		end
	end
	placed, tries = 0, 0
	while placed < count and tries < 6000 do
		tries = tries + 1
		local peg = { kind = "circle", x = MIN_X + rng() * (MAX_X - MIN_X), y = MIN_Y + rng() * (MAX_Y - MIN_Y) }
		if self:Fits(peg) then
			table.insert(self.pegs, peg)
			placed = placed + 1
		end
	end
end

-- Keeps pegs in order of creation, dropping anything out of bounds or too
-- close to a kept one.
function Builder:Finish()
	local kept = {}
	for _, peg in ipairs(self.pegs) do
		local hw = (peg.w or 2 * R) / 2
		local hh = (peg.h or 2 * R) / 2
		if peg.x - hw >= 8 and peg.x + hw <= W - 8 and peg.y - hh >= MIN_Y - 8 and peg.y + hh <= MAX_Y + 8 then
			local ok = true
			for _, other in ipairs(kept) do
				if Overlaps(peg, other) then
					ok = false
					break
				end
			end
			if ok then
				table.insert(kept, peg)
			end
		end
	end
	return kept
end

-------------------------------------------------------------------------------
-- The designed boards
-------------------------------------------------------------------------------

local function Diamond(b, cx, cy, s, spacing)
	b:Line(cx, cy - s, cx + s, cy, spacing)
	b:Line(cx + s, cy, cx, cy + s, spacing)
	b:Line(cx, cy + s, cx - s, cy, spacing)
	b:Line(cx - s, cy, cx, cy - s, spacing)
end

local function Chevron(b, cx, ay)
	b:Line(cx, ay, cx - 56, ay - 48, 22)
	b:Line(cx, ay, cx + 56, ay - 48, 22)
end

local function Box(b, cx, cy)
	b:Brick(cx, cy - 46, 64, 12)
	b:Brick(cx, cy + 46, 64, 12)
	b:Brick(cx - 56, cy, 12, 48)
	b:Brick(cx + 56, cy, 12, 48)
	b:Circle(cx - 22, cy - 14)
	b:Circle(cx + 22, cy - 14)
	b:Circle(cx, cy + 14)
end

Levels.LIST = {
	{
		name = "Goldshire Grid", power = "guide",
		build = function(b, rng)
			for i = 0, 6 do
				local y = 96 + i * 42
				local offset = (i % 2) * 20
				for x = 60 + offset, 500, 40 do
					if rng() > 0.12 then
						b:Circle(x, y)
					end
				end
			end
		end,
	},
	{
		name = "Dun Morogh Diamonds", power = "multiball",
		build = function(b)
			for _, cx in ipairs({ 125, 280, 435 }) do
				Diamond(b, cx, 215, 78, 27)
				Diamond(b, cx, 215, 34, 30)
			end
			b:Row(88, 60, 500, 44)
			for _, x in ipairs({ 125, 280, 435 }) do
				b:Brick(x, 338, 60, 12)
			end
			b:Circle(202, 215)
			b:Circle(358, 215)
		end,
	},
	{
		name = "Barrens Rings", power = "fire",
		build = function(b)
			local cx, cy = 280, 222
			b:Circle(cx, cy)
			b:Ring(cx, cy, 40, 8, 0)
			b:Ring(cx, cy, 66, 12, 15)
			b:Ring(cx, cy, 92, 16, 0)
			b:Ring(cx, cy, 118, 20, 9)
			b:Arc(cx, cy, 146, -40, 40, 26)
			b:Arc(cx, cy, 146, 140, 220, 26)
			for _, p in ipairs({ { 60, 100 }, { 84, 100 }, { 72, 122 }, { 500, 100 }, { 476, 100 }, { 488, 122 },
				{ 60, 340 }, { 84, 340 }, { 72, 318 }, { 500, 340 }, { 476, 340 }, { 488, 318 } }) do
				b:Circle(p[1], p[2])
			end
		end,
	},
	{
		name = "Westfall Chevrons", power = "blast",
		build = function(b)
			for _, cx in ipairs({ 110, 280, 450 }) do
				Chevron(b, cx, 178)
				Chevron(b, cx, 348)
			end
			for _, cx in ipairs({ 195, 365 }) do
				Chevron(b, cx, 263)
			end
			for _, cx in ipairs({ 110, 280, 450 }) do
				b:Brick(cx, 92, 50, 12)
			end
			b:Circle(195, 120)
			b:Circle(365, 120)
			b:Circle(110, 230)
			b:Circle(280, 230)
			b:Circle(450, 230)
			b:Brick(40, 230, 12, 70)
			b:Brick(520, 230, 12, 70)
		end,
	},
	{
		name = "Stormwind Pillars", power = "spooky",
		build = function(b)
			for _, x in ipairs({ 95, 188, 280, 372, 465 }) do
				for y = 112, 312, 40 do
					b:Brick(x, y, 14, 26)
				end
			end
			for _, x in ipairs({ 48, 141, 234, 326, 418, 512 }) do
				for y = 132, 332, 40 do
					b:Circle(x, y)
				end
			end
			b:Row(84, 60, 500, 40)
		end,
	},
	{
		name = "Thunder Bluff Smile", power = "flower",
		build = function(b)
			b:Arc(280, 185, 150, 28, 152, 26)
			b:Arc(280, 185, 120, 40, 140, 26)
			b:Ring(205, 148, 26, 7, 0)
			b:Circle(205, 148)
			b:Ring(355, 148, 26, 7, 0)
			b:Circle(355, 148)
			b:Line(280, 165, 280, 220, 27)
			b:Brick(205, 92, 54, 12)
			b:Brick(355, 92, 54, 12)
			for _, p in ipairs({ { 110, 232 }, { 450, 232 }, { 92, 300 }, { 468, 300 }, { 140, 340 }, { 420, 340 } }) do
				b:Circle(p[1], p[2])
			end
			b:Row(80, 100, 460, 40)
			b:Line(55, 120, 55, 330, 42)
			b:Line(505, 120, 505, 330, 42)
		end,
	},
	{
		name = "Darkshore Waves", power = "guide",
		build = function(b)
			local bases = { 108, 182, 256, 330 }
			for w, base in ipairs(bases) do
				local phase = (w % 2 == 0) and math.pi or 0
				for x = 56, 504, 32 do
					b:Circle(x, base + 22 * math.sin((x - 56) / 36 + phase))
				end
			end
			b:Brick(36, 150, 12, 56)
			b:Brick(524, 150, 12, 56)
			b:Brick(36, 290, 12, 56)
			b:Brick(524, 290, 12, 56)
		end,
	},
	{
		name = "Maelstrom Spiral", power = "multiball",
		build = function(b)
			local cx, cy = 280, 226
			local theta, maxTheta = 0, 5 * math.pi
			while theta <= maxTheta do
				local r = 22 + 42 * theta / (2 * math.pi)
				b:Circle(cx + r * math.cos(theta), cy + r * math.sin(theta))
				theta = theta + 27 / r
			end
			b:Row(80, 60, 500, 40)
			b:Brick(60, 340, 56, 12)
			b:Brick(500, 340, 56, 12)
			b:Brick(36, 200, 12, 60)
			b:Brick(524, 200, 12, 60)
			b:Circle(60, 300)
			b:Circle(500, 300)
		end,
	},
	{
		name = "Un'Goro Honeycomb", power = "fire",
		build = function(b, rng)
			for j = 0, 7 do
				local y = 92 + j * 36
				for i = 0, 11 do
					local x = 60 + i * 40 + (j % 2) * 20
					local dx, dy = x - 280, y - 218
					if dx * dx + dy * dy > 58 * 58 and rng() > 0.1 then
						b:Circle(x, y)
					end
				end
			end
			b:Circle(280, 218)
		end,
	},
	{
		name = "Ironforge Fortress", power = "blast",
		build = function(b)
			Box(b, 125, 200)
			Box(b, 280, 262)
			Box(b, 435, 200)
			b:Row(88, 60, 500, 40)
			for _, x in ipairs({ 60, 180, 220, 260, 300, 340, 380, 500 }) do
				b:Circle(x, 128)
			end
			b:Circle(202, 150)
			b:Circle(358, 150)
			b:Circle(202, 330)
			b:Circle(358, 330)
			b:Circle(125, 300)
			b:Circle(435, 300)
			b:Line(36, 140, 36, 260, 40)
			b:Line(524, 140, 524, 260, 40)
			b:Row(345, 60, 500, 40)
		end,
	},
	{
		name = "Thousand Needles Stairs", power = "spooky",
		build = function(b)
			for k = 0, 3 do
				local x, y = 70 + k * 50, 332 - k * 50
				b:Brick(x, y, 38, 12)
				b:Circle(x, y - 26)
				local xr = 490 - k * 50
				b:Brick(xr, y, 38, 12)
				b:Circle(xr, y - 26)
			end
			b:Brick(280, 132, 50, 12)
			b:Circle(280, 106)
			b:Ring(280, 215, 40, 8, 0)
			for _, y in ipairs({ 250, 300, 345 }) do
				b:Row(y, 150, 410, 40)
			end
			b:Row(80, 60, 500, 44)
			b:Line(36, 120, 36, 300, 45)
			b:Line(524, 120, 524, 300, 45)
		end,
	},
	{
		name = "Deadmines Scatter", power = "flower",
		build = function(b)
			b:Scatter(78, 10)
		end,
	},
}

function Levels.Name(index)
	local def = Levels.LIST[index]
	if def then
		return def.name
	end
	return string.format("Uncharted %d", index - #Levels.LIST)
end

function Levels.DefaultPower(index)
	local def = Levels.LIST[index]
	if def then
		return def.power
	end
	return NS.POWERS[(index - 1) % #NS.POWERS + 1]
end

-- Returns { name, power, pegs } with fresh peg tables.
function Levels.Build(index)
	index = math.max(1, math.floor(index))
	local rng = Rng(index * 7919 + 17)
	local b = NewBuilder(rng)
	local def = Levels.LIST[index]
	if def then
		def.build(b, rng)
	else
		local extra = index - #Levels.LIST
		b:Scatter(76 + math.min(24, extra * 2), 10 + math.min(8, extra))
	end
	return { name = Levels.Name(index), power = Levels.DefaultPower(index), pegs = b:Finish() }
end
