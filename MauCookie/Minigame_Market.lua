-- MauCookie Stock market (Bank level 1), ported from minigameMarket.js:
-- eighteen goods whose values drift every minute of bakery time, bought
-- and sold in units of seconds of your highest raw CpS, brokers that cut
-- the buying overhead, five office levels paid in cursors, three loans
-- (buffs that end in interest).  The graph shows the last 65 ticks.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

local M = { building = "Bank", name = "Stock Market", height = 560 }

M.goods = {
	{ building = "Farm", name = "Cereals", symbol = "CRL", company = "Old Mills" },
	{ building = "Mine", name = "Chocolate", symbol = "CHC", company = "Cocoa Excavations" },
	{ building = "Factory", name = "Butter", symbol = "BTR", company = "Bovine Industries" },
	{ building = "Bank", name = "Sugar", symbol = "SUG", company = "Candy Trust" },
	{ building = "Temple", name = "Nuts", symbol = "NUT", company = "Hazel Monastery" },
	{ building = "Wizard tower", name = "Salt", symbol = "SLT", company = "Wacky Reagants" },
	{ building = "Shipment", name = "Vanilla", symbol = "VNL", company = "Cosmic Exports" },
	{ building = "Alchemy lab", name = "Eggs", symbol = "EGG", company = "Organic Gnostics" },
	{ building = "Portal", name = "Cinnamon", symbol = "CNM", company = "Dimensional Exchange" },
	{ building = "Time machine", name = "Cream", symbol = "CRM", company = "Precision Aging" },
	{ building = "Antimatter condenser", name = "Jam", symbol = "JAM", company = "Pectin Research" },
	{ building = "Prism", name = "White chocolate", symbol = "WCH", company = "Dazzle Corp Ltd." },
	{ building = "Chancemaker", name = "Honey", symbol = "HNY", company = "Prosperity Hive" },
	{ building = "Fractal engine", name = "Cookies", symbol = "CKI", company = "Selfmade Bakeries" },
	{ building = "Javascript console", name = "Recipes", symbol = "RCP", company = "Figments Associated" },
	{ building = "Idleverse", name = "Subsidiaries", symbol = "SBD", company = "Polyvalent Acquisitions" },
	{ building = "Cortex baker", name = "Publicists", symbol = "PBL", company = "Great Minds" },
	{ building = "You", name = "You", symbol = "YOU", company = "Your Bakery" },
}
for i, g in ipairs(M.goods) do
	g.id = i - 1
	g.icon = { NS.B[g.building] and NS.B[g.building].iconColumn or 0, 33 }
end

M.offices = {
	{ name = "Credit garage", icon = {0,33}, cost = { 100, 2 }, desc = "This is your starting office. Upgrading will grant you +25 warehouse space for all goods." },
	{ name = "Tiny bank", icon = {9,33}, cost = { 200, 4 }, desc = "Upgrading will grant you +1 loan slot and +50 warehouse space for all goods." },
	{ name = "Loaning company", icon = {10,33}, cost = { 350, 8 }, desc = "Upgrading will grant you +75 warehouse space for all goods." },
	{ name = "Finance headquarters", icon = {11,33}, cost = { 500, 10 }, desc = "Upgrading will grant you +1 loan slot and +100 warehouse space for all goods." },
	{ name = "International exchange", icon = {12,33}, cost = { 700, 12 }, desc = "Upgrading will grant you +1 loan slot and +50% base warehouse space for all goods." },
	{ name = "Palace of Greed", icon = {18,33}, desc = "It is fully upgraded. Its lavish interiors, spanning across innumerable floors, are host to many a decadent party, owing to your nigh-unfathomable wealth." },
}

-- name, CpS multiplier, minutes, interest multiplier, interest minutes, downpayment fraction, quote
M.loanTypes = {
	{ "a modest loan", 1.5, 60 * 2, 0.25, 60 * 4, 0.2, "Buy that vintage car you've always wanted. Just pay us back." },
	{ "a pawnshop loan", 2, 0.67, 0.1, 40, 0.4, "Bad credit? No problem. It's your money, and you need it now." },
	{ "a retirement loan", 1.2, 60 * 24 * 2, 0.8, 60 * 24 * 5, 0.5, "Finance your next house, boat, spouse, etc. You've earned it." },
}

local function Highest()
	return Game.save.cpsHighest or 0
