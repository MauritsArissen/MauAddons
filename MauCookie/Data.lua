-- MauCookie data: buildings, upgrades, research, synergies, heavenly
-- upgrades, achievements, news ticker.
--
-- Numbers follow the original game.  Icons are cells of the original icon
-- sheet (column, row), cut into Textures\icon_<c>_<r>.tga.

local _, NS = ...

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
	return u
end

for _, b in ipairs(NS.BUILDINGS) do
	for tier = 1, 5 do
		AddUpgrade({
			id = b.id .. tier, kind = "building", building = b.id, tier = tier,
			name = TIER_NAMES[b.id][tier], cost = b.cost * TIER_COST[tier], requires = TIER_OWNED[tier],
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

-- Luck.
AddUpgrade({ id = "luck1", kind = "luck", name = "Lucky day", cost = 777777, requiresGolden = 7, icon = { 27, 6 }, desc = "Golden cookies appear twice as often." })
AddUpgrade({ id = "luck2", kind = "luck", name = "Serendipity", cost = 77777777, requiresGolden = 27, icon = { 27, 7 }, desc = "Golden cookies appear twice as often." })
AddUpgrade({ id = "luck3", kind = "lucklong", name = "Get lucky", cost = 77777777777, requiresGolden = 77, icon = { 27, 8 }, desc = "Golden cookie effects last twice as long." })

-- Grandma types: grandmas twice as efficient, the building gains +1% per
-- (index - 2) grandmas.  Need 15 grandmas and 15 of the building.
local GRANDMA_TYPES = {
	farm = "Farmer grandmas", mine = "Miner grandmas", factory = "Worker grandmas", bank = "Banker grandmas", temple = "Priestess grandmas",
	wizard = "Witch grandmas", shipment = "Cosmic grandmas", alchemy = "Transmuted grandmas", portal = "Altered grandmas",
	timemachine = "Grandmas' grandmas", antimatter = "Antigrandmas", prism = "Rainbow grandmas", chancemaker = "Lucky grandmas",
	fractal = "Metagrandmas", javascript = "Binary grandmas", idleverse = "Alternate grandmas", cortex = "Brainy grandmas", you = "Clone grandmas",
}
NS.GRANDMA_TYPE_BY_BUILDING = {}
for _, b in ipairs(NS.BUILDINGS) do
	local name = GRANDMA_TYPES[b.id]
	if name then
		local per = b.index - 2
		local u = AddUpgrade({
			id = "gtype_" .. b.id, kind = "grandmatype", building = b.id, per = per, name = name, cost = b.cost * 15,
			icon = { b.col, 1 },
			desc = string.format("Grandmas are twice as efficient. %ss gain +1%% CpS per %d grandma%s.", b.name, per, per == 1 and "" or "s"),
		})
		NS.GRANDMA_TYPE_BY_BUILDING[b.id] = u
	end
end

-- Research: the Bingo center, then one discovery after the other.  Three of
-- them wake the grandmas (Grandmapocalypse stages 1, 2, 3).
NS.RESEARCH = {
	{ id = "bingo", name = "Bingo center/Research facility", cost = 1e15, grandmaMult = 4, desc = "Grandma-operated science lab, dedicated to the study of cookies. Grandmas are 4 times as efficient. Unlocks research." },
	{ id = "research1", name = "Specialized chocolate chips", cost = 1e15, mult = 1.01, desc = "Cookie production +1%." },
	{ id = "research2", name = "Designer cocoa beans", cost = 2e15, mult = 1.02, desc = "Cookie production +2%." },
	{ id = "research3", name = "Ritual rolling pins", cost = 4e15, grandmaMult = 2, desc = "Grandmas are twice as efficient." },
	{ id = "research4", name = "Underworld ovens", cost = 8e15, mult = 1.03, desc = "Cookie production +3%." },
	{ id = "research5", name = "One mind", cost = 1.6e16, perGrandma = 0.02, stage = 1, desc = "Each grandma gains +0.02 base CpS per grandma. The grandmas are starting to seem a little strange." },
	{ id = "research6", name = "Exotic nuts", cost = 3.2e16, mult = 1.04, desc = "Cookie production +4%." },
	{ id = "research7", name = "Communal brainsweep", cost = 6.4e16, perGrandma = 0.02, stage = 2, desc = "Each grandma gains another +0.02 base CpS per grandma. The grandmas are getting restless." },
	{ id = "research8", name = "Arcane sugar", cost = 1.28e17, mult = 1.05, desc = "Cookie production +5%." },
	{ id = "research9", name = "Elder Pact", cost = 2.56e17, perPortal = 0.05, stage = 3, desc = "Each grandma gains +0.05 base CpS per portal. The grandmas have risen." },
	{ id = "research10", name = "Sacrificial rolling pins", cost = 2.56e18, pledgeDouble = true, desc = "Elder pledges last twice as long." },
}
for order, r in ipairs(NS.RESEARCH) do
	r.kind = "research"
	r.order = order - 1
	r.icon = { 1, (r.stage and 14) or 13 }
	AddUpgrade(r)
end

AddUpgrade({ id = "pledge", kind = "pledge", repeatable = true, name = "Elder Pledge", icon = { 1, 2 }, desc = "Contains the wrath of the elders, at least for a while. Pops every wrinkler. Each pledge costs eight times the last." })
AddUpgrade({ id = "covenant", kind = "covenant", repeatable = true, name = "Elder Covenant", cost = 66666666666666, icon = { 1, 13 }, desc = "Puts a permanent end to the elders' wrath, at the cost of 5% of your CpS." })
AddUpgrade({ id = "revoke", kind = "revoke", repeatable = true, name = "Revoke Elder Covenant", cost = 6666666666666, icon = { 1, 14 }, desc = "You will have to deal with the elders again, but you will regain the 5% of CpS you sacrificed." })
AddUpgrade({ id = "switch", kind = "switch", repeatable = true, name = "Golden switch", icon = { 27, 8 }, desc = "Boosts your CpS by 50% but disables golden cookies while on. Switching it on costs an hour of production." })

-- Synergies: A gains +5% per B, B gains +0.1% per A.  Need 15 of each and
-- the heavenly volume.  Cost: a thousand times the dearer building.
local SYNERGIES = {
	{ 1, "Future almanacs", "farm", "timemachine" }, { 1, "Rain prayer", "farm", "temple" }, { 1, "Seismic magic", "mine", "wizard" },
	{ 1, "Asteroid mining", "mine", "shipment" }, { 1, "Quantum electronics", "factory", "antimatter" }, { 1, "Temporal overclocking", "factory", "timemachine" },
	{ 1, "Contracts from beyond", "bank", "portal" }, { 1, "Printing presses", "bank", "factory" }, { 1, "Paganism", "temple", "portal" },
	{ 1, "God particle", "temple", "antimatter" }, { 1, "Arcane knowledge", "wizard", "alchemy" }, { 1, "Magical botany", "wizard", "farm" },
	{ 1, "Fossil fuels", "shipment", "mine" }, { 1, "Shipyards", "shipment", "factory" }, { 1, "Primordial ores", "alchemy", "mine" },
	{ 1, "Gold fund", "alchemy", "bank" }, { 1, "Infernal crops", "portal", "farm" }, { 1, "Abysmal glimmer", "portal", "prism" },
	{ 2, "Relativistic parsec-skipping", "timemachine", "shipment" }, { 2, "Primeval glow", "timemachine", "prism" },
	{ 2, "Extra physics funding", "antimatter", "bank" }, { 2, "Chemical proficiency", "antimatter", "alchemy" },
	{ 2, "Light magic", "prism", "wizard" }, { 2, "Mystical energies", "prism", "temple" }, { 2, "Gemmed talismans", "chancemaker", "mine" },
	{ 2, "Charm quarks", "chancemaker", "antimatter" }, { 2, "Recursive mirrors", "fractal", "prism" }, { 2, "Mice clicking mice", "fractal", "cursor" },
	{ 2, "Boolean fiction", "javascript", "cortex" }, { 2, "Reverse-engineered trade routes", "idleverse", "shipment" },
	{ 2, "Thoughts and prayers", "cortex", "temple" }, { 2, "Self-help cults", "you", "cortex" },
}
NS.SYNERGY_BY_BUILDING = {}
for i, s in ipairs(SYNERGIES) do
	local a, b = NS.BUILDING_BY_ID[s[3]], NS.BUILDING_BY_ID[s[4]]
	local u = AddUpgrade({
		id = "syn" .. i, kind = "synergy", vol = s[1], name = s[2], a = a.id, b = b.id, cost = 1000 * math.max(a.cost, b.cost),
		icon = { a.col, 2 },
		desc = string.format("%ss gain +5%% CpS per %s. %ss gain +0.1%% CpS per %s. (Synergies Vol. %s)", a.name, b.name:lower(), b.name, a.name:lower(), s[1] == 1 and "I" or "II"),
	})
	NS.SYNERGY_BY_BUILDING[a.id] = NS.SYNERGY_BY_BUILDING[a.id] or {}
	NS.SYNERGY_BY_BUILDING[b.id] = NS.SYNERGY_BY_BUILDING[b.id] or {}
	table.insert(NS.SYNERGY_BY_BUILDING[a.id], u)
	table.insert(NS.SYNERGY_BY_BUILDING[b.id], u)
end

NS.UPGRADE_BY_ID = {}
for _, u in ipairs(NS.UPGRADES) do
	NS.UPGRADE_BY_ID[u.id] = u
end

-- Heavenly upgrades: bought with heavenly chips, kept across ascensions.
NS.HEAVENLY = {
	{ id = "heavenlycookies", name = "Heavenly cookies", cost = 3, icon = { 19, 7 }, desc = "Cookie production +10%." },
	{ id = "luckydigit", name = "Lucky digit", cost = 7, icon = { 27, 6 }, desc = "Prestige levels 1% more powerful, golden cookie effects last 1% longer." },
	{ id = "angels", name = "Angels", cost = 7, icon = { 19, 7 }, desc = "Prestige levels are 10% more powerful." },
	{ id = "kittenangels", name = "Kitten angels", cost = 9, icon = { 18, 8 }, factor = 0.1, desc = "A heavenly kitten: production x(1 + milk x 0.1), forever." },
	{ id = "decisivefate", name = "Decisive fate", cost = 11, icon = { 27, 7 }, desc = "Golden cookie effects last 5% longer." },
	{ id = "synergies1", name = "Synergies Vol. I", cost = 20, icon = { 10, 20 }, desc = "Unlocks upgrades that make pairs of buildings boost each other." },
	{ id = "goldenswitch", name = "Golden switch", cost = 30, icon = { 27, 8 }, desc = "Unlocks the Golden switch in the store: +50% CpS while golden cookies are turned off." },
	{ id = "elderspice", name = "Elder spice", cost = 44, icon = { 1, 14 }, desc = "You can attract 2 more wrinklers." },
	{ id = "sacrilegious", name = "Sacrilegious corruption", cost = 44, icon = { 1, 13 }, desc = "Wrinklers regurgitate 5% more cookies." },
	{ id = "starterkit", name = "Starter kit", cost = 50, icon = { 0, 14 }, desc = "You start every ascension with 10 cursors." },
	{ id = "halogloves", name = "Halo gloves", cost = 55, icon = { 11, 14 }, desc = "Clicks are 10% more powerful." },
	{ id = "wrinklycookies", name = "Wrinkly cookies", cost = 66, icon = { 1, 2 }, desc = "Cookie production +10%." },
	{ id = "heavenlyluck", name = "Heavenly luck", cost = 77, icon = { 10, 14 }, desc = "Golden cookies appear twice as often." },
	{ id = "lastingfortune", name = "Lasting fortune", cost = 77, icon = { 27, 7 }, desc = "Golden cookie effects last 10% longer." },
	{ id = "archangels", name = "Archangels", cost = 77, icon = { 19, 7 }, desc = "Prestige levels are 10% more powerful." },
	{ id = "starterkitchen", name = "Starter kitchen", cost = 100, icon = { 1, 14 }, desc = "You start every ascension with 5 grandmas." },
	{ id = "synergies2", name = "Synergies Vol. II", cost = 200, icon = { 10, 20 }, desc = "Unlocks a second volume of synergy upgrades." },
	{ id = "heavenlykey", name = "Heavenly key", cost = 500, icon = { 19, 7 }, desc = "Cookie production +25%." },
	{ id = "virtues", name = "Virtues", cost = 777, icon = { 19, 7 }, desc = "Prestige levels are 10% more powerful." },
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
Ach("grandmas100", "Retirement home", "Own 100 grandmas.", function(save)
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

Ach("elder", "Elder", "Own 7 grandma types.", function(_, game)
	return game:GrandmaTypes() >= 7
end)
Ach("eldernap", "Elder nap", "Appease the grandmatriarchs once.", function(save)
	return (save.pledges or 0) >= 1
end)
Ach("elderslumber", "Elder slumber", "Appease the grandmatriarchs 5 times.", function(save)
	return (save.pledges or 0) >= 5
end)
Ach("eldercalm", "Elder calm", "Declare a covenant with the grandmatriarchs.", function(save)
	return save.covenantEver == true
end)
Ach("wrinkler1", "Itchscratcher", "Burst 1 wrinkler.", function(save)
	return (save.wrinklersPopped or 0) >= 1
end)
Ach("wrinkler50", "Wrinklesquisher", "Burst 50 wrinklers.", function(save)
	return (save.wrinklersPopped or 0) >= 50
end)
Ach("wrinkler200", "Moistburster", "Burst 200 wrinklers.", function(save)
	return (save.wrinklersPopped or 0) >= 200
end)
Ach("justwrong", "Just wrong", "Sell a grandma.", function(save)
	return (save.grandmasSold or 0) >= 1
end)
Ach("chain", "Four-leaf cookie", "Finish a cookie chain.", function(save)
	return (save.chains or 0) >= 1
end)

NS.ACHIEVEMENT_BY_ID = {}
for _, a in ipairs(NS.ACHIEVEMENTS) do
	NS.ACHIEVEMENT_BY_ID[a.id] = a
end

-- News ticker lines, in the spirit of the original.
NS.TICKER = {
	"News: cookie farms suspected of employing undeclared elderly workforce!",
	"News: cookie mines found to contain unusually high amounts of chocolate chips.",
	"News: local factory now producing cookies at an alarming rate.",
	"News: cookie-flavoured mortgages now available at your local bank.",
	"News: temple of cookies draws pilgrims from across the land.",
	"News: wizards accused of turning children into cookies. Children allegedly delicious.",
	"News: shipment of cookies arrives from the cookie planet. Customs baffled.",
	"News: alchemists finally turn gold into cookies, immediately regret it.",
	"News: portal to the Cookieverse opened; dough levels in the atmosphere rising.",
	"News: time machine used to eat cookies before they were baked. Grandmas furious.",
	"News: antimatter condenser causes small spatial anomaly; cookies unaffected.",
	"News: prism owner blinded by own cookies, says it was worth it.",
	"News: cookie clicker addict clicks 10,000 times, develops suspiciously strong finger.",
	"News: man found dead after eating 1,000 cookies. Was it suicide, or murder by grandma?",
	"News: all cookies have been declared legal tender.",
	"News: local grandma says she has 'never felt more alive'.",
	"News: scientists discover that cookies are, in fact, made of dreams.",
	"News: new study finds cookie-induced happiness is 'not a medical condition'.",
	"News: golden cookie sighted in the sky; astronomers urge calm.",
	"News: kittens observed baking; experts suspect milk involvement.",
	"News: economists warn cookie inflation 'baked in' for the foreseeable future.",
	"News: raid delayed by cookie emergency, guild leader reportedly 'fine with it'.",
	"News: flight master reports passengers suspiciously busy on long flights.",
}
NS.TICKER_GRANDMA = {
	[1] = {
		"Grandma: we're here for you.",
		"Grandma: we have always been here.",
		"Grandma: have you ever wondered what is in the cookies?",
		"Grandma: it has begun.",
	},
	[2] = {
		"Grandma: you have no idea what you've unleashed.",
		"Grandma: we will rise.",
		"Grandma: the cookies are not the end. They are the beginning.",
		"Grandma: you are not in control. You never were.",
	},
	[3] = {
		"Grandma: the time of man is over.",
		"Grandma: we feed on your clicks.",
		"Grandma: there is no escape.",
		"Grandma: your pledges mean nothing to us.",
	},
}
