-- MauCookie rules: production, clicking, buying and selling, golden and
-- wrath cookies, buffs, the Grandmapocalypse (research, wrinklers, pledges),
-- achievements, ascension, the news ticker, flight auto-open.
--
-- The bakery ticks from a frame that is always shown, so cookies keep
-- coming while the window is closed; the window only draws.  Nothing is
-- produced while logged out; timers for research and pledges run on
-- save.playTime, which only advances while logged in.

local _, NS = ...

local Game = {}
NS.Game = Game

Game.GOLDEN_MIN, Game.GOLDEN_MAX = 300, 900   -- seconds between golden cookies, as in the original
Game.GOLDEN_SHOW = 13
Game.FRENZY_TIME, Game.FRENZY_MULT = 77, 7
Game.CLICK_FRENZY_TIME, Game.CLICK_FRENZY_MULT = 13, 777
Game.SPECIAL_TIME = 30
Game.CLOT_TIME = 66
Game.ELDER_FRENZY_TIME, Game.ELDER_FRENZY_MULT = 6, 666
Game.CURSED_TIME = 10
Game.LUCKY_CAP_SECONDS = 900
Game.STORM_TIME = 7
Game.STORM_DROP_LIFE = 3
Game.MAX_TICK = 5
Game.RESEARCH_TIME = 600       -- seconds of bakery time between discoveries (the original: 30 min)
Game.PLEDGE_TIME = 1800
Game.SELL_RATE = 0.25
Game.WRINKLER_EAT = 0.05
Game.WRINKLER_RETURN = 1.1
Game.WRINKLER_HP = 3
Game.MAX_WRINKLERS = 10

function Game:Start()
	self.save = MauCookieDB.save
	self.buffs = {}
	self.version = 0
	self.nextGolden = self:RollGolden()
	self.ticker = CreateFrame("Frame")
	self.ticker:SetScript("OnUpdate", function(_, elapsed)
		NS.Guard("tick", Game.Tick, Game, elapsed)
	end)
end

-------------------------------------------------------------------------------
-- Counts and flags
-------------------------------------------------------------------------------

function Game:Count(buildingId)
	return self.save.buildings[buildingId] or 0
end

function Game:HasUpgrade(id)
	return self.save.upgrades[id] == true
end

function Game:HasHeavenly(id)
	return self.save.heavenly[id] == true
end

function Game:Tiers(buildingId)
	local tiers = 0
	for tier = 1, 5 do
		if self:HasUpgrade(buildingId .. tier) then
			tiers = tiers + 1
		end
	end
	return tiers
end

function Game:UpgradesBought()
	local n = 0
	for _ in pairs(self.save.upgrades) do
		n = n + 1
	end
	return n
end

function Game:AchievementsUnlocked()
	local n = 0
	for _ in pairs(self.save.achievements) do
		n = n + 1
	end
	return n
end

function Game:TotalBuildings()
	local n = 0
	for _, count in pairs(self.save.buildings) do
		n = n + count
	end
	return n
end

function Game:CountKind(kind)
	local n = 0
	for _, u in ipairs(NS.UPGRADES) do
		if u.kind == kind and self:HasUpgrade(u.id) then
			n = n + 1
		end
	end
	return n
end

function Game:GrandmaTypes()
	return self:CountKind("grandmatype")
end

function Game:AllTime()
	return (self.save.allTime or 0) + self.save.baked
end

-- Grandmapocalypse: 0 quiet, 1..3 after One mind, Communal brainsweep,
-- Elder Pact.  A pledge or the covenant calms it to 0.
function Game:RawStage()
	local stage = 0
	if self:HasUpgrade("research5") then stage = 1 end
	if self:HasUpgrade("research7") then stage = 2 end
	if self:HasUpgrade("research9") then stage = 3 end
	return stage
end

function Game:IsPledged()
	return (self.save.pledgeUntil or 0) > self.save.playTime
end

function Game:Stage()
	if self.save.covenant or self:IsPledged() then
		return 0
	end
	return self:RawStage()
end

function Game:MaxWrinklers()
	return self.MAX_WRINKLERS + (self:HasHeavenly("elderspice") and 2 or 0)
end

-------------------------------------------------------------------------------
-- Production
-------------------------------------------------------------------------------

function Game:Milk()
	return 0.04 * self:AchievementsUnlocked()
