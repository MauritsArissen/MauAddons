-- MauCookie wrinklers, ported from the original's Game.UpdateWrinklers.
-- Fourteen slots live in save.wrinklers: { id, phase (0 away, 1 crawling
-- in, 2 feeding), close (0..1), sucked, hp, type (1 = shiny), clicks }.
-- A wrinkler sucks a twentieth of production while feeding and gives it
-- back with interest when popped.  The original uses per-frame chances at
-- 30 fps; the tick converts them for its own dt.

local _, NS = ...

local Game = NS.Game
local FPS = 30
local Choose = NS.Choose

Game.wrinklerHP = 2.1
Game.wrinklerLimit = 14

local function NewWrinkler(id)
	return { id = id, close = 0, sucked = 0, phase = 0, hp = Game.wrinklerHP, type = 0, clicks = 0 }
end

function Game:Wrinklers()
	local S = self.save
	S.wrinklers = S.wrinklers or {}
	if #S.wrinklers < self.wrinklerLimit then
		for i = #S.wrinklers, self.wrinklerLimit - 1 do
			S.wrinklers[i + 1] = NewWrinkler(i)
		end
	end
	return S.wrinklers
end

function Game:GetWrinklersMax()
	local n = 10
	if self:Has("Elder spice") then n = n + 2 end
	n = n + math.floor(self:AuraMult("Dragon Guts") * 2 + 0.5)
	return math.min(self.wrinklerLimit, n)
end

function Game:ResetWrinklers()
	local S = self.save
	S.wrinklers = {}
	for i = 0, self.wrinklerLimit - 1 do
		S.wrinklers[i + 1] = NewWrinkler(i)
	end
	if NS.UI and NS.UI.RefreshWrinklers then
		NS.UI:RefreshWrinklers()
	end
end

function Game:CollectWrinklers()
	for _, w in ipairs(self:Wrinklers()) do
		w.hp = 0
	end
end

function Game:ActiveWrinklers()
	local n = 0
	for _, w in ipairs(self:Wrinklers()) do
		if w.phase > 0 then
			n = n + 1
		end
	end
	return n
end

function Game:SpawnWrinkler(me)
	if not me then
		local max = self:GetWrinklersMax()
		local n = self:ActiveWrinklers()
		for _, w in ipairs(self:Wrinklers()) do
			if w.phase == 0 and (self.save.elderWrath or 0) > 0 and n < max and w.id < max then
				me = w
				break
			end
		end
	end
	if not me then
		return false
	end
	me.phase = 1
	me.hp = self.wrinklerHP
	me.type = 0
	me.clicks = 0
	me.close = 0
	if math.random() < 0.0001 then
		me.type = 1
	end
	if NS.UI and NS.UI.RefreshWrinklers then
		NS.UI:RefreshWrinklers()
	end
	return me
end

function Game:PopRandomWrinkler()
	local list = {}
	for _, w in ipairs(self:Wrinklers()) do
		if w.phase > 0 and w.hp > 0 then
			table.insert(list, w)
		end
	end
	if #list > 0 then
		local me = Choose(list)
		me.hp = -10
		return me
	end
	return false
end

function Game:UpdateWrinklers(dt)
	local S = self.save
	local max = self:GetWrinklersMax()
	local list = self:Wrinklers()
	local n = self:ActiveWrinklers()
	local frames = dt * FPS
	local changed = false
	for _, me in ipairs(list) do
		if me.phase == 0 and (S.elderWrath or 0) > 0 and n < max and me.id < max then
			local chance = 0.00001 * S.elderWrath
			chance = chance * self:Eff("wrinklerSpawn")
			if self:Has("Unholy bait") then chance = chance * 5 end
			local godLvl = self:HasGod("scorn")
			if godLvl == 1 then chance = chance * 2.5 elseif godLvl == 2 then chance = chance * 2 elseif godLvl == 3 then chance = chance * 1.5 end
			if self:Has("Wrinkler doormat") then chance = 0.1 end
			if math.random() < 1 - (1 - chance) ^ frames then
				self:SpawnWrinkler(me)
				n = n + 1
				changed = true
			end
		end
		if me.phase > 0 then
			if me.close < 1 then
				me.close = me.close + dt / 10
			end
			if me.close > 1 then
				me.close = 1
			end
			if me.id >= max then
				me.hp = 0
			end
		else
			me.close = 0
		end
		if me.close >= 1 and me.phase == 1 then
			me.phase = 2
			self.recalc = true
			changed = true
		end
		if me.phase == 2 then
			me.sucked = me.sucked + (self.cps or 0) * dt * (self.cpsSucked or 0)
		end
		if me.phase > 0 then
			local maxHp = me.type == 1 and self.wrinklerHP * 3 or self.wrinklerHP
			if me.hp < maxHp then
				me.hp = math.min(maxHp, me.hp + 0.04 * frames)
			end
			if me.hp <= 0.5 then
				self:PopWrinkler(me)
				changed = true
			end
		end
	end
	if changed and NS.UI and NS.UI.RefreshWrinklers then
		NS.UI:RefreshWrinklers()
	end
