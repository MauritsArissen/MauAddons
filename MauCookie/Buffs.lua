-- MauCookie buffs: the original's Game.buffTypes and gainBuff, ported.  A
-- buff lives in save.buffs as { type, name, desc, icon, time, maxTime,
-- multCpS, multClick, power, arg1, arg2, arg3 } with time in seconds of
-- bakery time, so it only runs down while you are logged in.

local _, NS = ...

local Game = NS.Game

local function SayTime(seconds)
	return NS.FormatDuration(seconds)
end

local function MultText(pow)
	if pow == math.floor(pow) then
		return string.format("%d", pow)
	end
	return string.format("%.2f", pow)
end

-- type -> function(time, pow, building) returning the buff definition.
NS.BUFF_TYPES = {
	["frenzy"] = function(time, pow)
		return { name = "Frenzy", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {10,14}, time = time, add = true, multCpS = pow, aura = 1 }
	end,
	["blood frenzy"] = function(time, pow)
		return { name = "Elder frenzy", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {29,6}, time = time, add = true, multCpS = pow, aura = 1 }
	end,
	["clot"] = function(time, pow)
		return { name = "Clot", desc = string.format("Cookie production halved for %s!", SayTime(time)), icon = {15,5}, time = time, add = true, multCpS = pow, aura = 2 }
	end,
	["dragon harvest"] = function(time, pow)
		if Game:Has("Dragon fang") then pow = math.ceil(pow * 1.1) end
		return { name = "Dragon Harvest", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {10,25}, time = time, add = true, multCpS = pow, aura = 1 }
	end,
	["everything must go"] = function(time, pow)
		return { name = "Everything must go", desc = string.format("All buildings are %d%% cheaper for %s!", pow, SayTime(time)), icon = {17,6}, time = time, add = true, power = pow, aura = 1 }
	end,
	["cursed finger"] = function(time, pow)
		return { name = "Cursed finger", desc = string.format("Cookie production halted for %s, but each click is worth %s of CpS.", SayTime(time), SayTime(time)), icon = {12,17}, time = time, add = true, power = pow, multCpS = 0, aura = 1 }
	end,
	["click frenzy"] = function(time, pow)
		return { name = "Click frenzy", desc = string.format("Clicking power x%s for %s!", MultText(pow), SayTime(time)), icon = {0,14}, time = time, add = true, multClick = pow, aura = 1 }
	end,
	["dragonflight"] = function(time, pow)
		if Game:Has("Dragon fang") then pow = math.ceil(pow * 1.1) end
		return { name = "Dragonflight", desc = string.format("Clicking power x%s for %s!", MultText(pow), SayTime(time)), icon = {0,25}, time = time, add = true, multClick = pow, aura = 1 }
	end,
	["cookie storm"] = function(time, pow)
		return { name = "Cookie storm", desc = "Cookies everywhere!", icon = {22,6}, time = time, add = true, power = pow, aura = 1 }
	end,
	["building buff"] = function(time, pow, building)
		local b = NS.BY_ID[building]
		local names = NS.BUILDING_BUFFS[b.name]
		return { name = names[1], desc = string.format("Your %d %s are boosting your CpS! Cookie production +%s%% for %s!", Game:Count(b.name), Game:Count(b.name) == 1 and b.single or b.plural, NS.Beautify(math.ceil(pow * 100 - 100)), SayTime(time)), icon = {b.iconColumn, 14}, time = time, add = true, multCpS = pow, aura = 1 }
	end,
	["building debuff"] = function(time, pow, building)
		local b = NS.BY_ID[building]
		local names = NS.BUILDING_BUFFS[b.name]
		return { name = names[2], desc = string.format("Your %d %s are rusting your CpS! Cookie production %s%% slower for %s!", Game:Count(b.name), Game:Count(b.name) == 1 and b.single or b.plural, NS.Beautify(math.ceil(pow * 100 - 100)), SayTime(time)), icon = {b.iconColumn, 15}, time = time, add = true, multCpS = 1 / pow, aura = 2 }
	end,
	["sugar blessing"] = function(time)
		return { name = "Sugar blessing", desc = string.format("You find 10%% more golden cookies for the next %s.", SayTime(time)), icon = {29,16}, time = time }
	end,
	["haggler luck"] = function(time, pow)
		return { name = "Haggler's luck", desc = string.format("All upgrades are %d%% cheaper for %s!", pow, SayTime(time)), icon = {25,11}, time = time, power = pow, max = true }
	end,
	["haggler misery"] = function(time, pow)
		return { name = "Haggler's misery", desc = string.format("All upgrades are %d%% pricier for %s!", pow, SayTime(time)), icon = {25,11}, time = time, power = pow, max = true }
	end,
	["pixie luck"] = function(time, pow)
		return { name = "Crafty pixies", desc = string.format("All buildings are %d%% cheaper for %s!", pow, SayTime(time)), icon = {26,11}, time = time, power = pow, max = true }
	end,
	["pixie misery"] = function(time, pow)
		return { name = "Nasty goblins", desc = string.format("All buildings are %d%% pricier for %s!", pow, SayTime(time)), icon = {26,11}, time = time, power = pow, max = true }
	end,
	["magic adept"] = function(time, pow)
		return { name = "Magic adept", desc = string.format("Spells backfire %d times less for %s.", pow, SayTime(time)), icon = {29,11}, time = time, power = pow, max = true }
	end,
	["magic inept"] = function(time, pow)
		return { name = "Magic inept", desc = string.format("Spells backfire %d times more for %s.", pow, SayTime(time)), icon = {29,11}, time = time, power = pow, max = true }
	end,
	["devastation"] = function(time, pow)
		return { name = "Devastation", desc = string.format("Clicking power +%d%% for %s!", math.floor(pow * 100 - 100), SayTime(time)), icon = {23,18}, time = time, multClick = pow, aura = 1, max = true }
	end,
	["sugar frenzy"] = function(time, pow)
		return { name = "Sugar frenzy", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {29,14}, time = time, add = true, multCpS = pow, aura = 0 }
	end,
	["loan 1"] = function(time, pow)
		return { name = "Loan 1", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true, onDie = "loan1" }
	end,
	["loan 1 interest"] = function(time, pow)
		return { name = "Loan 1 (interest)", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true }
	end,
	["loan 2"] = function(time, pow)
		return { name = "Loan 2", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true, onDie = "loan2" }
	end,
	["loan 2 interest"] = function(time, pow)
		return { name = "Loan 2 (interest)", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true }
	end,
	["loan 3"] = function(time, pow)
		return { name = "Loan 3", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true, onDie = "loan3" }
	end,
	["loan 3 interest"] = function(time, pow)
		return { name = "Loan 3 (interest)", desc = string.format("Cookie production x%s for %s!", MultText(pow), SayTime(time)), icon = {1,33}, time = time, power = pow, multCpS = pow, max = true }
	end,
}

