-- MauCookie Garden (Farm level 1), ported from minigameGarden.js: a 6 x 6
-- plot that opens with the Farm's level, 34 plants that age in ticks (every
-- 5 minutes of bakery time on dirt), mature, spread, mutate into new seeds
-- next to each other and die; soils, tools (harvest all, freeze,
-- sacrifice) and passive effects that feed CalculateGains.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

local G = { building = "Farm", name = "Garden", height = 340 }

-- key, name, icon row, cost (minutes of CpS), costM (minimum), ageTick, ageTickR, mature, children, flags, effects text, quote
G.plants = {
	{ key = "bakerWheat", name = "Baker's wheat", icon = 0, cost = 1, costM = 30, ageTick = 7, ageTickR = 2, mature = 35, children = { "bakerWheat", "thumbcorn", "cronerice", "bakeberry", "clover", "goldenClover", "chocoroot", "tidygrass" }, effs = "CpS +1%", q = "A plentiful crop whose hardy grain is used to make flour for pastries." },
	{ key = "thumbcorn", name = "Thumbcorn", icon = 1, cost = 5, costM = 100, ageTick = 6, ageTickR = 2, mature = 20, children = { "bakerWheat", "thumbcorn", "cronerice", "gildmillet", "glovemorel" }, effs = "cookies/click +2%", q = "A strangely-shaped variant of corn. The amount of strands that can sprout from one seed is usually in the single digits." },
	{ key = "cronerice", name = "Cronerice", icon = 2, cost = 15, costM = 250, ageTick = 0.4, ageTickR = 0.7, mature = 55, children = { "thumbcorn", "gildmillet", "elderwort", "wardlichen" }, effs = "grandma CpS +3%", q = "Not only does this wrinkly bulb look nothing like rice, it's not even related to it either; its closest extant relative is the weeping willow." },
	{ key = "gildmillet", name = "Gildmillet", icon = 3, cost = 15, costM = 1500, ageTick = 2, ageTickR = 1.5, mature = 40, children = { "clover", "goldenClover", "shimmerlily" }, effs = "golden cookie gains +1%, golden cookie effect duration +0.1%", q = "An ancient staple crop, famed for its golden sheen. Was once used to bake birthday cakes for kings and queens of old." },
	{ key = "clover", name = "Ordinary clover", icon = 4, cost = 25, costM = 77777, ageTick = 1, ageTickR = 1.5, mature = 35, children = { "goldenClover", "greenRot", "shimmerlily" }, effs = "golden cookie frequency +1%", q = "Trifolium repens, a fairly mundane variety of clover with a tendency to produce four leaves. Such instances are considered lucky by some." },
	{ key = "goldenClover", name = "Golden clover", icon = 5, cost = 125, costM = 777777777777, ageTick = 4, ageTickR = 12, mature = 50, children = {}, effs = "golden cookie frequency +3%", q = "A variant of the ordinary clover that traded its chlorophyll for pure organic gold. Tragically short-lived, this herb is an evolutionary dead-end - but at least it looks pretty." },
	{ key = "shimmerlily", name = "Shimmerlily", icon = 6, cost = 60, costM = 777777, ageTick = 5, ageTickR = 6, mature = 70, children = { "elderwort", "whiskerbloom", "chimerose", "cheapcap" }, effs = "golden cookie gains +1%, golden cookie frequency +1%, random drops +1%", q = "These little flowers are easiest to find at dawn, as the sunlight refracting in dew drops draws attention to their pure-white petals." },
	{ key = "elderwort", name = "Elderwort", icon = 7, cost = 180, costM = 100000000, ageTick = 0.3, ageTickR = 0.5, mature = 90, immortal = true, noContam = true, details = "Immortal", children = { "everdaisy", "ichorpuff", "shriekbulb" }, effs = "wrath cookie gains +1%, wrath cookie frequency +1%, grandma CpS +1%, surrounding plants (3x3) age 3% faster", q = "A very old, long-forgotten subspecies of edelweiss that emits a strange, heady scent. There is some anecdotal evidence that these do not undergo molecular aging." },
	{ key = "bakeberry", name = "Bakeberry", icon = 8, cost = 45, costM = 100000000, ageTick = 1, ageTickR = 1, mature = 50, children = { "queenbeet" }, effs = "CpS +1%, harvest when mature for +30 minutes of CpS (max. 3% of bank)", q = "A favorite among cooks, this large berry has a crunchy brown exterior and a creamy red center. Excellent in pies or chicken stews." },
	{ key = "chocoroot", name = "Chocoroot", icon = 9, cost = 15, costM = 100000, ageTick = 4, ageTickR = 0, mature = 25, details = "Predictable growth", children = { "whiteChocoroot", "drowsyfern", "queenbeet" }, effs = "CpS +1%, harvest when mature for +3 minutes of CpS (max. 3% of bank), predictable growth", q = "A tangly bramble coated in a sticky, sweet substance. Unknown genetic ancestry. Children often pick these from fields as-is as a snack." },
	{ key = "whiteChocoroot", name = "White chocoroot", icon = 10, cost = 15, costM = 100000, ageTick = 4, ageTickR = 0, mature = 25, details = "Predictable growth", children = { "whiskerbloom", "tidygrass" }, effs = "golden cookie gains +1%, harvest when mature for +3 minutes of CpS (max. 3% of bank), predictable growth", q = "A pale, even sweeter variant of the chocoroot. Often impedes travelers with its twisty branches." },
	{ key = "whiteMildew", name = "White mildew", fungus = true, icon = 26, cost = 20, costM = 9999, ageTick = 8, ageTickR = 12, mature = 70, details = "Spreads easily", children = { "brownMold", "whiteChocoroot", "wardlichen", "greenRot" }, effs = "CpS +1%, may spread as Brown mold", q = "A common rot that infests shady plots of earth. Grows in little creamy capsules. Smells sweet, but sadly wilts quickly." },
	{ key = "brownMold", name = "Brown mold", fungus = true, icon = 27, cost = 20, costM = 9999, ageTick = 8, ageTickR = 12, mature = 70, details = "Spreads easily", children = { "whiteMildew", "chocoroot", "keenmoss", "wrinklegill" }, effs = "CpS -1%, may spread as White mildew", q = "A common rot that infests shady plots of earth. Grows in odd reddish clumps. Smells bitter, but thankfully wilts quickly." },
	{ key = "meddleweed", name = "Meddleweed", weed = true, icon = 29, cost = 1, costM = 10, ageTick = 10, ageTickR = 6, mature = 50, contam = 0.05, details = "Grows in empty tiles, spreads easily", children = { "meddleweed", "brownMold", "crumbspore" }, effs = "useless, may overtake nearby plants, may sometimes drop spores when uprooted", q = "The sign of a neglected farmland, this annoying weed spawns from unused dirt and may sometimes spread to other plants, killing them in the process." },
	{ key = "whiskerbloom", name = "Whiskerbloom", icon = 11, cost = 20, costM = 1000000, ageTick = 2, ageTickR = 2, mature = 60, children = { "chimerose", "nursetulip" }, effs = "milk effects +0.2%", q = "Squeezing the translucent pods makes them excrete a milky liquid, while producing a faint squeak akin to a cat's meow." },
	{ key = "chimerose", name = "Chimerose", icon = 12, cost = 15, costM = 242424, ageTick = 1, ageTickR = 1.5, mature = 30, children = { "chimerose" }, effs = "reindeer gains +1%, reindeer frequency +1%", q = "Originating in the greener flanks of polar mountains, this beautiful flower with golden accents is fragrant enough to make any room feel a little bit more festive." },
	{ key = "nursetulip", name = "Nursetulip", icon = 13, cost = 40, costM = 1000000000, ageTick = 0.5, ageTickR = 2, mature = 60, children = {}, effs = "surrounding plants (3x3) are 20% more efficient, CpS -2%", q = "This flower grows an intricate root network that distributes nutrients throughout the surrounding soil. The reason for this seemingly altruistic behavior is still unknown." },
	{ key = "drowsyfern", name = "Drowsyfern", icon = 14, cost = 90, costM = 100000, ageTick = 0.05, ageTickR = 0.1, mature = 30, children = {}, effs = "CpS +3%, cookies/click -5%, golden cookie frequency -10%", q = "Traditionally used to brew a tea that guarantees a good night of sleep." },
	{ key = "wardlichen", name = "Wardlichen", icon = 15, cost = 10, costM = 10000, ageTick = 5, ageTickR = 4, mature = 65, children = { "wardlichen" }, effs = "wrath cookie frequency -2%, wrinkler spawn rate -15%", q = "The metallic stench that emanates from this organism has been known to keep insects and slugs away." },
	{ key = "keenmoss", name = "Keenmoss", icon = 16, cost = 50, costM = 1000000, ageTick = 4, ageTickR = 5, mature = 65, children = { "drowsyfern", "wardlichen", "keenmoss" }, effs = "random drops +3%", q = "Fuzzy to the touch and of a vibrant green. In plant symbolism, keenmoss is associated with good luck for finding lost objects." },
	{ key = "queenbeet", name = "Queenbeet", icon = 17, cost = 90, costM = 1000000000, ageTick = 1, ageTickR = 0.4, mature = 80, noContam = true, children = { "duketater", "queenbeetLump", "shriekbulb" }, effs = "golden cookie effect duration +0.3%, CpS -2%, harvest when mature for +1 hour of CpS (max. 4% of bank)", q = "A delicious taproot used to prepare high-grade white sugar. Entire countries once went to war over these." },
	{ key = "queenbeetLump", name = "Juicy queenbeet", icon = 18, plantable = false, cost = 120, costM = 1000000000000, ageTick = 0.04, ageTickR = 0.08, mature = 85, noContam = true, children = {}, effs = "CpS -10%, surrounding plants (3x3) are 20% less efficient, harvest when mature for a sugar lump", q = "It looks like this one has grown especially sweeter and juicier from growing in close proximity to other queenbeets." },
	{ key = "duketater", name = "Duketater", icon = 19, cost = 480, costM = 1000000000000, ageTick = 0.4, ageTickR = 0.1, mature = 95, noContam = true, children = { "shriekbulb" }, effs = "harvest when mature for +2 hours of CpS (max. 8% of bank)", q = "A rare, rich-tasting tuber fit for a whole meal, as long as its strict harvesting schedule is respected. Its starch has fascinating baking properties." },
	{ key = "crumbspore", name = "Crumbspore", fungus = true, icon = 20, cost = 10, costM = 999, ageTick = 3, ageTickR = 3, mature = 65, contam = 0.03, noContam = true, details = "Spreads easily", children = { "crumbspore", "glovemorel", "cheapcap", "doughshroom", "wrinklegill", "ichorpuff" }, effs = "explodes into up to 1 minute of CpS at the end of its lifecycle (max. 1% of bank), may overtake nearby plants", q = "An archaic mold that spreads its spores to the surrounding dirt through simple pod explosion." },
	{ key = "doughshroom", name = "Doughshroom", fungus = true, icon = 24, cost = 100, costM = 100000000, ageTick = 1, ageTickR = 2, mature = 85, contam = 0.03, noContam = true, details = "Spreads easily", children = { "crumbspore", "doughshroom", "foolBolete", "shriekbulb" }, effs = "explodes into up to 5 minutes of CpS at the end of its lifecycle (max. 3% of bank), may overtake nearby plants", q = "Jammed full of warm spores; some forest walkers often describe the smell as similar to passing by a bakery." },
	{ key = "glovemorel", name = "Glovemorel", fungus = true, icon = 21, cost = 30, costM = 10000, ageTick = 3, ageTickR = 18, mature = 80, children = {}, effs = "cookies/click +4%, cursor CpS +1%, CpS -1%", q = "Touching its waxy skin reveals that the interior is hollow and uncomfortably squishy." },
	{ key = "cheapcap", name = "Cheapcap", fungus = true, icon = 22, cost = 40, costM = 100000, ageTick = 6, ageTickR = 16, mature = 40, children = {}, effs = "buildings and upgrades are 0.2% cheaper, cannot handle cold climates; 15% chance to die when frozen", q = "Small, tough, and good in omelettes. Some historians propose that the heads of dried cheapcaps were once used as currency in some bronze age societies." },
	{ key = "foolBolete", name = "Fool's bolete", fungus = true, icon = 23, cost = 15, costM = 10000, ageTick = 5, ageTickR = 25, mature = 50, children = {}, effs = "golden cookie frequency +2%, golden cookie gains -5%, golden cookie duration -2%, golden cookie effect duration -2%", q = "Named for its ability to fool mushroom pickers. The fool's bolete is not actually poisonous, it's just extremely bland." },
	{ key = "wrinklegill", name = "Wrinklegill", fungus = true, icon = 25, cost = 20, costM = 1000000, ageTick = 1, ageTickR = 3, mature = 65, children = { "elderwort", "shriekbulb" }, effs = "wrinkler spawn rate +2%, wrinkler appetite +1%", q = "This mushroom's odor resembles that of a well-done steak, and is said to whet the appetite - making one's stomach start gurgling within seconds." },
	{ key = "greenRot", name = "Green rot", fungus = true, icon = 28, cost = 60, costM = 1000000, ageTick = 12, ageTickR = 13, mature = 65, children = { "keenmoss", "foolBolete" }, effs = "golden cookie duration +0.5%, golden cookie frequency +1%, random drops +1%", q = "This short-lived mold is also known as \"emerald pebbles\", and is considered by some as a pseudo-gem that symbolizes good fortune." },
	{ key = "shriekbulb", name = "Shriekbulb", icon = 30, cost = 60, costM = 4444444444444, ageTick = 3, ageTickR = 1, mature = 60, noContam = true, details = "The unfortunate result of some plant combinations", children = { "shriekbulb" }, effs = "CpS -2%, surrounding plants (3x3) are 5% less efficient", q = "A nasty vegetable with a dreadful quirk: its flesh resonates with a high-pitched howl whenever it is hit at the right angle by sunlight, moonlight, or even a slight breeze." },
	{ key = "tidygrass", name = "Tidygrass", icon = 31, cost = 90, costM = 100000000000000, ageTick = 0.5, ageTickR = 0, mature = 40, children = { "everdaisy" }, effs = "surrounding tiles (5x5) develop no weeds or fungus", q = "The molecules this grass emits are a natural weedkiller. Its stems grow following a predictable pattern, making it an interesting -if expensive- choice for a lawn grass." },
	{ key = "everdaisy", name = "Everdaisy", icon = 32, cost = 180, costM = 1e20, ageTick = 0.3, ageTickR = 0, mature = 75, noContam = true, immortal = true, details = "Immortal", children = {}, effs = "surrounding tiles (3x3) develop no weeds or fungus, immortal", q = "While promoted by some as a superfood owing to its association with longevity and intriguing geometry, this elusive flower is actually mildly toxic." },
	{ key = "ichorpuff", name = "Ichorpuff", fungus = true, icon = 33, cost = 120, costM = 987654321, ageTick = 1, ageTickR = 1.5, mature = 35, children = {}, effs = "surrounding plants (3x3) age 50% slower, surrounding plants (3x3) are 50% less efficient", q = "This puffball mushroom contains sugary spores, but it never seems to mature to bursting on its own. Surrounding plants under its influence have a very slow metabolism, reducing their effects but lengthening their lifespan." },
}
G.byKey = {}
for i, p in ipairs(G.plants) do
	p.id = i
	p.matureBase = p.mature
	if p.plantable == nil then
		p.plantable = true
	end
	G.byKey[p.key] = p
