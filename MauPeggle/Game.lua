-- MauPeggle rules: levels, shots, scoring, powers, fever, progress.
--
-- States: idle (no level), aim (waiting for a shot), shot (balls in play),
-- clear (lit pegs are being removed one by one), fever (last orange peg hit,
-- balls still falling), won, lost.  Board.lua drives Update(dt) from its
-- OnUpdate and draws what happens; nothing here touches a texture.
--
-- Scoring follows the original: blue 10 (more once a shot has hit many
-- pegs), orange 100, green 10, purple 500, all times the multiplier that
-- grows as orange pegs go (x2 at 10 cleared of 25, x3 at 15, x5 at 19, x10
-- at 22).  25,000 points in one shot gives a free ball (then 75,000 and
-- 125,000), so does catching the ball in the bucket.  A long flight between
-- two pegs is a Long Shot (+25,000).  The last orange starts the fever: the
-- bucket goes, five bonus bins appear (10k 50k 100k 50k 10k), each ball still
-- on the launcher pays 10,000 at the end.

local _, NS = ...

local Game = {}
NS.Game = Game

local P

Game.BALLS_PER_LEVEL = 10
Game.ORANGE_COUNT = 25
Game.FREE_BALL_SCORES = { 25000, 75000, 125000 }
Game.LONG_SHOT_DISTANCE = 320
Game.LONG_SHOT_BONUS = 25000
Game.BALL_BONUS = 10000
Game.FEVER_BINS = { 10000, 50000, 100000, 50000, 10000 }
Game.CLEAR_INTERVAL = 0.05
Game.STUCK_TIME = 1.6
Game.FEVER_SLOWMO = 1.3
Game.BLAST_RADIUS = 95

local COLOR_VALUE = { blue = 10, orange = 100, green = 10, purple = 500 }

local function BlueValue(pegsHitThisShot)
	if pegsHitThisShot <= 10 then
		return 10
	elseif pegsHitThisShot <= 15 then
		return 20
	elseif pegsHitThisShot <= 20 then
		return 30
	elseif pegsHitThisShot <= 25 then
		return 50
	end
	return 100
end

function Game:Start()
	P = NS.Physics
	self.state = "idle"
	self.activeBalls = {}
	self.hitHandler = function(peg, ball)
		Game:OnPegHit(peg, ball)
	end
end

function Game:Progress()
	return MauPeggleDB.progress
end

function Game:Stats()
	return MauPeggleDB.stats
end

-------------------------------------------------------------------------------
-- Levels
-------------------------------------------------------------------------------

function Game:StartLevel(index)
	index = math.max(1, math.floor(index or 1))
	for _, ball in ipairs(self.activeBalls or {}) do
		NS.Board:RemoveBall(ball)
	end
	local level = NS.Levels.Build(index)
	self.level = index
	self.levelName = level.name
	self.pegs = level.pegs
	self.world = { pegs = self.pegs }

	-- Colours: oranges and greens at random, the rest blue, purple later.
	local n = #self.pegs
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	for i = n, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local orangeCount = math.min(self.ORANGE_COUNT, math.floor(n * 0.4))
	local greenCount = math.max(0, math.min(2, n - orangeCount - 2))
	for i = 1, n do
		local peg = self.pegs[order[i]]
		peg.lit, peg.removed = false, false
		if i <= orangeCount then
			peg.color = "orange"
		elseif i <= orangeCount + greenCount then
			peg.color = "green"
		else
			peg.color = "blue"
		end
	end
	self.orangeTotal, self.oranges = orangeCount, orangeCount
	self.lastMult = 1

	self.balls = self.BALLS_PER_LEVEL
	self.score, self.feverBonus, self.ballBonus, self.levelTotal = 0, 0, 0, 0
	self.shotScore, self.pegsHit, self.freeBallsGiven, self.longShot = 0, 0, 0, false
	self.guideShots, self.nextFire = 0, false
	self.activeBalls = {}
	self.litOrder = {}
	self.bucket = { x = P.W / 2, y = P.H - 12, half = 36, t = 0 }
	self.world.bucket = self.bucket
	self.slowmo, self.acc = 0, 0
	self.power = level.power
	self.state = "aim"
	self:Progress().last = index

	NS.Board:LoadLevel(self)
	self.purple = nil
	self:MovePurple()
	NS.UI:RefreshAll()
	NS.Board:Banner(string.format("Level %d: %s", index, level.name), 1, 0.85, 0.3, 1.8)
