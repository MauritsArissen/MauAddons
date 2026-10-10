-- MauCookie: lookups over the generated data (Data_*.lua).  Everything is
-- keyed by the original's names, which is also how the save stores
-- ownership (save.up[name], save.unl[name], save.ach[name], save.bld[name]).

local _, NS = ...

NS.B, NS.BY_ID = {}, {}            -- buildings by name / by id (0 = Cursor)
NS.U, NS.A = {}, {}                -- upgrades / achievements by name
NS.COOKIE_UPGRADES = {}            -- pool "cookie" (production multipliers)
NS.KITTENS = {}                    -- kitten upgrades in tier order
NS.PRESTIGE_UPGRADES = {}          -- the heavenly tree
NS.FORTUNE_UPGRADES = {}           -- tier "fortune"
NS.SYNERGY_UPGRADES = {}           -- tiers synergy1 / synergy2
NS.TIERED_UPGRADES = {}            -- every upgrade with a numeric tier and a building
NS.ACHIEVEMENT_LIST = {}           -- achievements in display order (pool normal then shadow)

for _, b in ipairs(NS.BUILDINGS) do
	NS.B[b.name] = b
	NS.BY_ID[b.id] = b
	b.tieredList = {}       -- [tier] = upgrade
	b.tieredAchievList = {} -- [tier] = achievement
	b.synergyList = {}      -- upgrades
end

for index, u in ipairs(NS.UPGRADES) do
	u.index = index
	NS.U[u.name] = u
	u.pool = u.pool or ""
	if u.pool == "cookie" then
		table.insert(NS.COOKIE_UPGRADES, u)
	elseif u.pool == "prestige" then
		table.insert(NS.PRESTIGE_UPGRADES, u)
	end
	if u.kitten then
		table.insert(NS.KITTENS, u)
	end
	if u.tier == "fortune" then
		table.insert(NS.FORTUNE_UPGRADES, u)
	elseif u.tier == "synergy1" or u.tier == "synergy2" then
		table.insert(NS.SYNERGY_UPGRADES, u)
	end
end

for index, a in ipairs(NS.ACHIEVEMENTS) do
	a.index = index
	NS.A[a.name] = a
	a.pool = a.pool or "normal"
end

-- Resolve the building ties recorded in the data.
for _, b in ipairs(NS.BUILDINGS) do
	for tier, name in pairs(b.tiered) do
		local u = NS.U[name]
		if u then
			u.buildingTie = b
			u.b1 = u.b1 or b.name
			b.tieredList[tier] = u
			if type(tier) == "number" then
				table.insert(NS.TIERED_UPGRADES, u)
			end
		end
	end
	for tier, name in pairs(b.tieredAchievs) do
		local a = NS.A[name]
		if a then
			a.buildingTie = b
			b.tieredAchievList[tier] = a
		end
	end
	for _, name in ipairs(b.synergies) do
		local u = NS.U[name]
		if u then
			table.insert(b.synergyList, u)
		end
	end
	b.grandmaUpgrade = b.grandma and NS.U[b.grandma] or nil
	b.fortuneUpgrade = b.fortune and NS.U[b.fortune] or nil
	for _, p in ipairs(b.productionAchievs) do
		p.achiev = NS.A[p.name]
	end
end

table.sort(NS.KITTENS, function(a, b)
	return (a.tier or 0) < (b.tier or 0)
end)

-- Heavenly tree: parents as upgrade objects, children lists.
for _, u in ipairs(NS.PRESTIGE_UPGRADES) do
	u.parentList = {}
	u.children = u.children or {}
	for _, pname in ipairs(u.parents or {}) do
		local p = NS.U[pname]
		if p then
			table.insert(u.parentList, p)
			p.children = p.children or {}
			table.insert(p.children, u)
		end
	end
end

-- Achievements in the order the original lists them: normal first, shadow after.
for _, a in ipairs(NS.ACHIEVEMENTS) do
	if a.pool ~= "dungeon" then
		table.insert(NS.ACHIEVEMENT_LIST, a)
	end
end
table.sort(NS.ACHIEVEMENT_LIST, function(a, b)
	if (a.pool == "shadow") ~= (b.pool == "shadow") then
		return a.pool ~= "shadow"
	end
	if a.order ~= b.order then
		return a.order < b.order
	end
	return a.index < b.index
end)