end

G.soils = {
	{ key = "dirt", name = "Dirt", icon = 0, tick = 5, effMult = 1, weedMult = 1, req = 0, effs = "tick every 5 minutes", q = "Simple, regular old dirt that you'd find in nature." },
	{ key = "fertilizer", name = "Fertilizer", icon = 1, tick = 3, effMult = 0.75, weedMult = 1.2, req = 50, effs = "tick every 3 minutes, passive plant effects -25%, weed growth +20%", q = "Soil with a healthy helping of fresh manure. Plants grow faster but are less efficient." },
	{ key = "clay", name = "Clay", icon = 2, tick = 15, effMult = 1.25, weedMult = 1, req = 100, effs = "tick every 15 minutes, passive plant effects +25%", q = "Rich soil with very good water retention. Plants grow slower but are more efficient." },
	{ key = "pebbles", name = "Pebbles", icon = 3, tick = 5, effMult = 0.25, weedMult = 0.1, req = 200, effs = "tick every 5 minutes, passive plant effects -75%, 35% chance of collecting seeds automatically when plants expire, weed growth -90%", q = "Dry soil made of small rocks tightly packed together. Not very conducive to plant health, but whatever falls off your crops will be easy to retrieve." },
	{ key = "woodchips", name = "Wood chips", icon = 4, tick = 5, effMult = 0.25, weedMult = 0.1, req = 300, effs = "tick every 5 minutes, passive plant effects -75%, plants spread and mutate 3 times more, weed growth -90%", q = "Soil made of bits and pieces of bark and sawdust. Helpful for young sprouts to develop, not so much for mature plants." },
}