end

function Game:KittenMult()
	local milk = self:Milk()
	local mult = 1
	for _, u in ipairs(NS.UPGRADES) do
		if u.kind == "kitten" and self:HasUpgrade(u.id) then
			mult = mult * (1 + milk * u.factor)
		end
	end
	if self:HasHeavenly("kittenangels") then
		mult = mult * (1 + milk * 0.1)
	end
	return mult
end

function Game:PrestigePower()
	local power = 1
	for _, id in ipairs({ "angels", "archangels", "virtues" }) do
		if self:HasHeavenly(id) then
			power = power + 0.1
		end
	end
	if self:HasHeavenly("luckydigit") then
		power = power + 0.01
	end
	return power
end

function Game:GlobalMult()
	local mult = (1 + 0.02 * self:CountKind("flavour")) * (1 + 0.01 * self:AchievementsUnlocked()) * self:KittenMult()
	mult = mult * (1 + 0.01 * (self.save.prestige or 0) * self:PrestigePower())
	if self:HasHeavenly("heavenlycookies") then mult = mult * 1.1 end
	if self:HasHeavenly("heavenlykey") then mult = mult * 1.25 end
	if self:HasHeavenly("wrinklycookies") then mult = mult * 1.1 end
	for _, r in ipairs(NS.RESEARCH) do
		if r.mult and self:HasUpgrade(r.id) then
			mult = mult * r.mult
		end
	end
	if self.save.covenant then mult = mult * 0.95 end
	if self.save.goldenSwitch then mult = mult * 1.5 end
	return mult
end

-- Production of one building of this kind per second, without the
-- whole-bakery buffs (Frenzy and friends) but with its own building special.
function Game:BuildingCps(b)
	local base = b.cps
	local grandmas = self:Count("grandma")
	local mult = 2 ^ self:Tiers(b.id)
	if b.id == "grandma" then
		for _, r in ipairs(NS.RESEARCH) do
			if self:HasUpgrade(r.id) then
				if r.perGrandma then base = base + r.perGrandma * grandmas end
				if r.perPortal then base = base + r.perPortal * self:Count("portal") end
				if r.grandmaMult then mult = mult * r.grandmaMult end
			end
		end
		mult = mult * (2 ^ self:GrandmaTypes())
	else
		local gt = NS.GRANDMA_TYPE_BY_BUILDING[b.id]
		if gt and self:HasUpgrade(gt.id) then
			mult = mult * (1 + 0.01 * grandmas / gt.per)
		end
	end
	for _, s in ipairs(NS.SYNERGY_BY_BUILDING[b.id] or {}) do
		if self:HasUpgrade(s.id) then
			if s.a == b.id then
				mult = mult * (1 + 0.05 * self:Count(s.b))
			else
				mult = mult * (1 + 0.001 * self:Count(s.a))
			end
		end
	end
	local special = self.buffs.special
	if special and special.building == b.id then
		mult = mult * special.mult
	end
	return base * mult * self:GlobalMult()
end

function Game:BuffMult()
	local mult = 1
	if self.buffs.frenzy then mult = mult * self.FRENZY_MULT end
	if self.buffs.clot then mult = mult * 0.5 end
	if self.buffs.elderFrenzy then mult = mult * self.ELDER_FRENZY_MULT end
	if self.buffs.cursed then mult = 0 end
	return mult
end

function Game:Cps(withBuffs)
	local total = 0
	for _, b in ipairs(NS.BUILDINGS) do
		local count = self:Count(b.id)
		if count > 0 then
			total = total + count * self:BuildingCps(b)
		end
	end
	if withBuffs ~= false then
		total = total * self:BuffMult()
	end
	return total
end

function Game:ClickPower()
	local cursed = self.buffs.cursed
	if cursed then
		return cursed.cps * 10
	end
	local power = (2 ^ self:Tiers("cursor")) * self:GlobalMult() + self:Cps(true) * 0.01 * self:CountKind("mouse")
	if self:HasHeavenly("halogloves") then
		power = power * 1.1
	end
	if self.buffs.clickFrenzy then
		power = power * self.CLICK_FRENZY_MULT
	end
	return power
end

-------------------------------------------------------------------------------
-- Store
-------------------------------------------------------------------------------

function Game:Price(b, owned)
	owned = owned or self:Count(b.id)
	return math.floor(b.cost * (NS.PRICE_GROWTH ^ owned))
