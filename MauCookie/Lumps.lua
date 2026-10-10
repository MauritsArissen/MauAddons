-- MauCookie sugar lumps, ported from the original.  A lump coalesces once
-- a billion cookies have been baked in total; it matures after 20 hours,
-- ripens after 23 and falls (auto-harvests) after 24, on real time like
-- the original (save.lumpT is a server timestamp), and lumps that fell
-- while you were away are harvested on login.  Lumps buy building levels
-- (level 1 opens a minigame) and a few switches.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

local HOUR = 60 * 60

function Game:CanLumps()
	local S = self.save
	if (S.lumpsTotal or -1) > -1 then
		return true
	end
	return S.ascensionMode ~= 1 and self:AllTime() >= 1e9
end

function Game:ComputeLumpTimes()
	self.lumpMatureAge = HOUR * 20
	self.lumpRipeAge = HOUR * 23
	if self:Has("Stevia Caelestis") then self.lumpRipeAge = self.lumpRipeAge - HOUR end
	if self:Has("Diabetica Daemonicus") then self.lumpMatureAge = self.lumpMatureAge - HOUR end
	if self:Has("Ichor syrup") then self.lumpMatureAge = self.lumpMatureAge - 60 * 7 end
	if self:Has("Sugar aging process") then self.lumpRipeAge = self.lumpRipeAge - 6 * math.min(600, self:Count("Grandma")) end
	if self:BuildingsOwned() % 10 == 0 then
		local godLvl = self:HasGod("order")
		if godLvl == 1 then self.lumpRipeAge = self.lumpRipeAge - HOUR
		elseif godLvl == 2 then self.lumpRipeAge = self.lumpRipeAge - (HOUR / 3) * 2
		elseif godLvl == 3 then self.lumpRipeAge = self.lumpRipeAge - HOUR / 3 end
	end
	local curve = 1 + self:AuraMult("Dragon's Curve") * 0.05
	self.lumpMatureAge = self.lumpMatureAge / curve
	self.lumpRipeAge = self.lumpRipeAge / curve
	self.lumpOverripeAge = self.lumpRipeAge + HOUR
	if self:Has("Glucose-charged air") then
		self.lumpMatureAge = self.lumpMatureAge / 2000
		self.lumpRipeAge = self.lumpRipeAge / 2000
		self.lumpOverripeAge = self.lumpOverripeAge / 2000
	end
end

-- Login: lumps that fell while away.
function Game:LoadLumps()
	local S = self.save
	self:ComputeLumpTimes()
	if not self:CanLumps() or (S.lumpsTotal or -1) == -1 then
		return
	end
	local now = time()
	S.lumpT = math.min(now, S.lumpT or now)
	local age = math.max(now - S.lumpT, 0)
	local amount = math.floor(age / self.lumpOverripeAge)
	if amount >= 1 then
		self:HarvestLumps(1, true)
		S.lumpType = 0
		if amount > 1 then
			self:HarvestLumps(amount - 1, true)
		end
		NS.Notify("", "You harvested " .. amount .. " sugar lump" .. (amount == 1 and "" or "s") .. " while you were away.", {29,14})
		S.lumpT = now - (age - amount * self.lumpOverripeAge)
		self:ComputeLumpType()
	end
end

function Game:GainLumps(total)
	local S = self.save
	if (S.lumpsTotal or -1) == -1 then
		S.lumpsTotal = 0
		S.lumps = 0
	end
	S.lumps = S.lumps + total
	S.lumpsTotal = S.lumpsTotal + total
	if S.lumpsTotal >= 7 then self:Win("Dude, sweet") end
	if S.lumpsTotal >= 30 then self:Win("Sugar rush") end
	if S.lumpsTotal >= 365 then self:Win("Year's worth of cavities") end
	self.recalc = true
	self:Changed()
end

function Game:LumpAge()
	return time() - (self.save.lumpT or time())
end