G.plotLimits = {
	{ 2, 2, 4, 4 }, { 2, 2, 5, 4 }, { 2, 2, 5, 5 }, { 1, 2, 5, 5 }, { 1, 1, 5, 5 }, { 1, 1, 6, 5 }, { 1, 1, 6, 6 }, { 0, 1, 6, 6 }, { 0, 0, 6, 6 },
}

local function Now()
	return Game.save.runTime or 0
end

local function RandomFloor(x)
	if (x % 1) < math.random() then
		return math.floor(x)
	end
	return math.ceil(x)
end

function G:load(fresh)
	local st = self.state
	if fresh or not st.plot then
		st.plot = {}
		for y = 1, 6 do
			st.plot[y] = {}
			for x = 1, 6 do
				st.plot[y][x] = { 0, 0 }
			end
		end
		st.soil = 1
		st.nextStep = Now()
		st.nextSoil = Now()
		st.freeze = false
		st.harvests = 0
		st.harvestsTotal = 0
		st.convertTimes = 0
		st.unlocked = { bakerWheat = true }
		st.loopsMult = 1
	end
	st.unlocked.bakerWheat = true
	self.seedSelected = nil
	self:computeStepT()
	self:computeMatures()
	self:computeBoostPlot()
	self:computeEffs()
end

function G:unlockedN()
	if not self.state then
		return 0
	end
	local n = 0
	for _, p in ipairs(self.plants) do
		if self.state.unlocked[p.key] then
			n = n + 1
		end
	end
	if n >= #self.plants then
		Game:Win("Keeper of the conservatory")
	end
	return n
end

function G:dropUpgrade(name, rate)
	if not Game:Has(name) and math.random() <= rate * Game:DropRateMult() * (Game:HasAchiev("Seedless to nay") and 1.05 or 1) then
		Game:Unlock(name)
		NS.Notify(name, "A plant dropped something!", NS.U[name] and NS.U[name].icon)
	end
end

function G:computeMatures()
	local mult = Game:HasAchiev("Seedless to nay") and 0.95 or 1
	for _, p in ipairs(self.plants) do
		p.mature = p.matureBase * mult
	end
end

function G:computeStepT()
	if Game:Has("Turbo-charged soil") then
		self.stepT = 1
	else
		self.stepT = self.soils[self.state.soil].tick * 60
	end
end

function G:getCost(p)
	if Game:Has("Turbo-charged soil") then
		return 0
	end
	return math.max(p.costM, (Game.cps or 0) * p.cost * 60) * (Game:HasAchiev("Seedless to nay") and 0.95 or 1)
end