end

function Game:Restart()
	if self.level then
		self:StartLevel(self.level)
	end
end

function Game:NextLevel()
	self:StartLevel((self.level or 0) + 1)
end

function Game:IsUnlocked(index)
	return index <= self:Progress().unlocked
end

function Game:SetPower(key)
	if NS.POWER_INFO[key] then
		self.power = key
		NS.UI:RefreshAll()
	end
end

-- The purple peg moves to a random unlit blue peg every shot.
function Game:MovePurple()
	if self.purple and not self.purple.removed and self.purple.color == "purple" then
		self.purple.color = "blue"
		NS.Board:RecolorPeg(self.purple)
	end
	self.purple = nil
	local candidates = {}
	for _, peg in ipairs(self.pegs) do
		if not peg.removed and not peg.lit and peg.color == "blue" then
			table.insert(candidates, peg)
		end
	end
	if #candidates > 0 then
		local peg = candidates[math.random(#candidates)]
		peg.color = "purple"
		self.purple = peg
		NS.Board:RecolorPeg(peg)
	end
end

-------------------------------------------------------------------------------
-- Shooting
-------------------------------------------------------------------------------

function Game:CanFire()
	return self.state == "aim" and self.balls > 0
end

function Game:Fire(angle)
	if not self:CanFire() then
		return false
	end
	local dx, dy = P.Direction(angle)
	local ball = P.NewBall(P.LAUNCH_X + dx * P.MUZZLE, P.LAUNCH_Y + dy * P.MUZZLE, dx * P.LAUNCH_SPEED, dy * P.LAUNCH_SPEED)
	if self.nextFire then
		ball.fire = true
		self.nextFire = false
	end
	self.balls = self.balls - 1
	if self.guideShots > 0 then
		self.guideShots = self.guideShots - 1
	end
	self.shotScore, self.pegsHit, self.freeBallsGiven, self.longShot = 0, 0, 0, false
	self.litOrder = {}
	self.acc = 0
	table.insert(self.activeBalls, ball)
	NS.Board:AddBall(ball)
	self.state = "shot"
	self:Stats().shots = self:Stats().shots + 1
	NS.PlayKit("IG_CHARACTER_INFO_TAB")
	NS.UI:RefreshAll()
	return true
end

function Game:Multiplier()
	local total = self.orangeTotal or 25
	if total <= 0 then
		return 1
	end
	local cleared = total - self.oranges
	local f = cleared / total
	if f >= 22 / 25 then
		return 10
	elseif f >= 19 / 25 then
		return 5
	elseif f >= 15 / 25 then
		return 3
	elseif f >= 10 / 25 then
		return 2
	end
	return 1
end

function Game:AddScore(value)
	self.shotScore = self.shotScore + value
	self.score = self.score + value
	local thresholds = self.FREE_BALL_SCORES
	while self.freeBallsGiven < #thresholds and self.shotScore >= thresholds[self.freeBallsGiven + 1] do
		self.freeBallsGiven = self.freeBallsGiven + 1
		self:FreeBall(string.format("Free ball! %s points", NS.Commas(thresholds[self.freeBallsGiven])))
	end
end

function Game:FreeBall(text)
	self.balls = self.balls + 1
	self:Stats().freeBalls = self:Stats().freeBalls + 1
	NS.Board:Banner(text, 0.4, 1, 0.5, 1.4)
	NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
	NS.UI:RefreshAll()
end

-- Every physics step the ball touches a peg.
function Game:OnPegHit(peg, ball)
	if peg.lit or peg.removed then
		return
	end
	if self.pegsHit > 0 and ball.travel >= self.LONG_SHOT_DISTANCE and not self.longShot then
		self.longShot = true
		self:AddScore(self.LONG_SHOT_BONUS)
		NS.Board:Banner("Long shot! +" .. NS.Commas(self.LONG_SHOT_BONUS), 0.6, 0.9, 1, 1.4)
		NS.PlayKit("UI_AUTO_QUEST_COMPLETE")
	end
	ball.travel = 0
	self:Light(peg, ball)
end

-- Lights a peg and scores it; powers and the fever start here too.
function Game:Light(peg, ball)
	if peg.lit or peg.removed then
		return
	end
	peg.lit = true
	self.pegsHit = self.pegsHit + 1
	table.insert(self.litOrder, peg)
	local base = COLOR_VALUE[peg.color] or 10
	if peg.color == "blue" then
		base = BlueValue(self.pegsHit)
	end
	local value = base * self:Multiplier()
	self:AddScore(value)
	self:Stats().pegs = self:Stats().pegs + 1
	NS.Board:LightPeg(peg, value)

	if peg.color == "orange" then
		self.oranges = self.oranges - 1
		local mult = self:Multiplier()
		if mult ~= self.lastMult then
			self.lastMult = mult
			NS.Board:Banner(string.format("x%d multiplier", mult), 1, 0.75, 0.2, 1.2)
		end
		if self.oranges <= 0 and self.state ~= "fever" then
			self:StartFever()
		end
	elseif peg.color == "green" then
		self:ActivatePower(peg, ball)
	end
	NS.UI:RefreshStatus()
end

function Game:ActivatePower(peg, ball)
	local power = self.power
	local info = NS.POWER_INFO[power]
	if power == "guide" then
		self.guideShots = 3
	elseif power == "multiball" then
		local extra = P.NewBall(ball.x, ball.y, -ball.vx, ball.vy)
		extra.spooky = ball.spooky
		table.insert(self.activeBalls, extra)
		NS.Board:AddBall(extra)
	elseif power == "fire" then
		self.nextFire = true
	elseif power == "blast" then
		local hits = {}
		local r2 = self.BLAST_RADIUS * self.BLAST_RADIUS
		for _, other in ipairs(self.pegs) do
			if not other.removed and not other.lit then
				local dx, dy = other.x - peg.x, other.y - peg.y
				if dx * dx + dy * dy <= r2 then
					table.insert(hits, other)
				end
			end
		end
		NS.Board:Blast(peg.x, peg.y, self.BLAST_RADIUS)
		for _, other in ipairs(hits) do
			self:Light(other, ball)
		end
	elseif power == "spooky" then
		ball.spooky = ball.spooky + 1
	elseif power == "flower" then
		local candidates = {}
		for _, other in ipairs(self.pegs) do
			if not other.removed and not other.lit then
				table.insert(candidates, other)
			end
		end
		local count = math.ceil(#candidates * 0.1)
		for _ = 1, count do
			if #candidates == 0 then
				break
			end
			local i = math.random(#candidates)
			local other = table.remove(candidates, i)
			self:Light(other, ball)
		end
	end
	NS.Board:Banner((info and info.name or "Power") .. "!", 0.5, 1, 0.5, 1.3)
	NS.PlayKit("UI_PET_BATTLE_START")
end

function Game:StartFever()
	self.state = "fever"
	if NS.GetSettings().slowmo then
		self.slowmo = self.FEVER_SLOWMO
	end
	self:Stats().fevers = self:Stats().fevers + 1
	NS.Board:FeverStart()
	NS.Board:Banner("EXTREME FEVER!", 1, 0.5, 0.1, 2.4)
	NS.PlayKit("UI_WORLDQUEST_COMPLETE")
end

function Game:FeverBin(ball)
	local zone = NS.Clamp(math.floor(ball.x / (P.W / 5)) + 1, 1, 5)
	local bonus = self.FEVER_BINS[zone]
	self.feverBonus = self.feverBonus + bonus
	NS.Board:BinHit(zone)
	NS.Board:Banner("+" .. NS.Commas(bonus), 1, 0.85, 0.3, 1.4)
	NS.PlayKit(zone == 3 and "UI_LEGENDARY_LOOT_TOAST" or "UI_EPICLOOT_TOAST")
end

-------------------------------------------------------------------------------
-- Simulation
-------------------------------------------------------------------------------

function Game:Update(dt)
	if self.state == "idle" or self.state == "won" or self.state == "lost" then
		return
	end
	dt = math.min(dt, 0.05)
	local bucket = self.bucket
	if bucket and self.state ~= "fever" then
		bucket.t = bucket.t + dt
		bucket.x = P.W / 2 + (P.W / 2 - bucket.half - 8) * math.sin(bucket.t * 0.9)
	end

	if self.state == "shot" or self.state == "fever" then
		local scale = 1
		if self.slowmo > 0 then
			self.slowmo = self.slowmo - dt
			scale = 0.3
		end
		self.acc = self.acc + dt * scale
		local steps = 0
		while self.acc >= P.DT and steps < 30 do
			self.acc = self.acc - P.DT
			steps = steps + 1
			self:PhysicsStep()
			if #self.activeBalls == 0 then
				self.acc = 0
				break
			end
		end
		if #self.activeBalls == 0 then
			self:EndShot()
		end
	elseif self.state == "clear" then
		self.clearTimer = self.clearTimer - dt
		while self.clearTimer <= 0 and #self.litOrder > 0 do
			local peg = table.remove(self.litOrder, 1)
			self:RemovePeg(peg)
			self.clearTimer = self.clearTimer + self.CLEAR_INTERVAL
		end
		if #self.litOrder == 0 then
			self:AfterClear()
		end
	end
end

function Game:PhysicsStep()
	local world = self.world
	world.bucket = (self.state ~= "fever") and self.bucket or nil
	for i = #self.activeBalls, 1, -1 do
		local ball = self.activeBalls[i]
		local result = P.Step(ball, world, self.hitHandler)
		local speed2 = ball.vx * ball.vx + ball.vy * ball.vy
		if speed2 < 30 * 30 then
			ball.slowTime = ball.slowTime + P.DT
			if ball.slowTime > self.STUCK_TIME then
				self:Unstick(ball)
			end
		else
			ball.slowTime = 0
		end
		if result == "caught" then
			table.remove(self.activeBalls, i)
			NS.Board:RemoveBall(ball)
			self:FreeBall("Free ball!")
		elseif result == "out" then
			if ball.spooky > 0 then
				ball.spooky = ball.spooky - 1
				ball.y = -P.BALL_R
				ball.vy = math.max(40, ball.vy * 0.25)
				ball.travel = 0
				NS.Board:Banner("Spooky!", 0.8, 0.6, 1, 1)
			else
				table.remove(self.activeBalls, i)
				NS.Board:RemoveBall(ball)
				if self.state == "fever" then
					self:FeverBin(ball)
				end
			end
		end
	end
end

-- A ball resting on pegs for too long: the pegs it rests on go away.
function Game:Unstick(ball)
	ball.slowTime = 0
	for _, peg in ipairs(self.pegs) do
		if not peg.removed and P.Touching(ball, peg, 2) then
			self:RemovePeg(peg)
		end
	end
	ball.vy = ball.vy - 40
	ball.vx = ball.vx + (math.random() - 0.5) * 60
end

function Game:RemovePeg(peg)
	if peg.removed then
		return
	end
	peg.removed = true
	if peg.color == "orange" and not peg.lit then
		-- Removed without being lit (unstick): still counts as cleared.
		self.oranges = self.oranges - 1
	end
	NS.Board:RemovePeg(peg)
end

function Game:EndShot()
	local stats = self:Stats()
	if self.shotScore > stats.bestShot then
		stats.bestShot = self.shotScore
	end
	self.state = "clear"
	self.clearTimer = (self.oranges <= 0) and 0.2 or 0.3
	NS.UI:RefreshAll()
end

function Game:AfterClear()
	if self.oranges <= 0 then
		self:LevelWon()
		return
	end
	self:MovePurple()
	if self.balls <= 0 then
		self:LevelLost()
	else
		self.state = "aim"
		NS.UI:RefreshAll()
	end
end

-------------------------------------------------------------------------------
-- Level end
-------------------------------------------------------------------------------

function Game:LevelWon()
	self.state = "won"
	self.ballBonus = self.balls * self.BALL_BONUS
	local total = self.score + self.feverBonus + self.ballBonus
	self.levelTotal = total
	local progress, stats = self:Progress(), self:Stats()
	progress.unlocked = math.max(progress.unlocked, self.level + 1)
	local best = progress.best[self.level]
	self.newBest = (not best) or total > best
	if self.newBest then
		progress.best[self.level] = total
	end
	progress.total = (progress.total or 0) + total
	stats.levelsCleared = stats.levelsCleared + 1
	if total > stats.bestLevel then
		stats.bestLevel = total
	end
	NS.Board:FeverEnd()
	NS.UI:ShowResult(true)
	NS.PlayKit("LFG_REWARDS")
end

function Game:LevelLost()
	self.state = "lost"
	NS.UI:ShowResult(false)
	NS.PlayKit("UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL")
end