end

-- A click on a wrinkler in the window.
function Game:ClickWrinkler(me)
	if not me or me.phase == 0 then
		return
	end
	me.clicks = me.clicks + 1
	if me.clicks >= 50 then
		self:Win("Wrinkler poker")
	end
	me.hp = me.hp - 0.75
	NS.PlayKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
	if me.hp <= 0.5 then
		self:PopWrinkler(me)
		if NS.UI and NS.UI.RefreshWrinklers then
			NS.UI:RefreshWrinklers()
		end
	end
end

function Game:PopWrinkler(me)
	local S = self.save
	S.wrinklersPopped = (S.wrinklersPopped or 0) + 1
	self.recalc = true
	local shiny = me.type == 1
	me.phase = 0
	me.close = 0
	me.hp = self.wrinklerHP * (shiny and 3 or 1)
	local toSuck = 1.1
	if self:Has("Sacrilegious corruption") then toSuck = toSuck * 1.05 end
	toSuck = toSuck * (1 + self:AuraMult("Dragon Guts") * 0.2)
	if shiny then toSuck = toSuck * 3 end
	me.sucked = me.sucked * toSuck
	if self:Has("Wrinklerspawn") then me.sucked = me.sucked * 1.05 end
	local godLvl = self:HasGod("scorn")
	if godLvl == 1 then me.sucked = me.sucked * 1.15 elseif godLvl == 2 then me.sucked = me.sucked * 1.1 elseif godLvl == 3 then me.sucked = me.sucked * 1.05 end
	if me.sucked > 0.5 then
		NS.Notify(shiny and "Exploded a shiny wrinkler" or "Exploded a wrinkler", "Found " .. NS.Beautify(me.sucked) .. " cookies!", {19,8})
		if not self:HasUnlocked("Wrinkler ambergris") and math.random() < 1 / (shiny and 1000 or 10000) then
			self:Unlock("Wrinkler ambergris")
			NS.Notify("Wrinkler ambergris", "You also found Wrinkler ambergris!", NS.U["Wrinkler ambergris"].icon)
		end
		if S.season == "halloween" then
			local failRate = 0.95
			if self:HasAchiev("Spooky cookies") then failRate = failRate * 0.8 end
			if self:Has("Starterror") then failRate = failRate * 0.9 end
			godLvl = self:HasGod("seasons")
			if godLvl == 1 then failRate = failRate * 0.9 elseif godLvl == 2 then failRate = failRate * 0.95 elseif godLvl == 3 then failRate = failRate * 0.97 end
			if shiny then failRate = failRate * 0.9 end
			failRate = failRate ^ self:DropRateMult()
			if math.random() > failRate then
				local cookie = Choose(NS.HALLOWEEN_DROPS)
				if not self:HasUnlocked(cookie) and not self:Has(cookie) then
					self:Unlock(cookie)
					NS.Notify(cookie, "You also found " .. cookie .. "!", NS.U[cookie].icon)
				end
			end
		end
		self:DropEgg(0.98)
	end
	if shiny then
		self:Win("Last Chance to See")
	end
	self:Earn(me.sucked)
	me.sucked = 0
	me.type = 0
	NS.PlayKit("IG_BACKPACK_COIN_OK")
	self:Changed()
end