end

function Game:PriceFor(b, amount)
	local owned, total = self:Count(b.id), 0
	for i = 0, amount - 1 do
		total = total + self:Price(b, owned + i)
	end
	return total
end

function Game:SellPriceFor(b, amount)
	local owned, total = self:Count(b.id), 0
	for i = 1, math.min(amount, owned) do
		total = total + math.floor(self:Price(b, owned - i) * self.SELL_RATE)
	end
	return total
end

function Game:IsRevealed(b)
	if self:Count(b.id) > 0 or b.index <= 2 then
		return true
	end
	local highest = 0
	for _, other in ipairs(NS.BUILDINGS) do
		if self:Count(other.id) > 0 then
			highest = other.index
		end
	end
	return b.index <= highest + 2
end

function Game:Gain(amount)
	self.save.cookies = self.save.cookies + amount
	self.save.baked = self.save.baked + amount
end

function Game:Click()
	if not self.save then
		return
	end
	local power = self:ClickPower()
	self:Gain(power)
	self.save.clicks = self.save.clicks + 1
	self.save.handmade = self.save.handmade + power
	NS.UI:OnClick(power)
	local now = GetTime()
	if now - (self.lastClickSound or 0) > 0.06 then
		self.lastClickSound = now
		NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
	end
end

function Game:Buy(b, amount)
	local bought = 0
	for _ = 1, amount do
		local price = self:Price(b)
		if self.save.cookies < price then
			break
		end
		self.save.cookies = self.save.cookies - price
		self.save.buildings[b.id] = self:Count(b.id) + 1
		bought = bought + 1
	end
	if bought > 0 then
		self:Changed()
		NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
	end
	return bought
end

function Game:Sell(b, amount)
	local sold = 0
	for _ = 1, amount do
		local owned = self:Count(b.id)
		if owned <= 0 then
			break
		end
		self.save.cookies = self.save.cookies + math.floor(self:Price(b, owned - 1) * self.SELL_RATE)
		self.save.buildings[b.id] = owned - 1
		sold = sold + 1
	end
	if sold > 0 then
		self.save.sold = (self.save.sold or 0) + sold
		if b.id == "grandma" then
			self.save.grandmasSold = (self.save.grandmasSold or 0) + sold
		end
		self:Changed()
		NS.PlayKit("IG_BACKPACK_COIN_SELECT")
	end
	return sold
end

function Game:UpgradeCost(u)
	if u.kind == "pledge" then
		return 8 ^ math.min((self.save.pledges or 0) + 2, 14)
	elseif u.kind == "switch" then
		return self.save.goldenSwitch and 0 or self:Cps(false) * 3600
	end
	return u.cost
end

function Game:UpgradeName(u)
	if u.kind == "switch" then
		return self.save.goldenSwitch and "Golden switch (on)" or "Golden switch (off)"
	end
	return u.name
end

function Game:UpgradeUnlocked(u)
	local save = self.save
	if u.kind == "building" then
		return self:Count(u.building) >= u.requires
	elseif u.requiresGolden then
		return save.golden >= u.requiresGolden
	elseif u.kind == "grandmatype" then
		return self:Count("grandma") >= 15 and self:Count(u.building) >= 15
	elseif u.kind == "research" then
		if u.order == 0 then
			return self:GrandmaTypes() >= 7
		end
		local previous = NS.RESEARCH[u.order]
		return self:HasUpgrade(previous.id) and save.playTime >= (save.researchReadyAt or 0)
	elseif u.kind == "pledge" then
		return self:RawStage() >= 1 and not self:IsPledged() and not save.covenant
	elseif u.kind == "covenant" then
		return (save.pledges or 0) >= 1 and self:RawStage() >= 1 and not save.covenant
	elseif u.kind == "revoke" then
		return save.covenant == true
	elseif u.kind == "synergy" then
		return self:HasHeavenly("synergies" .. u.vol) and self:Count(u.a) >= 15 and self:Count(u.b) >= 15
	elseif u.kind == "switch" then
		return self:HasHeavenly("goldenswitch")
	end
	return save.baked >= (u.unlockBaked or 0)
end

function Game:UpgradeAvailable(u)
	if not u.repeatable and self:HasUpgrade(u.id) then
		return false
	end
	return self:UpgradeUnlocked(u)
