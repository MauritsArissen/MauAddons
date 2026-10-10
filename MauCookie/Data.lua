-- MauCookie data: buildings, upgrades, heavenly upgrades and achievements.
--
-- Numbers follow the original game's twenty buildings.  Icons are cells of
-- the original icon sheet (column, row), cut into Textures\icon_<c>_<r>.tga.

local _, NS = ...

-- Tier k of a building's upgrades uses icon row TIER_ROWS[k] in the
-- building's icon column.
local TIER_ROWS = { 0, 1, 2, 13, 14 }
local TIER_OWNED = { 1, 5, 25, 50, 100 }
local TIER_COST = { 10, 50, 500, 5000, 50000 }

NS.BUILDINGS = {
	{ id = "cursor", name = "Cursor", cost = 15, cps = 0.1, col = 0, desc = "Autoclicks once every 10 seconds." },
	{ id = "grandma", name = "Grandma", cost = 100, cps = 1, col = 1, desc = "A nice grandma to bake more cookies." },
	{ id = "farm", name = "Farm", cost = 1100, cps = 8, col = 2, desc = "Grows cookie plants from cookie seeds." },
	{ id = "mine", name = "Mine", cost = 12000, cps = 47, col = 3, desc = "Mines out cookie dough and chocolate chips." },
	{ id = "factory", name = "Factory", cost = 130000, cps = 260, col = 4, desc = "Produces large quantities of cookies." },
	{ id = "bank", name = "Bank", cost = 1400000, cps = 1400, col = 15, desc = "Generates cookies from interest." },
	{ id = "temple", name = "Temple", cost = 20000000, cps = 7800, col = 16, desc = "Full of precious, ancient chocolate." },
	{ id = "wizard", name = "Wizard tower", cost = 330000000, cps = 44000, col = 17, desc = "Summons cookies with magic spells." },
	{ id = "shipment", name = "Shipment", cost = 5100000000, cps = 260000, col = 5, desc = "Brings in fresh cookies from the cookie planet." },
	{ id = "alchemy", name = "Alchemy lab", cost = 75000000000, cps = 1600000, col = 6, desc = "Turns gold into cookies!" },
	{ id = "portal", name = "Portal", cost = 1e12, cps = 1e7, col = 7, desc = "Opens a door to the Cookieverse." },
	{ id = "timemachine", name = "Time machine", cost = 1.4e13, cps = 6.5e7, col = 8, desc = "Brings cookies from the past, before they were even eaten." },
	{ id = "antimatter", name = "Antimatter condenser", cost = 1.7e14, cps = 4.3e8, col = 13, desc = "Condenses the antimatter in the universe into cookies." },
	{ id = "prism", name = "Prism", cost = 2.1e15, cps = 2.9e9, col = 14, desc = "Converts light itself into cookies." },
	{ id = "chancemaker", name = "Chancemaker", cost = 2.6e16, cps = 2.1e10, col = 19, desc = "Generates cookies out of thin air through sheer luck." },
	{ id = "fractal", name = "Fractal engine", cost = 3.1e17, cps = 1.5e11, col = 20, desc = "Turns cookies into even more cookies." },
	{ id = "javascript", name = "Javascript console", cost = 7.1e19, cps = 1.1e12, col = 32, desc = "Creates cookies from the very code this game was written in." },
	{ id = "idleverse", name = "Idleverse", cost = 1.2e22, cps = 8.3e12, col = 33, desc = "Hooks into countless other idle universes and profits off their production." },
	{ id = "cortex", name = "Cortex baker", cost = 1.9e24, cps = 6.4e13, col = 34, desc = "Artificial brains the size of planets, thinking up new ways of making cookies." },
	{ id = "you", name = "You", cost = 5.4e26, cps = 5.1e14, col = 35, desc = "You, alone, are the one thing that can bake more cookies: so let's make more of you." },
}

NS.BUILDING_BY_ID = {}
for index, b in ipairs(NS.BUILDINGS) do
	b.index = index
	NS.BUILDING_BY_ID[b.id] = b
end