end

function M:good(i)
	return self.state.goods[i]
end

function M:load(fresh)
	local st = self.state
	if fresh or not st.goods then
		st.officeLevel = 0
		st.brokers = 0
		st.profit = 0
		st.tickT = 0
		st.ticks = 0
		st.goods = {}
		for i = 1, #self.goods do
			st.goods[i] = { stock = 0, mode = 0, dur = 0, val = 1, d = 0, vals = {}, hidden = true, last = 0, prev = 0 }
		end
		self:resetGoods()
	end
	Game.takeLoan = function(id, interest)
		return M:takeLoan(id, interest)
	end
end

function M:getRestingVal(id)
	return 10 + 10 * id + (Game:Level("Bank") - 1)
end

function M:getGoodMaxStock(i)
	local st = self.state
	local g = self.goods[i]
	local r = Game:Bld(g.building)
	local bonus = 0
	if st.officeLevel > 0 then bonus = bonus + 25 end
	if st.officeLevel > 1 then bonus = bonus + 50 end
	if st.officeLevel > 2 then bonus = bonus + 75 end
	if st.officeLevel > 3 then bonus = bonus + 100 end
	return math.ceil(r.highest * (st.officeLevel > 4 and 1.5 or 1) + bonus + r.level * 10)
end

function M:isActive(i)
	return Game:Bld(self.goods[i].building).highest > 0
end

function M:goodDelta(i, back)
	back = back or 0
	local g = self:good(i)
	local val = 0
	if #g.vals >= 2 + back then
		val = g.vals[1 + back] / g.vals[2 + back] - 1
	end
	return math.floor(val * 10000) / 100
end

function M:overhead()
	return 1 + 0.01 * (20 * (0.95 ^ (self.state.brokers or 0)))
end

function M:buyGood(i, n)
	local st = self.state
	local g = self:good(i)
	local costInS = g.val
	local cost = Highest() * costInS * self:overhead()
	if n == 10000 then
		n = cost > 0 and math.floor(Game.save.cookies / cost) or 0
	end
	n = math.min(n, self:getGoodMaxStock(i) - g.stock)
	if n > 0 and g.last ~= 2 and Game.save.cookies >= cost * n then
		if costInS * self:overhead() * n >= 86400 then Game:Win("Buy buy buy") end
		st.profit = st.profit - costInS * self:overhead() * n
		Game:Spend(cost * n)
		g.stock = g.stock + n
		local min = 10000
		for j = 1, #self.goods do
			local it = self:good(j)
			min = math.min(min, it.stock)
			if it.stock >= 1000 then Game:Win("Full warehouses") end
		end
		if min >= 100 then Game:Win("Rookie numbers") end
		if min >= 500 then Game:Win("No nobility in poverty") end
		g.last = 1
		g.prev = costInS
		NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
		Game:Changed()
		return true
	end
	return false
end

function M:sellGood(i, n)
	local st = self.state
	local g = self:good(i)
	if n == 10000 then
		n = g.stock
	end
	n = math.min(n, g.stock)
	if n > 0 and g.last ~= 1 then
		local costInS = g.val
		if costInS * n >= 86400 then Game:Win("Make my day") end
		st.profit = st.profit + costInS * n
		if st.profit > 0 then Game:Win("Initial public offering") end
		if st.profit >= 10000000 then Game:Win("Liquid assets") end
		if st.profit >= 31536000 then Game:Win("Gaseous assets") end
		Game.save.cookies = Game.save.cookies + Highest() * costInS * n
		Game.save.earned = math.max(Game.save.cookies, Game.save.earned)
		g.stock = g.stock - n
		g.last = 2
		NS.PlayKit("IG_BACKPACK_COIN_SELECT")
		Game:Changed()
		return true
	end
	return false
end

function M:getMaxBrokers()
	local r = Game:Bld("Grandma")
	return math.ceil(r.highest / 10 + r.level)
end

function M:getBrokerPrice()
	return Highest() * 60 * 20
end

function M:hireBroker()
	local st = self.state
	if st.brokers < self:getMaxBrokers() and Game.save.cookies >= self:getBrokerPrice() then
		Game:Spend(self:getBrokerPrice())
		st.brokers = st.brokers + 1
		Game:Changed()
		return true
	end
	return false
end

