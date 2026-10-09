-- MauCookie data: buildings, upgrades and achievements.
--
-- Numbers follow the original game's first fourteen buildings.  Icons are
-- classic icon files that every client has.

local _, NS = ...

local ICONS = "Interface\\Icons\\"

NS.BUILDINGS = {
	{ id = "cursor", name = "Cursor", cost = 15, cps = 0.1, icon = "INV_Gauntlets_04", desc = "Autoclicks once every 10 seconds." },
	{ id = "grandma", name = "Grandma", cost = 100, cps = 1, icon = "INV_Misc_Head_Human_01", desc = "A nice grandma to bake more cookies." },
	{ id = "farm", name = "Farm", cost = 1100, cps = 8, icon = "Trade_Herbalism", desc = "Grows cookie plants from cookie seeds." },
	{ id = "mine", name = "Mine", cost = 12000, cps = 47, icon = "Trade_Mining", desc = "Mines out cookie dough and chocolate chips." },
	{ id = "factory", name = "Factory", cost = 130000, cps = 260, icon = "Trade_Engineering", desc = "Produces large quantities of cookies." },
	{ id = "bank", name = "Bank", cost = 1400000, cps = 1400, icon = "INV_Misc_Coin_02", desc = "Generates cookies from interest." },
	{ id = "temple", name = "Temple", cost = 20000000, cps = 7800, icon = "Spell_Holy_PrayerOfHealing", desc = "Full of precious, ancient chocolate." },
	{ id = "wizard", name = "Wizard tower", cost = 330000000, cps = 44000, icon = "INV_Misc_Orb_01", desc = "Summons cookies with magic spells." },
	{ id = "shipment", name = "Shipment", cost = 5100000000, cps = 260000, icon = "INV_Crate_01", desc = "Brings in fresh cookies from the cookie planet." },
	{ id = "alchemy", name = "Alchemy lab", cost = 75000000000, cps = 1600000, icon = "Trade_Alchemy", desc = "Turns gold into cookies!" },
	{ id = "portal", name = "Portal", cost = 1e12, cps = 1e7, icon = "Spell_Arcane_PortalOrgrimmar", desc = "Opens a door to the Cookieverse." },
	{ id = "timemachine", name = "Time machine", cost = 1.4e13, cps = 6.5e7, icon = "Spell_Nature_TimeStop", desc = "Brings cookies from the past, before they were even eaten." },
	{ id = "antimatter", name = "Antimatter condenser", cost = 1.7e14, cps = 4.3e8, icon = "Spell_Arcane_StarFire", desc = "Condenses the antimatter in the universe into cookies." },
	{ id = "prism", name = "Prism", cost = 2.1e15, cps = 2.9e9, icon = "INV_Misc_Gem_Diamond_01", desc = "Converts light itself into cookies." },
}

NS.BUILDING_BY_ID = {}
for index, b in ipairs(NS.BUILDINGS) do
	b.index = index
	b.iconPath = ICONS .. b.icon
	NS.BUILDING_BY_ID[b.id] = b
end

-- Five upgrades per building: tier k needs `TIER_OWNED[k]` of the building,
-- costs the building's base price times TIER_COST[k] and doubles its output.
local TIER_OWNED = { 1, 5, 25, 50, 100 }
local TIER_COST = { 10, 50, 500, 5000, 50000 }
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
			iconPath = b.iconPath,
			desc = string.format("%ss are twice as efficient.%s", b.name, b.id == "cursor" and " Clicking too." or ""),
		})
	end
end

-- Mice: clicking gains 1% of the cookies per second each.  Unlock by cookies
-- baked.
local MICE = { { "Plastic mouse", 50000 }, { "Iron mouse", 5e6 }, { "Titanium mouse", 5e8 }, { "Adamantium mouse", 5e10 }, { "Unobtainium mouse", 5e12 } }
for i, m in ipairs(MICE) do
	AddUpgrade({
		id = "mouse" .. i, kind = "mouse", name = m[1], cost = m[2], unlockBaked = m[2] / 10,
		iconPath = ICONS .. "INV_Misc_Gear_01", desc = "Clicking gains +1% of your cookies per second.",
	})
end

