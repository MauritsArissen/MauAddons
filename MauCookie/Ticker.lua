-- MauCookie news ticker: the original's Game.getNewTicker, ported.  A new
-- line every ten seconds while the window is open, built from the lists in
-- Data_Ticker.lua with the same conditions and odds (building lines on
-- every other ticker, owned-upgrade lines 5% of the time, the lore by
-- progress, the Grandmapocalypse and Business day overrides), occasionally
-- a fortune (Specials.lua) that can be clicked.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

Game.ticker = ""
Game.tickerAge = 0
Game.tickerEffect = nil
Game.tickerN = 0

local T = NS.TICKER

local function BakeryName()
	return NS.ShortName(UnitName("player")) or "Your"
end

-- %A animal, %B bakery name, %E cookies earned, %Y the "average person"
-- figure, %N<max>+<add> a random integer, %{a|b|c} a random choice
-- (nestable).
local function Expand(line)
	local S = Game.save
	local guard = 0
	while guard < 20 do
		guard = guard + 1
		local before = line
		line = line:gsub("%%{([^{}]*)}", function(body)
			local options = {}
			for part in (body .. "|"):gmatch("([^|]*)|") do
				table.insert(options, part)
			end
			return options[math.random(#options)] or ""
		end)
		if line == before then
			break
		end
	end
	line = line:gsub("%%N(%d+)%+(%d+)", function(max, add)
		return tostring(math.floor(math.random() * tonumber(max) + tonumber(add)))
	end)
	line = line:gsub("%%A", function()
		return Choose(T.ANIMALS)
	end)
	line = line:gsub("%%B", function()
		return BakeryName()
	end)
	line = line:gsub("%%E", function()
		return NS.Beautify(S.earned or 0)
	end)
	line = line:gsub("%%Y", function()
		return NS.Beautify(math.ceil((S.earned or 0) / 8000000000))
	end)
	return line
end

local function LoreProgress()
	local earned = Game.save.earned or 0
	if earned <= 0 then
		return 0
	end
	return math.floor(math.log10(earned / 10) + 1 + 0.5)
end

-- Builds the candidate list exactly like the original and picks one.
function Game:TickerLine()
	local S = self.save
	local list = {}
	local function push(...)
		for _, v in ipairs({ ... }) do
			table.insert(list, v)
		end
	end
	local earned = S.earned or 0
	local loreProgress = LoreProgress()
	local grandmas = self:Count("Grandma")
	if self.tickerN % 2 == 0 or loreProgress > 14 then
		if math.random() < 0.75 or earned < 10000 then
			if grandmas > 0 then push(Choose(T.GRANDMA) .. " - grandma") end
			if grandmas >= 50 then push(Choose(T.GRANDMA_THREATENING) .. " - grandma") end
			if self:HasAchiev("Just wrong") and math.random() < 0.05 then push("News : cookie manufacturer downsizes, sells own grandmother!") end
			if self:HasAchiev("Just wrong") and math.random() < 0.05 then push(Choose(T.GRANDMA_ANGRY) .. " - grandma") end
			if grandmas >= 1 and (S.pledges or 0) > 0 and (S.elderWrath or 0) == 0 then push(Choose(T.GRANDMA_RETURN) .. " - grandma") end
			for _, b in ipairs(NS.BUILDINGS) do
				local lines = T.BUILDINGS[b.name]
				if lines and self:Count(b.name) > 0 then
					push(Choose(lines))
				end
			end
			if earned >= 1000 and T.SEASONS[S.season] then
				push(Choose(T.SEASONS[S.season]))
			end
		end
		if math.random() < 0.05 then
			for _, entry in ipairs(T.OWNED) do
				if (entry.achiev and self:HasAchiev(entry.achiev)) or (entry.upgrade and self:Has(entry.upgrade)) then
					push(entry.line)
				end
			end
		end
		if self:HasAchiev("Dude, sweet") and math.random() < 0.2 then
			push(Choose(T.SUGAR))
		end
		if math.random() < 0.001 then
			push(unpack(T.OMENS))
		end
		if earned >= 10000 then
			push(Choose(T.GENERIC_A), "News : \"" .. Choose(T.CELEBRITY) .. "\", reveals celebrity.", Choose(T.GENERIC_B), Choose(T.GENERIC_C), Choose(T.GENERIC_D), Choose(T.GENERIC_E))
		end
	end
	if #list == 0 then
		local lore = T.LORE[math.min(#T.LORE, math.max(0, loreProgress) + 1)]
		push(unpack(lore))
	end
	local wrath = S.elderWrath or 0
	if wrath > 0 and ((((S.pledges or 0) == 0 and (S.resets or 0) == 0) and math.random() < 0.3) or math.random() < 0.03) then
		list = {}
		local lines = T.WRATH[math.min(3, wrath)]
		if lines then
			table.insert(list, Choose(lines))
		end
	end
	if S.season == "fools" then
		list = {}
		if earned >= 1000 then
			local kind = math.random(3)
			if kind == 1 then push(Choose(T.FOOLS_MOOD))
			elseif kind == 2 then push(Choose(T.FOOLS_AGENDA_A) .. " " .. Choose(T.FOOLS_AGENDA_B) .. "!")
			else push("The word of the day is: " .. Choose(T.FOOLS_WORDS) .. ".") end
		end
		if earned >= 1000 and math.random() < 0.05 then
			push(Choose(T.FOOLS_RARE))
		end
		if self.tickerN % 2 == 0 then
			for _, b in ipairs(NS.BUILDINGS) do
				local lines = T.FOOLS_BUILDINGS[b.name]
				if lines and self:Count(b.name) > 0 then
					push(Choose(lines))
				end
			end
		end
		push(T.FOOLS_LORE[math.min(#T.FOOLS_LORE, math.max(0, loreProgress) + 1)])
	end
	if #list == 0 then
		return ""
	end
	return Expand(Choose(list))
end

function Game:NewTicker(manual)
	local effect = nil
	if not manual then
		effect = self:RollFortune()
	end
	if effect then
		self.ticker = effect.text
		self.tickerEffect = effect
	else
		self.ticker = self:TickerLine()
		self.tickerEffect = nil
	end
	self.tickerAge = 10
	self.tickerN = (self.tickerN or 0) + 1
	if NS.UI and NS.UI.OnTicker then
		NS.UI:OnTicker()
	end
end

function Game:UpdateTicker(dt)
	if not (NS.UI and NS.UI:IsShown()) then
		return
	end
	self.tickerAge = (self.tickerAge or 0) - dt
	if self.tickerAge <= 0 then
		self:NewTicker(false)
	end
end

function Game:ClickTicker()
	local effect = self.tickerEffect
	self.ticker = ""
	self.tickerEffect = nil
	self:ClickTickerEffect(effect)
	if NS.UI and NS.UI.OnTicker then
		NS.UI:OnTicker()
	end
end
