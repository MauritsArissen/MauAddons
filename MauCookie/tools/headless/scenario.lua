-- Drives the loaded addon through a long session: login, clicks, buying,
-- upgrades, golden cookies, wrinklers, lumps, minigames, ascension, wipe,
-- a 0.4.0 migration.  Any Lua error is reported with a traceback.
local NS = __NS
local errors = 0
local function step(name, f, ...)
	local ok, err = xpcall(f, function(m) return debug.traceback(tostring(m), 2) end, ...)
	if not ok then
		errors = errors + 1
		print("STEP FAIL [" .. name .. "]: " .. err)
	end
end
local function advance(seconds, dt)
	dt = dt or 0.1
	local n = math.floor(seconds / dt)
	for _ = 1, n do
		__clock = __clock + dt
		NS.Game:Tick(dt)
		if NS.UI and NS.UI.OnUpdate and NS.UI:IsShown() then NS.UI:OnUpdate(dt) end
	end
	__flushTimers()
end

-- Login.
step("InitDB", NS.InitDB)
step("Game:Start", function() NS.Game:Start() end)
step("Comm:Start", function() NS.Comm:Start() end)
step("Minimap:Create", function() NS.Minimap:Create() end)
step("Options:Register", function() NS.Options:Register() end)
local Game, S = NS.Game, NS.Game.save
print("start: cookies", S.cookies, "cps", Game.cps)

-- Open the window and click.
step("UI:Show", function() NS.UI:Show() end)
step("clicks", function() for i = 1, 20 do __clock = __clock + 0.1; Game:ClickCookie() end end)
step("tick 30s", function() advance(30) end)
print("after clicks:", S.cookies, "handmade", S.handmade)

