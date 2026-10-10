-- MauCookie ascension, ported from the original: prestige is the cube root
-- of all cookies ever forfeited divided by a trillion, heavenly chips are
-- the prestige levels gained, the heavenly tree needs every parent bought,
-- permanent upgrade slots carry one bought upgrade across runs.  Ascend()
-- banks the chips and shows the tree (production stops), Reincarnate()
-- resets the run.  Reset(true) is the "wipe save".

local _, NS = ...

local Game = NS.Game

local FORFEIT = {
	{ 1e6, "Sacrifice" }, { 1e9, "Oblivion" }, { 1e12, "From scratch" }, { 1e15, "Nihilism" }, { 1e18, "Dematerialize" },
	{ 1e21, "Nil zero zilch" }, { 1e24, "Transcendence" }, { 1e27, "Obliterate" }, { 1e30, "Negative void" },
	{ 1e33, "To crumbs, you say?" }, { 1e36, "You get nothing" }, { 1e39, "Humble rebeginnings" }, { 1e42, "The end of the world" },
	{ 1e45, "Oh, you're back" }, { 1e48, "Lazarus" }, { 1e51, "Smurf account" }, { 1e54, "If at first you don't succeed" },
	{ 1e57, "No more room in hell" },
}

local NO_PERM = { ["Bingo center/Research facility"] = true }

function Game:HowMuchPrestige(cookies)
	return (math.max(0, cookies) / 1e12) ^ (1 / self.HCfactor)
end

function Game:HowManyCookiesReset(chips)
	return (chips ^ self.HCfactor) * 1e12
end

-- toGet, levelAfter, cookiesToNext, percent towards the next chip
function Game:AscendInfo()
	local S = self.save
	local chipsOwned = self:HowMuchPrestige(S.reset or 0)
	local ascendNowToOwn = math.floor(self:HowMuchPrestige((S.reset or 0) + (S.earned or 0)))
	local toGet = ascendNowToOwn - math.floor(chipsOwned)
	local nextChipAt = self:HowManyCookiesReset(math.floor(chipsOwned + toGet + 1)) - self:HowManyCookiesReset(math.floor(chipsOwned + toGet))
	local cookiesToNext = self:HowManyCookiesReset(ascendNowToOwn + 1) - ((S.earned or 0) + (S.reset or 0))
	local percent = 1 - cookiesToNext / nextChipAt
	return toGet, ascendNowToOwn, cookiesToNext, percent
end

function Game:EarnHeavenlyChips(forfeited, silent)
	local S = self.save
	local prestige = math.max(0, math.floor(self:HowMuchPrestige((S.reset or 0) + forfeited)))
	if prestige ~= (S.prestige or 0) then
		local diff = prestige - (S.prestige or 0)
		self.gainedPrestige = diff
		S.chips = (S.chips or 0) + diff
		S.prestige = prestige
		if not silent and diff > 0 then
			NS.Notify("You forfeit your " .. NS.Beautify(forfeited) .. " cookies.", "You gain " .. NS.Beautify(diff) .. " prestige level" .. (diff == 1 and "" or "s") .. "!", {19,7})
		end
	end
end

function Game:Ascend()
	local S = self.save
	if S.onAscend then
		return false
	end
	self:KillShimmers()
	self:EarnHeavenlyChips(S.earned or 0)
	S.onAscend = true
	S.nextAscensionMode = 0
	NS.PlayKit("UI_LEGENDARY_LOOT_TOAST")
	NS.Notify("Ascending", "So long, cookies.", {20,7}, true)
	if NS.UI and NS.UI.OnAscendChanged then
		NS.UI:OnAscendChanged()
	end
	self:Changed()
	return true
end

