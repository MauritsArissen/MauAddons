-- MauPeggle physics: the ball, the pegs, the walls and the bucket.
--
-- The board is W x H units (pixels at scale 1), origin top left, y down.
-- The simulation runs in fixed steps of DT seconds: gravity, a move, then
-- every overlap is resolved by pushing the ball out along the contact normal
-- and reflecting its velocity with some loss (PEG_BOUNCE / WALL_BOUNCE).
-- Steps are small enough (a ball at top speed moves under 4 units a step,
-- a peg plus ball is 14) that nothing tunnels.  Pegs are circles of radius
-- PEG_R or axis-aligned bricks (w x h).  Nothing in here knows about scores
-- or colours; Game.lua reacts to the onHit callback.

local _, NS = ...

local P = {}
NS.Physics = P

P.W, P.H = 560, 420
P.BALL_R = 6
P.PEG_R = 8
P.RIM_R = 5
P.GRAVITY = 640          -- units per second squared
P.LAUNCH_SPEED = 400
P.PEG_BOUNCE = 0.74
P.WALL_BOUNCE = 0.85
P.MAX_SPEED = 950
P.DT = 1 / 240
P.LAUNCH_X, P.LAUNCH_Y = P.W / 2, 18   -- the launcher pivot
P.MUZZLE = 40                          -- where the ball starts, along the aim
P.MAX_ANGLE = 1.45                     -- radians either side of straight down

function P.NewBall(x, y, vx, vy)
	return { x = x, y = y, vx = vx, vy = vy, travel = 0, spooky = 0, fire = false, slowTime = 0 }
end

-- Aim angle (0 = straight down, positive = right) to a unit direction.
function P.Direction(angle)
	angle = NS.Clamp(angle, -P.MAX_ANGLE, P.MAX_ANGLE)
	return math.sin(angle), math.cos(angle)
end

local function Bounce(ball, nx, ny, e)
	local vn = ball.vx * nx + ball.vy * ny
	if vn < 0 then
		ball.vx = ball.vx - (1 + e) * vn * nx
		ball.vy = ball.vy - (1 + e) * vn * ny
	end
end

-- Contact with a circle at (cx, cy) of radius rad.  When solid, the ball is
-- pushed out and bounced.  Returns true when they overlap.
local function CircleContact(ball, cx, cy, rad, e, solid)
	local dx, dy = ball.x - cx, ball.y - cy
	local rr = rad + P.BALL_R
	local d2 = dx * dx + dy * dy
	if d2 >= rr * rr then
		return false
	end
	if solid then
		local d = math.sqrt(d2)
		if d < 0.0001 then
			dx, dy, d = 0, -1, 1
		end
		local nx, ny = dx / d, dy / d
		ball.x = cx + nx * rr
		ball.y = cy + ny * rr
		Bounce(ball, nx, ny, e)
	end
	return true
end

-- Contact with an axis-aligned brick, grown by `margin`.
local function BrickContact(ball, peg, e, solid, margin)
	local hw, hh = peg.w / 2, peg.h / 2
	local cx = NS.Clamp(ball.x, peg.x - hw, peg.x + hw)
	local cy = NS.Clamp(ball.y, peg.y - hh, peg.y + hh)
	local dx, dy = ball.x - cx, ball.y - cy
	local r = P.BALL_R + margin
	local d2 = dx * dx + dy * dy
	if d2 >= r * r then
		return false
	end
	if solid then
		local nx, ny
		if d2 < 0.0001 then
			-- Centre inside the brick: leave through the nearest face.
			local left, right = ball.x - (peg.x - hw), (peg.x + hw) - ball.x
			local top, bottom = ball.y - (peg.y - hh), (peg.y + hh) - ball.y
			local m = math.min(left, right, top, bottom)
			if m == left then
				nx, ny = -1, 0
				ball.x = peg.x - hw - r
			elseif m == right then
				nx, ny = 1, 0
				ball.x = peg.x + hw + r
			elseif m == top then
				nx, ny = 0, -1
				ball.y = peg.y - hh - r
			else
				nx, ny = 0, 1
				ball.y = peg.y + hh + r
			end
		else
			local d = math.sqrt(d2)
			nx, ny = dx / d, dy / d
			ball.x = cx + nx * r
			ball.y = cy + ny * r
		end
		Bounce(ball, nx, ny, e)
	end
	return true