local TIER_NAMES = {
	cursor = { "Reinforced index finger", "Carpal tunnel prevention cream", "Ambidextrous", "Thousand fingers", "Million fingers" },
	grandma = { "Forwards from grandma", "Steel-plated rolling pins", "Lubricated dentures", "Prune juice", "Double-thick glasses" },
	farm = { "Cheap hoes", "Fertilizer", "Cookie trees", "Genetically-modified cookies", "Gingerbread scarecrows" },
	mine = { "Sugar gas", "Megadrill", "Ultradrill", "Ultimadrill", "H-bomb mining" },
	factory = { "Sturdier conveyor belts", "Child labor", "Sweatshop", "Radium reactors", "Recombobulators" },
	bank = { "Taller tellers", "Scissor-resistant credit cards", "Acid-proof vaults", "Chocolate coins", "Exponential interest rates" },
	temple = { "Golden idols", "Sacrifices", "Delicious blessing", "Sun festival", "Enlarged pantheon" },
	wizard = { "Pointier hats", "Beardlier beards", "Ancient grimoires", "Kitchen curses", "School of sorcery" },
	shipment = { "Vanilla nebulae", "Wormholes", "Frequent flyer", "Warp drive", "Chocolate monoliths" },
	alchemy = { "Antimony", "Essence of dough", "True chocolate", "Ambrosia", "Aqua crustulae" },
	portal = { "Ancient tablet", "Insane oatling workers", "Soul bond", "Sanity dance", "Brane transplant" },
	timemachine = { "Flux capacitors", "Time paradox resolver", "Quantum conundrum", "Causality enforcer", "Yestermorrow comparators" },
	antimatter = { "Sugar bosons", "String theory", "Large macaron collider", "Big bang bake", "Reverse cyclotrons" },
	prism = { "Gem polish", "9th color", "Chocolate light", "Grainbow", "Pure cosmic light" },
	chancemaker = { "Your lucky cookie", "All Bets Are Off magic coin", "Winning lottery ticket", "Four-leaf clover field", "A recipe book about books" },
	fractal = { "Metabakeries", "Mandelbrown sugar", "Fractoids", "Nested universe theory", "Menger sponge cake" },
	javascript = { "The JavaScript console for dummies", "64bit arrays", "Stack overflow", "Enterprise compiler", "Syntactic sugar" },
	idleverse = { "Manifest destiny", "The multiverse in a nutshell", "All-conversion", "Multiverse agents", "Escape plan" },
	cortex = { "Principled neural shackles", "Obey", "A sprinkle of irrationality", "Front and back hemispheres", "Neural networking" },
	you = { "Cloning vats", "Energized nutrients", "Stunt doubles", "Clone recycling plant", "Free-range clones" },
}

NS.UPGRADES = {}

local function AddUpgrade(u)
	table.insert(NS.UPGRADES, u)
end

for _, b in ipairs(NS.BUILDINGS) do
	for tier = 1, 5 do
		AddUpgrade({
			id = b.id .. tier,
			kind = "building",
			building = b.id,
			tier = tier,
			name = TIER_NAMES[b.id][tier],
			cost = b.cost * TIER_COST[tier],
			requires = TIER_OWNED[tier],
			icon = { b.col, TIER_ROWS[tier] },
			desc = string.format("%ss are twice as efficient.%s", b.name, b.id == "cursor" and " Clicking too." or ""),
		})
	end
end

-- Mice: clicking gains 1% of the cookies per second each.
local MICE = { { "Plastic mouse", 50000 }, { "Iron mouse", 5e6 }, { "Titanium mouse", 5e8 }, { "Adamantium mouse", 5e10 }, { "Unobtainium mouse", 5e12 } }
for i, m in ipairs(MICE) do
	AddUpgrade({
		id = "mouse" .. i, kind = "mouse", name = m[1], cost = m[2], unlockBaked = m[2] / 10,
		icon = { 11, TIER_ROWS[i] }, desc = "Clicking gains +1% of your cookies per second.",
	})
end