end

function Game:AvailableUpgrades()
	local list = {}
	for _, u in ipairs(NS.UPGRADES) do
		if self:UpgradeAvailable(u) then
			table.insert(list, u)
		end
	end
	table.sort(list, function(a, b)
		local ca, cb = self:UpgradeCost(a), self:UpgradeCost(b)
		if ca ~= cb then
			return ca < cb
		end
		return a.id < b.id
	end)
	return list
end

function Game:BuyUpgrade(u)
	if not self:UpgradeAvailable(u) then
		return false
	end
	local cost = self:UpgradeCost(u)
	if self.save.cookies < cost then
		return false
	end
	self.save.cookies = self.save.cookies - cost
	local save = self.save
	if u.kind == "pledge" then
		save.pledges = (save.pledges or 0) + 1
		save.pledgeUntil = save.playTime + self.PLEDGE_TIME * (self:HasUpgrade("research10") and 2 or 1)
		self:PopAllWrinklers()
		NS.UI:Banner("The grandmas are calm, for now.")
	elseif u.kind == "covenant" then
		save.covenant = true
		save.covenantEver = true
		self:PopAllWrinklers()
		NS.UI:Banner("The elders are at peace.")
	elseif u.kind == "revoke" then
		save.covenant = false
		NS.UI:Banner("The elders stir again.")
	elseif u.kind == "switch" then
		save.goldenSwitch = not save.goldenSwitch
		if save.goldenSwitch then
			NS.UI:HideGolden()
			self.goldenShown = nil
		end
	else
		save.upgrades[u.id] = true
		if u.kind == "research" then
			save.researchReadyAt = save.playTime + self.RESEARCH_TIME
			if u.stage then
				NS.UI:Banner("The grandmas are restless...")
			end
		end
	end
	self:Changed()
	NS.PlayKit("IG_BACKPACK_COIN_OK")
	return true
end

function Game:Changed()
	self.version = self.version + 1
	NS.UI:Refresh(true)
	NS.Comm:OnChanged()
end

-------------------------------------------------------------------------------
-- Ascension
-------------------------------------------------------------------------------

function Game:PrestigeFor(total)
	if total <= 0 then
		return 0
	end
	return math.floor((total / NS.PRESTIGE_BASE) ^ (1 / 3))
end

function Game:AscendPreview()
	local level = self:PrestigeFor(self:AllTime())
	return math.max(0, level - (self.save.prestige or 0)), level
end

function Game:CookiesToNextChip()
	local nextLevel = self:PrestigeFor(self:AllTime()) + 1
	return math.max(0, (nextLevel ^ 3) * NS.PRESTIGE_BASE - self:AllTime())
end

function Game:Ascend()
	local gain, level = self:AscendPreview()
	if gain <= 0 then
		return false
	end
	local save = self.save
	save.allTime = (save.allTime or 0) + save.baked
	save.prestige = level
	save.chips = (save.chips or 0) + gain
	save.ascensions = (save.ascensions or 0) + 1
	save.cookies, save.baked = 0, 0
	save.buildings, save.upgrades = {}, {}
	save.wrinklers = {}
	save.pledges, save.pledgeUntil, save.covenant, save.goldenSwitch = 0, 0, false, false
	save.researchReadyAt = 0
	if self:HasHeavenly("starterkit") then
		save.buildings.cursor = 10
	end
	if self:HasHeavenly("starterkitchen") then
		save.buildings.grandma = 5
	end
	self.buffs = {}
	self.chain, self.storm = nil, nil
	self.goldenShown = nil
	self.nextGolden = self:RollGolden()
	NS.UI:HideGolden()
	NS.UI:RefreshWrinklers()
	NS.Print("Ascended! +%d heavenly chip%s, prestige level %d (production +%d%%).", gain, gain == 1 and "" or "s", level, level)
	NS.UI:Banner(string.format("Ascended! +%d chips", gain))
	NS.PlayKit("UI_LEGENDARY_LOOT_TOAST")
	self:Changed()
	return true
end

function Game:BuyHeavenly(h)
	if self:HasHeavenly(h.id) or (self.save.chips or 0) < h.cost then
		return false
	end
	self.save.chips = self.save.chips - h.cost
	self.save.heavenly[h.id] = true
	NS.PlayKit("UI_EPICLOOT_TOAST")
	self:Changed()
	return true