function Game:ClickLump()
	local S = self.save
	if not self:CanLumps() or (S.lumpsTotal or -1) == -1 then
		return
	end
	local age = self:LumpAge()
	if age < self.lumpMatureAge then
		return
	elseif age < self.lumpRipeAge then
		local amount = Choose({ 0, 1 })
		if amount ~= 0 then
			self:Win("Hand-picked")
		end
		self:HarvestLumps(amount)
		self:ComputeLumpType()
	elseif age < self.lumpOverripeAge then
		self:HarvestLumps(1)
		self:ComputeLumpType()
	end
end

function Game:HarvestLumps(amount, silent)
	local S = self.save
	if not self:CanLumps() then
		return
	end
	S.lumpT = time()
	local total = amount
	local t = S.lumpType or 0
	if t == 1 and self:Has("Sucralosia Inutilis") and math.random() < 0.05 then
		total = total * 2
	elseif t == 1 then
		total = total * Choose({ 1, 2 })
	elseif t == 2 then
		total = total * Choose({ 2, 3, 4, 5, 6, 7 })
		self:GainBuff("sugar blessing", 24 * 60 * 60, 1)
		self:Earn(math.min((self.cps or 0) * 60 * 60 * 24, S.cookies))
		NS.Notify("Sugar blessing activated!", "Your cookies have been doubled. +10% golden cookies for the next 24 hours.", {29,16})
	elseif t == 3 then
		total = total * Choose({ 0, 0, 1, 2, 2 })
	elseif t == 4 then
		total = total * Choose({ 1, 2, 3 })
		S.lumpRefill = 0
		NS.Notify("Sugar lump cooldowns cleared!", "", {29,27})
	end
	total = math.floor(total)
	self:GainLumps(total)
	if t == 1 then self:Win("Sugar sugar")
	elseif t == 2 then self:Win("All-natural cane sugar")
	elseif t == 3 then self:Win("Sweetmeats")
	elseif t == 4 then self:Win("Maillard reaction") end
	if not silent then
		if total > 0 then
			NS.Notify("Sugar lump harvested", "+" .. total .. " sugar lump" .. (total == 1 and "" or "s"), {29,14})
		else
			NS.Notify("Botched harvest!", "", {29,14})
		end
		NS.PlayKit("UI_EPICLOOT_TOAST")
	end
	self:ComputeLumpTimes()
end

function Game:ComputeLumpType()
	local S = self.save
	local types = { 0 }
	local loop = 1 + self:AuraMult("Dragon's Curve")
	if (loop % 1) < math.random() then loop = math.floor(loop) else loop = math.ceil(loop) end
	for _ = 1, loop do
		if math.random() < (self:Has("Sucralosia Inutilis") and 0.15 or 0.1) then table.insert(types, 1) end
		if math.random() < 3 / 1000 then table.insert(types, 2) end
		if math.random() < 0.1 * (S.elderWrath or 0) then table.insert(types, 3) end
		if math.random() < 1 / 50 then table.insert(types, 4) end
	end
	S.lumpType = Choose(types)
end

function Game:LumpRefillMax()
	return 60 * 15
end

function Game:CanRefillLump()
	return (self.save.lumpRefill or 0) <= 0
end

-- Spend lumps; returns true when paid.
function Game:SpendLumps(n)
	local S = self.save
	if (S.lumps or 0) < n then
		return false
	end
	S.lumps = S.lumps - n
	self.recalc = true
	return true
end

function Game:RefillLump(n, func)
	local S = self.save
	if (S.lumps or 0) >= n and self:CanRefillLump() then
		S.lumps = S.lumps - n
		S.lumpRefill = self:LumpRefillMax()
		func()
		self.recalc = true
		return true
	end
	return false
end

function Game:DoLumps(dt)
	local S = self.save
	if (S.lumpRefill or 0) > 0 then
		S.lumpRefill = S.lumpRefill - dt
	end
	if not self:CanLumps() then
		return
	end
	if (S.lumpsTotal or -1) == -1 then
		S.lumpT = time()
		S.lumpsTotal = 0
		S.lumps = 0
		self:ComputeLumpType()
		NS.Notify("Sugar lumps!", "Because you've baked a billion cookies in total, you are now attracting sugar lumps. They coalesce quietly near the top of your screen, under the Stats button. You will be able to harvest them when they're ripe, after which you may spend them on all sorts of things!", {23,14})
		if NS.UI and NS.UI.OnLumpsEnabled then
			NS.UI:OnLumpsEnabled()
		end
	end
	local age = self:LumpAge()
	if age > self.lumpOverripeAge then
		self:HarvestLumps(1)
		self:ComputeLumpType()
	end
