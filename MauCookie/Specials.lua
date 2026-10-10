-- MauCookie specials: Santa (Christmas), Krumblor the cookie dragon and
-- the fortune cookie ticker, ported from the original.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

-------------------------------------------------------------------------------
-- Santa
-------------------------------------------------------------------------------

function Game:SpecialTabs()
	local tabs = {}
	if self:Has("A festive hat") then
		table.insert(tabs, "santa")
	end
	if self:Has("A crumbly egg") then
		table.insert(tabs, "dragon")
	end
	return tabs
end

function Game:SantaCost()
	local level = self.save.santaLevel or 0
	return (level + 1) ^ (level + 1)
end

function Game:SantaName()
	return NS.SANTA_LEVELS[(self.save.santaLevel or 0) + 1] or NS.SANTA_LEVELS[#NS.SANTA_LEVELS]
end

function Game:UpgradeSanta()
	local S = self.save
	local moni = self:SantaCost()
	if S.cookies > moni and (S.santaLevel or 0) < 14 then
		self:Spend(moni)
		S.santaLevel = ((S.santaLevel or 0) + 1) % 15
		if S.santaLevel == 14 then
			self:Unlock("Santa's dominion")
			NS.Notify("You are granted Santa's dominion.", "", NS.U["Santa's dominion"].icon)
		end
		local drops = {}
		for _, name in ipairs(NS.SANTA_DROPS) do
			if not self:HasUnlocked(name) then
				table.insert(drops, name)
			end
		end
		if #drops > 0 then
			local drop = Choose(drops)
			self:Unlock(drop)
			NS.Notify("Found a present!", "You find a present which contains... " .. drop .. "!", NS.U[drop].icon)
		end
		if S.santaLevel >= 6 then self:Win("Coming to town") end
		if S.santaLevel >= 14 then self:Win("All hail Santa") end
		self.recalc = true
		NS.PlayKit("UI_EPICLOOT_TOAST")
		self:Changed()
		return true
	end
	return false
end

-------------------------------------------------------------------------------
-- Krumblor
-------------------------------------------------------------------------------

-- Dragon levels are 0-based in the original; NS.DRAGON_LEVELS[i] is level i-1.
function Game:DragonLevelInfo(level)
	level = level or (self.save.dragonLevel or 0)
	return NS.DRAGON_LEVELS[level + 1]
end

-- What the next training costs: returns kind ("cookies" / "building" /
-- "all" / "done"), amount, building.
function Game:DragonCost(level)
	level = level or (self.save.dragonLevel or 0)
	local last = #NS.DRAGON_LEVELS - 1
	if level >= last then
		return "done"
	elseif level <= 4 then
		return "cookies", 1000000 * (2 ^ level)
	elseif level < last - 2 then
		return "building", 100, NS.BY_ID[level - 5]
	elseif level == last - 2 then
		return "all", 50
	end
	return "all", 200
end

function Game:DragonCostText(level)
	local kind, amount, b = self:DragonCost(level)
	if kind == "cookies" then
		return NS.Beautify(amount) .. " cookies"
	elseif kind == "building" then
		return amount .. " " .. b.plural
	elseif kind == "all" then
		return amount .. " of every building"
	end
	return ""
end

function Game:DragonCanBuy(level)
	local kind, amount, b = self:DragonCost(level)
	if kind == "cookies" then
		return self.save.cookies >= amount
	elseif kind == "building" then
		return self:Count(b.name) >= amount
	elseif kind == "all" then
		for _, bb in ipairs(NS.BUILDINGS) do
			if self:Count(bb.name) < amount then
				return false
			end
		end
		return true
	end
	return false
end

function Game:UpgradeDragon()
	local S = self.save
	local level = S.dragonLevel or 0
	if level >= #NS.DRAGON_LEVELS - 1 or not self:DragonCanBuy(level) then
		return false
	end
	local kind, amount, b = self:DragonCost(level)
	if kind == "cookies" then
		self:Spend(amount)
	elseif kind == "building" then
		self:Sacrifice(b, amount)
	elseif kind == "all" then
		for _, bb in ipairs(NS.BUILDINGS) do
			self:Sacrifice(bb, amount)
		end
		if amount == 50 then
			self:Unlock("Dragon cookie")
		end
	end
	S.dragonLevel = level + 1
	if S.dragonLevel >= #NS.DRAGON_LEVELS - 1 then
		self:Win("Here be dragon")
	end
	self.recalc = true
	NS.PlayKit("UI_EPICLOOT_TOAST")
	self:Changed()
	return true
end

-- Auras the dragon knows: ids with dragonLevel >= id + 4.
function Game:KnownAuras()
	local list = {}
	for id = 0, 21 do
		local aura = NS.DRAGON_AURAS[id]
		if aura and (self.save.dragonLevel or 0) >= id + 4 then
			table.insert(list, aura)
		end
	end
	return list
end

function Game:CanUseSecondAura()
	return (self.save.dragonLevel or 0) >= #NS.DRAGON_LEVELS - 1
end

-- Switching costs one of your best building unless you own none or keep
-- the same aura.
function Game:SetDragonAura(auraId, slot)
	local S = self.save
	local current = slot == 2 and (S.dragonAura2 or 0) or (S.dragonAura or 0)
	local other = slot == 2 and (S.dragonAura or 0) or (S.dragonAura2 or 0)
	if auraId ~= 0 and auraId == other then
		return false
	end
	local highest = self:HighestBuilding()
	if highest and current ~= auraId then
		self:Sacrifice(highest, 1)
	end
	if slot == 2 then
		S.dragonAura2 = auraId
	else
		S.dragonAura = auraId
	end
	self.recalc = true
	self:Changed()
	return true
end

function Game:PetDragon()
	local S = self.save
	if (S.dragonLevel or 0) < 4 or not self:Has("Pet the dragon") then
		return
	end
	local now = GetTime()
	if now - (self.lastPet or 0) > 2 then
		NS.PlayKit("IG_CREATURE_AGGRO_SELECT")
	end
	self.lastPet = now
	if (S.dragonLevel or 0) >= 8 and math.random() < 1 / 20 then
		local drops = {}
		for _, name in ipairs(NS.DRAGON_DROPS) do
			if not self:Has(name) and not self:HasUnlocked(name) then
				table.insert(drops, name)
			end
		end
		if #drops > 0 then
			local drop = Choose(drops)
			self:Unlock(drop)
			NS.Notify(drop, "Your dragon dropped something!", NS.U[drop].icon)
		end
	end
end

-------------------------------------------------------------------------------
-- Fortune cookies (the news ticker)
-------------------------------------------------------------------------------

-- Returns the fortune effect for a new ticker line, or nil.
function Game:RollFortune()
	local S = self.save
	if not self:Has("Fortune cookies") or (S.runTime or 0) < 10 then
		return nil
	end
	if math.random() >= (self:HasAchiev("O Fortuna") and 0.04 or 0.02) then
		return nil
	end
	local fortunes = {}
	for _, u in ipairs(NS.FORTUNE_UPGRADES) do
		if not self:HasUnlocked(u.name) then
			table.insert(fortunes, u)
		end
	end
	if not S.fortuneGC then table.insert(fortunes, "fortuneGC") end
	if not S.fortuneCPS then table.insert(fortunes, "fortuneCPS") end
	if #fortunes == 0 then
		return nil
	end
	local me = Choose(fortunes)
	local text
	if me == "fortuneGC" then
		text = "Today is your lucky day!"
	elseif me == "fortuneCPS" then
		text = string.format("Your lucky numbers are: %d %d %d %d", math.random(0, 99), math.random(0, 99), math.random(0, 99), math.random(0, 99))
	else
		local q = me.quote or ""
		text = me.name:gsub("^Fortune ", "") .. ": " .. q
	end
	return { type = "fortune", sub = me, text = text }
end

function Game:ClickTickerEffect(effect)
	local S = self.save
	S.tickerClicks = (S.tickerClicks or 0) + 1
	if S.tickerClicks >= 50 then
		self:Win("Tabloid addiction")
	end
	if not effect or effect.type ~= "fortune" then
		return
	end
	NS.PlayKit("UI_EPICLOOT_TOAST")
	local sub = effect.sub
	if sub == "fortuneGC" then
		NS.Notify("Fortune!", "A golden cookie has appeared.", {10,32})
		S.fortuneGC = true
		self:SpawnShimmer("golden", { noWrath = true })
	elseif sub == "fortuneCPS" then
		NS.Notify("Fortune!", "You gain one hour of your CpS (capped at double your bank).", {10,32})
		S.fortuneCPS = true
		self:Earn(math.min((self.cps or 0) * 60 * 60, S.cookies))
	else
		NS.Notify(sub.name, "You've unlocked a new upgrade.", sub.icon)
		self:Unlock(sub.name)
	end
	self:Changed()
end
