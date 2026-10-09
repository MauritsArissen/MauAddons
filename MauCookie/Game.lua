-- MauCookie rules: production, clicking, buying, golden cookies, buffs,
-- achievements, offline cookies.
--
-- The bakery ticks from a frame that is always shown, so cookies keep
-- coming while the window is closed; the window only draws.  Golden
-- cookies wait while the window is closed so none are missed.

local _, NS = ...

local Game = {}
NS.Game = Game

Game.GOLDEN_MIN, Game.GOLDEN_MAX = 120, 360   -- seconds between golden cookies
Game.GOLDEN_SHOW = 13
Game.FRENZY_TIME, Game.FRENZY_MULT = 77, 7
Game.CLICK_FRENZY_TIME, Game.CLICK_FRENZY_MULT = 13, 777
Game.LUCKY_CAP_SECONDS = 900                  -- lucky pays at most 15 minutes of production
Game.MAX_TICK = 5

function Game:Start()
	self.save = MauCookieDB.save
	self.buffs = {}
	self.version = 0           -- bumped when buildings, upgrades or achievements change
	self.nextGolden = self:RollGolden()
	self:Offline()
	self.ticker = CreateFrame("Frame")
	self.ticker:SetScript("OnUpdate", function(_, elapsed)
		NS.Guard("tick", Game.Tick, Game, elapsed)
	end)
end

function Game:Save()
	if self.save then
		self.save.lastSeen = NS.Now()
	end
end

-------------------------------------------------------------------------------
-- Numbers
-------------------------------------------------------------------------------

function Game:Count(buildingId)
	return self.save.buildings[buildingId] or 0
end

function Game:HasUpgrade(id)
	return self.save.upgrades[id] == true
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

function Game:GlobalMult()
	return (1 + 0.02 * self:CountKind("flavour")) * (1 + 0.01 * self:AchievementsUnlocked())
end

-- Production of one building of this kind per second (without buffs).
function Game:BuildingCps(b)
	return b.cps * (2 ^ self:Tiers(b.id)) * self:GlobalMult()
end

function Game:FrenzyMult()
	return self.buffs.frenzy and self.FRENZY_MULT or 1
end

function Game:Cps(withBuffs)
	local total = 0
	for _, b in ipairs(NS.BUILDINGS) do
		total = total + self:Count(b.id) * self:BuildingCps(b)
	end
	if withBuffs ~= false then
		total = total * self:FrenzyMult()
	end
	return total
end

function Game:ClickPower()
	local base = 2 ^ self:Tiers("cursor")
	local fromCps = self:Cps(true) * 0.01 * self:CountKind("mouse")
	local power = (base + fromCps) * self:GlobalMult()
	if self.buffs.clickFrenzy then
		power = power * self.CLICK_FRENZY_MULT
	end
	return power
end

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

-- Buildings show up to two past the highest one owned.
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

-------------------------------------------------------------------------------
-- Actions
-------------------------------------------------------------------------------

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

-- Buys up to `amount` buildings, as many as affordable.  Returns the number bought.
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
		self.version = self.version + 1
		NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
		NS.UI:Refresh(true)
	end
	return bought
end

function Game:UpgradeUnlocked(u)
	if u.kind == "building" then
		return self:Count(u.building) >= u.requires
	elseif u.kind == "luck" then
		return self.save.golden >= u.requiresGolden
	end
	return self.save.baked >= (u.unlockBaked or 0)
end

function Game:UpgradeAvailable(u)
	return not self:HasUpgrade(u.id) and self:UpgradeUnlocked(u)
end

-- Available upgrades, cheapest first.
function Game:AvailableUpgrades()
	local list = {}
	for _, u in ipairs(NS.UPGRADES) do
		if self:UpgradeAvailable(u) then
			table.insert(list, u)
		end
	end
	table.sort(list, function(a, b)
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.id < b.id
	end)
	return list
end

function Game:BuyUpgrade(u)
	if not self:UpgradeAvailable(u) or self.save.cookies < u.cost then
		return false
	end
	self.save.cookies = self.save.cookies - u.cost
	self.save.upgrades[u.id] = true
	self.version = self.version + 1
	NS.PlayKit("IG_BACKPACK_COIN_OK")
	NS.UI:Refresh(true)
	return true
end

-------------------------------------------------------------------------------
-- Golden cookies and buffs
-------------------------------------------------------------------------------

function Game:RollGolden()
	local divisor = 2 ^ self:CountKind("luck")
	return (self.GOLDEN_MIN + math.random() * (self.GOLDEN_MAX - self.GOLDEN_MIN)) / divisor
