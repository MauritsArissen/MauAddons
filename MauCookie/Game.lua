-- MauCookie rules, ported from the original's main.js (version 2.052):
-- production (CalculateGains), clicking (mouseCps), building and upgrade
-- prices, buying and selling, unlock rules, the achievement checks, the
-- research chain, seasons, the tick.  Golden cookies live in Shimmers.lua,
-- buffs in Buffs.lua, wrinklers in Wrinklers.lua, sugar lumps in Lumps.lua,
-- Santa, the dragon and the fortune ticker in Specials.lua, ascension in
-- Ascend.lua.
--
-- The bakery ticks from a frame that is always shown, so cookies keep
-- coming while the window is closed; nothing is produced while logged out
-- (the user's wish).  Timers (research, pledges, seasons, buffs) run on
-- bakery time, sugar lumps on real time like the original.

local _, NS = ...

local Game = {}
NS.Game = Game

local MAX_TICK = 5
local FPS = 30

Game.priceIncrease = 1.15
Game.heavenlyPower = 1
Game.HCfactor = 3
Game.SpecialGrandmaUnlock = 15
Game.baseResearchTime = 30 * 60
Game.seasonTriggerBasePrice = 1e9

local S -- the save, set in Start

local function Choose(list)
	return list[math.random(#list)]
end
NS.Choose = Choose

function NS.Notify(title, text, icon, quick)
	if NS.UI and NS.UI.Notify then
		NS.UI:Notify(title, text, icon, quick)
	end
end

function Game:Start()
	self.save = MauCookieDB.save
	S = self.save
	self.effs = {}
	self.cpsBy = {}
	self.version = 0
	self.recalc = true
	self.countsDirty = true
	self.heralds = 0
	self.lastClick = 0
	self.autoclicker = 0
	self.checkAcc = 0
	self.secondAcc = 0
	self.tenAcc = 0
	self:InitShimmers()
	self:ComputeLumpTimes()
	self:LoadLumps()
	self:CalculateGains()
	self:CheckMilkUnlocks()
	if S.migrated then
		-- A carried-over 0.4.0 save: rebuild the unlock state from what is owned.
		S.migrated = nil
		for _, b in ipairs(NS.BUILDINGS) do
			if self:Count(b.name) > 0 then
				self:OnBuildingBought(b)
			end
		end
		self:CheckUnlocks()
		self:CalculateGains()
	end
	if NS.Minigames then
		NS.Minigames:Start()
		self:CalculateGains()
	end
	self.tickFrame = CreateFrame("Frame")
	self.tickFrame:SetScript("OnUpdate", function(_, elapsed)
		NS.Guard("tick", Game.Tick, Game, elapsed)
	end)
end

-- Called after a wipe or a migration replaced the save table.
function Game:Rebind()
	self.save = MauCookieDB.save
	S = self.save
	self.cpsBy = {}
	self.recalc = true
	self.countsDirty = true
	self:InitShimmers()
	self:ComputeLumpTimes()
	self:CalculateGains()
	self:CheckMilkUnlocks()
end

-------------------------------------------------------------------------------
-- Ownership
-------------------------------------------------------------------------------

function Game:Has(name)
	return S.up[name] == true
end

function Game:HasUnlocked(name)
	return S.unl[name] == true
end

function Game:HasAchiev(name)
	return S.ach[name] == true
end

function Game:Unlock(what)
	if type(what) == "table" then
		for _, name in ipairs(what) do
			self:Unlock(name)
		end
		return
	end
	if NS.U[what] and not S.unl[what] then
		S.unl[what] = true
		self:StoreDirty()
	end
end

function Game:Lock(name)
	if NS.U[name] then
		if S.up[name] then
			S.up[name] = nil
			self.recalc = true
			self.countsDirty = true
		end
		S.unl[name] = nil
		self:StoreDirty()
	end
end

-- Own an upgrade without paying (permanent slots, the veil).
function Game:EarnUpgrade(name)
	if NS.U[name] then
		S.unl[name] = true
		S.up[name] = true
		self:OnUpgradeBought(NS.U[name], true)
		self.recalc = true
		self.countsDirty = true
		self:StoreDirty()
	end
end

function Game:Win(what)
	if type(what) == "table" then
		for _, name in ipairs(what) do
			self:Win(name)
		end
		return
	end
	local a = NS.A[what]
	if a and not S.ach[what] then
		S.ach[what] = true
		self.countsDirty = true
		self.recalc = true
		NS.Notify("Achievement unlocked", what, a.icon)
		NS.PlayKit("UI_WORLDQUEST_COMPLETE")
		self:Changed()
	end
end

function Game:Recount()
	if not self.countsDirty then
		return
	end
	self.countsDirty = false
	local n = 0
	for name in pairs(S.up) do
		local u = NS.U[name]
		if u and (u.pool == "" or u.pool == "cookie" or u.pool == "tech") then
			n = n + 1
		end
	end
	self.upgradesOwned = n
	n = 0
	local shadow = 0
	for name in pairs(S.ach) do
		local a = NS.A[name]
		if a then
			if a.pool == "normal" then
				n = n + 1
			else
				shadow = shadow + 1
			end
		end
	end
	self.achievementsOwned = n
	self.shadowOwned = shadow
	n = 0
	for _, u in ipairs(NS.PRESTIGE_UPGRADES) do
		if S.up[u.name] then
			n = n + 1
		end
	end
	self.prestigeOwned = n
end

function Game:UpgradesOwned()
	self:Recount()
	return self.upgradesOwned
end

function Game:AchievementsOwned()
	self:Recount()
	return self.achievementsOwned
end

function Game:ShadowOwned()
	self:Recount()
	return self.shadowOwned
end

function Game:PrestigeUpgradesOwned()
	self:Recount()
	return self.prestigeOwned
end

-------------------------------------------------------------------------------
-- Buildings
-------------------------------------------------------------------------------

function Game:Bld(name)
	local r = S.bld[name]
	if not r then
		r = { n = 0, bought = 0, highest = 0, free = 0, total = 0, level = 0 }
		S.bld[name] = r
	end
	return r
end

function Game:Count(name)
	local r = S.bld[name]
	return r and r.n or 0
end

function Game:Level(name)
	local r = S.bld[name]
	return r and r.level or 0
end

function Game:BuildingsOwned()
	local n = 0
	for _, b in ipairs(NS.BUILDINGS) do
		n = n + self:Count(b.name)
	end
	return n
end

function Game:HighestBuilding()
	local highest
	for _, b in ipairs(NS.BUILDINGS) do
		if self:Count(b.name) > 0 then
			highest = b
		end
	end
	return highest
end

-------------------------------------------------------------------------------
-- Cookies
-------------------------------------------------------------------------------

function Game:Earn(howmuch)
	if S.onAscend then
		return
	end
	S.cookies = S.cookies + howmuch
	S.earned = S.earned + howmuch
end

function Game:Spend(howmuch)
	if S.onAscend then
		return
	end
	S.cookies = S.cookies - howmuch
end

function Game:Dissolve(howmuch)
	if S.onAscend then
		return
	end
	S.cookies = math.max(0, S.cookies - howmuch)
	S.earned = math.max(0, S.earned - howmuch)
end

function Game:AllTime()
	return (S.reset or 0) + (S.earned or 0)
end

-------------------------------------------------------------------------------
-- Dragon auras, minigame effects, gods (the minigames fill these in later)
-------------------------------------------------------------------------------

function Game:HasAura(what)
	local a1, a2 = NS.DRAGON_AURAS[S.dragonAura or 0], NS.DRAGON_AURAS[S.dragonAura2 or 0]
	return (a1 and a1.name == what) or (a2 and a2.name == what) or false
end

function Game:AuraMult(what)
	local n = 0
	local a1, a2 = NS.DRAGON_AURAS[S.dragonAura or 0], NS.DRAGON_AURAS[S.dragonAura2 or 0]
	if (a1 and a1.name == what) or (a2 and a2.name == what) then
		n = 1
	end
	local aura = NS.AURA_BY_NAME[what]
	if aura and ((a1 and a1.name == "Reality Bending") or (a2 and a2.name == "Reality Bending")) and (S.dragonLevel or 0) >= aura.id + 4 then
		n = n + 0.1
	end
	return n
end

function Game:Eff(name)
	return self.effs[name] or 1
end

-- Pantheon slot level of a god, 0 when none (the Pantheon minigame sets hasGodFunc).
function Game:HasGod(name)
	if self.hasGodFunc then
		return self.hasGodFunc(name)
	end
	return 0
end

function Game:DropRateMult()
	local rate = 1
	if self:Has("Green yeast digestives") then rate = rate * 1.03 end
	if self:Has("Dragon teddy bear") then rate = rate * 1.03 end
	rate = rate * self:Eff("itemDrops")
	rate = rate * (1 + self:AuraMult("Mind Over Matter") * 0.25)
	if self:Has("Santa's bottomless bag") then rate = rate * 1.1 end
	if self:Has("Cosmic beginner's luck") and not self:Has("Heavenly chip secret") then rate = rate * 5 end
	return rate
end

-------------------------------------------------------------------------------
-- Production
-------------------------------------------------------------------------------

function Game:ComputeCps(base, mult, bonus)
	return base * (2 ^ mult) + (bonus or 0)
end

local function B(flag)
	return flag and 1 or 0
end

function Game:GetTieredCpsMult(b)
	local mult = 1
	for tier, u in pairs(b.tieredList) do
		local t = NS.TIERS[tier]
		if t and not t.special and self:Has(u.name) then
			local tierMult = 2
			if S.ascensionMode ~= 1 and b.unshackle and self:Has(b.unshackle) and NS.TIER_UNSHACKLE[tier] and self:Has(NS.TIER_UNSHACKLE[tier]) then
				tierMult = tierMult + (b.id == 1 and 0.5 or (20 - b.id) * 0.1)
			end
			mult = mult * tierMult
		end
	end
	for _, syn in ipairs(b.synergyList) do
		if self:Has(syn.name) then
			if syn.b1 == b.name then
				mult = mult * (1 + 0.05 * self:Count(syn.b2))
			elseif syn.b2 == b.name then
				mult = mult * (1 + 0.001 * self:Count(syn.b1))
			end
		end
	end
	if b.fortune and self:Has(b.fortune) then
		mult = mult * 1.07
	end
	if b.grandma and self:Has(b.grandma) then
		mult = mult * (1 + self:Count("Grandma") * 0.01 * (1 / (b.id - 1)))
	end
	return mult
end

function Game:ThousandFingersAdd()
	local add = 0
	if self:Has("Thousand fingers") then add = add + 0.1 end
	if self:Has("Million fingers") then add = add * 5 end
	if self:Has("Billion fingers") then add = add * 10 end
	if self:Has("Trillion fingers") then add = add * 20 end
	if self:Has("Quadrillion fingers") then add = add * 20 end
	if self:Has("Quintillion fingers") then add = add * 20 end
	if self:Has("Sextillion fingers") then add = add * 20 end
	if self:Has("Septillion fingers") then add = add * 20 end
	if self:Has("Octillion fingers") then add = add * 20 end
	if self:Has("Nonillion fingers") then add = add * 20 end
	if self:Has("Decillion fingers") then add = add * 20 end
	if self:Has("Undecillion fingers") then add = add * 20 end
	if self:Has("Unshackled cursors") then add = add * 25 end
	return add * (self:BuildingsOwned() - self:Count("Cursor"))
end

function Game:KittensOwned()
	local n = 0
	for _, k in ipairs(NS.KITTENS) do
		if self:Has(k.name) then
			n = n + 1
		end
	end
	return n
end

-- The original's per-building cps functions.
function Game:BuildingCpsBase(b)
	if b.id == 0 then
		local mult = self:GetTieredCpsMult(b) * self:Eff("cursorCps")
		return self:ComputeCps(0.1, B(self:Has("Reinforced index finger")) + B(self:Has("Carpal tunnel prevention cream")) + B(self:Has("Ambidextrous")), self:ThousandFingersAdd()) * mult
	elseif b.id == 1 then
		local mult = 1
		for _, name in ipairs(NS.GRANDMA_SYNERGIES) do
			if self:Has(name) then mult = mult * 2 end
		end
		if self:Has("Bingo center/Research facility") then mult = mult * 4 end
		if self:Has("Ritual rolling pins") then mult = mult * 2 end
		if self:Has("Naughty list") then mult = mult * 2 end
		if self:Has("Elderwort biscuits") then mult = mult * 1.02 end
		mult = mult * self:Eff("grandmaCps")
		if self:Has("Cat ladies") then
			for _, k in ipairs(NS.KITTENS) do
				if self:Has(k.name) then mult = mult * 1.29 end
			end
		end
		mult = mult * self:GetTieredCpsMult(b)
		local add = 0
		local grandmas = self:Count("Grandma")
		if self:Has("One mind") then add = add + grandmas * 0.02 end
		if self:Has("Communal brainsweep") then add = add + grandmas * 0.02 end
		if self:Has("Elder Pact") then add = add + self:Count("Portal") * 0.05 end
		mult = mult * (1 + self:AuraMult("Elder Battalion") * 0.01 * (self:BuildingsOwned() - grandmas))
		return (b.baseCps + add) * mult
	end
	return b.baseCps * self:GetTieredCpsMult(b)
end

function Game:GetHeavenlyMultiplier()
	local heavenlyMult = 0
	if self:Has("Heavenly chip secret") then heavenlyMult = heavenlyMult + 0.05 end
	if self:Has("Heavenly cookie stand") then heavenlyMult = heavenlyMult + 0.20 end
	if self:Has("Heavenly bakery") then heavenlyMult = heavenlyMult + 0.25 end
	if self:Has("Heavenly confectionery") then heavenlyMult = heavenlyMult + 0.25 end
	if self:Has("Heavenly key") then heavenlyMult = heavenlyMult + 0.25 end
	heavenlyMult = heavenlyMult * (1 + self:AuraMult("Dragon God") * 0.05)
	if self:Has("Lucky digit") then heavenlyMult = heavenlyMult * 1.01 end
	if self:Has("Lucky number") then heavenlyMult = heavenlyMult * 1.01 end
	if self:Has("Lucky payout") then heavenlyMult = heavenlyMult * 1.01 end
	local godLvl = self:HasGod("creation")
	if godLvl == 1 then heavenlyMult = heavenlyMult * 0.7
	elseif godLvl == 2 then heavenlyMult = heavenlyMult * 0.8
	elseif godLvl == 3 then heavenlyMult = heavenlyMult * 0.9 end
	return heavenlyMult
end

-- Power of a cookie upgrade (some are functions in the original).
function Game:CookiePower(u)
	if not u.powerFn then
		return u.power or 0
	end
	local name = u.name
	if name == "Birthday cookie" then
		local y = tonumber(date("%Y")) - 2013
		local m, d = tonumber(date("%m")), tonumber(date("%d"))
		if m < 8 or (m == 8 and d < 8) then
			y = y - 1
		end
		return y
	elseif name == "Sugar crystal cookies" then
		local n = 5
		for _, b in ipairs(NS.BUILDINGS) do
			if self:Level(b.name) >= 10 then
				n = n + 1
			end
		end
		return n
	end
	-- the heart biscuits
	local pow = 2
	if self:Has("Starlove") then pow = 3 end
	local godLvl = self:HasGod("seasons")
	if godLvl == 1 then pow = pow * 1.3
	elseif godLvl == 2 then pow = pow * 1.2
	elseif godLvl == 3 then pow = pow * 1.1 end
	return pow
end

function Game:CalculateGains()
	self.recalc = false
	local effs = {}
	if self.minigames then
		for _, mg in pairs(self.minigames) do
			if mg.effs and mg.loaded then
				for k, v in pairs(mg.effs) do
					effs[k] = (effs[k] or 1) * v
				end
			end
		end
	end
	self.effs = effs

	local cookiesPs = 0
	local mult = 1
	if S.ascensionMode ~= 1 then
		mult = mult + (S.prestige or 0) * 0.01 * self.heavenlyPower * self:GetHeavenlyMultiplier()
	end
	mult = mult * self:Eff("cps")
	if self:Has("Heralds") and S.ascensionMode ~= 1 then
		mult = mult * (1 + 0.01 * self.heralds)
	end
	for _, u in ipairs(NS.COOKIE_UPGRADES) do
		if S.up[u.name] then
			mult = mult * (1 + self:CookiePower(u) * 0.01)
		end
	end
	if self:Has("Specialized chocolate chips") then mult = mult * 1.01 end
	if self:Has("Designer cocoa beans") then mult = mult * 1.02 end
	if self:Has("Underworld ovens") then mult = mult * 1.03 end
	if self:Has("Exotic nuts") then mult = mult * 1.04 end
	if self:Has("Arcane sugar") then mult = mult * 1.05 end
	if self:Has("Increased merriness") then mult = mult * 1.15 end
	if self:Has("Improved jolliness") then mult = mult * 1.15 end
	if self:Has("A lump of coal") then mult = mult * 1.01 end
	if self:Has("An itchy sweater") then mult = mult * 1.01 end
	if self:Has("Santa's dominion") then mult = mult * 1.2 end
	if self:Has("Fortune #100") then mult = mult * 1.01 end
	if self:Has("Fortune #101") then mult = mult * 1.07 end
	if self:Has("Dragon scale") then mult = mult * 1.03 end
	if self:Has("Wrinkler ambergris") then mult = mult * 1.06 end

	local buildMult = 1
	local godLvl = self:HasGod("asceticism")
	if godLvl == 1 then mult = mult * 1.15 elseif godLvl == 2 then mult = mult * 1.1 elseif godLvl == 3 then mult = mult * 1.05 end
	godLvl = self:HasGod("ages")
	local now = time()
	if godLvl == 1 then mult = mult * (1 + 0.15 * math.sin((now / (60 * 60 * 3)) * math.pi * 2))
	elseif godLvl == 2 then mult = mult * (1 + 0.15 * math.sin((now / (60 * 60 * 12)) * math.pi * 2))
	elseif godLvl == 3 then mult = mult * (1 + 0.15 * math.sin((now / (60 * 60 * 24)) * math.pi * 2)) end
	godLvl = self:HasGod("decadence")
	if godLvl == 1 then buildMult = buildMult * 0.93 elseif godLvl == 2 then buildMult = buildMult * 0.95 elseif godLvl == 3 then buildMult = buildMult * 0.98 end
	godLvl = self:HasGod("industry")
	if godLvl == 1 then buildMult = buildMult * 1.1 elseif godLvl == 2 then buildMult = buildMult * 1.06 elseif godLvl == 3 then buildMult = buildMult * 1.03 end
	godLvl = self:HasGod("labor")
	if godLvl == 1 then buildMult = buildMult * 0.97 elseif godLvl == 2 then buildMult = buildMult * 0.98 elseif godLvl == 3 then buildMult = buildMult * 0.99 end

	if self:Has("Santa's legacy") then
		mult = mult * (1 + ((S.santaLevel or 0) + 1) * 0.03)
	end

	self.milkProgress = self:AchievementsOwned() / 25
	local milkMult = 1
	if self:Has("Santa's milk and cookies") then milkMult = milkMult * 1.05 end
	milkMult = milkMult * (1 + self:AuraMult("Breath of Milk") * 0.05)
	godLvl = self:HasGod("mother")
	if godLvl == 1 then milkMult = milkMult * 1.1 elseif godLvl == 2 then milkMult = milkMult * 1.05 elseif godLvl == 3 then milkMult = milkMult * 1.03 end
	milkMult = milkMult * self:Eff("milk")
	self.milkMult = milkMult

	local catMult = 1
	local mp = self.milkProgress
	if self:Has("Kitten helpers") then catMult = catMult * (1 + mp * 0.1 * milkMult) end
	if self:Has("Kitten workers") then catMult = catMult * (1 + mp * 0.125 * milkMult) end
	if self:Has("Kitten engineers") then catMult = catMult * (1 + mp * 0.15 * milkMult) end
	if self:Has("Kitten overseers") then catMult = catMult * (1 + mp * 0.175 * milkMult) end
	if self:Has("Kitten managers") then catMult = catMult * (1 + mp * 0.2 * milkMult) end
	if self:Has("Kitten accountants") then catMult = catMult * (1 + mp * 0.2 * milkMult) end
	if self:Has("Kitten specialists") then catMult = catMult * (1 + mp * 0.2 * milkMult) end
	if self:Has("Kitten experts") then catMult = catMult * (1 + mp * 0.2 * milkMult) end
	if self:Has("Kitten consultants") then catMult = catMult * (1 + mp * 0.2 * milkMult) end
	if self:Has("Kitten assistants to the regional manager") then catMult = catMult * (1 + mp * 0.175 * milkMult) end
	if self:Has("Kitten marketeers") then catMult = catMult * (1 + mp * 0.15 * milkMult) end
	if self:Has("Kitten analysts") then catMult = catMult * (1 + mp * 0.125 * milkMult) end
	if self:Has("Kitten executives") then catMult = catMult * (1 + mp * 0.115 * milkMult) end
	if self:Has("Kitten admins") then catMult = catMult * (1 + mp * 0.11 * milkMult) end
	if self:Has("Kitten strategists") then catMult = catMult * (1 + mp * 0.105 * milkMult) end
	if self:Has("Kitten angels") then catMult = catMult * (1 + mp * 0.1 * milkMult) end
	if self:Has("Fortune #103") then catMult = catMult * (1 + mp * 0.05 * milkMult) end
	self.catMult = catMult

	for _, b in ipairs(NS.BUILDINGS) do
		local r = S.bld[b.name]
		local stored = self:BuildingCpsBase(b)
		if S.ascensionMode ~= 1 then
			stored = stored * (1 + (r and r.level or 0) * 0.01) * buildMult
		end
		if b.id == 1 and self:Has("Milkhelp(R) lactose intolerance relief tablets") then
			stored = stored * (1 + 0.05 * mp * milkMult)
		end
		local entry = self.cpsBy[b.name]
		if not entry then
			entry = {}
			self.cpsBy[b.name] = entry
		end
		entry.each = stored
		entry.total = (r and r.n or 0) * stored
		cookiesPs = cookiesPs + entry.total
	end
	self.buildingCps = cookiesPs
	if self:Has('"egg"') then
		cookiesPs = cookiesPs + 9
	end
	mult = mult * catMult

	local eggMult = 1
	for _, name in ipairs(NS.EGG_DROPS) do
		if self:Has(name) then eggMult = eggMult * 1.01 end
	end
	if self:Has("Century egg") then
		local day = math.floor((time() - (S.startDate or time())) / 10) * 10 / 60 / 60 / 24
		day = math.max(0, math.min(day, 100))
		eggMult = eggMult * (1 + (1 - (1 - day / 100) ^ 3) * 0.1)
	end
	self.eggMult = eggMult
	mult = mult * eggMult

	if self:Has("Sugar baking") then
		mult = mult * (1 + math.min(100, math.max(0, S.lumps or 0)) * 0.01)
	end
	mult = mult * (1 + self:AuraMult("Radiant Appetite"))

	local rawCookiesPs = cookiesPs * mult
	for _, name in ipairs(NS.CPS_ACHIEVEMENTS) do
		local a = NS.A[name]
		if a and a.threshold and rawCookiesPs >= a.threshold then
			self:Win(name)
		end
	end
	self.rawCps = rawCookiesPs
	S.cpsHighest = math.max(S.cpsHighest or 0, rawCookiesPs)

	local n = self:GoldenOnScreen()
	local auraMult = self:AuraMult("Dragon's Fortune")
	for _ = 1, n do
		mult = mult * (1 + auraMult * 1.23)
	end

	local sucking = 0
	for _, w in ipairs(self:Wrinklers()) do
		if w.phase == 2 then
			sucking = sucking + 1
		end
	end
	local suckRate = 1 / 20
	suckRate = suckRate * self:Eff("wrinklerEat")
	suckRate = suckRate * (1 + self:AuraMult("Dragon Guts") * 0.2)
	self.cpsSucked = math.min(1, sucking * suckRate)

	if self:Has("Elder Covenant") then mult = mult * 0.95 end
	if self:Has("Golden switch [off]") then
		local goldenSwitchMult = 1.5
		if self:Has("Residual luck") then
			for _, name in ipairs(NS.GOLDEN_UPGRADES) do
				if self:Has(name) then goldenSwitchMult = goldenSwitchMult + 0.1 end
			end
		end
		mult = mult * goldenSwitchMult
	end
	if self:Has("Shimmering veil [off]") then
		mult = mult * (1 + self:GetVeilBoost())
	end

	self.unbuffedCps = cookiesPs * mult
	for _, buff in ipairs(self:Buffs()) do
		if buff.multCpS ~= nil then
			mult = mult * buff.multCpS
		end
	end
	self.globalMult = mult
	self.cps = cookiesPs * mult
	self.mouse = self:MouseCps()
	self:ComputeLumpTimes()
end

local MICE = { "Plastic mouse", "Iron mouse", "Titanium mouse", "Adamantium mouse", "Unobtainium mouse", "Eludium mouse", "Wishalloy mouse", "Fantasteel mouse", "Nevercrack mouse", "Armythril mouse", "Technobsidian mouse", "Plasmarble mouse", "Miraculite mouse", "Aetherice mouse", "Omniplast mouse", "Fortune #104" }

function Game:MouseCps()
	local add = self:ThousandFingersAdd()
	local cps = self.cps or 0
	for _, name in ipairs(MICE) do
		if self:Has(name) then
			add = add + cps * 0.01
		end
	end
	local mult = 1
	if self:Has("Santa's helpers") then mult = mult * 1.1 end
	if self:Has("Cookie egg") then mult = mult * 1.1 end
	if self:Has("Halo gloves") then mult = mult * 1.1 end
	if self:Has("Dragon claw") then mult = mult * 1.03 end
	if self:Has("Aura gloves") then
		mult = mult * (1 + 0.05 * math.min(self:Level("Cursor"), self:Has("Luminous gloves") and 20 or 10))
	end
	mult = mult * self:Eff("click")
	local godLvl = self:HasGod("labor")
	if godLvl == 1 then mult = mult * 1.15 elseif godLvl == 2 then mult = mult * 1.1 elseif godLvl == 3 then mult = mult * 1.05 end
	for _, buff in ipairs(self:Buffs()) do
		if buff.multClick ~= nil then
			mult = mult * buff.multClick
		end
	end
	mult = mult * (1 + self:AuraMult("Dragon Cursor") * 0.05)
	local out = mult * self:ComputeCps(1, B(self:Has("Reinforced index finger")) + B(self:Has("Carpal tunnel prevention cream")) + B(self:Has("Ambidextrous")), add)
	local cursed = self:HasBuff("Cursed finger")
	if cursed then
		out = cursed.power
	end
	return out
end

function Game:GetVeilDefense()
	local n = 0
	if self:Has("Reinforced membrane") then n = n + 0.1 end
	if self:Has("Delicate touch") then n = n + 0.1 end
	if self:Has("Steadfast murmur") then n = n + 0.1 end
	if self:Has("Glittering edge") then n = n + 0.1 end
	return n
end

function Game:GetVeilBoost()
	local n = 0.5
	if self:Has("Reinforced membrane") then n = n + 0.1 end
	if self:Has("Delicate touch") then n = n + 0.05 end
	if self:Has("Steadfast murmur") then n = n + 0.05 end
	if self:Has("Glittering edge") then n = n + 0.05 end
	return n
end

function Game:LoseShimmeringVeil(context)
	if not self:Has("Shimmering veil") then
		return false
	end
	if not self:Has("Shimmering veil [off]") and self:Has("Shimmering veil [on]") then
		return false
	end
	if self:Has("Reinforced membrane") and math.random() < self:GetVeilDefense() then
		NS.Notify("The reinforced membrane protects the shimmering veil.", "", {7,10})
		self:Win("Thick-skinned")
		return false
	end
	S.up["Shimmering veil [on]"] = true
	self:Lock("Shimmering veil [off]")
	self:Unlock("Shimmering veil [off]")
	NS.Notify("The shimmering veil disappears...", "", {9,10})
	self.recalc = true
	self:StoreDirty()
	return true
end

-------------------------------------------------------------------------------
-- Clicking
-------------------------------------------------------------------------------

function Game:ClickCookie()
	if not S or S.onAscend then
		return
	end
	local now = GetTime()
	if now - self.lastClick < 1 / 50 then
		return
	end
	if now - self.lastClick < 1 / 15 then
		self.autoclicker = self.autoclicker + FPS
		if self.autoclicker >= FPS * 5 then
			self:Win("Uncanny clicker")
		end
	end
	self:LoseShimmeringVeil("click")
	local amount = self.mouse or 1
	self:Earn(amount)
	S.handmade = S.handmade + amount
	S.clicks = S.clicks + 1
	self.lastClick = now
	if NS.UI and NS.UI.OnClick then
		NS.UI:OnClick(amount)
	end
	if now - (self.lastClickSound or 0) > 0.06 then
		self.lastClickSound = now
		NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
	end
end

-------------------------------------------------------------------------------
-- Building prices, buying, selling
-------------------------------------------------------------------------------

function Game:ModifyBuildingPrice(b, price)
	if self:Has("Season savings") then price = price * 0.99 end
	if self:Has("Santa's dominion") then price = price * 0.99 end
	if self:Has("Faberge egg") then price = price * 0.99 end
	if self:Has("Divine discount") then price = price * 0.99 end
	if self:Has("Fortune #100") then price = price * 0.99 end
	price = price * (1 - self:AuraMult("Fierce Hoarder") * 0.02)
	if self:HasBuff("Everything must go") then price = price * 0.95 end
	if self:HasBuff("Crafty pixies") then price = price * 0.98 end
	if self:HasBuff("Nasty goblins") then price = price * 1.02 end
	if b.fortune and self:Has(b.fortune) then price = price * 0.93 end
	price = price * self:Eff("buildingCost")
	local godLvl = self:HasGod("creation")
	if godLvl == 1 then price = price * 0.93 elseif godLvl == 2 then price = price * 0.95 elseif godLvl == 3 then price = price * 0.98 end
	return price
end

function Game:BuildingPrice(b)
	local r = self:Bld(b.name)
	local price = b.basePrice * (self.priceIncrease ^ math.max(0, r.n - r.free))
	return math.ceil(self:ModifyBuildingPrice(b, price))
end

function Game:SumPrice(b, amount)
	local r = self:Bld(b.name)
	local price = 0
	for i = math.max(0, r.n), math.max(0, r.n + amount) - 1 do
		price = price + b.basePrice * (self.priceIncrease ^ math.max(0, i - r.free))
	end
	return math.ceil(self:ModifyBuildingPrice(b, price))
end

function Game:SellMultiplier()
	return 0.25 * (1 + self:AuraMult("Earth Shatterer"))
end

function Game:ReverseSumPrice(b, amount)
	local r = self:Bld(b.name)
	local price = 0
	for i = math.max(0, r.n - amount), math.max(0, r.n) - 1 do
		price = price + b.basePrice * (self.priceIncrease ^ math.max(0, i - r.free))
	end
	price = self:ModifyBuildingPrice(b, price) * self:SellMultiplier()
	return math.ceil(price)
end

-- amount -1 buys as many as affordable.
function Game:BuyBuilding(b, amount)
	if S.onAscend then
		return 0
	end
	if amount == -1 then
		amount = 1000
	end
	local r = self:Bld(b.name)
	local bought = 0
	for _ = 1, amount do
		local price = self:BuildingPrice(b)
		if S.cookies >= price then
			self:Spend(price)
			r.n = r.n + 1
			r.bought = r.bought + 1
			r.highest = math.max(r.highest, r.n)
			bought = bought + 1
		else
			break
		end
	end
	if bought > 0 then
		self.recalc = true
		self:OnBuildingBought(b)
		NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
		self:Changed()
	end
	return bought
end

function Game:SellBuilding(b, amount)
	if S.onAscend then
		return 0
	end
	local r = self:Bld(b.name)
	if amount == -1 then
		amount = r.n
	end
	local sold = 0
	for _ = 1, amount do
		if r.n <= 0 then
			break
		end
		local price = math.floor(self:BuildingPrice(b) * self:SellMultiplier())
		S.cookies = S.cookies + price
		S.earned = math.max(S.cookies, S.earned)
		r.n = r.n - 1
		sold = sold + 1
	end
	if sold > 0 then
		S.sold = (S.sold or 0) + sold
		self.recalc = true
		if b.id == 1 then
			self:Win("Just wrong")
			if r.n == 0 then
				self:Lock("Elder Pledge")
				self:CollectWrinklers()
				S.pledgeT = 0
			end
		end
		local godLvl = self:HasGod("ruin")
		if godLvl > 0 then
			local old = self:HasBuff("Devastation")
			local per = godLvl == 1 and 0.01 or godLvl == 2 and 0.005 or 0.0025
			if old then
				old.multClick = old.multClick + sold * per
			else
				self:GainBuff("devastation", 10, 1 + sold * per)
			end
		end
		if self:GoldenOnScreen() <= 0 and self:AuraMult("Dragon Orbs") > 0 then
			local highest = self:HighestBuilding()
			if (not highest or highest.id <= b.id) and math.random() < self:AuraMult("Dragon Orbs") * 0.1 and #self:Buffs() == 0 then
				self:SpawnShimmer("golden")
				NS.Notify("Dragon Orbs!", "Wish granted. Golden cookie spawned.", {33,25})
			end
		end
		NS.PlayKit("IG_BACKPACK_COIN_SELECT")
		self:Changed()
	end
	return sold
end

-- Sell without getting anything back (dragon training).
function Game:Sacrifice(b, amount)
	local r = self:Bld(b.name)
	if amount == -1 then
		amount = r.n
	end
	local sold = 0
	for _ = 1, amount do
		if r.n <= 0 then
			break
		end
		r.n = r.n - 1
		sold = sold + 1
	end
	if sold > 0 then
		self.recalc = true
		self:Changed()
	end
	return sold
end

-- Free buildings whose price behaves as if you did not have them.
function Game:GetFree(b, amount)
	local r = self:Bld(b.name)
	r.n = r.n + amount
	r.bought = r.bought + amount
	r.free = r.free + amount
	r.highest = math.max(r.highest, r.n)
	self.recalc = true
end

-- The buildings' buyFunctions.
function Game:OnBuildingBought(b)
	self:UnlockTiered(b)
	local n = self:Count(b.name)
	if b.id == 0 then
		if n >= 1 then self:Unlock({ "Reinforced index finger", "Carpal tunnel prevention cream" }) end
		if n >= 10 then self:Unlock("Ambidextrous") end
		if n >= 25 then self:Unlock("Thousand fingers") end
		if n >= 50 then self:Unlock("Million fingers") end
		if n >= 100 then self:Unlock("Billion fingers") end
		if n >= 150 then self:Unlock("Trillion fingers") end
		if n >= 200 then self:Unlock("Quadrillion fingers") end
		if n >= 250 then self:Unlock("Quintillion fingers") end
		if n >= 300 then self:Unlock("Sextillion fingers") end
		if n >= 350 then self:Unlock("Septillion fingers") end
		if n >= 400 then self:Unlock("Octillion fingers") end
		if n >= 450 then self:Unlock("Nonillion fingers") end
		if n >= 500 then self:Unlock("Decillion fingers") end
		if n >= 550 then self:Unlock("Undecillion fingers") end
		for _, step in ipairs(NS.CURSOR_ACHIEVEMENTS) do
			if n >= step[1] then
				self:Win(step[2])
			end
		end
	elseif b.id >= 2 then
		if n >= self.SpecialGrandmaUnlock and self:Count("Grandma") > 0 and b.grandma then
			self:Unlock(b.grandma)
		end
	end
end

function Game:UnlockTiered(b)
	local n = self:Count(b.name)
	for tier, u in pairs(b.tieredList) do
		local t = NS.TIERS[tier]
		if t and t.unlock ~= -1 and n >= t.unlock then
			self:Unlock(u.name)
		end
	end
	for tier, a in pairs(b.tieredAchievList) do
		local t = NS.TIERS[tier]
		if t and t.achievUnlock and n >= t.achievUnlock then
			self:Win(a.name)
		end
	end
	for _, syn in ipairs(b.synergyList) do
		local t = NS.TIERS[syn.tier]
		if t and t.req and self:Has(t.req) and self:Count(syn.b1) >= t.unlock and self:Count(syn.b2) >= t.unlock then
			self:Unlock(syn.name)
		end
	end
end

-- Spends sugar lumps on a building level.
function Game:LevelUp(b)
	local r = self:Bld(b.name)
	if not self:SpendLumps(r.level + 1) then
		return false
	end
	r.level = r.level + 1
	if r.level >= 10 and NS.LEVEL_ACHIEVEMENTS[b.name] then
		self:Win(NS.LEVEL_ACHIEVEMENTS[b.name])
	end
	NS.PlayKit("UI_EPICLOOT_TOAST")
	self.recalc = true
	if self.OnBuildingLevel then
		self:OnBuildingLevel(b, r.level)
	end
	self:Changed()
	return true
end

-------------------------------------------------------------------------------
-- Upgrade prices and buying
-------------------------------------------------------------------------------

local CPS_SCALED = { ["Elderwort biscuits"] = 120, ["Bakeberry cookies"] = 60, ["Duketater cookies"] = 180, ["Green yeast digestives"] = 180, ["Fern tea"] = 60, ["Ichor syrup"] = 120, ["Wheat slims"] = 30, ["Wrinkler ambergris"] = 60 }
local FORTUNE_BASE = { ["Fortune #100"] = 7.777777777777777e33, ["Fortune #101"] = 7.777777777777777e36, ["Fortune #102"] = 7.777777777777777e39 }
local TOGGLE_INTO = {
	["Golden switch [off]"] = "Golden switch [on]", ["Golden switch [on]"] = "Golden switch [off]",
	["Shimmering veil [off]"] = "Shimmering veil [on]", ["Shimmering veil [on]"] = "Shimmering veil [off]",
}
NS.TOGGLE_INTO = TOGGLE_INTO
local SANTA_DROP_SET, EGG_SET, RARE_EGG_SET, DRAGON_DROP_SET = {}, {}, {}, {}
for _, name in ipairs(NS.SANTA_DROPS) do SANTA_DROP_SET[name] = true end
for _, name in ipairs(NS.EGG_DROPS) do EGG_SET[name] = true end
for _, name in ipairs(NS.RARE_EGG_DROPS) do RARE_EGG_SET[name] = true end
for _, name in ipairs(NS.DRAGON_DROPS) do DRAGON_DROP_SET[name] = true end

function Game:EggsOwned()
	local n = 0
	for _, name in ipairs(NS.EASTER_EGGS) do
		if self:Has(name) then
			n = n + 1
		end
	end
	return n
end

-- The original's priceFunc, by name.
function Game:UpgradeBasePrice(u)
	local name = u.name
	if name == "Elder Pledge" then
		return 8 ^ math.min((S.pledges or 0) + 2, 14)
	elseif name == "Golden switch [off]" or name == "Golden switch [on]" then
		return (self.cps or 0) * 60 * 60
	elseif name == "Shimmering veil [off]" then
		return (self.unbuffedCps or 0) * 60 * 60 * 24
	elseif FORTUNE_BASE[name] then
		return math.min(FORTUNE_BASE[name], (self.unbuffedCps or 0) * 60 * 60 * 24)
	elseif CPS_SCALED[name] then
		return CPS_SCALED[name] * (self.cps or 0) * 60
	elseif DRAGON_DROP_SET[name] then
		return (self.unbuffedCps or 0) * 60 * 30 * (((S.dragonLevel or 0) < #NS.DRAGON_LEVELS - 1) and 1 or 0.1)
	elseif SANTA_DROP_SET[name] then
		return (3 ^ (S.santaLevel or 0)) * 2525
	elseif EGG_SET[name] then
		return (2 ^ self:EggsOwned()) * 999
	elseif RARE_EGG_SET[name] then
		return (3 ^ self:EggsOwned()) * 999
	elseif u.seasonTrigger then
		return self:SeasonTriggerPrice()
	elseif u.tier == "synergy1" or u.tier == "synergy2" then
		return u.price * (self:Has("Chimera") and 0.98 or 1)
	end
	return u.price or 0
end

function Game:UpgradePrice(u)
	local price = self:UpgradeBasePrice(u)
	if price == 0 then
		return 0
	end
	if u.pool ~= "prestige" then
		if self:Has("Toy workshop") then price = price * 0.95 end
		if self:Has("Five-finger discount") then price = price * (0.99 ^ (self:Count("Cursor") / 100)) end
		if self:Has("Santa's dominion") then price = price * 0.98 end
		if self:Has("Faberge egg") then price = price * 0.99 end
		if self:Has("Divine sales") then price = price * 0.99 end
		if self:Has("Fortune #100") then price = price * 0.99 end
		if self:Has("Wrinkler ambergris") then price = price * 0.99 end
		if u.kitten and self:Has("Kitten wages") then price = price * 0.9 end
		if self:HasBuff("Haggler's luck") then price = price * 0.98 end
		if self:HasBuff("Haggler's misery") then price = price * 1.02 end
		price = price * (1 - self:AuraMult("Master of the Armory") * 0.02)
		price = price * self:Eff("upgradeCost")
		if u.pool == "cookie" and self:Has("Divine bakeries") then price = price / 5 end
	end
	return math.ceil(price)
end

function Game:CanBuyUpgrade(u)
	if (u.lumps or 0) > 0 then
		return (S.lumps or 0) >= u.lumps
	end
	return S.cookies >= self:UpgradePrice(u)
end

-- Toggles that open a selector instead of buying (the UI handles them).
NS.SELECTORS = { ["Milk selector"] = true, ["Background selector"] = true, ["Golden cookie sound selector"] = true, ["Jukebox"] = true }

function Game:BuyUpgrade(u)
	if S.onAscend then
		return false
	end
	if u.pool == "prestige" then
		return self:BuyPrestige(u)
	end
	if NS.SELECTORS[u.name] then
		if NS.UI and NS.UI.OpenSelector then
			NS.UI:OpenSelector(u)
		end
		return true
	end
	-- A season trigger that is running: clicking it again cancels the season.
	if u.seasonTrigger and self:Has(u.name) and S.season == u.seasonTrigger then
		self:EndSeason(true)
		return true
	end
	if self:Has(u.name) then
		return false
	end
	if not self:CanBuyUpgrade(u) then
		return false
	end
	if (u.lumps or 0) > 0 then
		if not self:SpendLumps(u.lumps) then
			return false
		end
	else
		self:Spend(self:UpgradePrice(u))
	end
	S.up[u.name] = true
	self:OnUpgradeBought(u)
	local into = TOGGLE_INTO[u.name]
	if into then
		self:Lock(into)
		self:Unlock(into)
	end
	self.recalc = true
	self.countsDirty = true
	self:StoreDirty()
	NS.PlayKit("IG_BACKPACK_COIN_OK")
	self:Changed()
	return true
end

-- The original's buyFunctions, by name.
local RESEARCH_NEXT = {
	["Bingo center/Research facility"] = "Specialized chocolate chips",
	["Specialized chocolate chips"] = "Designer cocoa beans",
	["Designer cocoa beans"] = "Ritual rolling pins",
	["Ritual rolling pins"] = "Underworld ovens",
	["Underworld ovens"] = "One mind",
	["One mind"] = "Exotic nuts",
	["Exotic nuts"] = "Communal brainsweep",
	["Communal brainsweep"] = "Arcane sugar",
	["Arcane sugar"] = "Elder Pact",
}

function Game:OnUpgradeBought(u, silent)
	local name = u.name
	if RESEARCH_NEXT[name] then
		if name == "One mind" then S.elderWrath = 1 end
		if name == "Communal brainsweep" then S.elderWrath = 2 end
		self:SetResearch(RESEARCH_NEXT[name])
	elseif name == "Elder Pact" then
		S.elderWrath = 3
	elseif name == "Elder Pledge" then
		S.elderWrath = 0
		S.pledges = (S.pledges or 0) + 1
		S.pledgeT = self:PledgeDuration()
		self:Unlock("Elder Covenant")
		self:CollectWrinklers()
	elseif name == "Elder Covenant" then
		S.pledgeT = 0
		self:Lock("Revoke Elder Covenant")
		self:Unlock("Revoke Elder Covenant")
		self:Lock("Elder Pledge")
		self:Win("Elder calm")
		self:CollectWrinklers()
	elseif name == "Revoke Elder Covenant" then
		self:Lock("Elder Covenant")
		self:Unlock("Elder Covenant")
	elseif name == "A festive hat" then
		local drop = Choose(NS.SANTA_DROPS)
		self:Unlock(drop)
		NS.Notify("In the festive hat, you find...", "a festive test tube and " .. drop .. ".", NS.U[drop] and NS.U[drop].icon)
	elseif name == "Chocolate egg" then
		local cookies = S.cookies * 0.05
		NS.Notify("Chocolate egg", "The egg bursts into " .. NS.Beautify(cookies) .. " cookies!", u.icon)
		self:Earn(cookies)
	elseif name == "Sugar frenzy" then
		self:GainBuff("sugar frenzy", 60 * 60, 3)
		NS.Notify("Sugar frenzy!", "CpS x3 for 1 hour!", {29,14})
	elseif name == "Season switcher" then
		for _, s in pairs(NS.SEASONS) do
			self:Unlock(s.trigger)
		end
	elseif u.seasonTrigger and not silent then
		self:StartSeason(u.seasonTrigger)
	end
end

function Game:PledgeDuration()
	return 60 * (self:Has("Sacrificial rolling pins") and 60 or 30)
end

function Game:SetResearch(what)
	if NS.U[what] and not self:Has(what) then
		S.researchT = self.baseResearchTime
		if self:Has("Persistent memory") then
			S.researchT = math.ceil(self.baseResearchTime / 10)
		end
		S.nextResearch = what
		NS.Notify("Research has begun", "Your bingo center/research facility is conducting experiments.", {9,0})
	end
end

-- The upgrades the store shows (the original's RebuildUpgrades), sorted.
function Game:UpgradesInStore()
	local list = {}
	for _, u in ipairs(NS.UPGRADES) do
		local bought = S.up[u.name]
		if not bought and u.pool ~= "debug" and u.pool ~= "prestige" and u.pool ~= "prestigeDecor" and (S.ascensionMode ~= 1 or (not u.lasting and u.tier ~= "fortune")) then
			if S.unl[u.name] then
				table.insert(list, u)
			end
		elseif bought and (u.name == "Elder Pledge" or u.seasonTrigger) then
			table.insert(list, u)
		end
	end
	local prices = {}
	for _, u in ipairs(list) do
		prices[u] = u.pool == "toggle" and u.order or self:UpgradePrice(u)
	end
	table.sort(list, function(a, b)
		if prices[a] ~= prices[b] then
			return prices[a] < prices[b]
		end
		return a.index < b.index
	end)
	return list
end

function Game:IsVaulted(u)
	S.vault = S.vault or {}
	return S.vault[u.name] == true
end

function Game:ToggleVault(u)
	S.vault = S.vault or {}
	if S.vault[u.name] then
		S.vault[u.name] = nil
	else
		S.vault[u.name] = true
	end
	self:StoreDirty()
end

function Game:BuyAllUpgrades()
	if not self:Has("Inspired checklist") then
		return
	end
	for _, u in ipairs(self:UpgradesInStore()) do
		if not self:IsVaulted(u) and u.pool ~= "toggle" and u.pool ~= "tech" and not NS.SELECTORS[u.name] and not u.seasonTrigger then
			self:BuyUpgrade(u)
		end
	end
end

-------------------------------------------------------------------------------
-- Seasons
-------------------------------------------------------------------------------

function Game:SeasonTriggerPrice()
	local m = 1
	local godLvl = self:HasGod("seasons")
	if godLvl == 1 then m = 2 elseif godLvl == 2 then m = 1.5 elseif godLvl == 3 then m = 1.25 end
	return self.seasonTriggerBasePrice + (self.unbuffedCps or 0) * 60 * (1.5 ^ (S.seasonUses or 0)) * m
end

function Game:SeasonDuration()
	return 60 * 60 * 24
end

function Game:StartSeason(key)
	S.seasonUses = (S.seasonUses or 0) + 1
	for k, s in pairs(NS.SEASONS) do
		if k ~= key then
			self:Lock(s.trigger)
			self:Unlock(s.trigger)
		end
	end
	if S.season ~= "" and S.season ~= key and NS.SEASONS[S.season] then
		NS.Notify(NS.SEASONS[S.season].over, "", NS.U[NS.SEASONS[S.season].trigger].icon, true)
	end
	S.season = key
	S.seasonT = self:SeasonDuration()
	NS.Notify(NS.SEASONS[key].start, "", NS.U[NS.SEASONS[key].trigger].icon, true)
	self.recalc = true
	self:StoreDirty()
	if NS.UI and NS.UI.OnSeasonChanged then
		NS.UI:OnSeasonChanged()
	end
end

function Game:EndSeason(cancelled)
	local key = S.season
	if key == "" or not NS.SEASONS[key] then
		return
	end
	local trigger = NS.SEASONS[key].trigger
	NS.Notify(NS.SEASONS[key].over, "", NS.U[trigger].icon)
	S.up[trigger] = nil
	if self:Has("Season switcher") then
		self:Unlock(trigger)
	end
	S.season = ""
	S.seasonT = -1
	self.recalc = true
	self.countsDirty = true
	self:StoreDirty()
	if NS.UI and NS.UI.OnSeasonChanged then
		NS.UI:OnSeasonChanged()
	end
	self:Changed()
end

-------------------------------------------------------------------------------
-- Grandmapocalypse
-------------------------------------------------------------------------------

function Game:UpdateGrandmapocalypse(dt)
	if self:Has("Elder Covenant") or self:Count("Grandma") == 0 then
		S.elderWrath = 0
	elseif (S.pledgeT or 0) > 0 then
		S.pledgeT = S.pledgeT - dt
		if S.pledgeT <= 0 then
			S.pledgeT = 0
			self:Lock("Elder Pledge")
			self:Unlock("Elder Pledge")
			S.elderWrath = 1
			NS.Notify("The pledge has worn off", "The grandmatriarchs stir again.", {9,9})
			self:Changed()
		end
	else
		if self:Has("One mind") and S.elderWrath == 0 then
			S.elderWrath = 1
		end
		local maxWrath = B(self:Has("One mind")) + B(self:Has("Communal brainsweep")) + B(self:Has("Elder Pact"))
		if S.elderWrath < maxWrath and math.random() < 1 - (1 - 0.001) ^ (dt * FPS) then
			S.elderWrath = S.elderWrath + 1
		end
		if self:Has("Elder Pact") and not self:HasUnlocked("Elder Pledge") then
			self:Lock("Elder Pledge")
			self:Unlock("Elder Pledge")
		end
	end
	if S.elderWrath ~= self.elderWrathOld then
		self.elderWrathOld = S.elderWrath
		self:StoreDirty()
		if NS.UI and NS.UI.OnWrathChanged then
			NS.UI:OnWrathChanged()
		end
	end
	self:UpdateWrinklers(dt)
end

-------------------------------------------------------------------------------
-- Unlock and achievement checks (the original's five-second block)
-------------------------------------------------------------------------------

local CENTENNIALS = {
	{ 100, "Centennial", "Milk chocolate butter biscuit" },
	{ 150, "Centennial and a half", "Dark chocolate butter biscuit" },
	{ 200, "Bicentennial", "White chocolate butter biscuit" },
	{ 250, "Bicentennial and a half", "Ruby chocolate butter biscuit" },
	{ 300, "Tricentennial", "Lavender chocolate butter biscuit" },
	{ 350, "Tricentennial and a half", "Synthetic chocolate green honey butter biscuit" },
	{ 400, "Quadricentennial", "Royal raspberry chocolate butter biscuit" },
	{ 450, "Quadricentennial and a half", "Ultra-concentrated high-energy chocolate butter biscuit" },
	{ 500, "Quincentennial", "Pure pitch-black chocolate butter biscuit" },
	{ 550, "Quincentennial and a half", "Cosmic chocolate butter biscuit" },
	{ 600, "Sexcentennial", "Butter biscuit (with butter)" },
	{ 650, "Sexcentennial and a half", "Everybutter biscuit" },
	{ 700, "Septcentennial", "Personal biscuit" },
}
local HANDMADE = {
	{ 1e3, "Clicktastic", "Plastic mouse" }, { 1e5, "Clickathlon", "Iron mouse" }, { 1e7, "Clickolympics", "Titanium mouse" },
	{ 1e9, "Clickorama", "Adamantium mouse" }, { 1e11, "Clickasmic", "Unobtainium mouse" }, { 1e13, "Clickageddon", "Eludium mouse" },
	{ 1e15, "Clicknarok", "Wishalloy mouse" }, { 1e17, "Clickastrophe", "Fantasteel mouse" }, { 1e19, "Clickataclysm", "Nevercrack mouse" },
	{ 1e21, "The ultimate clickdown", "Armythril mouse" }, { 1e23, "All the other kids with the pumped up clicks", "Technobsidian mouse" },
	{ 1e25, "One...more...click...", "Plasmarble mouse" }, { 1e27, "Clickety split", "Miraculite mouse" },
	{ 1e29, "Ain't that a click in the head", "Aetherice mouse" }, { 1e31, "What's not clicking", "Omniplast mouse" },
}
local KITTEN_UNLOCKS = {
	{ 0.5, "Kitten helpers" }, { 1, "Kitten workers" }, { 2, "Kitten engineers" }, { 3, "Kitten overseers" }, { 4, "Kitten managers" },
	{ 5, "Kitten accountants" }, { 6, "Kitten specialists" }, { 7, "Kitten experts" }, { 8, "Kitten consultants" },
	{ 9, "Kitten assistants to the regional manager" }, { 10, "Kitten marketeers" }, { 11, "Kitten analysts" }, { 12, "Kitten executives" },
	{ 13, "Kitten admins" }, { 14, "Kitten strategists" },
}
local BUILDINGS_OWNED = { { 100, "Builder" }, { 500, "Architect" }, { 1000, "Engineer" }, { 2500, "Lord of Constructs" }, { 5000, "Grand design" }, { 7500, "Ecumenopolis" }, { 10000, "Myriad" } }
local UPGRADES_OWNED = { { 20, "Enhancer" }, { 50, "Augmenter" }, { 100, "Upgrader" }, { 200, "Lord of Progress" }, { 300, "The full picture" }, { 400, "When there's nothing left to add" }, { 500, "Kaizen" }, { 600, "Beyond quality" }, { 700, "Oft we mar what's well" } }

local function HasAll(game, list)
	for _, name in ipairs(list) do
		if not game:Has(name) then
			return false
		end
	end
	return true
end

function Game:CheckMilkUnlocks()
	local mp = self:AchievementsOwned() / 25
	for _, step in ipairs(KITTEN_UNLOCKS) do
		if mp >= step[1] then
			self:Unlock(step[2])
		end
	end
	self.milkProgress = mp
	local rank = math.min(math.floor(mp), #NS.MILK_RANKS - 1)
	self.milk = NS.MILK_RANKS[rank + 1]
end

function Game:CheckUnlocks()
	local earned = S.earned
	if earned ~= earned then -- NaN guard
		S.cookies, S.earned = 0, 0
		earned = 0
		self.recalc = true
	end
	local now = time()
	if not S.fullDate or now - S.fullDate >= 365 * 24 * 60 * 60 then
		self:Win("So much to do so much to see")
	end
	if earned >= 1e6 and (S.ascensionMode == 1 or (S.resets or 0) == 0) then
		local played = S.runTime or 0
		if played <= 60 * 35 then self:Win("Speed baking I") end
		if played <= 60 * 25 then self:Win("Speed baking II") end
		if played <= 60 * 15 then self:Win("Speed baking III") end
		if S.clicks <= 15 then self:Win("Neverclick") end
		if S.clicks <= 0 then self:Win("True Neverclick") end
		if earned >= 1e9 and self:UpgradesOwned() == 0 then self:Win("Hardcore") end
	end
	for _, unlock in ipairs(NS.UNLOCK_AT) do
		if earned >= unlock.cookies then
			local pass = true
			if unlock.require and not self:Has(unlock.require) and not self:HasAchiev(unlock.require) then pass = false end
			if unlock.season and S.season ~= unlock.season then pass = false end
			if pass then
				self:Unlock(unlock.name)
				self:Win(unlock.name)
			end
		end
	end
	if self:Has("Golden switch") then self:Unlock("Golden switch [off]") end
	if self:Has("Shimmering veil") and not self:Has("Shimmering veil [off]") and not self:Has("Shimmering veil [on]") then
		self:Unlock("Shimmering veil [on]")
		self:EarnUpgrade("Shimmering veil [off]")
	end
	if self:Has("Sugar craving") then self:Unlock("Sugar frenzy") end
	if self:Has("Classic dairy selection") then self:Unlock("Milk selector") end
	if self:Has("Basic wallpaper assortment") then self:Unlock("Background selector") end
	if self:Has("Golden cookie alert sound") then self:Unlock("Golden cookie sound selector") end
	if self:Has("Sound test") then self:Unlock("Jukebox") end
	if self:Has("Prism heart biscuits") then self:Win("Lovely cookies") end
	if S.season == "easter" then
		local eggs = 0
		for _, name in ipairs(NS.EASTER_EGGS) do
			if self:HasUnlocked(name) then eggs = eggs + 1 end
		end
		if eggs >= 1 then self:Win("The hunt is on") end
		if eggs >= 7 then self:Win("Egging on") end
		if eggs >= 14 then self:Win("Mass Easteria") end
		if eggs >= #NS.EASTER_EGGS then self:Win("Hide & seek champion") end
	end
	if self:Has("Fortune cookies") then
		local fortunes = 0
		for _, u in ipairs(NS.FORTUNE_UPGRADES) do
			if self:Has(u.name) then fortunes = fortunes + 1 end
		end
		if fortunes >= #NS.FORTUNE_UPGRADES then self:Win("O Fortuna") end
	end
	if self:Has("Legacy") and S.ascensionMode ~= 1 then
		self:Unlock("Heavenly chip secret")
		if self:Has("Heavenly chip secret") then self:Unlock("Heavenly cookie stand") end
		if self:Has("Heavenly cookie stand") then self:Unlock("Heavenly bakery") end
		if self:Has("Heavenly bakery") then self:Unlock("Heavenly confectionery") end
		if self:Has("Heavenly confectionery") then self:Unlock("Heavenly key") end
		if self:Has("Heavenly key") then self:Win("Wholesome") end
	end
	for _, name in ipairs(NS.BANK_ACHIEVEMENTS) do
		local a = NS.A[name]
		if a and a.threshold and earned >= a.threshold then self:Win(name) end
	end
	if (S.elderWrath or 0) >= 3 then self:Win("Grandmapocalypse") end

	local buildingsOwned = 0
	local mathematician, base10 = true, true
	local minAmount = 100000
	local total = #NS.BUILDINGS
	for _, b in ipairs(NS.BUILDINGS) do
		local n = self:Count(b.name)
		buildingsOwned = buildingsOwned + n
		minAmount = math.min(n, minAmount)
		if not self:HasAchiev("Mathematician") and n < math.min(128, 2 ^ ((total - b.id) - 1)) then mathematician = false end
		if not self:HasAchiev("Base 10") and n < (total - b.id) * 10 then base10 = false end
	end
	if minAmount >= 1 then self:Win("One with everything") end
	if mathematician then self:Win("Mathematician") end
	if base10 then self:Win("Base 10") end
	for _, step in ipairs(CENTENNIALS) do
		if minAmount >= step[1] then
			self:Win(step[2])
			self:Unlock(step[3])
		end
	end
	for _, step in ipairs(HANDMADE) do
		if S.handmade >= step[1] then
			self:Win(step[2])
			self:Unlock(step[3])
		end
	end
	if earned < S.cookies then self:Win("Cheated cookies taste awful") end
	if HasAll(self, NS.HALLOWEEN_DROPS) then self:Win("Spooky cookies") end
	if (S.wrinklersPopped or 0) >= 1 then self:Win("Itchscratcher") end
	if (S.wrinklersPopped or 0) >= 50 then self:Win("Wrinklesquisher") end
	if (S.wrinklersPopped or 0) >= 200 then self:Win("Moistburster") end
	if earned >= 1e6 and self:Has("How to bake your dragon") then self:Unlock("A crumbly egg") end
	if earned >= 25 and S.season == "christmas" then self:Unlock("A festive hat") end
	if HasAll(self, NS.REINDEER_DROPS) then self:Win("Let it snow") end
	if (S.reindeerClicked or 0) >= 1 then self:Win("Oh deer") end
	if (S.reindeerClicked or 0) >= 50 then self:Win("Sleigh of hand") end
	if (S.reindeerClicked or 0) >= 200 then self:Win("Reindeer sleigher") end
	for _, step in ipairs(BUILDINGS_OWNED) do
		if buildingsOwned >= step[1] then self:Win(step[2]) end
	end
	local upgradesOwned = self:UpgradesOwned()
	for _, step in ipairs(UPGRADES_OWNED) do
		if upgradesOwned >= step[1] then self:Win(step[2]) end
	end
	if buildingsOwned >= 4000 and upgradesOwned >= 300 then self:Win("Polymath") end
	if buildingsOwned >= 8000 and upgradesOwned >= 400 then self:Win("Renaissance baker") end
	if not self:HasAchiev("Jellicles") and self:KittensOwned() >= 10 then self:Win("Jellicles") end
	if earned >= 1e14 and not self:HasAchiev("You win a cookie") then
		self:Win("You win a cookie")
		self:Earn(1)
	end
	if self:GoldenOnScreen() >= 4 then self:Win("Four-leaf cookie") end
	local grandmas = 0
	for _, name in ipairs(NS.GRANDMA_SYNERGIES) do
		if self:Has(name) then grandmas = grandmas + 1 end
	end
	if not self:HasAchiev("Elder") and grandmas >= 7 then self:Win("Elder") end
	if not self:HasAchiev("Veteran") and grandmas >= 14 then self:Win("Veteran") end
	if self:Count("Grandma") >= 6 and not self:Has("Bingo center/Research facility") and self:HasAchiev("Elder") then
		self:Unlock("Bingo center/Research facility")
	end
	if (S.pledges or 0) > 0 then self:Win("Elder nap") end
	if (S.pledges or 0) >= 5 then self:Win("Elder slumber") end
	if (S.pledges or 0) >= 10 then self:Unlock("Sacrificial rolling pins") end
	if self:Count("Cursor") + self:Count("Grandma") >= 777 then self:Win("The elder scrolls") end
	for _, b in ipairs(NS.BUILDINGS) do
		local r = S.bld[b.name]
		if r then
			for _, p in ipairs(b.productionAchievs) do
				if r.total >= p.pow and p.achiev then
					self:Win(p.achiev.name)
				end
			end
		end
	end
	if not self:HasAchiev("Cookie-dunker") and (self.milkProgress or 0) >= 1 then
		self:Win("Cookie-dunker")
	end
	self:CheckMilkUnlocks()
end

-------------------------------------------------------------------------------
-- The tick
-------------------------------------------------------------------------------

function Game:Tick(dt)
	if not S then
		return
	end
	dt = math.min(dt, MAX_TICK)
	self.flightAcc = (self.flightAcc or 0) + dt
	if self.flightAcc >= 0.5 then
		self.flightAcc = 0
		self:CheckFlight()
	end
	if S.onAscend then
		return
	end
	S.playTime = (S.playTime or 0) + dt
	S.runTime = (S.runTime or 0) + dt

	self:UpdateGrandmapocalypse(dt)

	if self.autoclicker > 0 then
		self.autoclicker = math.max(0, self.autoclicker - dt * FPS)
	end
	if (S.researchT or 0) > 0 then
		S.researchT = S.researchT - dt
		if S.researchT <= 0 then
			S.researchT = 0
			if S.nextResearch and not self:Has(S.nextResearch) then
				self:Unlock(S.nextResearch)
				NS.Notify("Research complete", "You have discovered: " .. S.nextResearch .. ".", NS.U[S.nextResearch] and NS.U[S.nextResearch].icon)
			end
			S.nextResearch = false
			self.recalc = true
		end
	end
	if (S.seasonT or 0) > 0 then
		S.seasonT = S.seasonT - dt
		if S.seasonT <= 0 and S.season ~= "" and not self:Has("Eternal seasons") then
			self:EndSeason(false)
		end
	end

	if self.recalc then
		self:CalculateGains()
	end
	local cps = self.cps or 0
	self:Earn(cps * dt)
	self:DoLumps(dt)
	if self.minigames then
		for _, mg in pairs(self.minigames) do
			if mg.loaded and mg.logic and S.ascensionMode ~= 1 then
				mg:logic(dt)
			end
		end
	end
	if (self.cpsSucked or 0) > 0 then
		local eaten = cps * dt * self.cpsSucked
		self:Dissolve(eaten)
		S.cookiesSucked = (S.cookiesSucked or 0) + eaten
	end
	local gm = self.globalMult or 1
	for name, entry in pairs(self.cpsBy) do
		local r = S.bld[name]
		if r and entry.total > 0 then
			r.total = r.total + entry.total * gm * dt
		end
	end

	self.tenAcc = self.tenAcc + dt
	if self.tenAcc >= 10 then
		self.tenAcc = 0
		self.recalc = true
	end
	self.secondAcc = self.secondAcc + dt
	if self.secondAcc >= 1 then
		self.secondAcc = 0
		if math.random() < 1 / 1000000 then
			self:Win("Just plain lucky")
		end
	end
	self.checkAcc = self.checkAcc + dt
	if self.checkAcc >= 5 then
		self.checkAcc = 0
		self:CheckUnlocks()
	end

	self:UpdateShimmers(dt)
	self:UpdateBuffs(dt)
	if self.UpdateTicker then
		self:UpdateTicker(dt)
	end
end

function Game:CheckFlight()
	local s = NS.GetSettings()
	local inFlight = (s.autoOpenTaxi and UnitOnTaxi("player")) or (s.autoOpenFlying and IsFlying and IsFlying()) or false
	if inFlight and not self.wasInFlight then
		if not NS.UI:IsShown() then
			NS.UI:Show()
			NS.UI.autoOpened = true
		end
	elseif not inFlight and self.wasInFlight then
		if s.autoClose and NS.UI.autoOpened and NS.UI:IsShown() then
			NS.UI:Hide()
		end
		NS.UI.autoOpened = nil
	end
	self.wasInFlight = inFlight
end

-------------------------------------------------------------------------------
-- Change hooks
-------------------------------------------------------------------------------

function Game:StoreDirty()
	self.storeDirty = true
end

function Game:Changed()
	self.version = (self.version or 0) + 1
	self.storeDirty = true
	if NS.UI and NS.UI.Refresh then
		NS.UI:Refresh(true)
	end
	if NS.Comm and NS.Comm.OnChanged then
		NS.Comm:OnChanged()
	end
end

-- Statistics helpers used by the guild board.
function Game:TotalBuildings()
	return self:BuildingsOwned()
end

function Game:AchievementsUnlocked()
	return self:AchievementsOwned()
end

function Game:Cps()
	return self.cps or 0
end