-- Buy buildings and upgrades with cheated cookies.
step("buy cursors", function() S.cookies = S.cookies + 1e4; Game:BuyBuilding(NS.B["Cursor"], 10) end)
step("buy grandma", function() S.cookies = S.cookies + 1e4; Game:BuyBuilding(NS.B["Grandma"], 5) end)
step("tick", function() advance(10) end)
print("cps", Game.cps, "store list", #Game:UpgradesInStore())
step("buy all store", function()
	for round = 1, 3 do
		S.cookies = S.cookies + 1e8
		for _, u in ipairs(Game:UpgradesInStore()) do Game:BuyUpgrade(u) end
	end
end)
step("buy everything", function()
	for _, b in ipairs(NS.BUILDINGS) do S.cookies = S.cookies + b.basePrice * 1e3; Game:BuyBuilding(b, 100) end
	S.earned = S.earned + 1e15
	Game:CheckUnlocks()
	for round = 1, 5 do
		S.cookies = S.cookies + 1e30
		for _, u in ipairs(Game:UpgradesInStore()) do Game:BuyUpgrade(u) end
		Game:CheckUnlocks()
	end
end)
step("tick 60s", function() advance(60) end)
print("owned upgrades", Game:UpgradesOwned(), "achievements", Game:AchievementsOwned(), "cps", Game.cps, "wrath", S.elderWrath)
step("refresh UI", function() NS.UI:Refresh(true) end)
step("menus", function()
	for _, m in ipairs({ "stats", "options", "info", "guild" }) do NS.UI:ToggleMenu(m); NS.UI:Refresh(true); NS.UI:ToggleMenu(m) end
	NS.UI:ToggleMenu("legacy"); NS.UI:RefreshAscend(); NS.UI:LayoutAscend(); NS.UI:ShowAscend(false)
end)
step("sell", function() Game:SellBuilding(NS.B["Farm"], 3); Game:SellBuilding(NS.B["Grandma"], -1); Game:BuyBuilding(NS.B["Grandma"], 50) end)

-- Golden cookies: spawn and pop many, both kinds, chains and storms.
step("golden", function()
	for i = 1, 60 do
		local me = Game:SpawnShimmer("golden", (i % 3 == 0) and { wrath = true } or nil)
		me.spawnLead = true
		advance(0.5)
		if i % 7 == 0 then me.force = "chain cookie" end
		if i % 11 == 0 then me.force = "cookie storm" end
		if i % 13 == 0 then me.force = "building special" end
		Game:PopShimmer(me)
		advance(1)
	end
	local me = Game:SpawnShimmer("reindeer"); me.spawnLead = true; Game:PopShimmer(me)
	advance(20)
end)
print("golden clicks", S.goldenClicks, "buffs", #Game:Buffs(), "shimmers", #Game.shimmers)
step("storm wait", function() advance(30) end)

-- Grandmapocalypse and wrinklers.
step("wrinklers", function()
	S.elderWrath = 3
	for i = 1, 14 do Game:SpawnWrinkler() end
	advance(120)
	NS.UI:RefreshWrinklers()
	for _, w in ipairs(Game:Wrinklers()) do if w.phase > 0 then for k = 1, 4 do Game:ClickWrinkler(w) end end end
	Game:CollectWrinklers(); advance(1)
	Game:PopRandomWrinkler(); advance(1)
end)
print("wrinklers popped", S.wrinklersPopped)
step("pledge", function()
	Game:Unlock("Elder Pledge"); S.cookies = S.cookies + 1e20
	Game:BuyUpgrade(NS.U["Elder Pledge"]); advance(5)
	S.pledgeT = 1; advance(5)
	Game:BuyUpgrade(NS.U["Elder Covenant"]); advance(1); Game:BuyUpgrade(NS.U["Revoke Elder Covenant"]); advance(1)
end)

-- Seasons.
step("seasons", function()
	Game:EarnUpgrade("Season switcher")
	for key, s in pairs(NS.SEASONS) do
		S.cookies = S.cookies + 1e30
		Game:BuyUpgrade(NS.U[s.trigger]); advance(5); NS.UI:Refresh(true)
		local me = Game:SpawnShimmer("golden"); me.spawnLead = true; Game:PopShimmer(me)
		if key == "christmas" then
			Game:Unlock("A festive hat"); S.cookies = S.cookies + 1e9; Game:BuyUpgrade(NS.U["A festive hat"])
			for i = 1, 15 do S.cookies = S.cookies + 1e20; Game:UpgradeSanta() end
			NS.UI:ToggleSpecial("santa"); NS.UI:RefreshSpecial()
			local r = Game:SpawnShimmer("reindeer"); r.spawnLead = true; Game:PopShimmer(r)
		end
		if key == "easter" then for i = 1, 30 do Game:DropEgg(0) end end
	end
	Game:EndSeason(true)
end)
print("season", S.season, "santa", S.santaLevel)

-- Dragon.
step("dragon", function()
	Game:EarnUpgrade("How to bake your dragon"); S.earned = math.max(S.earned, 2e6); Game:CheckUnlocks()
	S.cookies = S.cookies + 1e9; Game:BuyUpgrade(NS.U["A crumbly egg"])
	for _, b in ipairs(NS.BUILDINGS) do S.cookies = S.cookies + 1e40; Game:BuyBuilding(b, 250) end
	for i = 1, 30 do S.cookies = S.cookies + 1e8; Game:UpgradeDragon() end
	NS.UI:ToggleSpecial("dragon"); NS.UI:RefreshSpecial()
	Game:SetDragonAura(15, 1); Game:SetDragonAura(21, 2); Game:EarnUpgrade("Pet the dragon"); for i = 1, 50 do Game:PetDragon() end
	advance(5)
end)
print("dragon level", S.dragonLevel, "auras", S.dragonAura, S.dragonAura2, "cps", Game.cps)

-- Lumps and minigames.
step("lumps", function()
	S.earned = math.max(S.earned, 2e9); S.reset = 0
	advance(2)
	S.lumps = 50; S.lumpsTotal = 50
	S.lumpT = os.time() - 24 * 3600; advance(1)
	Game:ClickLump()
	for _, name in ipairs({ "Farm", "Bank", "Temple", "Wizard tower", "Cursor", "Grandma" }) do
		for lvl = 1, 3 do Game:LevelUp(NS.B[name]) end
	end
	NS.UI:Refresh(true)
end)
print("lumps", S.lumps, "levels", Game:Level("Farm"), Game:Level("Bank"), Game:Level("Temple"), Game:Level("Wizard tower"))
step("minigame panels", function()
	for _, name in ipairs({ "Farm", "Bank", "Temple", "Wizard tower" }) do
		NS.UI:ToggleMinigame(NS.B[name])
		NS.UI:Refresh(true)
	end
	advance(5)
end)
step("grimoire", function()
	local G = NS.Minigames.byBuilding["Wizard tower"]
	for i = 1, 60 do
		G.state.magic = G.magicM
		for _, s in ipairs(G.spells) do G:castSpell(s) end
		advance(2)
	end
end)
step("pantheon", function()
	local P = NS.Minigames.byBuilding["Temple"]
	for i, god in ipairs(P.gods) do P:useSwap(1); P:slotGod(god, (i % 3) + 1) end
	P.state.swaps = 0; P.state.swapT = -1e9; advance(1)
	Game:CalculateGains(); advance(5)
	print("gods", Game:HasGod("asceticism"), Game:HasGod("order"), Game:HasGod("ruin"))
	Game:SellBuilding(NS.B["Farm"], 10)
	local me = Game:SpawnShimmer("golden"); me.spawnLead = true; Game:PopShimmer(me)
end)
step("market", function()
	local M = NS.Minigames.byBuilding["Bank"]
	for i = 1, 70 do M:tick() end
	for i = 1, #M.goods do M:buyGood(i, 10000); M.selected = i; M:refresh(M.panel) end
	advance(61)
	for i = 1, #M.goods do M:sellGood(i, 10000) end
	for i = 1, 6 do M:upgradeOffice(); M:hireBroker() end
	M:takeLoan(1); M:takeLoan(2); M:takeLoan(3)
	advance(60 * 3)
	for _, b in ipairs(Game:Buffs()) do b.time = 0 end
	advance(1)
end)
step("garden", function()
	local G = NS.Minigames.byBuilding["Farm"]
	for key in pairs(G.byKey) do G.state.unlocked[key] = true end
	for y = 1, 6 do for x = 1, 6 do
		G.seedSelected = ((x + y) % #G.plants) + 1
		S.cookies = S.cookies + 1e30
		G:clickTile(x, y)
	end end
	for i = 1, 40 do G:step() end
	G:computeBoostPlot(); G:computeEffs(); Game:CalculateGains()
	for i = 1, 5 do G:setSoil(i); G.state.nextSoil = 0 end
	G:toggleFreeze(); G:toggleFreeze()
	G:harvestAll(true); G:harvestAll()
	G:convert()
	G:refresh(G.panel)
	advance(5)
end)
print("effs", Game:Eff("cps"), "cps", Game.cps)

-- Ascension.
step("ascend", function()
	S.earned = S.earned + 5e15
	print("ascend info", Game:AscendInfo())
	Game:Ascend()
	NS.UI:OnAscendChanged(); NS.UI:LayoutAscend(); NS.UI:RefreshAscend()
	advance(1)
	for round = 1, 3 do
		for _, u in ipairs(NS.PRESTIGE_UPGRADES) do Game:BuyPrestige(u) end
	end
	for slot = 1, 5 do local list = Game:PermanentSlotCandidates(slot); if list[1] then Game:SetPermanentSlot(slot, list[1].name) end end
	NS.UI:LayoutAscend()
	Game:Reincarnate()
	advance(5)
end)
print("after ascend: prestige", S.prestige, "chips", S.chips, "cursors", Game:Count("Cursor"), "cps", Game.cps, "resets", S.resets)
step("ticker", function()
	for i = 1, 50 do Game:NewTicker(false); Game:ClickTicker() end
	Game:EarnUpgrade("Fortune cookies"); S.runTime = 100
	for i = 1, 200 do Game:NewTicker(false); if Game.tickerEffect then Game:ClickTicker() end end
end)
step("wipe", function() Game:Wipe(); advance(5) end)
print("after wipe: cookies", S.cookies, "ach", Game:AchievementsOwned())

-- 0.4.0 migration.
step("migration", function()
	MauCookieDB.save = {
		cookies = 123456, baked = 5e11, clicks = 100, handmade = 5000, golden = 12, playTime = 7200, started = os.time() - 86400,
		prestige = 9, chips = 3, allTime = 3e12, ascensions = 2, pledges = 1, pledgeUntil = 9000, covenant = false, researchReadyAt = 0, sold = 4,
		buildings = { cursor = 50, grandma = 30, farm = 20, mine = 10, bank = 3 },
		upgrades = { cursor1 = true, cursor2 = true, cursor3 = true, grandma1 = true, farm1 = true, mouse1 = true, flavour1 = true, kitten1 = true, luck1 = true, syn1 = true, research5 = true, bingo = true, gtype_farm = true },
		achievements = { baked1 = true, baked2 = true, cps1 = true, hand1 = true, golden1 = true, elder = true, justwrong = true, chain = true },
		heavenly = { heavenlycookies = true }, wrinklers = { { slot = 1, sucked = 10, hp = 3 } },
	}
	NS.InitDB()
	Game:Rebind()
	Game:Start()
	advance(10)
	print("migrated: prestige", Game.save.prestige, "chips", Game.save.chips, "cursors", Game:Count("Cursor"), "has RIF", Game:Has("Reinforced index finger"), "ach", Game:AchievementsOwned(), "store", #Game:UpgradesInStore(), "cps", Game.cps)
end)

local printed = 0
for _, line in ipairs(__log) do
	if line:find("Error in") then printed = printed + 1 end
end
print("guarded errors:", printed, "step failures:", errors)