function Game:Buffs()
	self.save.buffs = self.save.buffs or {}
	return self.save.buffs
end

-- Returns the buff, or nil when it is not running.
function Game:HasBuff(name)
	for _, buff in ipairs(self:Buffs()) do
		if buff.name == name and buff.time > 0 then
			return buff
		end
	end
	return nil
end

function Game:GainBuff(typeName, time, arg1, arg2, arg3)
	local maker = NS.BUFF_TYPES[typeName]
	if not maker then
		return nil
	end
	local def = maker(time, arg1, arg2, arg3)
	def.type = typeName
	def.arg1, def.arg2, def.arg3 = arg1, arg2, arg3
	local existing = self:HasBuff(def.name)
	if existing then
		if def.max then
			existing.time = math.max(def.time, existing.time)
		elseif def.add then
			existing.time = existing.time + def.time
		else
			existing.time = def.time
		end
		existing.maxTime = existing.time
		self.recalc = true
		self:StoreDirty()
		return existing
	end
	def.maxTime = def.time
	table.insert(self:Buffs(), def)
	self.recalc = true
	self:StoreDirty()
	if NS.UI and NS.UI.OnBuffsChanged then
		NS.UI:OnBuffsChanged()
	end
	return def
end

function Game:UpdateBuffs(dt)
	local list = self:Buffs()
	local changed = false
	for i = #list, 1, -1 do
		local buff = list[i]
		buff.time = buff.time - dt
		if buff.time <= 0 then
			table.remove(list, i)
			if buff.onDie and self.OnBuffDie then
				self:OnBuffDie(buff)
			end
			changed = true
		end
	end
	if changed then
		self.recalc = true
		self:StoreDirty()
		if NS.UI and NS.UI.OnBuffsChanged then
			NS.UI:OnBuffsChanged()
		end
	end
end

function Game:KillBuff(name)
	local buff = self:HasBuff(name)
	if buff then
		buff.time = 0
	end
end

function Game:KillBuffs()
	self.save.buffs = {}
	self.recalc = true
	self:StoreDirty()
	if NS.UI and NS.UI.OnBuffsChanged then
		NS.UI:OnBuffsChanged()
	end
end