-- Cookie flavours: +2% to all production each.
local FLAVOURS = {
	{ "Plain cookies", 999999, 10, 3 }, { "Sugar cookies", 999999, 11, 3 }, { "Oatmeal raisin cookies", 9999999, 12, 3 },
	{ "Peanut butter cookies", 9999999, 13, 3 }, { "Coconut cookies", 99999999, 14, 3 }, { "White chocolate cookies", 99999999, 15, 3 },
	{ "Macadamia nut cookies", 999999999, 16, 3 }, { "Double-chip cookies", 999999999, 17, 3 },
	{ "White chocolate macadamia nut cookies", 9999999999, 18, 3 }, { "All-chocolate cookies", 9999999999, 19, 3 },
	{ "Dark chocolate-coated cookies", 99999999999, 11, 4 }, { "White chocolate-coated cookies", 99999999999, 12, 4 },
}
for i, c in ipairs(FLAVOURS) do
	AddUpgrade({
		id = "flavour" .. i, kind = "flavour", name = c[1], cost = c[2], unlockBaked = c[2] / 10,
		icon = { c[3], c[4] }, desc = "Cookie production +2%.",
	})
end

-- Kittens: production grows with milk (4% per achievement).
NS.KITTENS = {
	{ "Kitten helpers", 9e6, 0.1 }, { "Kitten workers", 9e9, 0.125 }, { "Kitten engineers", 9e13, 0.15 }, { "Kitten overseers", 9e16, 0.175 },
	{ "Kitten managers", 9e20, 0.2 }, { "Kitten accountants", 9e23, 0.2 }, { "Kitten specialists", 9e26, 0.2 }, { "Kitten experts", 9e29, 0.2 },
}
for i, k in ipairs(NS.KITTENS) do
	AddUpgrade({
		id = "kitten" .. i, kind = "kitten", name = k[1], cost = k[2], unlockBaked = k[2] / 10, factor = k[3],
		icon = { 18, i - 1 }, desc = string.format("You gain more cookies per second the more milk you have: production x(1 + milk x %g). Milk is 4%% per achievement.", k[3]),
	})
end

-- Luck: golden cookies twice as often each; Get lucky doubles their effects' length.
AddUpgrade({ id = "luck1", kind = "luck", name = "Lucky day", cost = 777777, requiresGolden = 7, icon = { 27, 6 }, desc = "Golden cookies appear twice as often." })
AddUpgrade({ id = "luck2", kind = "luck", name = "Serendipity", cost = 77777777, requiresGolden = 27, icon = { 27, 7 }, desc = "Golden cookies appear twice as often." })
AddUpgrade({ id = "luck3", kind = "lucklong", name = "Get lucky", cost = 77777777777, requiresGolden = 77, icon = { 27, 8 }, desc = "Golden cookie effects last twice as long." })

NS.UPGRADE_BY_ID = {}
for _, u in ipairs(NS.UPGRADES) do
	NS.UPGRADE_BY_ID[u.id] = u
end

-- Heavenly upgrades: bought with heavenly chips, kept across ascensions.
NS.HEAVENLY = {
	{ id = "heavenlycookies", name = "Heavenly cookies", cost = 3, icon = { 19, 7 }, desc = "Cookie production +10%." },
	{ id = "starterkit", name = "Starter kit", cost = 50, icon = { 0, 14 }, desc = "You start every ascension with 10 cursors." },
	{ id = "heavenlyluck", name = "Heavenly luck", cost = 77, icon = { 10, 14 }, desc = "Golden cookies appear twice as often." },
	{ id = "starterkitchen", name = "Starter kitchen", cost = 100, icon = { 1, 14 }, desc = "You start every ascension with 5 grandmas." },
	{ id = "heavenlykey", name = "Heavenly key", cost = 500, icon = { 19, 7 }, desc = "Cookie production +25%." },
}
NS.HEAVENLY_BY_ID = {}
for _, h in ipairs(NS.HEAVENLY) do
	NS.HEAVENLY_BY_ID[h.id] = h
end

-- Achievements: { id, name, desc, check(save, game) }.  Each unlocked one
-- adds 1% to production and 4% milk.
NS.ACHIEVEMENTS = {}

local function Ach(id, name, desc, check)
	table.insert(NS.ACHIEVEMENTS, { id = id, name = name, desc = desc, check = check })
end