end

-- Icon cells and blend for the lump drawn under the Stats button.
function Game:LumpIcons()
	local S = self.save
	local age = self:LumpAge()
	local phase = math.min(6, math.floor((age / self.lumpOverripeAge) * 7))
	local phase2 = math.min(6, math.floor((age / self.lumpOverripeAge) * 7) + 1)
	local row, row2 = 14, 14
	local t = S.lumpType or 0
	if t == 1 then
		if phase2 >= 6 then row2 = 15 end
	elseif t == 2 then
		if phase >= 4 then row = 16 end
		if phase2 >= 4 then row2 = 16 end
	elseif t == 3 then
		if phase >= 4 then row = 17 end
		if phase2 >= 4 then row2 = 17 end
	elseif t == 4 then
		if phase >= 4 then row = 27 end
		if phase2 >= 4 then row2 = 27 end
	end
	local icon = { 23 + math.min(phase, 5), row }
	local icon2 = { 23 + phase2, row2 }
	if age < 0 then
		icon, icon2 = { 17, 5 }, { 17, 5 }
	end
	local opacity = (math.min(6, (age / self.lumpOverripeAge) * 7)) % 1
	if phase >= 6 then
		opacity = 1
	end
	return icon, icon2, opacity
end

function Game:LumpTooltipLines()
	local S = self.save
	local lines = {}
	table.insert(lines, string.format("You have %d sugar lump%s.", S.lumps or 0, (S.lumps or 0) == 1 and "" or "s"))
	table.insert(lines, "A sugar lump is coalescing here, attracted by your accomplishments.")
	local age = self:LumpAge()
	if age < self.lumpMatureAge then
		table.insert(lines, "This sugar lump is still growing and will take " .. NS.FormatDuration(self.lumpMatureAge - age + 1) .. " to reach maturity.")
	elseif age < self.lumpRipeAge then
		table.insert(lines, "This sugar lump is mature and will be ripe in " .. NS.FormatDuration(self.lumpRipeAge - age + 1) .. ". You may click it to harvest it now, but there is a 50% chance you won't get anything.")
	elseif age < self.lumpOverripeAge then
		table.insert(lines, "This sugar lump is ripe! Click it to harvest it. If you do nothing, it will auto-harvest in " .. NS.FormatDuration(self.lumpOverripeAge - age + 1) .. ".")
	end
	local phase = (age / self.lumpOverripeAge) * 7
	if phase >= 3 then
		local t = S.lumpType or 0
		if t == 1 then table.insert(lines, "This sugar lump grew to be bifurcated; harvesting it has a 50% chance of yielding two lumps.")
		elseif t == 2 then table.insert(lines, "This sugar lump grew to be golden; harvesting it will yield 2 to 7 lumps, your current cookies will be doubled (capped to a gain of 24 hours of your CpS), and you will find 10% more golden cookies for the next 24 hours.")
		elseif t == 3 then table.insert(lines, "This sugar lump was affected by the elders and grew to be meaty; harvesting it will yield between 0 and 2 lumps.")
		elseif t == 4 then table.insert(lines, "This sugar lump is caramelized, its stickiness binding it to unexpected things; harvesting it will yield between 1 and 3 lumps and will refill your sugar lump cooldowns.") end
	end
	table.insert(lines, string.format("Your sugar lumps mature after %s, ripen after %s, and fall after %s.", NS.FormatDuration(self.lumpMatureAge), NS.FormatDuration(self.lumpRipeAge), NS.FormatDuration(self.lumpOverripeAge)))
	table.insert(lines, "Sugar lumps can be harvested when mature, though if left alone beyond that point they will start ripening (increasing the chance of harvesting them) and will eventually fall and be auto-harvested after 24 hours. They are used to level up buildings and buy a few other things.")
	return lines
end