function M:upgradeOffice()
	local st = self.state
	local office = self.offices[st.officeLevel + 1]
	if office.cost and Game:Count("Cursor") >= office.cost[1] and Game:Level("Cursor") >= office.cost[2] then
		Game:Sacrifice(NS.B["Cursor"], office.cost[1])
		st.officeLevel = st.officeLevel + 1
		if st.officeLevel >= #self.offices - 1 then
			Game:Win("Pyramid scheme")
		end
		Game:Changed()
		return true
	end
	return false
end

function M:loanSlots()
	local st = self.state
	local slots = 0
	if st.officeLevel > 1 then slots = slots + 1 end
	if st.officeLevel > 3 then slots = slots + 1 end
	if st.officeLevel > 4 then slots = slots + 1 end
	return slots
end

function M:takeLoan(id, interest)
	local loan = self.loanTypes[id]
	if not loan then
		return false
	end
	if not interest then
		if Game:HasBuff("Loan " .. id) or Game:HasBuff("Loan " .. id .. " (interest)") then
			return false
		end
		Game:Spend(Game.save.cookies * loan[6])
		Game:GainBuff("loan " .. id, loan[3] * 60, loan[2])
		NS.PlayKit("LOOT_WINDOW_COIN_SOUND")
	else
		Game:GainBuff("loan " .. id .. " interest", loan[5] * 60, loan[4])
		NS.Notify("Loan over", "Your loan has expired, and you must now repay the interest.", {1,33})
	end
	Game:Changed()
	return true
end

function Game:OnBuffDie(buff)
	if buff.onDie == "loan1" then Game.takeLoan(1, true)
	elseif buff.onDie == "loan2" then Game.takeLoan(2, true)
	elseif buff.onDie == "loan3" then Game.takeLoan(3, true) end
end
Game.takeLoan = function(id, interest)
	return M:takeLoan(id, interest)
end

function M:resetGoods()
	local st = self.state
	for i = 1, #self.goods do
		local g = st.goods[i]
		g.stock = 0
		g.mode = Choose({ 0, 1, 1, 2, 2, 3, 4, 5 })
		g.dur = math.floor(10 + math.random() * 690)
		g.val = self:getRestingVal(i - 1)
		g.d = math.random() * 0.2 - 0.1
		g.vals = { g.val, g.val - g.d }
		g.hidden = true
		g.last = 0
		g.prev = 0
	end
	st.ticks = 0
	for _ = 1, 15 do
		self:tick()
	end
end

function M:reset(hard)
	local st = self.state
	if not st then
		return
	end
	st.tickT = 0
	st.officeLevel = 0
	st.brokers = 0
	st.profit = 0
	self:resetGoods()
end

