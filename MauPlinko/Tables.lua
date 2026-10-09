-- MauPlinko payout tables, odds and colours.
--
-- A ball that falls through N rows bounces N times, each time left or right
-- with the same chance, so the bucket it ends in (0 = far left, N = far
-- right) follows the binomial distribution: the middle is common, the edges
-- are rare.  The tables pay little in the middle and a lot at the edges, and
-- are tuned so every one of them returns about 99% of what is wagered over
-- the long run (the house keeps about 1%, as in the well known online
-- version of the game).  build-check-tables.js in the repository's scratch
-- tooling recomputes the return of every table from these numbers.

local _, NS = ...

NS.MIN_ROWS, NS.MAX_ROWS = 8, 16
NS.RISKS = { "low", "medium", "high" }
NS.RISK_LABELS = { low = "Low", medium = "Medium", high = "High" }

-- NS.TABLES[risk][rows] lists the multiplier of every bucket from left to
-- right (rows + 1 entries, symmetric).
NS.TABLES = {
	low = {
		[8] = { 5.6, 2.1, 1.1, 1, 0.5, 1, 1.1, 2.1, 5.6 },
		[9] = { 5.6, 2, 1.6, 1, 0.7, 0.7, 1, 1.6, 2, 5.6 },
		[10] = { 8.9, 3, 1.4, 1.1, 1, 0.5, 1, 1.1, 1.4, 3, 8.9 },
		[11] = { 8.4, 3, 1.9, 1.3, 1, 0.7, 0.7, 1, 1.3, 1.9, 3, 8.4 },
		[12] = { 10, 3, 1.6, 1.4, 1.1, 1, 0.5, 1, 1.1, 1.4, 1.6, 3, 10 },
		[13] = { 8.1, 4, 3, 1.9, 1.2, 0.9, 0.7, 0.7, 0.9, 1.2, 1.9, 3, 4, 8.1 },
		[14] = { 7.1, 4, 1.9, 1.4, 1.3, 1.1, 1, 0.5, 1, 1.1, 1.3, 1.4, 1.9, 4, 7.1 },
		[15] = { 15, 8, 3, 2, 1.5, 1.1, 1, 0.7, 0.7, 1, 1.1, 1.5, 2, 3, 8, 15 },
		[16] = { 16, 9, 2, 1.4, 1.4, 1.2, 1.1, 1, 0.5, 1, 1.1, 1.2, 1.4, 1.4, 2, 9, 16 },
	},
	medium = {
		[8] = { 13, 3, 1.3, 0.7, 0.4, 0.7, 1.3, 3, 13 },
		[9] = { 18, 4, 1.7, 0.9, 0.5, 0.5, 0.9, 1.7, 4, 18 },
		[10] = { 22, 5, 2, 1.4, 0.6, 0.4, 0.6, 1.4, 2, 5, 22 },
		[11] = { 24, 6, 3, 1.8, 0.7, 0.5, 0.5, 0.7, 1.8, 3, 6, 24 },
		[12] = { 33, 11, 4, 2, 1.1, 0.6, 0.3, 0.6, 1.1, 2, 4, 11, 33 },
		[13] = { 43, 13, 6, 3, 1.3, 0.7, 0.4, 0.4, 0.7, 1.3, 3, 6, 13, 43 },
		[14] = { 58, 15, 7, 4, 1.9, 1, 0.5, 0.2, 0.5, 1, 1.9, 4, 7, 15, 58 },
		[15] = { 88, 18, 11, 5, 3, 1.3, 0.5, 0.3, 0.3, 0.5, 1.3, 3, 5, 11, 18, 88 },
		[16] = { 110, 41, 10, 5, 3, 1.5, 1, 0.5, 0.3, 0.5, 1, 1.5, 3, 5, 10, 41, 110 },
	},
	high = {
		[8] = { 29, 4, 1.5, 0.3, 0.2, 0.3, 1.5, 4, 29 },
		[9] = { 43, 7, 2, 0.6, 0.2, 0.2, 0.6, 2, 7, 43 },
		[10] = { 76, 10, 3, 0.9, 0.3, 0.2, 0.3, 0.9, 3, 10, 76 },
		[11] = { 120, 14, 5.2, 1.4, 0.4, 0.2, 0.2, 0.4, 1.4, 5.2, 14, 120 },
		[12] = { 170, 24, 8.1, 2, 0.7, 0.2, 0.2, 0.2, 0.7, 2, 8.1, 24, 170 },
		[13] = { 260, 37, 11, 4, 1, 0.2, 0.2, 0.2, 0.2, 1, 4, 11, 37, 260 },
		[14] = { 420, 56, 18, 5, 1.9, 0.3, 0.2, 0.2, 0.2, 0.3, 1.9, 5, 18, 56, 420 },
		[15] = { 620, 83, 27, 8, 3, 0.5, 0.2, 0.2, 0.2, 0.2, 0.5, 3, 8, 27, 83, 620 },
		[16] = { 1000, 130, 26, 9, 4, 2, 0.2, 0.2, 0.2, 0.2, 0.2, 2, 4, 9, 26, 130, 1000 },
	},
}

function NS.GetMultipliers(risk, rows)
	local byRisk = NS.TABLES[risk] or NS.TABLES.medium
	return byRisk[rows] or byRisk[NS.GAME_DEFAULTS.rows]
end

-- Number of ways to pick k of n (n choose k).
function NS.Binomial(n, k)
	if k < 0 or k > n then
		return 0
	end
	k = math.min(k, n - k)
	local result = 1
	for i = 1, k do
		result = result * (n - k + i) / i
	end
	return result
end

-- Chance that a ball through `rows` rows ends in bucket k (0..rows).
function NS.BucketProbability(rows, k)
	return NS.Binomial(rows, k) / (2 ^ rows)
end

-- Expected return per chip wagered on this table (0.99 = 99%).
function NS.RTP(risk, rows)
	local mults = NS.GetMultipliers(risk, rows)
	local total = 0
	for k = 0, rows do
		total = total + NS.BucketProbability(rows, k) * (mults[k + 1] or 0)
	end
	return total
end

local function Lerp(a, b, t)
	return a + (b - a) * t
end

-- Bucket colour by position: yellow in the middle, orange, red at the edges.
function NS.BucketColor(rows, k)
	local half = rows / 2
	local t = math.abs(k - half) / half
	local r, g, b
	if t < 0.6 then
		local u = t / 0.6
		r, g, b = Lerp(1.0, 1.0, u), Lerp(0.80, 0.45, u), Lerp(0.15, 0.08, u)
	else
		local u = (t - 0.6) / 0.4
		r, g, b = Lerp(1.0, 0.92, u), Lerp(0.45, 0.12, u), Lerp(0.08, 0.10, u)
	end
	return r, g, b
end

-- Text colour for a multiplier: grey for a loss, white around even, gold,
-- orange and red for ever bigger hits.
function NS.TierColor(mult)
	if mult < 1 then
		return 0.72, 0.72, 0.78
	elseif mult < 2 then
		return 1, 1, 1
	elseif mult < 10 then
		return 1, 0.85, 0.25
	elseif mult < 100 then
		return 1, 0.55, 0.15
	end
	return 1, 0.28, 0.22
end