function G:isTileUnlocked(x, y)
	local level = math.max(1, math.min(#self.plotLimits, Game:Level("Farm")))
	local lim = self.plotLimits[level]
	return x >= lim[1] and x < lim[3] and y >= lim[2] and y < lim[4]
end

-- x, y are 0-based like the original.
function G:getTile(x, y)
	if x < 0 or x > 5 or y < 0 or y > 5 or not self:isTileUnlocked(x, y) then
		return { 0, 0 }
	end
	return self.state.plot[y + 1][x + 1]
end

function G:stage(p, age)
	if age >= p.mature then return 4
	elseif age >= p.mature * 0.666 then return 3
	elseif age >= p.mature * 0.333 then return 2 end
	return 1
end

function G:computeBoostPlot()
	local st = self.state
	self.plotBoost = {}
	for y = 1, 6 do
		self.plotBoost[y] = {}
		for x = 1, 6 do
			self.plotBoost[y][x] = { 1, 1, 1 }
		end
	end
	local function effectOn(X, Y, s, mult)
		for y = math.max(1, Y - s), math.min(6, Y + s) do
			for x = math.max(1, X - s), math.min(6, X + s) do
				if not (X == x and Y == y) then
					for i = 1, 3 do
						self.plotBoost[y][x][i] = self.plotBoost[y][x][i] * mult[i]
					end
				end
			end
		end
	end
	local soilMult = self.soils[st.soil].effMult
	for y = 1, 6 do
		for x = 1, 6 do
			local tile = st.plot[y][x]
			if tile[1] > 0 then
				local me = self.plants[tile[1]]
				local stage = self:stage(me, tile[2])
				local mult = soilMult
				if stage == 1 then mult = mult * 0.1 elseif stage == 2 then mult = mult * 0.25 elseif stage == 3 then mult = mult * 0.5 end
				local ageMult, powerMult, weedMult, range = 1, 1, 1, 0
				local name = me.key
				if name == "elderwort" then ageMult = 1.03; range = 1
				elseif name == "queenbeetLump" then powerMult = 0.8; range = 1
				elseif name == "nursetulip" then powerMult = 1.2; range = 1
				elseif name == "shriekbulb" then powerMult = 0.95; range = 1
				elseif name == "tidygrass" then weedMult = 0; range = 2
				elseif name == "everdaisy" then weedMult = 0; range = 1
				elseif name == "ichorpuff" then ageMult = 0.5; powerMult = 0.5; range = 1 end
				if ageMult >= 1 then ageMult = (ageMult - 1) * mult + 1 end
				if powerMult >= 1 then powerMult = (powerMult - 1) * mult + 1 end
				if range > 0 then
					effectOn(x, y, range, { ageMult, powerMult, weedMult })
				end
			end
		end
	end
end

function G:computeEffs()
	local st = self.state
	local effs = {}
	if not st.freeze then
		local soilMult = self.soils[st.soil].effMult
		local e = { cps = 1, click = 1, cursorCps = 1, grandmaCps = 1, goldenCookieGain = 1, goldenCookieFreq = 1, goldenCookieDur = 1, goldenCookieEffDur = 1, wrathCookieGain = 1, wrathCookieFreq = 1, wrathCookieDur = 1, wrathCookieEffDur = 1, reindeerGain = 1, reindeerFreq = 1, reindeerDur = 1, itemDrops = 1, milk = 1, wrinklerSpawn = 1, wrinklerEat = 1, upgradeCost = 1, buildingCost = 1 }
		for y = 1, 6 do
			for x = 1, 6 do
				local tile = st.plot[y][x]
				if tile[1] > 0 then
					local me = self.plants[tile[1]]
					local stage = self:stage(me, tile[2])
					local mult = soilMult
					if stage == 1 then mult = mult * 0.1 elseif stage == 2 then mult = mult * 0.25 elseif stage == 3 then mult = mult * 0.5 end
					mult = mult * self.plotBoost[y][x][2]
					local name = me.key
					if name == "bakerWheat" then e.cps = e.cps + 0.01 * mult
					elseif name == "thumbcorn" then e.click = e.click + 0.02 * mult
					elseif name == "cronerice" then e.grandmaCps = e.grandmaCps + 0.03 * mult
					elseif name == "gildmillet" then e.goldenCookieGain = e.goldenCookieGain + 0.01 * mult; e.goldenCookieEffDur = e.goldenCookieEffDur + 0.001 * mult
					elseif name == "clover" then e.goldenCookieFreq = e.goldenCookieFreq + 0.01 * mult
					elseif name == "goldenClover" then e.goldenCookieFreq = e.goldenCookieFreq + 0.03 * mult
					elseif name == "shimmerlily" then e.goldenCookieGain = e.goldenCookieGain + 0.01 * mult; e.goldenCookieFreq = e.goldenCookieFreq + 0.01 * mult; e.itemDrops = e.itemDrops + 0.01 * mult
					elseif name == "elderwort" then e.wrathCookieGain = e.wrathCookieGain + 0.01 * mult; e.wrathCookieFreq = e.wrathCookieFreq + 0.01 * mult; e.grandmaCps = e.grandmaCps + 0.01 * mult
					elseif name == "bakeberry" then e.cps = e.cps + 0.01 * mult
					elseif name == "chocoroot" then e.cps = e.cps + 0.01 * mult
					elseif name == "whiteChocoroot" then e.goldenCookieGain = e.goldenCookieGain + 0.01 * mult
					elseif name == "whiteMildew" then e.cps = e.cps + 0.01 * mult
					elseif name == "brownMold" then e.cps = e.cps * (1 - 0.01 * mult)
					elseif name == "whiskerbloom" then e.milk = e.milk + 0.002 * mult
					elseif name == "chimerose" then e.reindeerGain = e.reindeerGain + 0.01 * mult; e.reindeerFreq = e.reindeerFreq + 0.01 * mult
					elseif name == "nursetulip" then e.cps = e.cps * (1 - 0.02 * mult)
					elseif name == "drowsyfern" then e.cps = e.cps + 0.03 * mult; e.click = e.click * (1 - 0.05 * mult); e.goldenCookieFreq = e.goldenCookieFreq * (1 - 0.1 * mult)
					elseif name == "wardlichen" then e.wrinklerSpawn = e.wrinklerSpawn * (1 - 0.15 * mult); e.wrathCookieFreq = e.wrathCookieFreq * (1 - 0.02 * mult)
					elseif name == "keenmoss" then e.itemDrops = e.itemDrops + 0.03 * mult
					elseif name == "queenbeet" then e.goldenCookieEffDur = e.goldenCookieEffDur + 0.003 * mult; e.cps = e.cps * (1 - 0.02 * mult)
					elseif name == "queenbeetLump" then e.cps = e.cps * (1 - 0.1 * mult)
					elseif name == "glovemorel" then e.click = e.click + 0.04 * mult; e.cursorCps = e.cursorCps + 0.01 * mult; e.cps = e.cps * (1 - 0.01 * mult)
					elseif name == "cheapcap" then e.upgradeCost = e.upgradeCost * (1 - 0.002 * mult); e.buildingCost = e.buildingCost * (1 - 0.002 * mult)
					elseif name == "foolBolete" then e.goldenCookieFreq = e.goldenCookieFreq + 0.02 * mult; e.goldenCookieGain = e.goldenCookieGain * (1 - 0.05 * mult); e.goldenCookieDur = e.goldenCookieDur * (1 - 0.02 * mult); e.goldenCookieEffDur = e.goldenCookieEffDur * (1 - 0.02 * mult)
					elseif name == "wrinklegill" then e.wrinklerSpawn = e.wrinklerSpawn + 0.02 * mult; e.wrinklerEat = e.wrinklerEat + 0.01 * mult
					elseif name == "greenRot" then e.goldenCookieDur = e.goldenCookieDur + 0.005 * mult; e.goldenCookieFreq = e.goldenCookieFreq + 0.01 * mult; e.itemDrops = e.itemDrops + 0.01 * mult
					elseif name == "shriekbulb" then e.cps = e.cps * (1 - 0.02 * mult) end
				end
			end
		end
		effs = e
	end
	self.effs = effs
	Game.recalc = true
end

-------------------------------------------------------------------------------
-- Planting, harvesting, tools
-------------------------------------------------------------------------------

local function Popup(text)
	NS.Notify("Garden", text, {2,16}, true)
end

function G:onHarvest(me, age)
	local S = Game.save
	local key = me.key
	if age < me.mature then
		return
	end
	if key == "bakerWheat" then self:dropUpgrade("Wheat slims", 0.001)
	elseif key == "elderwort" then self:dropUpgrade("Elderwort biscuits", 0.01)
	elseif key == "bakeberry" then
		local moni = math.min(S.cookies * 0.03, (Game.cps or 0) * 60 * 30)
		if moni ~= 0 then Game:Earn(moni); Popup("(Bakeberry) +" .. NS.Beautify(moni) .. " cookies!") end
		self:dropUpgrade("Bakeberry cookies", 0.015)
	elseif key == "chocoroot" or key == "whiteChocoroot" then
		local moni = math.min(S.cookies * 0.03, (Game.cps or 0) * 60 * 3)
		if moni ~= 0 then Game:Earn(moni); Popup("(" .. me.name .. ") +" .. NS.Beautify(moni) .. " cookies!") end
	elseif key == "drowsyfern" then self:dropUpgrade("Fern tea", 0.01)
	elseif key == "queenbeet" then
		local moni = math.min(S.cookies * 0.04, (Game.cps or 0) * 60 * 60)
		if moni ~= 0 then Game:Earn(moni); Popup("(Queenbeet) +" .. NS.Beautify(moni) .. " cookies!") end
	elseif key == "queenbeetLump" then
		Game:GainLumps(1)
		Popup("(Juicy queenbeet) Sweet! Found 1 sugar lump!")
	elseif key == "duketater" then
		local moni = math.min(S.cookies * 0.08, (Game.cps or 0) * 60 * 60 * 2)
		if moni ~= 0 then Game:Earn(moni); Popup("(Duketater) +" .. NS.Beautify(moni) .. " cookies!") end
		self:dropUpgrade("Duketater cookies", 0.005)
	elseif key == "greenRot" then self:dropUpgrade("Green yeast digestives", 0.005)
	elseif key == "ichorpuff" then self:dropUpgrade("Ichor syrup", 0.005) end
end

function G:onDie(me)
	local S = Game.save
	if me.key == "crumbspore" then
		local moni = math.min(S.cookies * 0.01, (Game.cps or 0) * 60) * math.random()
		if moni ~= 0 then Game:Earn(moni); Popup("(Crumbspore) +" .. NS.Beautify(moni) .. " cookies!") end
	elseif me.key == "doughshroom" then
		local moni = math.min(S.cookies * 0.03, (Game.cps or 0) * 60 * 5) * math.random()
		if moni ~= 0 then Game:Earn(moni); Popup("(Doughshroom) +" .. NS.Beautify(moni) .. " cookies!") end
	end
end

function G:onKill(me, x, y, age)
	if me.key == "meddleweed" and math.random() < 0.2 * (age / 100) then
		self.state.plot[y][x] = { self.byKey[Choose({ "brownMold", "crumbspore" })].id, 0 }
	end
end

function G:unlockSeed(me)
	if self.state.unlocked[me.key] then
		return false
	end
	self.state.unlocked[me.key] = true
	self:unlockedN()
	return true
end

-- Harvest the tile (1-based); returns true when something was there.
function G:harvest(x, y)
	local st = self.state
	local tile = st.plot[y][x]
	if tile[1] >= 1 then
		local me = self.plants[tile[1]]
		local age = tile[2]
		self:onHarvest(me, age)
		if age >= me.mature then
			if self:unlockSeed(me) then
				Popup("Unlocked " .. me.name .. " seed.")
			end
			st.harvests = st.harvests + 1
			st.harvestsTotal = st.harvestsTotal + 1
			if st.harvestsTotal >= 100 then Game:Win("Botany enthusiast") end
			if st.harvestsTotal >= 1000 then Game:Win("Green, aching thumb") end
		end
		st.plot[y][x] = { 0, 0 }
		self:onKill(me, x, y, age)
		self.toCompute = true
		return true
	end
	return false
end

function G:harvestAll(matureOnly)
	if not self.state then
		return
	end
	local harvested = 0
	for _ = 1, 2 do
		for y = 1, 6 do
			for x = 1, 6 do
				local tile = self.state.plot[y][x]
				if tile[1] >= 1 then
					local me = self.plants[tile[1]]
					local doIt = true
					if matureOnly and (me.immortal or tile[2] < me.mature) then
						doIt = false
					end
					if doIt and self:harvest(x, y) then
						harvested = harvested + 1
					end
				end
			end
		end
	end
	if harvested > 0 then
		NS.PlayKit("IG_BACKPACK_COIN_OK")
	end
	self:afterChange()
end

function G:clickTile(x, y)
	local st = self.state
	if not st or not self:isTileUnlocked(x - 1, y - 1) then
		return
	end
	if self:harvest(x, y) then
		NS.PlayKit("IG_BACKPACK_COIN_OK")
	elseif self.seedSelected then
		local me = self.plants[self.seedSelected]
		if me and Game.save.cookies >= self:getCost(me) then
			st.plot[y][x] = { me.id, 0 }
			Game:Spend(self:getCost(me))
			NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
			if not IsShiftKeyDown() then
				self.seedSelected = nil
			end
		end
	end
	self:afterChange()
end

function G:setSoil(id)
	local st = self.state
	local soil = self.soils[id]
	if not st or st.freeze or st.soil == id or st.nextSoil > Now() or Game:Count("Farm") < soil.req then
		return false
	end
	st.nextSoil = Now() + (Game:Has("Turbo-charged soil") and 1 or 60 * 10)
	st.soil = id
	self:computeStepT()
	self:afterChange()
	return true
end

function G:toggleFreeze()
	local st = self.state
	if not st then
		return
	end
	st.freeze = not st.freeze
	if st.freeze then
		for y = 1, 6 do
			for x = 1, 6 do
				local tile = st.plot[y][x]
				if tile[1] > 0 then
					local me = self.plants[tile[1]]
					if me.key == "cheapcap" and math.random() < 0.15 then
						st.plot[y][x] = { 0, 0 }
					end
				end
			end
		end
	end
	self:afterChange()
end

function G:convert()
	local st = self.state
	if not st or self:unlockedN() < #self.plants then
		return false
	end
	self:harvestAll()
	st.unlocked = { bakerWheat = true }
	Game:GainLumps(10)
	NS.Notify("Sacrifice!", "You've sacrificed your garden to the sugar hornets, destroying your crops and your knowledge of seeds. In the remains, you find 10 sugar lumps.", {29,14})
	self.seedSelected = nil
	Game:Win("Seedless to nay")
	st.convertTimes = (st.convertTimes or 0) + 1
	self:computeMatures()
	self:afterChange()
	return true
end

function G:afterChange()
	self:computeBoostPlot()
	self:computeEffs()
	Game:Changed()
	NS.Minigames:Refresh()
end

function G:reset(hard)
	local st = self.state
	if not st then
		return
	end
	st.soil = 1
	self.seedSelected = nil
	st.nextStep = 0
	st.nextSoil = 0
	for y = 1, 6 do
		for x = 1, 6 do
			st.plot[y][x] = { 0, 0 }
		end
	end
	st.harvests = 0
	if hard then
		st.convertTimes = 0
		st.harvestsTotal = 0
		st.unlocked = {}
	end
	st.unlocked.bakerWheat = true
	st.loopsMult = 1
	st.freeze = false
	self:computeStepT()
	self:computeMatures()
	self:computeBoostPlot()
	self:computeEffs()
end

-------------------------------------------------------------------------------
-- The growth tick
-------------------------------------------------------------------------------

local function Neighbours(self, x, y, diagonal)
	local neighs, neighsM, any = {}, {}, 0
	for _, p in ipairs(self.plants) do
		neighs[p.key] = 0
		neighsM[p.key] = 0
	end
	local offsets = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
	if diagonal then
		table.insert(offsets, { -1, -1 })
		table.insert(offsets, { -1, 1 })
		table.insert(offsets, { 1, -1 })
		table.insert(offsets, { 1, 1 })
	end
	for _, o in ipairs(offsets) do
		local t = self:getTile(x + o[1], y + o[2])
		if t[1] > 0 then
			local p = self.plants[t[1]]
			any = any + 1
			neighs[p.key] = neighs[p.key] + 1
			if t[2] >= p.mature then
				neighsM[p.key] = neighsM[p.key] + 1
			end
		end
	end
	return neighs, neighsM, any
end

local function Muts(n, m)
	local muts = {}
	local function push(...)
		for _, v in ipairs({ ... }) do
			table.insert(muts, v)
		end
	end
	if m.bakerWheat >= 2 then push({ "bakerWheat", 0.2 }, { "thumbcorn", 0.05 }, { "bakeberry", 0.001 }) end
	if m.bakerWheat >= 1 and m.thumbcorn >= 1 then push({ "cronerice", 0.01 }) end
	if m.thumbcorn >= 2 then push({ "thumbcorn", 0.1 }, { "bakerWheat", 0.05 }) end
	if m.cronerice >= 1 and m.thumbcorn >= 1 then push({ "gildmillet", 0.03 }) end
	if m.cronerice >= 2 then push({ "thumbcorn", 0.02 }) end
	if m.bakerWheat >= 1 and m.gildmillet >= 1 then push({ "clover", 0.03 }, { "goldenClover", 0.0007 }) end
	if m.clover >= 1 and m.gildmillet >= 1 then push({ "shimmerlily", 0.02 }) end
	if m.clover >= 2 and n.clover < 5 then push({ "clover", 0.007 }, { "goldenClover", 0.0001 }) end
	if m.clover >= 4 then push({ "goldenClover", 0.0007 }) end
	if m.shimmerlily >= 1 and m.cronerice >= 1 then push({ "elderwort", 0.01 }) end
	if m.wrinklegill >= 1 and m.cronerice >= 1 then push({ "elderwort", 0.002 }) end
	if m.bakerWheat >= 1 and n.brownMold >= 1 then push({ "chocoroot", 0.1 }) end
	if m.chocoroot >= 1 and n.whiteMildew >= 1 then push({ "whiteChocoroot", 0.1 }) end
	if m.whiteMildew >= 1 and n.brownMold <= 1 then push({ "brownMold", 0.5 }) end
	if m.brownMold >= 1 and n.whiteMildew <= 1 then push({ "whiteMildew", 0.5 }) end
	if m.meddleweed >= 1 and n.meddleweed <= 3 then push({ "meddleweed", 0.15 }) end
	if m.shimmerlily >= 1 and m.whiteChocoroot >= 1 then push({ "whiskerbloom", 0.01 }) end
	if m.shimmerlily >= 1 and m.whiskerbloom >= 1 then push({ "chimerose", 0.05 }) end
	if m.chimerose >= 2 then push({ "chimerose", 0.005 }) end
	if m.whiskerbloom >= 2 then push({ "nursetulip", 0.05 }) end
	if m.chocoroot >= 1 and m.keenmoss >= 1 then push({ "drowsyfern", 0.005 }) end
	if (m.cronerice >= 1 and m.keenmoss >= 1) or (m.cronerice >= 1 and m.whiteMildew >= 1) then push({ "wardlichen", 0.005 }) end
	if m.wardlichen >= 1 and n.wardlichen < 2 then push({ "wardlichen", 0.05 }) end
	if m.greenRot >= 1 and m.brownMold >= 1 then push({ "keenmoss", 0.1 }) end
	if m.keenmoss >= 1 and n.keenmoss < 2 then push({ "keenmoss", 0.05 }) end
	if m.chocoroot >= 1 and m.bakeberry >= 1 then push({ "queenbeet", 0.01 }) end
	if m.queenbeet >= 8 then push({ "queenbeetLump", 0.001 }) end
	if m.queenbeet >= 2 then push({ "duketater", 0.001 }) end
	if m.crumbspore >= 1 and n.crumbspore <= 1 then push({ "crumbspore", 0.07 }) end
	if m.crumbspore >= 1 and m.thumbcorn >= 1 then push({ "glovemorel", 0.02 }) end
	if m.crumbspore >= 1 and m.shimmerlily >= 1 then push({ "cheapcap", 0.04 }) end
	if m.doughshroom >= 1 and m.greenRot >= 1 then push({ "foolBolete", 0.04 }) end
	if m.crumbspore >= 2 then push({ "doughshroom", 0.005 }) end
	if m.doughshroom >= 1 and n.doughshroom <= 1 then push({ "doughshroom", 0.07 }) end
	if m.doughshroom >= 2 then push({ "crumbspore", 0.005 }) end
	if m.crumbspore >= 1 and m.brownMold >= 1 then push({ "wrinklegill", 0.06 }) end
	if m.whiteMildew >= 1 and m.clover >= 1 then push({ "greenRot", 0.05 }) end
	if m.wrinklegill >= 1 and m.elderwort >= 1 then push({ "shriekbulb", 0.001 }) end
	if m.elderwort >= 5 then push({ "shriekbulb", 0.001 }) end
	if n.duketater >= 3 then push({ "shriekbulb", 0.005 }) end
	if n.doughshroom >= 4 then push({ "shriekbulb", 0.002 }) end
	if m.queenbeet >= 5 then push({ "shriekbulb", 0.001 }) end
	if n.shriekbulb >= 1 and n.shriekbulb < 2 then push({ "shriekbulb", 0.005 }) end
	if m.bakerWheat >= 1 and m.whiteChocoroot >= 1 then push({ "tidygrass", 0.002 }) end
	if m.tidygrass >= 3 and m.elderwort >= 3 then push({ "everdaisy", 0.002 }) end
	if m.elderwort >= 1 and m.crumbspore >= 1 then push({ "ichorpuff", 0.002 }) end
	return muts
end

function G:step()
	local st = self.state
	self:computeStepT()
	st.nextStep = Now() + self.stepT
	self:computeBoostPlot()
	self:computeMatures()
	local soil = self.soils[st.soil]
	local weedMult = soil.weedMult
	local dragonBoost = 1 + 0.05 * Game:AuraMult("Supreme Intellect")
	local loops = soil.key == "woodchips" and 3 or 1
	loops = RandomFloor(loops * dragonBoost) * (st.loopsMult or 1)
	st.loopsMult = 1
	for y = 1, 6 do
		for x = 1, 6 do
			if self:isTileUnlocked(x - 1, y - 1) then
				local tile = st.plot[y][x]
				if tile[1] > 0 then
					local me = self.plants[tile[1]]
					tile[2] = tile[2] + RandomFloor((me.ageTick + me.ageTickR * math.random()) * self.plotBoost[y][x][1] * dragonBoost)
					tile[2] = math.max(tile[2], 0)
					if me.immortal then
						tile[2] = math.min(me.mature + 1, tile[2])
					elseif tile[2] >= 100 then
						st.plot[y][x] = { 0, 0 }
						self:onDie(me)
						if soil.key == "pebbles" and math.random() < 0.35 then
							if self:unlockSeed(me) then
								Popup("Unlocked " .. me.name .. " seed.")
							end
						end
					elseif not me.noContam then
						local list = {}
						for _, p in ipairs(self.plants) do
							if p.contam and math.random() < p.contam and (not p.weed or math.random() < weedMult) then
								table.insert(list, p.key)
							end
						end
						local contam = #list > 0 and Choose(list) or nil
						if contam and me.key ~= contam then
							local cp = self.byKey[contam]
							if (not cp.weed and not cp.fungus) or math.random() < self.plotBoost[y][x][3] then
								local _, neighsM = Neighbours(self, x - 1, y - 1, false)
								if neighsM[contam] >= 1 then
									st.plot[y][x] = { cp.id, 0 }
								end
							end
						end
					end
				else
					for loop = 1, loops do
						local neighs, neighsM, any = Neighbours(self, x - 1, y - 1, true)
						if any > 0 then
							local muts = Muts(neighs, neighsM)
							local list = {}
							for _, mut in ipairs(muts) do
								local p = self.byKey[mut[1]]
								if math.random() < mut[2] and (not p.weed or math.random() < weedMult) and ((not p.weed and not p.fungus) or math.random() < self.plotBoost[y][x][3]) then
									table.insert(list, mut[1])
								end
							end
							if #list > 0 then
								st.plot[y][x] = { self.byKey[Choose(list)].id, 0 }
							end
						elseif loop == 1 then
							local chance = 0.002 * weedMult * self.plotBoost[y][x][3]
							if math.random() < chance then
								st.plot[y][x] = { self.byKey.meddleweed.id, 0 }
							end
						end
					end
				end
			end
		end
	end
	self.toCompute = true
end

function G:logic(dt)
	local st = self.state
	if not st.freeze then
		st.nextStep = math.min(st.nextStep, Now() + self.stepT)
		if Now() >= st.nextStep then
			self:step()
			self.dirty = true
		end
	end
	if self.toCompute then
		self.toCompute = false
		self:computeBoostPlot()
		self:computeEffs()
		self.dirty = true
	end
end

function G:onLevel(level)
	self.dirty = true
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

local TILE = 40

local function SetPlantIcon(tex, col, row)
	NS.SetSheetCell(tex, "gardenPlants", 48, 48, col, row)
end

function G:render(panel)
	local UI = NS.UI
	NS.Minigames:Decorate(panel, "BGgarden")
	panel.Title:SetText("Garden")
	-- Plot.
	local plot = CreateFrame("Frame", nil, panel)
	plot:SetSize(6 * TILE, 6 * TILE)
	plot:SetPoint("TOPLEFT", 8, -30)
	plot.Tiles = {}
	for y = 1, 6 do
		plot.Tiles[y] = {}
		for x = 1, 6 do
			local t = CreateFrame("Button", nil, plot)
			t:SetSize(TILE, TILE)
			t:SetPoint("TOPLEFT", (x - 1) * TILE, -(y - 1) * TILE)
			t.x, t.y = x, y
			t.Soil = t:CreateTexture(nil, "BACKGROUND")
			t.Soil:SetAllPoints()
			t.Plant = t:CreateTexture(nil, "ARTWORK")
			t.Plant:SetPoint("TOPLEFT", -4, 4)
			t.Plant:SetPoint("BOTTOMRIGHT", 4, -4)
			t:SetHighlightTexture(UI.WHITE)
			t:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
			t:SetScript("OnClick", function(self)
				G:clickTile(self.x, self.y)
			end)
			UI.SetTooltip(t, function(self)
				G:tileTooltip(self.x, self.y)
			end)
			plot.Tiles[y][x] = t
		end
	end
	panel.Plot = plot
	-- Seeds: four columns of 24 px to the right of the plot.
	panel.Seeds = {}
	local sx, sy = 6 * TILE + 16, -30
	for i, p in ipairs(self.plants) do
		local c = CreateFrame("Button", nil, panel)
		c:SetSize(22, 22)
		c.plant = p
		c.Icon = c:CreateTexture(nil, "ARTWORK")
		c.Icon:SetAllPoints()
		SetPlantIcon(c.Icon, 0, p.icon)
		c.Sel = UI.Solid(c, "BACKGROUND", 1, 1, 0.6, 0.35)
		c.Sel:SetAllPoints()
		c.Sel:Hide()
		c:SetHighlightTexture(UI.WHITE)
		c:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
		c:SetScript("OnClick", function(self)
			if not G.state or not self.plant.plantable or not G.state.unlocked[self.plant.key] then
				return
			end
			if G.seedSelected == self.plant.id then
				G.seedSelected = nil
			else
				G.seedSelected = self.plant.id
			end
			G:refresh(panel)
		end)
		UI.SetTooltip(c, function(self)
			G:seedTooltip(self.plant)
		end)
		panel.Seeds[i] = c
	end
	-- Soils.
	panel.Soils = {}
	for i, s in ipairs(self.soils) do
		local c = CreateFrame("Button", nil, panel)
		c:SetSize(26, 26)
		c.soil = i
		c.Icon = c:CreateTexture(nil, "ARTWORK")
		c.Icon:SetAllPoints()
		SetPlantIcon(c.Icon, s.icon, 34)
		c.Sel = UI.Solid(c, "BACKGROUND", 1, 1, 0.6, 0.35)
		c.Sel:SetAllPoints()
		c.Sel:Hide()
		c:SetHighlightTexture(UI.WHITE)
		c:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
		c:SetScript("OnClick", function(self)
			G:setSoil(self.soil)
			G:refresh(panel)
		end)
		UI.SetTooltip(c, function(self)
			local soil = G.soils[self.soil]
			GameTooltip:SetText(soil.name)
			if Game:Count("Farm") < soil.req then
				GameTooltip:AddLine(string.format("Requires %d farms.", soil.req), 1, 0.4, 0.4)
			end
			GameTooltip:AddLine(soil.effs, 1, 1, 1, true)
			GameTooltip:AddLine(soil.q, 0.6, 0.6, 0.6, true)
			if G.state.nextSoil > Now() then
				GameTooltip:AddLine("You can change soil again in " .. NS.FormatDuration(G.state.nextSoil - Now()) .. ".", 0.8, 0.8, 0.8)
			end
		end)
		c:SetPoint("TOPLEFT", 8 + (i - 1) * 30, -(30 + 6 * TILE + 8))
		panel.Soils[i] = c
	end
	-- Tools.
	panel.Tools = {}
	local tools = {
		{ "Harvest all", 0, "Instantly harvest all plants in your garden. Shift-click to harvest only mature, mortal plants.", function()
			G:harvestAll(IsShiftKeyDown())
		end },
		{ "Freeze", 1, "Cryogenically preserve your garden. Plants no longer grow, spread or die; they provide no benefits. Soil cannot be changed. Using this will effectively pause your garden.", function()
			G:toggleFreeze()
		end },
		{ "Sacrifice garden", 2, "A swarm of sugar hornets comes down on your garden, destroying every plant as well as every seed you've unlocked, leaving only a Baker's wheat seed. In exchange, they will grant you 10 sugar lumps. This action is only available with a complete seed log.", function()
			if G:unlockedN() < #G.plants then
				return
			end
			NS.UI:Prompt("Sacrifice garden", "Do you REALLY want to sacrifice your garden to the sugar hornets? You will be left with an empty plot and only the Baker's wheat seed unlocked. In return, you will gain 10 sugar lumps.", {
				{ "Do it!", function()
					G:convert()
				end },
				{ "No" },
			})
		end },
	}
	for i, def in ipairs(tools) do
		local c = CreateFrame("Button", nil, panel)
		c:SetSize(26, 26)
		c.Icon = c:CreateTexture(nil, "ARTWORK")
		c.Icon:SetAllPoints()
		SetPlantIcon(c.Icon, def[2], 35)
		c:SetHighlightTexture(UI.WHITE)
		c:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
		c:SetScript("OnClick", def[4])
		UI.SetTooltip(c, function()
			GameTooltip:SetText(def[1])
			GameTooltip:AddLine(def[3], 1, 1, 1, true)
		end)
		c:SetPoint("TOPLEFT", 8 + 160 + (i - 1) * 30, -(30 + 6 * TILE + 8))
		panel.Tools[i] = c
	end
	panel.Refill = NS.Minigames:RefillButton(panel, "Click to refill your soil timer and trigger 1 plant growth tick with x3 spread and mutation rate for 1 sugar lump.", function()
		if G.state then
			G.state.loopsMult = 3
			G.state.nextSoil = Now()
			G.state.nextStep = Now()
		end
	end)
	panel.Refill:SetPoint("TOPRIGHT", -8, -2)
	panel.Status = UI.Text(panel, 10, "OUTLINE")
	panel.Status:SetPoint("BOTTOMLEFT", 8, 4)
	panel.Status:SetWidth(350)
	panel.Status:SetWordWrap(true)
	panel.Status:SetTextColor(0.85, 0.85, 0.85)
	panel.Note:SetText("")
	panel.seedsX, panel.seedsY = sx, sy
end

function G:seedTooltip(p)
	local st = self.state
	if not st then
		GameTooltip:SetText(p.name)
		return
	end
	local unlocked = st.unlocked[p.key]
	GameTooltip:SetText(unlocked and p.name or "???")
	if not unlocked then
		GameTooltip:AddLine("Seed not yet unlocked. Harvest a mature plant of this kind to learn its seed.", 0.6, 0.6, 0.6, true)
		return
	end
	if p.plantable then
		local cost = self:getCost(p)
		local can = Game.save.cookies >= cost
		GameTooltip:AddLine(string.format("Planting cost: %s (%d minutes of CpS, minimum %s)", NS.Beautify(math.floor(cost + 0.5)), p.cost, NS.Beautify(p.costM)), can and 0.4 or 1, can and 1 or 0.4, 0.4, true)
	else
		GameTooltip:AddLine("Cannot be planted.", 0.8, 0.8, 0.8)
	end
	local dragonBoost = 1 / (1 + 0.05 * Game:AuraMult("Supreme Intellect"))
	if not p.immortal then
		local ticks = math.ceil((100 / ((p.ageTick + p.ageTickR / 2) / dragonBoost)))
		GameTooltip:AddLine(string.format("Average lifespan: %s (%d ticks)", NS.FormatDuration(ticks * self.stepT), ticks), 1, 1, 1, true)
	end
	if p.weed then GameTooltip:AddLine("Is a weed", 1, 1, 1) end
	if p.fungus then GameTooltip:AddLine("Is a fungus", 1, 1, 1) end
	if p.details then GameTooltip:AddLine("Details: " .. p.details, 1, 1, 1, true) end
	GameTooltip:AddLine("Effects: " .. p.effs, 0.5, 1, 0.5, true)
	if #p.children > 0 then
		local names = {}
		for _, key in ipairs(p.children) do
			local c = self.byKey[key]
			table.insert(names, st.unlocked[key] and c.name or "???")
		end
		GameTooltip:AddLine("Possible mutations: " .. table.concat(names, ", "), 0.8, 0.8, 0.8, true)
	end
	GameTooltip:AddLine(p.q, 0.6, 0.6, 0.6, true)
end

function G:tileTooltip(x, y)
	local st = self.state
	if not st then
		GameTooltip:SetText("Garden")
		return
	end
	if not self:isTileUnlocked(x - 1, y - 1) then
		GameTooltip:SetText("Locked tile")
		GameTooltip:AddLine("Level up your farms to expand the garden.", 0.8, 0.8, 0.8, true)
		return
	end
	local tile = st.plot[y][x]
	local boost = self.plotBoost[y][x]
	if tile[1] == 0 then
		GameTooltip:SetText("Empty tile")
		GameTooltip:AddLine("This tile of soil is empty. Pick a seed and plant something!", 0.8, 0.8, 0.8, true)
		if self.seedSelected then
			local p = self.plants[self.seedSelected]
			GameTooltip:AddLine(string.format("Click to plant %s for %s. Hold shift to keep the seed selected.", p.name, NS.Beautify(math.floor(self:getCost(p) + 0.5))), 1, 1, 1, true)
		end
	else
		local p = self.plants[tile[1]]
		local stage = self:stage(p, tile[2])
		GameTooltip:SetText(p.name)
		local stageNames = { "bud", "sprout", "bloom", "mature" }
		GameTooltip:AddLine(string.format("Stage: %s (age %d)", stageNames[stage], tile[2]), 1, 1, 1)
		local dragonBoost = 1 / (1 + 0.05 * Game:AuraMult("Supreme Intellect"))
		local rate = boost[1] * (p.ageTick + p.ageTickR / 2) / dragonBoost
		if stage < 4 then
			local ticks = math.ceil((100 / rate) * ((p.mature - tile[2]) / 100))
			GameTooltip:AddLine(string.format("Mature in about %s (%d ticks)", NS.FormatDuration(ticks * self.stepT), ticks), 0.8, 0.8, 0.8, true)
		elseif not p.immortal then
			local ticks = math.ceil((100 / rate) * ((100 - tile[2]) / 100))
			GameTooltip:AddLine(string.format("Decays in about %s (%d ticks)", NS.FormatDuration(ticks * self.stepT), ticks), 0.8, 0.8, 0.8, true)
		else
			GameTooltip:AddLine("Does not decay", 0.8, 0.8, 0.8)
		end
		GameTooltip:AddLine("Effects: " .. p.effs, 0.5, 1, 0.5, true)
		GameTooltip:AddLine("Click to harvest.", 0.6, 0.6, 0.6)
	end
	if boost[1] ~= 1 then GameTooltip:AddLine(string.format("Aging multiplier: %d%%", boost[1] * 100), 0.7, 0.7, 0.7) end
	if boost[2] ~= 1 then GameTooltip:AddLine(string.format("Effect multiplier: %d%%", boost[2] * 100), 0.7, 0.7, 0.7) end
	if boost[3] ~= 1 then GameTooltip:AddLine(string.format("Weeds/fungus repellent: %d%%", 100 - boost[3] * 100), 0.7, 0.7, 0.7) end
end

function G:refresh(panel)
	local st = self.state
	if not st or not panel.Plot then
		return
	end
	local soilIcon = math.min(3, self.soils[st.soil].icon)
	for y = 1, 6 do
		for x = 1, 6 do
			local t = panel.Plot.Tiles[y][x]
			local unlocked = self:isTileUnlocked(x - 1, y - 1)
			if unlocked then
				NS.SetSheetCell(t.Soil, "gardenPlots", 40, 40, soilIcon, 0)
				t.Soil:SetVertexColor(1, 1, 1, st.freeze and 0.6 or 1)
				t:SetAlpha(1)
			else
				t.Soil:SetTexture(NS.UI.WHITE)
				t.Soil:SetVertexColor(0, 0, 0, 0.5)
				t:SetAlpha(0.5)
			end
			local tile = st.plot[y][x]
			if tile[1] > 0 and unlocked then
				local p = self.plants[tile[1]]
				SetPlantIcon(t.Plant, self:stage(p, tile[2]), p.icon)
				t.Plant:Show()
			else
				t.Plant:Hide()
			end
		end
	end
	-- Seeds: unlocked ones in order, greyed for locked.
	local sx, sy = panel.seedsX, panel.seedsY
	local shown = 0
	for i, c in ipairs(panel.Seeds) do
		local p = c.plant
		local unlocked = st.unlocked[p.key]
		local col, row = shown % 4, math.floor(shown / 4)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", sx + col * 24, sy - row * 24)
		shown = shown + 1
		if unlocked then
			SetPlantIcon(c.Icon, 0, p.icon)
			c.Icon:SetDesaturated(false)
			c:SetAlpha(p.plantable and 1 or 0.6)
		else
			NS.SetIcon(c.Icon, { 0, 7 })
			c:SetAlpha(0.3)
		end
		c.Sel:SetShown(self.seedSelected == p.id)
	end
	for i, c in ipairs(panel.Soils) do
		c.Sel:SetShown(st.soil == i)
		c:SetAlpha(Game:Count("Farm") >= self.soils[i].req and 1 or 0.35)
	end
	panel.Tools[2].Icon:SetVertexColor(st.freeze and 0.6 or 1, st.freeze and 0.8 or 1, 1)
	panel.Tools[3]:SetShown(self:unlockedN() >= #self.plants)
	local effText = {}
	local names = { cps = "CpS", click = "cookies/click", cursorCps = "cursor CpS", grandmaCps = "grandma CpS", goldenCookieGain = "golden cookie gains", goldenCookieFreq = "golden cookie frequency", goldenCookieDur = "golden cookie duration", goldenCookieEffDur = "golden cookie effect duration", wrathCookieGain = "wrath cookie gains", wrathCookieFreq = "wrath cookie frequency", reindeerGain = "reindeer gains", reindeerFreq = "reindeer frequency", itemDrops = "random drops", milk = "milk effects", wrinklerSpawn = "wrinkler spawn rate", wrinklerEat = "wrinkler appetite", upgradeCost = "upgrade costs", buildingCost = "building costs" }
	for key, v in pairs(self.effs or {}) do
		if v ~= 1 and names[key] then
			table.insert(effText, string.format("%s %s%.2f%%", names[key], v > 1 and "+" or "", (v - 1) * 100))
		end
	end
	table.sort(effText)
	local next = st.freeze and "frozen" or ("next tick in " .. NS.FormatDuration(math.max(0, st.nextStep - Now())))
	panel.Status:SetText(string.format("Seeds: %d/%d. Soil: %s, %s. Harvests: %d. %s", self:unlockedN(), #self.plants, self.soils[st.soil].name, next, st.harvests or 0, #effText > 0 and ("Effects: " .. table.concat(effText, ", ")) or "No effects."))
	self.dirty = false
end

NS.Minigames:Register(G)