function M:tick()
	local st = self.state
	local dragonBoost = Game:AuraMult("Supreme Intellect")
	local globD = 0
	local globP = math.random()
	if math.random() < 0.1 + 0.1 * dragonBoost then
		globD = (math.random() - 0.5) * 2
	end
	local bankLevel = Game:Level("Bank")
	for i = 1, #self.goods do
		local me = st.goods[i]
		me.last = 0
		me.d = me.d * (0.97 + 0.01 * dragonBoost)
		if me.mode == 0 then me.d = me.d * 0.95; me.d = me.d + 0.05 * (math.random() - 0.5)
		elseif me.mode == 1 then me.d = me.d * 0.99; me.d = me.d + 0.05 * (math.random() - 0.1)
		elseif me.mode == 2 then me.d = me.d * 0.99; me.d = me.d - 0.05 * (math.random() - 0.1)
		elseif me.mode == 3 then me.d = me.d + 0.15 * (math.random() - 0.1); me.val = me.val + math.random() * 5
		elseif me.mode == 4 then me.d = me.d - 0.15 * (math.random() - 0.1); me.val = me.val - math.random() * 5
		elseif me.mode == 5 then me.d = me.d + 0.3 * (math.random() - 0.5) end
		me.val = me.val + (self:getRestingVal(i - 1) - me.val) * 0.01
		if globD ~= 0 and math.random() < globP then
			me.val = me.val - (1 + me.d * (math.random() ^ 3) * 7) * globD
			me.val = me.val - globD * (1 + (math.random() ^ 3) * 7)
			me.d = me.d + globD * (1 + math.random() * 4)
			me.dur = 0
		end
		me.val = me.val + (((math.random() - 0.5) * 2) ^ 11) * 3
		me.d = me.d + 0.1 * (math.random() - 0.5)
		if math.random() < 0.15 then me.val = me.val + (math.random() - 0.5) * 3 end
		if math.random() < 0.03 then me.val = me.val + (math.random() - 0.5) * (10 + 10 * dragonBoost) end
		if math.random() < 0.1 then me.d = me.d + (math.random() - 0.5) * (0.3 + 0.2 * dragonBoost) end
		if me.mode == 5 then
			if math.random() < 0.5 then me.val = me.val + (math.random() - 0.5) * 10 end
			if math.random() < 0.2 then me.d = (math.random() - 0.5) * (2 + 6 * dragonBoost) end
		end
		if me.mode == 3 and math.random() < 0.3 then me.d = me.d + (math.random() - 0.5) * 0.1; me.val = me.val + (math.random() - 0.7) * 10 end
		if me.mode == 3 and math.random() < 0.03 then me.mode = 4 end
		if me.mode == 4 and math.random() < 0.3 then me.d = me.d + (math.random() - 0.5) * 0.1; me.val = me.val + (math.random() - 0.3) * 10 end
		if me.val > (100 + (bankLevel - 1) * 3) and me.d > 0 then me.d = me.d * 0.9 end
		me.val = me.val + me.d
		if me.val < 5 then me.val = me.val + (5 - me.val) * 0.5 end
		if me.val < 5 and me.d < 0 then me.d = me.d * 0.95 end
		me.val = math.max(me.val, 1)
		table.insert(me.vals, 1, me.val)
		if #me.vals > 65 then
			table.remove(me.vals)
		end
		me.dur = me.dur - 1
		if me.dur <= 0 then
			me.dur = math.floor(10 + math.random() * (690 - 200 * dragonBoost))
			if math.random() < dragonBoost and math.random() < 0.5 then me.mode = 5
			elseif math.random() < 0.7 and (me.mode == 3 or me.mode == 4) then me.mode = 5
			else me.mode = Choose({ 0, 1, 1, 2, 2, 3, 4, 5 }) end
		end
	end
	st.ticks = (st.ticks or 0) + 1
	self.dirty = true
end

function M:logic(dt)
	local st = self.state
	st.tickT = (st.tickT or 0) + dt
	if st.tickT >= 60 then
		st.tickT = 0
		self:tick()
	end
	self.activeAcc = (self.activeAcc or 0) + dt
	if self.activeAcc >= 1 then
		self.activeAcc = 0
		for i = 1, #self.goods do
			local g = st.goods[i]
			if g.hidden and self:isActive(i) and not g.seen then
				g.hidden = false
				g.seen = true
				self.dirty = true
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

local GRAPH_H = 110
local ROW_H = 19
local COLORS = {
	{ 0.9, 0.3, 0.3 }, { 0.3, 0.9, 0.4 }, { 0.4, 0.5, 1 }, { 1, 0.8, 0.2 }, { 0.9, 0.4, 0.9 }, { 0.3, 0.9, 0.9 },
	{ 1, 0.6, 0.2 }, { 0.6, 0.9, 0.3 }, { 0.5, 0.3, 1 }, { 1, 0.4, 0.6 }, { 0.3, 0.7, 0.6 }, { 0.9, 0.9, 0.9 },
	{ 0.8, 0.5, 0.3 }, { 0.4, 0.8, 1 }, { 0.7, 0.7, 0.2 }, { 0.9, 0.5, 0.8 }, { 0.5, 0.9, 0.7 }, { 1, 1, 0.6 },
}