NS.NORMAL_ACHIEVEMENTS = 0
for _, a in ipairs(NS.ACHIEVEMENTS) do
	if a.pool == "normal" then
		NS.NORMAL_ACHIEVEMENTS = NS.NORMAL_ACHIEVEMENTS + 1
	end
end

-- Season trigger upgrades.
NS.SEASON_BY_TRIGGER = {}
for key, s in pairs(NS.SEASONS) do
	s.key = key
	NS.SEASON_BY_TRIGGER[s.trigger] = key
	local u = NS.U[s.trigger]
	if u then
		u.season = u.season or key
		u.seasonTrigger = key
	end
end

-- Lists kept by name in Data_Misc, resolved once.
local function Resolve(names)
	local list = {}
	for _, name in ipairs(names) do
		if NS.U[name] then
			table.insert(list, NS.U[name])
		end
	end
	return list
end
NS.SANTA_DROP_UPGRADES = Resolve(NS.SANTA_DROPS)
NS.REINDEER_DROP_UPGRADES = Resolve(NS.REINDEER_DROPS)
NS.EGG_UPGRADES = Resolve(NS.EASTER_EGGS)
NS.HALLOWEEN_UPGRADES = Resolve(NS.HALLOWEEN_DROPS)
NS.HEART_UPGRADES = Resolve(NS.HEART_DROPS)

NS.GRANDMA_SYNERGY_SET = {}
for _, name in ipairs(NS.GRANDMA_SYNERGIES) do
	NS.GRANDMA_SYNERGY_SET[name] = true
end

NS.SEASON_DROPS = {}
NS.SEASON_DROP_SET = {}
for _, list in ipairs({ NS.HEART_DROPS, NS.HALLOWEEN_DROPS, NS.EASTER_EGGS, NS.SANTA_DROPS, NS.REINDEER_DROPS }) do
	for _, name in ipairs(list) do
		table.insert(NS.SEASON_DROPS, name)
		NS.SEASON_DROP_SET[name] = true
	end
end

-- Dragon auras by name.
NS.AURA_BY_NAME = {}
for id, aura in pairs(NS.DRAGON_AURAS) do
	aura.id = id
	NS.AURA_BY_NAME[aura.name] = aura
end

-- The tier unshackle upgrades ("Unshackled flavor", "Unshackled berrylium", ...).
NS.TIER_UNSHACKLE = {}
for tier, t in pairs(NS.TIERS) do
	if type(tier) == "number" then
		local name = tier == 1 and "Unshackled flavor" or ("Unshackled " .. t.name:lower())
		if NS.U[name] then
			NS.TIER_UNSHACKLE[tier] = name
		end
	end
end

-- Achievements won by owning cursors (the Cursor's buyFunction).
NS.CURSOR_ACHIEVEMENTS = {
	{ 1, "Click" }, { 2, "Double-click" }, { 50, "Mouse wheel" }, { 100, "Of Mice and Men" }, { 200, "The Digital" },
	{ 300, "Extreme polydactyly" }, { 400, "Dr. T" }, { 500, "Thumbs, phalanges, metacarpals" }, { 600, "With her finger and her thumb" },
	{ 700, "Gotta hand it to you" }, { 800, "The devil's workshop" }, { 900, "All on deck" }, { 1000, "A round of applause" },
}

-- Achievements for a building reaching level 10.
NS.LEVEL_ACHIEVEMENTS = {
	["Cursor"] = "Freaky jazz hands", ["Grandma"] = "Methuselah", ["Farm"] = "Huge tracts of land", ["Mine"] = "D-d-d-d-deeper",
	["Factory"] = "Patently genius", ["Bank"] = "A capital idea", ["Temple"] = "It belongs in a bakery", ["Wizard tower"] = "Motormouth",
	["Shipment"] = "Been there done that", ["Alchemy lab"] = "Phlogisticated substances", ["Portal"] = "Bizarro world",
	["Time machine"] = "The long now", ["Antimatter condenser"] = "Chubby hadrons", ["Prism"] = "Palettable",
	["Chancemaker"] = "Let's leaf it at that", ["Fractal engine"] = "Sierpinski rhomboids", ["Javascript console"] = "Alexandria",
	["Idleverse"] = "Strange topologies", ["Cortex baker"] = "Gifted", ["You"] = "Self-improvement",
}