function Game:Reincarnate()
	local S = self.save
	if not S.onAscend then
		return false
	end
	S.ascensionMode = S.nextAscensionMode or 0
	S.nextAscensionMode = 0
	S.onAscend = false
	self:Reset(false)
	if self:HasAchiev("Rebirth") then
		NS.Notify("Reincarnated", "Hello, cookies!", {10,0}, true)
	end
	local resets = S.resets or 0
	if resets >= 1000 then self:Win("Endless cycle") end
	if resets >= 100 then self:Win("Reincarnation") end
	if resets >= 10 then self:Win("Resurrection") end
	if resets >= 1 then self:Win("Rebirth") end
	if self:PrestigeUpgradesOwned() >= 100 then
		self:Win("All the stars in heaven")
	end
	NS.PlayKit("UI_EPICLOOT_TOAST")
	if NS.UI and NS.UI.OnAscendChanged then
		NS.UI:OnAscendChanged()
	end
	self:Changed()
	return true
end

function Game:Reset(hard)
	local S = self.save
	local now = time()
	local forfeited = S.earned or 0
	if not hard then
		for _, step in ipairs(FORFEIT) do
			if forfeited >= step[1] then
				self:Win(step[2])
			end
		end
		if math.floor((S.cookies or 0) + 0.5) == 1e12 then
			self:Win("When the cookies ascend just right")
		end
		if self:HasBuff("Loan 1") or self:HasBuff("Loan 2") or self:HasBuff("Loan 3") then
			self:Win("Debt evasion")
		end
	end
	self:KillBuffs()
	S.reset = (S.reset or 0) + forfeited
	S.cookies, S.earned, S.clicks, S.goldenClicksLocal, S.handmade, S.cpsHighest = 0, 0, 0, 0, 0, 0
	if hard then
		S.bgType, S.milkType, S.chimeType = 0, 0, 0
		S.vault = {}
		S.ach = {}
		S.goldenClicks, S.missedGolden, S.resets = 0, 0, 0
		S.fullDate = now
		S.reset = 0
		S.prestige, S.chips, S.chipsSpent = 0, 0, 0
		self.gainedPrestige = 0
		S.perma = {}
		S.ascensionMode = 0
		S.lumps, S.lumpsTotal, S.lumpT, S.lumpRefill, S.lumpType = -1, -1, now, 0, 0
		S.minigames = {}
		S.sold = 0
		S.playTime = 0
	end
	S.pledges, S.pledgeT, S.elderWrath = 0, 0, 0
	self.elderWrathOld = 0
	S.nextResearch, S.researchT = false, 0
	S.seasonT, S.seasonUses, S.season = 0, 0, ""
	S.startDate = now
	S.runTime = 0
	S.cookiesSucked, S.wrinklersPopped = 0, 0
	self:ResetWrinklers()
	S.santaLevel, S.reindeerClicked = 0, 0
	S.dragonLevel, S.dragonAura, S.dragonAura2 = 0, 0, 0
	S.fortuneGC, S.fortuneCPS, S.tickerClicks = false, false, 0
	if not hard and (self.gainedPrestige or 0) > 0 then
		S.resets = (S.resets or 0) + 1
	end
	self.gainedPrestige = 0

	for _, b in ipairs(NS.BUILDINGS) do
		local r = self:Bld(b.name)
		r.n, r.bought, r.highest, r.free, r.total = 0, 0, 0, 0, 0
		if hard then
			r.level = 0
		end
	end
	for _, u in ipairs(NS.UPGRADES) do
		if hard or u.pool ~= "prestige" then
			S.up[u.name] = nil
		end
		if hard then
			S.unl[u.name] = nil
		end
		if u.pool ~= "prestige" and not u.lasting then
			local keep = false
			if self:Has("Keepsakes") and NS.SEASON_DROP_SET[u.name] and math.random() < 1 / 5 then
				keep = true
			elseif S.ascensionMode == 1 and self:HasAchiev("O Fortuna") and u.tier == "fortune" then
				keep = true
			elseif self:HasAchiev("O Fortuna") and u.tier == "fortune" and math.random() < 0.4 then
				keep = true
			end
			if not keep then
				S.unl[u.name] = nil
			end
		end
	end
	if not hard and S.ascensionMode ~= 1 then
		for slot = 1, 5 do
			local name = S.perma[slot]
			if name and NS.U[name] then
				self:EarnUpgrade(name)
			end
		end
		if self:Has("Season switcher") then
			for _, s in pairs(NS.SEASONS) do
				self:Unlock(s.trigger)
			end
		end
		if self:Has("Starter kit") then
			self:GetFree(NS.B["Cursor"], 10)
		end
		if self:Has("Starter kitchen") then
			self:GetFree(NS.B["Grandma"], 5)
		end
	end
	self.cpsBy = {}
	self.recalc = true
	self.countsDirty = true
	self:KillShimmers()
	self.ticker, self.tickerEffect, self.tickerAge = "", nil, 0
	if self.minigames then
		for _, mg in pairs(self.minigames) do
			if mg.reset then
				mg:reset(hard)
			end
		end
	end
	if hard and NS.Minigames then
		-- The wipe replaced save.minigames; forget the old state tables.
		NS.Minigames:Start()
	end
	self:CalculateGains()
	self:CheckMilkUnlocks()
	self:StoreDirty()
	if NS.UI and NS.UI.OnReset then
		NS.UI:OnReset()
	end