end

-------------------------------------------------------------------------------
-- Golden and wrath cookies, buffs
-------------------------------------------------------------------------------

function Game:RollGolden()
	local luck = self:CountKind("luck") + (self:HasHeavenly("heavenlyluck") and 1 or 0)
	return (self.GOLDEN_MIN + math.random() * (self.GOLDEN_MAX - self.GOLDEN_MIN)) / (2 ^ luck)
end

function Game:BuffDuration(duration)
	if self:HasUpgrade("luck3") then duration = duration * 2 end
	if self:HasHeavenly("lastingfortune") then duration = duration * 1.1 end
	if self:HasHeavenly("decisivefate") then duration = duration * 1.05 end
	if self:HasHeavenly("luckydigit") then duration = duration * 1.01 end
	return duration
end

function Game:AddBuff(key, duration, extra)
	duration = self:BuffDuration(duration)
	local buff = extra or {}
	buff.ends = GetTime() + duration
	buff.duration = duration
	self.buffs[key] = buff
end

function Game:BuffLeft(key)
	local buff = self.buffs[key]
	if not buff then
		return 0
	end
	return math.max(0, buff.ends - GetTime())
end

-- Called by the tick when it is time: golden, or wrath by the stage.
function Game:SpawnGolden(forcedWrath)
	if forcedWrath == nil then
		self.goldenWrath = math.random() < self:Stage() / 3
	else
		self.goldenWrath = forcedWrath
	end
	self.goldenShown = self.GOLDEN_SHOW
	NS.UI:ShowGolden(self.goldenWrath)
end

function Game:ChainValue(step, wrath)
	local digit = wrath and 6 or 7
	return digit * (10 ^ step - 1) / 9
end

