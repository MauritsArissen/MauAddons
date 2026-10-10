-- MauCookie news ticker: a new line every ten seconds while the window is
-- open, occasionally a fortune (Specials.lua) that can be clicked.  The
-- lines come from Data_Ticker.lua until the original's getNewTicker is
-- ported in full.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

Game.ticker = ""
Game.tickerAge = 0
Game.tickerEffect = nil

local function Count(game, name)
	return game:Count(name)
end

function Game:TickerLine()
	local S = self.save
	local list = {}
	local wrath = S.elderWrath or 0
	if wrath > 0 and NS.TICKER_GRANDMA and NS.TICKER_GRANDMA[wrath] then
		for _, line in ipairs(NS.TICKER_GRANDMA[wrath]) do
			table.insert(list, line)
		end
	end
	if S.season == "fools" then
		table.insert(list, "News : the stock market is up! Cookie shares have never been this hot.")
		table.insert(list, "News : local baker on track to become richest person alive, say analysts.")
	elseif S.season == "christmas" then
		table.insert(list, "News : bearded fatso hospitalized after reportedly being struck by cookie shipment, is it really him?")
		table.insert(list, "News : local children shocked to learn Santa Claus is really just a man in a fat suit, grandmas rejoice.")
	elseif S.season == "halloween" then
		table.insert(list, "News : strange twisting creatures amass around cookie factories, nibble at assembly lines.")
		table.insert(list, "News : spooky cookies in high demand, bakers report; monsters stuffing their faces, say experts.")
	elseif S.season == "easter" then
		table.insert(list, "News : bunnies are not real, says expert; those were just all the eggs.")
		table.insert(list, "News : eggs in cookies? Wild bunny population booming, say worried farmers.")
	elseif S.season == "valentines" then
		table.insert(list, "News : love is in the air, say bakers; sales of heart-shaped biscuits through the roof.")
	end
	if #list > 0 and math.random() < 0.5 then
		return Choose(list)
	end
	return Choose(NS.TICKER)
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