end

function Game:AddBuff(key, duration, label)
	self.buffs[key] = { ends = GetTime() + duration, label = label, duration = duration }
end

function Game:BuffLeft(key)
	local buff = self.buffs[key]
	if not buff then
		return 0
	end
	return math.max(0, buff.ends - GetTime())
end

function Game:ClickGolden()
	if not self.goldenShown then
		return
	end
	self.goldenShown = nil
	self.save.golden = self.save.golden + 1
	self.nextGolden = self:RollGolden()
	local roll = math.random()
	local text
	if roll < 0.08 then
		self:AddBuff("clickFrenzy", self.CLICK_FRENZY_TIME, "Click frenzy")
		text = string.format("Click frenzy! Clicks x%d for %d s", self.CLICK_FRENZY_MULT, self.CLICK_FRENZY_TIME)
	elseif roll < 0.55 then
		self:AddBuff("frenzy", self.FRENZY_TIME, "Frenzy")
		text = string.format("Frenzy! Production x%d for %d s", self.FRENZY_MULT, self.FRENZY_TIME)
	else
		local gain = math.min(self.save.cookies * 0.15, self:Cps(true) * self.LUCKY_CAP_SECONDS) + 13
		self:Gain(gain)
		text = "Lucky! +" .. NS.Beautify(gain) .. " cookies"
	end
	NS.UI:HideGolden()
	NS.UI:Banner(text)
	NS.PlayKit("UI_EPICLOOT_TOAST")
	NS.UI:Refresh(true)
end

-------------------------------------------------------------------------------
-- Tick
-------------------------------------------------------------------------------

function Game:Tick(dt)
	if not self.save then
		return
	end
	dt = math.min(dt, self.MAX_TICK)
	local cps = self:Cps(true)
	if cps > 0 then
		self:Gain(cps * dt)
	end
	self.save.playTime = self.save.playTime + dt

	local now = GetTime()
	for key, buff in pairs(self.buffs) do
		if now >= buff.ends then
			self.buffs[key] = nil
			NS.UI:Refresh(true)
		end
	end

	if NS.UI:IsShown() then
		if self.goldenShown then
			self.goldenShown = self.goldenShown - dt
			if self.goldenShown <= 0 then
				self.goldenShown = nil
				self.nextGolden = self:RollGolden()
				NS.UI:HideGolden()
			end
		else
			self.nextGolden = self.nextGolden - dt
			if self.nextGolden <= 0 then
				self.goldenShown = self.GOLDEN_SHOW
				NS.UI:ShowGolden()
			end
		end
	end

	self.achAcc = (self.achAcc or 0) + dt
	if self.achAcc >= 1 then
		self.achAcc = 0
		self:CheckAchievements()
	end
	self.saveAcc = (self.saveAcc or 0) + dt
	if self.saveAcc >= 5 then
		self.saveAcc = 0
		self:Save()
	end
end

function Game:CheckAchievements()
	local save = self.save
	for _, a in ipairs(NS.ACHIEVEMENTS) do
		if not save.achievements[a.id] and a.check(save, self) then
			save.achievements[a.id] = true
			self.version = self.version + 1
			NS.Print("Achievement unlocked: |cffffd100%s|r (%s) Production +1%%.", a.name, a.desc)
			NS.UI:Banner("Achievement: " .. a.name)
			NS.PlayKit("UI_WORLDQUEST_COMPLETE")
			NS.UI:Refresh(true)
		end
	end
end

-- Cookies for the time logged out, at half rate, up to eight hours.
function Game:Offline()
	local save = self.save
	local away = NS.Now() - (save.lastSeen or NS.Now())
	save.lastSeen = NS.Now()
	if not NS.GetSettings().offline or away < 60 then
		return
	end
	local cps = self:Cps(false)
	if cps <= 0 then
		return
	end
	local credited = math.min(away, NS.OFFLINE_CAP)
	local gain = cps * credited * NS.OFFLINE_RATE
	self:Gain(gain)
	NS.Print("While you were away (%s) your bakery made %s cookies (half rate, up to %d hours).", NS.FormatDuration(away), NS.Beautify(gain), NS.OFFLINE_CAP / 3600)
end

function Game:Wipe()
	MauCookieDB.save = NS.NewSave()
	self.save = MauCookieDB.save
	self.buffs = {}
	self.goldenShown = nil
	self.nextGolden = self:RollGolden()
	self.version = self.version + 1
	NS.UI:HideGolden()
	NS.UI:Refresh(true)
	NS.Print("The bakery starts over.")
end