function Game:ClickGolden()
	if not self.goldenShown then
		return
	end
	self.goldenShown = nil
	self.save.golden = self.save.golden + 1
	local wrath = self.goldenWrath
	local effect
	if self.chain then
		effect = "chain"
	else
		local choices = {}
		if wrath then
			table.insert(choices, "clot")
			table.insert(choices, "ruin")
			if math.random() < 0.1 then
				table.insert(choices, "cursed")
				table.insert(choices, "elderFrenzy")
			end
			if math.random() < 0.3 then
				table.insert(choices, "frenzy")
				table.insert(choices, "lucky")
			end
		else
			table.insert(choices, "frenzy")
			table.insert(choices, "lucky")
			table.insert(choices, "clickFrenzy")
			if math.random() < 0.1 then
				table.insert(choices, "chain")
				table.insert(choices, "storm")
			end
			if self:TotalBuildings() >= 10 and math.random() < 0.25 then
				table.insert(choices, "special")
			end
		end
		effect = choices[math.random(#choices)]
	end
	self:ApplyGoldenEffect(effect, wrath)
	NS.UI:HideGolden()
	if self.chain then
		self.nextGolden = 0.6   -- the next link comes right away
	else
		self.nextGolden = self:RollGolden()
	end
	NS.UI:Refresh(true)
end

function Game:ApplyGoldenEffect(effect, wrath)
	local text, sound = "", "UI_EPICLOOT_TOAST"
	if effect == "frenzy" then
		self:AddBuff("frenzy", self.FRENZY_TIME)
		text = string.format("Frenzy! Production x%d for %d s", self.FRENZY_MULT, math.floor(self:BuffDuration(self.FRENZY_TIME)))
	elseif effect == "lucky" then
		local gain = math.min(self.save.cookies * 0.15, self:Cps(true) * self.LUCKY_CAP_SECONDS) + 13
		self:Gain(gain)
		text = "Lucky! +" .. NS.Beautify(gain) .. " cookies"
	elseif effect == "clickFrenzy" then
		self:AddBuff("clickFrenzy", self.CLICK_FRENZY_TIME)
		text = string.format("Click frenzy! Clicks x%d for %d s", self.CLICK_FRENZY_MULT, math.floor(self:BuffDuration(self.CLICK_FRENZY_TIME)))
	elseif effect == "special" then
		local candidates = {}
		for _, b in ipairs(NS.BUILDINGS) do
			if self:Count(b.id) >= 10 then
				table.insert(candidates, b)
			end
		end
		local b = candidates[math.random(#candidates)]
		local mult = 1 + self:Count(b.id) / 10
		self:AddBuff("special", self.SPECIAL_TIME, { building = b.id, mult = mult })
		text = string.format("Building special! %ss x%d for %d s", b.name, math.floor(mult), math.floor(self:BuffDuration(self.SPECIAL_TIME)))
	elseif effect == "chain" then
		if not self.chain then
			self.chain = { step = 0, wrath = wrath }
		end
		self.chain.step = self.chain.step + 1
		local value = self:ChainValue(self.chain.step, wrath)
		local cap = math.min(self:Cps(true) * 3600 * 6, self.save.cookies * 0.5)
		local last = false
		if value > cap then
			value = math.max(cap, 7)
			last = true
		elseif self.chain.step > 1 and math.random() < 0.01 then
			last = true
		end
		self:Gain(value)
		text = string.format("Cookie chain! +%s", NS.Beautify(value))
		if last then
			self.chain = nil
			self.save.chains = (self.save.chains or 0) + 1
			text = text .. " (chain over)"
		end
	elseif effect == "storm" then
		self.storm = { ends = GetTime() + self.STORM_TIME, nextDrop = 0 }
		text = "Cookie storm!"
	elseif effect == "clot" then
		self:AddBuff("clot", self.CLOT_TIME)
		text = string.format("Clot. Production halved for %d s", math.floor(self:BuffDuration(self.CLOT_TIME)))
		sound = "IG_MAINMENU_OPTION_CHECKBOX_OFF"
	elseif effect == "ruin" then
		local loss = math.min(self.save.cookies * 0.05, self:Cps(true) * 600) + 13
		loss = math.min(loss, self.save.cookies)
		self.save.cookies = self.save.cookies - loss
		text = "Ruin! -" .. NS.Beautify(loss) .. " cookies"
		sound = "IG_MAINMENU_OPTION_CHECKBOX_OFF"
	elseif effect == "elderFrenzy" then
		self:AddBuff("elderFrenzy", self.ELDER_FRENZY_TIME)
		text = string.format("Elder frenzy! Production x%d for %d s", self.ELDER_FRENZY_MULT, math.floor(self:BuffDuration(self.ELDER_FRENZY_TIME)))
		sound = "UI_LEGENDARY_LOOT_TOAST"
	elseif effect == "cursed" then
		self:AddBuff("cursed", self.CURSED_TIME, { cps = self:Cps(false) })
		text = string.format("Cursed finger! No production for %d s, but each click gives 10 s of it", math.floor(self:BuffDuration(self.CURSED_TIME)))
		sound = "IG_MAINMENU_OPTION_CHECKBOX_OFF"
	end
	NS.UI:Banner(text)
	NS.PlayKit(sound)
end

-- A cookie storm drop was clicked.
function Game:ClickDrop(value)
	self:Gain(value)
	self.save.golden = self.save.golden + 1
	NS.UI:Banner("+" .. NS.Beautify(value))
end

-------------------------------------------------------------------------------
-- Wrinklers
-------------------------------------------------------------------------------

function Game:Wrinklers()
	self.save.wrinklers = self.save.wrinklers or {}
	return self.save.wrinklers
end

function Game:SpawnWrinkler()
	local list = self:Wrinklers()
	local used = {}
	for _, w in ipairs(list) do
		used[w.slot] = true
	end
	local free = {}
	for slot = 1, self:MaxWrinklers() do
		if not used[slot] then
			table.insert(free, slot)
		end
	end
	if #free == 0 then
		return
	end
	table.insert(list, { slot = free[math.random(#free)], sucked = 0, hp = self.WRINKLER_HP, shiny = math.random() < 0.0001 })
	NS.UI:RefreshWrinklers()
end

function Game:PopWrinkler(index)
	local list = self:Wrinklers()
	local w = table.remove(list, index)
	if not w then
		return
	end
	local back = w.sucked * self.WRINKLER_RETURN * (self:HasHeavenly("sacrilegious") and 1.05 or 1) * (w.shiny and 3 or 1)
	self:Gain(back)
	self.save.wrinklersPopped = (self.save.wrinklersPopped or 0) + 1
	NS.UI:Banner("Wrinkler burst! +" .. NS.Beautify(back))
	NS.PlayKit("IG_BACKPACK_COIN_OK")
	NS.UI:RefreshWrinklers()
	NS.UI:Refresh(true)
end

function Game:ClickWrinkler(index)
	local w = self:Wrinklers()[index]
	if not w then
		return
	end
	w.hp = w.hp - 1
	if w.hp <= 0 then
		self:PopWrinkler(index)
	else
		NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
	end
end

function Game:PopAllWrinklers()
	local list = self:Wrinklers()
	while #list > 0 do
		self:PopWrinkler(#list)
	end
end

-------------------------------------------------------------------------------
-- Tick
-------------------------------------------------------------------------------

function Game:Tick(dt)
	if not self.save then
		return
	end
	dt = math.min(dt, self.MAX_TICK)
	local save = self.save
	local now = GetTime()

	for key, buff in pairs(self.buffs) do
		if now >= buff.ends then
			self.buffs[key] = nil
			NS.UI:Refresh(true)
		end
	end

	local cps = self:Cps(true)
	if cps > 0 then
		local wrinklers = self:Wrinklers()
		local n = #wrinklers
		if n > 0 then
			local eaten = cps * dt * self.WRINKLER_EAT
			for _, w in ipairs(wrinklers) do
				w.sucked = w.sucked + eaten
			end
			self:Gain(cps * dt * math.max(0, 1 - self.WRINKLER_EAT * n))
		else
			self:Gain(cps * dt)
		end
	end
	save.playTime = save.playTime + dt

	if NS.UI:IsShown() then
		if self.goldenShown then
			self.goldenShown = self.goldenShown - dt
			if self.goldenShown <= 0 then
				self.goldenShown = nil
				NS.UI:HideGolden()
				if self.chain then
					self.chain = nil   -- a missed link ends the chain
				end
				self.nextGolden = self:RollGolden()
			end
		elseif not save.goldenSwitch then
			self.nextGolden = self.nextGolden - dt
			if self.nextGolden <= 0 then
				self:SpawnGolden(self.chain and self.chain.wrath or nil)
			end
		end
		if self.storm then
			if now >= self.storm.ends then
				self.storm = nil
			elseif now >= self.storm.nextDrop then
				self.storm.nextDrop = now + 0.3 + math.random() * 0.3
				local value = cps * 60 * math.random(1, 7) / 7 + 7
				NS.UI:SpawnDrop(value, self.STORM_DROP_LIFE)
			end
		end
	end

	self.secondAcc = (self.secondAcc or 0) + dt
	if self.secondAcc >= 1 then
		self.secondAcc = 0
		self:CheckAchievements()
		local stage = self:Stage()
		if stage > 0 and #self:Wrinklers() < self:MaxWrinklers() and math.random() < 0.002 * stage then
			self:SpawnWrinkler()
		end
		if self.wasPledged and not self:IsPledged() then
			NS.UI:Banner("The pledge has worn off.")
			self:Changed()
		end
		self.wasPledged = self:IsPledged()
	end

	self.flightAcc = (self.flightAcc or 0) + dt
	if self.flightAcc >= 0.5 then
		self.flightAcc = 0
		self:CheckFlight()
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

function Game:CheckAchievements()
	local save = self.save
	for _, a in ipairs(NS.ACHIEVEMENTS) do
		if not save.achievements[a.id] and a.check(save, self) then
			save.achievements[a.id] = true
			NS.Print("Achievement unlocked: |cffffd100%s|r (%s) Production +1%%, milk +4%%.", a.name, a.desc)
			NS.UI:Banner("Achievement: " .. a.name)
			NS.PlayKit("UI_WORLDQUEST_COMPLETE")
			self:Changed()
		end
	end
end

-- A line for the news ticker.
function Game:TickerLine()
	local stage = self:Stage()
	if stage > 0 and math.random() < 0.5 then
		local lines = NS.TICKER_GRANDMA[stage]
		return lines[math.random(#lines)]
	end
	return NS.TICKER[math.random(#NS.TICKER)]
end

function Game:Wipe()
	MauCookieDB.save = NS.NewSave()
	self.save = MauCookieDB.save
	self.buffs = {}
	self.chain, self.storm = nil, nil
	self.goldenShown = nil
	self.nextGolden = self:RollGolden()
	NS.UI:HideGolden()
	NS.UI:RefreshWrinklers()
	NS.Print("The bakery starts over.")
	self:Changed()
end