-- Cookie flavours: +2% to all production each.
local FLAVOURS = {
	{ "Plain cookies", 999999 }, { "Sugar cookies", 999999 }, { "Oatmeal raisin cookies", 9999999 }, { "Peanut butter cookies", 9999999 },
	{ "Coconut cookies", 99999999 }, { "White chocolate cookies", 99999999 }, { "Macadamia nut cookies", 999999999 },
	{ "Double-chip cookies", 999999999 }, { "White chocolate macadamia nut cookies", 9999999999 }, { "All-chocolate cookies", 9999999999 },
	{ "Dark chocolate-coated cookies", 99999999999 }, { "White chocolate-coated cookies", 99999999999 },
}
for i, c in ipairs(FLAVOURS) do
	AddUpgrade({
		id = "flavour" .. i, kind = "flavour", name = c[1], cost = c[2], unlockBaked = c[2] / 10,
		iconPath = ICONS .. "INV_Misc_Food_19", desc = "Cookie production +2%.",
	})
end

-- Luck: golden cookies twice as often each.  Unlock by golden cookies clicked.
AddUpgrade({ id = "luck1", kind = "luck", name = "Lucky day", cost = 777777, requiresGolden = 7, iconPath = ICONS .. "INV_Misc_Coin_01", desc = "Golden cookies appear twice as often." })
AddUpgrade({ id = "luck2", kind = "luck", name = "Serendipity", cost = 77777777, requiresGolden = 27, iconPath = ICONS .. "INV_Misc_Coin_01", desc = "Golden cookies appear twice as often." })

NS.UPGRADE_BY_ID = {}
for _, u in ipairs(NS.UPGRADES) do
	NS.UPGRADE_BY_ID[u.id] = u
end

-- Achievements: { id, name, desc, check(save, game) }.  Each unlocked one
-- adds 1% to production.
NS.ACHIEVEMENTS = {}

local function Ach(id, name, desc, check)
	table.insert(NS.ACHIEVEMENTS, { id = id, name = name, desc = desc, check = check })
end

local BAKED = {
	{ "Wake and bake", 1 }, { "Making some dough", 1000 }, { "So baked right now", 1e5 }, { "Fledgling bakery", 1e6 },
	{ "Affluent bakery", 1e7 }, { "World-famous bakery", 1e8 }, { "Cosmic bakery", 1e9 }, { "Galactic bakery", 1e10 },
	{ "Universal bakery", 1e11 }, { "Timeless bakery", 1e12 }, { "Infinite bakery", 1e13 }, { "Immortal bakery", 1e14 },
	{ "Don't stop me now", 1e15 }, { "You can stop now", 1e16 },
}
for i, a in ipairs(BAKED) do
	local n = a[2]
	Ach("baked" .. i, a[1], "Bake " .. NS.Beautify(n) .. " cookies in one playthrough.", function(save)
		return save.baked >= n
	end)
end

local CPS = {
	{ "Casual baking", 1 }, { "Hardcore baking", 10 }, { "Steady tasty stream", 100 }, { "Cookie monster", 1000 },
	{ "Mass producer", 1e4 }, { "Cookie vortex", 1e5 }, { "Cookie pulsar", 1e6 }, { "Cookie quasar", 1e7 }, { "Oh hey, you're still here", 1e8 },
}
for i, a in ipairs(CPS) do
	local n = a[2]
	Ach("cps" .. i, a[1], "Bake " .. NS.Beautify(n) .. " cookies per second.", function(_, game)
		return game:Cps(false) >= n
	end)
end

local HANDMADE = { { "Clicktastic", 1000 }, { "Clickathlon", 1e5 }, { "Clickolympics", 1e7 }, { "Clickorama", 1e9 } }
for i, a in ipairs(HANDMADE) do
	local n = a[2]
	Ach("hand" .. i, a[1], "Make " .. NS.Beautify(n) .. " cookies from clicking.", function(save)
		return save.handmade >= n
	end)
end

local TOTALS = { { "Builder", 1 }, { "Architect", 50 }, { "Engineer", 100 }, { "Tycoon", 200 }, { "Mogul", 300 }, { "Magnate", 400 } }
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

local GOLDEN = { { "Golden cookie", 1 }, { "Lucky cookie", 7 }, { "A stroke of luck", 27 }, { "Fortune", 77 } }
for i, a in ipairs(GOLDEN) do
	local n = a[2]
	Ach("golden" .. i, a[1], "Click " .. n .. " golden cookie" .. (n == 1 and "" or "s") .. ".", function(save)
		return save.golden >= n
	end)
end

local UPGRADED = { { "Enhancer", 5 }, { "Augmenter", 20 }, { "Upgrader", 50 } }
for i, a in ipairs(UPGRADED) do
	local n = a[2]
	Ach("upg" .. i, a[1], "Buy " .. n .. " upgrades.", function(_, game)
		return game:UpgradesBought() >= n
	end)
end

NS.ACHIEVEMENT_BY_ID = {}
for _, a in ipairs(NS.ACHIEVEMENTS) do
	NS.ACHIEVEMENT_BY_ID[a.id] = a
end