function M:render(panel)
	local UI = NS.UI
	NS.Minigames:Decorate(panel, "BGmarket")
	panel.Title:SetText("Stock Market")
	local width = panel:GetWidth()
	if not width or width < 10 then
		width = UI.MID_W - 16
	end
	-- Office, brokers, loans.
	panel.Office = UI.FancyButton(panel, "", 150, 20, function()
		M:upgradeOffice()
		M:refresh(panel)
	end)
	panel.Office:SetPoint("TOPLEFT", 8, -28)
	UI.SetTooltip(panel.Office, function()
		local office = M.offices[M.state.officeLevel + 1]
		GameTooltip:SetText(office.name)
		GameTooltip:AddLine(office.desc, 1, 1, 1, true)
		if office.cost then
			local okN = Game:Count("Cursor") >= office.cost[1]
			local okL = Game:Level("Cursor") >= office.cost[2]
			GameTooltip:AddLine(string.format("Upgrading will cost you %d cursors.", office.cost[1]), okN and 0.4 or 1, okN and 1 or 0.4, 0.4)
			GameTooltip:AddLine(string.format("Upgrading requires level %d cursors.", office.cost[2]), okL and 0.4 or 1, okL and 1 or 0.4, 0.4)
		end
	end)
	panel.Brokers = UI.FancyButton(panel, "", 150, 20, function()
		M:hireBroker()
		M:refresh(panel)
	end)
	panel.Brokers:SetPoint("LEFT", panel.Office, "RIGHT", 6, 0)
	UI.SetTooltip(panel.Brokers, function()
		GameTooltip:SetText("Brokers")
		GameTooltip:AddLine("A nice broker to trade more cookies. Buying goods normally incurs overhead costs of 20% extra. Each broker you hire reduces that cost by 5%.", 1, 1, 1, true)
		GameTooltip:AddLine(string.format("Current overhead costs thanks to your brokers: +%.2f%%", 20 * (0.95 ^ M.state.brokers)), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(string.format("Maximum number of brokers you can own: %d (the highest amount of grandmas you've owned this run, divided by 10, plus your grandma level).", M:getMaxBrokers()), 0.8, 0.8, 0.8, true)
		local ok = Game.save.cookies >= M:getBrokerPrice()
		GameTooltip:AddLine("Hiring a new broker will cost you " .. NS.Beautify(M:getBrokerPrice()) .. " cookies (20 minutes of CpS).", ok and 0.4 or 1, ok and 1 or 0.4, 0.4, true)
	end)
	panel.Loans = {}
	for i = 1, 3 do
		local b = UI.FancyButton(panel, "Loan " .. i, 50, 18, function()
			if M:takeLoan(i) then
				M:refresh(panel)
			end
		end)
		b:SetPoint("TOPLEFT", 8 + (i - 1) * 54, -52)
		b.loan = i
		UI.SetTooltip(b, function(self)
			local loan = M.loanTypes[self.loan]
			GameTooltip:SetText("Take out " .. loan[1])
			GameTooltip:AddLine(string.format("By taking this loan, you will get +%d%% CpS for the next %s.", math.floor((loan[2] - 1) * 100 + 0.5), NS.FormatDuration(loan[3] * 60)), 0.4, 1, 0.4, true)
			GameTooltip:AddLine(string.format("However, you will get %d%% CpS for the next %s after that.", math.floor((loan[4] - 1) * 100 - 0.5), NS.FormatDuration(loan[5] * 60)), 1, 0.4, 0.4, true)
			GameTooltip:AddLine(string.format("You must also pay an immediate downpayment of %s (%d%% of your current bank).", NS.Beautify(Game.save.cookies * loan[6]), loan[6] * 100), 1, 1, 1, true)
			GameTooltip:AddLine(loan[7], 0.6, 0.6, 0.6, true)
		end)
		panel.Loans[i] = b
	end
	panel.Profit = UI.Text(panel, 11, "OUTLINE")
	panel.Profit:SetPoint("LEFT", panel.Loans[3], "RIGHT", 10, 0)
	panel.Refill = NS.Minigames:RefillButton(panel, "Click to give a quick burst to your economy (one market tick) for 1 sugar lump.", function()
		M:tick()
	end)
	panel.Refill:SetPoint("TOPRIGHT", -8, -26)
	-- Graph.
	local graph = CreateFrame("Frame", nil, panel)
	graph:SetSize(width - 16, GRAPH_H)
	graph:SetPoint("TOPLEFT", 8, -76)
	graph.Bg = UI.Solid(graph, "BACKGROUND", 0.12, 0.16, 0.21, 0.95)
	graph.Bg:SetAllPoints()
	graph.Lines = {}
	panel.Graph = graph
	-- Goods list.
	panel.Rows = {}
	for i = 1, #self.goods do
		local row = CreateFrame("Button", nil, panel)
		row:SetSize(width - 16, ROW_H)
		row:SetPoint("TOPLEFT", 8, -(80 + GRAPH_H + (i - 1) * ROW_H))
		row.index = i
		row.Bg = UI.Solid(row, "BACKGROUND", 0, 0, 0, 0.35)
		row.Bg:SetAllPoints()
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(16, 16)
		row.Icon:SetPoint("LEFT", 2, 0)
		NS.SetIcon(row.Icon, self.goods[i].icon)
		row.Swatch = UI.Solid(row, "ARTWORK", COLORS[i][1], COLORS[i][2], COLORS[i][3], 1)
		row.Swatch:SetSize(4, 14)
		row.Swatch:SetPoint("LEFT", 20, 0)
		row.Name = UI.Text(row, 11, "")
		row.Name:SetPoint("LEFT", 28, 0)
		row.Name:SetWidth(110)
		row.Name:SetWordWrap(false)
		row.Val = UI.Text(row, 11, "")
		row.Val:SetPoint("LEFT", 140, 0)
		row.Val:SetWidth(60)
		row.Delta = UI.Text(row, 10, "")
		row.Delta:SetPoint("LEFT", 200, 0)
		row.Delta:SetWidth(50)
		row.Stock = UI.Text(row, 11, "")
		row.Stock:SetPoint("RIGHT", -24, 0)
		row.Stock:SetJustifyH("RIGHT")
		row.Hide = CreateFrame("Button", nil, row)
		row.Hide:SetSize(16, 16)
		row.Hide:SetPoint("RIGHT", -2, 0)
		row.Hide.Icon = row.Hide:CreateTexture(nil, "ARTWORK")
		row.Hide.Icon:SetAllPoints()
		row.Hide:SetScript("OnClick", function(self)
			local g = M:good(self:GetParent().index)
			g.hidden = not g.hidden
			M.dirty = true
			M:refresh(panel)
		end)
		row:SetHighlightTexture(UI.WHITE)
		row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
		row:SetScript("OnClick", function(self)
			M.selected = self.index
			M:refresh(panel)
		end)
		UI.SetTooltip(row, function(self)
			local g = M.goods[self.index]
			local s = M:good(self.index)
			GameTooltip:SetText(g.company .. " (" .. g.symbol .. ")")
			GameTooltip:AddLine(g.name, 0.8, 0.8, 0.8)
			GameTooltip:AddLine(string.format("Value: $%.2f  (%s cookies)", s.val, NS.Beautify(Highest() * s.val)), 1, 1, 1)
			GameTooltip:AddLine(string.format("Stock: %d / %d", s.stock, M:getGoodMaxStock(self.index)), 1, 1, 1)
			if s.prev and s.prev > 0 and s.stock > 0 then
				GameTooltip:AddLine(string.format("Bought at $%.2f", s.prev), 0.8, 0.8, 0.8)
			end
			GameTooltip:AddLine("Click to select this good for trading. The eye hides it from the graph.", 0.6, 0.6, 0.6, true)
		end)
		panel.Rows[i] = row
	end
	-- Trade bar.
	local bar = CreateFrame("Frame", nil, panel)
	bar:SetSize(width - 16, 24)
	bar:SetPoint("TOPLEFT", 8, -(84 + GRAPH_H + #self.goods * ROW_H))
	bar.Label = UI.Text(bar, 11, "OUTLINE")
	bar.Label:SetPoint("LEFT")
	bar.Label:SetWidth(110)
	bar.Buttons = {}
	local x = 112
	for _, def in ipairs({ { "Buy 1", 1 }, { "10", 10 }, { "100", 100 }, { "Max", 10000 }, { "Sell 1", -1 }, { "10", -10 }, { "100", -100 }, { "All", -10000 } }) do
		local b = UI.FancyButton(bar, def[1], def[2] == 1 or def[2] == -1 and 40 or 32, 18, function()
			if not M.selected then
				return
			end
			if def[2] > 0 then
				M:buyGood(M.selected, def[2])
			else
				M:sellGood(M.selected, -def[2])
			end
			M:refresh(panel)
		end)
		local w = (def[1] == "Buy 1" or def[1] == "Sell 1") and 44 or 30
		b:SetWidth(w)
		b:SetPoint("LEFT", x, 0)
		x = x + w + 2
		table.insert(bar.Buttons, b)
	end
	panel.Trade = bar
	panel.Note:SetText("")
end

function M:drawGraph(panel)
	local UI = NS.UI
	local graph = panel.Graph
	local w, h = graph:GetWidth(), graph:GetHeight()
	if not w or w < 10 then
		return
	end
	local maxVal = 10
	for i = 1, #self.goods do
		local g = self:good(i)
		if not g.hidden and self:isActive(i) then
			for _, v in ipairs(g.vals) do
				if v > maxVal then maxVal = v end
			end
		end
	end
	local scale = (h - 4) / (maxVal + 10)
	local span = w / 64
	local li = 0
	for i = 1, #self.goods do
		local g = self:good(i)
		if not g.hidden and self:isActive(i) then
			local c = COLORS[i]
			for k = 1, math.min(64, #g.vals - 1) do
				li = li + 1
				local t = graph.Lines[li]
				if not t then
					t = graph:CreateTexture(nil, "ARTWORK")
					t:SetTexture(UI.WHITE)
					graph.Lines[li] = t
				end
				t:SetVertexColor(c[1], c[2], c[3], self.selected == i and 1 or 0.7)
				local x1 = w / 2 - (k - 1) * span
				local x2 = w / 2 - k * span
				local y1 = g.vals[k] * scale - h / 2
				local y2 = g.vals[k + 1] * scale - h / 2
				UI.DrawLine(t, graph, w / 2 - (k - 1) * span - w / 2 + (w - 2), y1, w / 2 - k * span - w / 2 + (w - 2), y2, self.selected == i and 2 or 1)
			end
		end
	end
	for i = li + 1, #graph.Lines do
		graph.Lines[i]:Hide()
	end
end

function M:refresh(panel)
	local st = self.state
	local office = self.offices[st.officeLevel + 1]
	panel.Office:SetText(office.name .. (office.cost and " (upgrade)" or ""))
	panel.Office:SetEnabledLook(office.cost ~= nil and Game:Count("Cursor") >= office.cost[1] and Game:Level("Cursor") >= office.cost[2])
	panel.Brokers:SetText(string.format("Brokers: %d/%d", st.brokers, self:getMaxBrokers()))
	panel.Brokers:SetEnabledLook(st.brokers < self:getMaxBrokers() and Game.save.cookies >= self:getBrokerPrice())
	local slots = self:loanSlots()
	for i, b in ipairs(panel.Loans) do
		b:SetShown(i <= slots)
		b:SetEnabledLook(not Game:HasBuff("Loan " .. i) and not Game:HasBuff("Loan " .. i .. " (interest)"))
	end
	panel.Profit:SetText(string.format("Profits: $%s", NS.Beautify(math.floor(st.profit))))
	panel.Profit:SetTextColor(st.profit >= 0 and 0.4 or 1, st.profit >= 0 and 1 or 0.4, 0.4)
	for i, row in ipairs(panel.Rows) do
		local g = self.goods[i]
		local s = self:good(i)
		if self:isActive(i) then
			row:SetAlpha(1)
			row.Name:SetText(g.symbol .. " " .. g.name)
			row.Val:SetText(string.format("$%.2f", s.val))
			local delta = self:goodDelta(i)
			row.Delta:SetText(string.format("%s%.2f%%", delta >= 0 and "+" or "", delta))
			row.Delta:SetTextColor(delta >= 0 and 0.4 or 1, delta >= 0 and 1 or 0.4, 0.4)
			row.Stock:SetText(string.format("%d/%d", s.stock, self:getGoodMaxStock(i)))
			NS.SetIcon(row.Hide.Icon, s.hidden and { 1, 7 } or { 0, 7 })
			row.Hide.Icon:SetAlpha(s.hidden and 0.4 or 1)
			row.Bg:SetVertexColor(self.selected == i and 0.3 or 0, self.selected == i and 0.3 or 0, self.selected == i and 0.2 or 0, 0.5)
			row:Show()
		else
			row:Hide()
		end
	end
	if self.selected and self:isActive(self.selected) then
		panel.Trade.Label:SetText(self.goods[self.selected].symbol .. " trading")
		for _, b in ipairs(panel.Trade.Buttons) do
			b:Show()
		end
	else
		panel.Trade.Label:SetText("Select a good to trade")
		for _, b in ipairs(panel.Trade.Buttons) do
			b:Hide()
		end
	end
	if self.dirty or not panel.drawn then
		self.dirty = false
		panel.drawn = true
		self:drawGraph(panel)
	end
end

NS.Minigames:Register(M)