end

-- "Wipe save": everything goes, including achievements and heaven.
function Game:Wipe()
	local S = self.save
	S.onAscend = false
	self:Reset(true)
	NS.Print("The bakery starts over from nothing.")
	if NS.UI and NS.UI.OnAscendChanged then
		NS.UI:OnAscendChanged()
	end
	self:Changed()
end

-------------------------------------------------------------------------------
-- The heavenly tree
-------------------------------------------------------------------------------

function Game:CanBuyPrestige(u)
	if self.save.up[u.name] then
		return false
	end
	for _, p in ipairs(u.parentList or {}) do
		if not self.save.up[p.name] then
			return false
		end
	end
	return true
end

-- Visible in the tree: bought, buyable, or a child of something buyable.
function Game:PrestigeVisible(u)
	if self.save.up[u.name] or self:CanBuyPrestige(u) then
		return true, false
	end
	for _, p in ipairs(u.parentList or {}) do
		if self:CanBuyPrestige(p) then
			return true, true
		end
	end
	return false, false
end

function Game:BuyPrestige(u)
	local S = self.save
	if not self:CanBuyPrestige(u) then
		return false
	end
	local price = self:UpgradePrice(u)
	if (S.chips or 0) < price then
		return false
	end
	S.chips = S.chips - price
	S.chipsSpent = (S.chipsSpent or 0) + price
	S.unl[u.name] = true
	S.up[u.name] = true
	self:OnUpgradeBought(u)
	self.recalc = true
	self.countsDirty = true
	self:StoreDirty()
	NS.PlayKit("UI_EPICLOOT_TOAST")
	if NS.UI and NS.UI.OnPrestigeBought then
		NS.UI:OnPrestigeBought(u)
	end
	self:Changed()
	return true
end

-------------------------------------------------------------------------------
-- Permanent upgrade slots
-------------------------------------------------------------------------------

NS.PERMANENT_SLOTS = { "Permanent upgrade slot I", "Permanent upgrade slot II", "Permanent upgrade slot III", "Permanent upgrade slot IV", "Permanent upgrade slot V" }
NS.PERMANENT_SLOT_INDEX = {}
for i, name in ipairs(NS.PERMANENT_SLOTS) do
	NS.PERMANENT_SLOT_INDEX[name] = i
end

-- Upgrades that may go in a slot: bought, unlocked, pool "" or "cookie",
-- not already slotted elsewhere.  Sorted by the store order.
function Game:PermanentSlotCandidates(slot)
	local S = self.save
	local list = {}
	for _, u in ipairs(NS.UPGRADES) do
		if S.up[u.name] and S.unl[u.name] and not NO_PERM[u.name] and (u.pool == "" or u.pool == "cookie") then
			local taken = false
			for i = 1, 5 do
				if i ~= slot and S.perma[i] == u.name then
					taken = true
				end
			end
			if not taken then
				table.insert(list, u)
			end
		end
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.index < b.index
	end)
	return list
end

function Game:SetPermanentSlot(slot, name)
	self.save.perma[slot] = name or false
	self:Changed()
end

function Game:PermanentSlotIcon(slot)
	local name = self.save.perma[slot]
	if name and NS.U[name] then
		return NS.U[name].icon
	end
	return { slot - 1, 10 }
end