end

-- Is the ball within `margin` of the peg's surface?
function P.Touching(ball, peg, margin)
	if peg.kind == "brick" then
		return BrickContact(ball, peg, 0, false, margin)
	end
	return CircleContact(ball, peg.x, peg.y, P.PEG_R + margin, 0, false)
end

-- One fixed step.  world = { pegs = {...}, bucket = { x, y, half } or nil }.
-- onHit(peg, ball) is called for every step the ball touches a peg that is
-- not removed.  Returns nil, "out" (fell off the bottom) or "caught".
function P.Step(ball, world, onHit)
	local dt = P.DT
	ball.vy = ball.vy + P.GRAVITY * dt
	local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	if speed > P.MAX_SPEED then
		local k = P.MAX_SPEED / speed
		ball.vx, ball.vy = ball.vx * k, ball.vy * k
	end
	local ox, oy = ball.x, ball.y
	ball.x = ball.x + ball.vx * dt
	ball.y = ball.y + ball.vy * dt
	local mx, my = ball.x - ox, ball.y - oy
	ball.travel = ball.travel + math.sqrt(mx * mx + my * my)

	local r = P.BALL_R
	if ball.x < r then
		ball.x = r
		if ball.vx < 0 then
			ball.vx = -ball.vx * P.WALL_BOUNCE
		end
	elseif ball.x > P.W - r then
		ball.x = P.W - r
		if ball.vx > 0 then
			ball.vx = -ball.vx * P.WALL_BOUNCE
		end
	end
	if ball.y < r then
		ball.y = r
		if ball.vy < 0 then
			ball.vy = -ball.vy * P.WALL_BOUNCE
		end
	end

	local pegs = world.pegs
	local solid = not ball.fire
	local margin = ball.fire and 5 or 0
	for i = 1, #pegs do
		local peg = pegs[i]
		if not peg.removed then
			local touched
			if peg.kind == "brick" then
				touched = BrickContact(ball, peg, P.PEG_BOUNCE, solid, margin)
			else
				touched = CircleContact(ball, peg.x, peg.y, P.PEG_R + margin, P.PEG_BOUNCE, solid)
			end
			if touched and onHit then
				onHit(peg, ball)
			end
		end
	end

	local bucket = world.bucket
	if bucket then
		CircleContact(ball, bucket.x - bucket.half, bucket.y, P.RIM_R, P.WALL_BOUNCE, true)
		CircleContact(ball, bucket.x + bucket.half, bucket.y, P.RIM_R, P.WALL_BOUNCE, true)
		if ball.y > bucket.y + 4 and math.abs(ball.x - bucket.x) < bucket.half - P.RIM_R then
			return "caught"
		end
	end
	if ball.y - r > P.H then
		return "out"
	end
	return nil
end

-- Predicts a launch for the aim guide: points every `every` seconds, up to
-- maxTime, stopping at the first peg unless `through`.  No bucket, no side
-- effects.
function P.Predict(x, y, vx, vy, pegs, maxTime, through, every)
	local ball = P.NewBall(x, y, vx, vy)
	local world = { pegs = pegs }
	local points = {}
	local t, nextSample = 0, 0
	local hit = false
	local function onHit()
		hit = true
	end
	while t < maxTime do
		local result = P.Step(ball, world, onHit)
		t = t + P.DT
		if t >= nextSample then
			table.insert(points, { x = ball.x, y = ball.y })
			nextSample = nextSample + every
		end
		if result then
			break
		end
		if hit then
			if not through then
				table.insert(points, { x = ball.x, y = ball.y })
				break
			end
			hit = false
		end
	end
	return points
end