local BAKED = {
	{ "Wake and bake", 1 }, { "Making some dough", 1000 }, { "So baked right now", 1e5 }, { "Fledgling bakery", 1e6 },
	{ "Affluent bakery", 1e7 }, { "World-famous bakery", 1e8 }, { "Cosmic bakery", 1e9 }, { "Galactic bakery", 1e10 },
	{ "Universal bakery", 1e11 }, { "Timeless bakery", 1e12 }, { "Infinite bakery", 1e13 }, { "Immortal bakery", 1e14 },
	{ "Don't stop me now", 1e15 }, { "You can stop now", 1e16 }, { "Cookies all the way down", 1e17 }, { "Overdose", 1e18 },
}
for i, a in ipairs(BAKED) do
	local n = a[2]
	Ach("baked" .. i, a[1], "Bake " .. NS.Beautify(n) .. " cookies in one run.", function(save)
		return save.baked >= n
	end)
end

local CPS = {
	{ "Casual baking", 1 }, { "Hardcore baking", 10 }, { "Steady tasty stream", 100 }, { "Cookie monster", 1000 },
	{ "Mass producer", 1e4 }, { "Cookie vortex", 1e5 }, { "Cookie pulsar", 1e6 }, { "Cookie quasar", 1e7 }, { "Oh hey, you're still here", 1e8 },
	{ "Let's never bake again", 1e9 }, { "Sacrifice", 1e10 },
}
for i, a in ipairs(CPS) do
	local n = a[2]
	Ach("cps" .. i, a[1], "Bake " .. NS.Beautify(n) .. " cookies per second.", function(_, game)
		return game:Cps(false) >= n
	end)
end

local HANDMADE = { { "Clicktastic", 1000 }, { "Clickathlon", 1e5 }, { "Clickolympics", 1e7 }, { "Clickorama", 1e9 }, { "Clickasmic", 1e11 } }
for i, a in ipairs(HANDMADE) do
	local n = a[2]
	Ach("hand" .. i, a[1], "Make " .. NS.Beautify(n) .. " cookies from clicking.", function(save)
		return save.handmade >= n
	end)
end

local TOTALS = { { "Builder", 1 }, { "Architect", 50 }, { "Engineer", 100 }, { "Tycoon", 200 }, { "Mogul", 300 }, { "Magnate", 400 }, { "Polymath", 600 } }
for i, a in ipairs(TOTALS) do
	local n = a[2]
	Ach("total" .. i, a[1], "Own " .. n .. " buildings.", function(_, game)
		return game:TotalBuildings() >= n
	end)
end

Ach("grandmas50", "Grandma's cookies", "Own 50 grandmas.", function(save)
	return (save.buildings.grandma or 0) >= 50
end)
Ach("grandmas100", "Elder", "Own 100 grandmas.", function(save)
	return (save.buildings.grandma or 0) >= 100
end)
Ach("cursors100", "Click delegation", "Own 100 cursors.", function(save)
	return (save.buildings.cursor or 0) >= 100
end)
Ach("oneofeach", "One of everything", "Own at least one of every building.", function(save)
	for _, b in ipairs(NS.BUILDINGS) do
		if (save.buildings[b.id] or 0) < 1 then
			return false
		end
	end
	return true
end)

local GOLDEN = { { "Golden cookie", 1 }, { "Lucky cookie", 7 }, { "A stroke of luck", 27 }, { "Fortune", 77 }, { "Leprechaun", 777 } }
for i, a in ipairs(GOLDEN) do
	local n = a[2]
	Ach("golden" .. i, a[1], "Click " .. n .. " golden cookie" .. (n == 1 and "" or "s") .. ".", function(save)
		return save.golden >= n
	end)
end

local UPGRADED = { { "Enhancer", 5 }, { "Augmenter", 20 }, { "Upgrader", 50 }, { "Perfectionist", 100 } }
for i, a in ipairs(UPGRADED) do
	local n = a[2]
	Ach("upg" .. i, a[1], "Buy " .. n .. " upgrades.", function(_, game)
		return game:UpgradesBought() >= n
	end)
end

local ASCENDED = { { "Rebirth", 1 }, { "Oblivion", 5 }, { "From scratch", 10 } }
for i, a in ipairs(ASCENDED) do
	local n = a[2]
	Ach("asc" .. i, a[1], "Ascend " .. n .. " time" .. (n == 1 and "" or "s") .. ".", function(save)
		return (save.ascensions or 0) >= n
	end)
end

NS.ACHIEVEMENT_BY_ID = {}
for _, a in ipairs(NS.ACHIEVEMENTS) do
	NS.ACHIEVEMENT_BY_ID[a.id] = a
end
