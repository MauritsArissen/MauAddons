-- MauCookie Pantheon (Temple level 1), ported from minigamePantheon.js:
-- eleven spirits, three slots (diamond, ruby, jade) with weaker effects
-- the lower the slot, three worship swaps that come back over time.  The
-- rules read the slots through Game:HasGod.

local _, NS = ...

local Game = NS.Game

local P = { building = "Temple", name = "Pantheon", height = 300 }

P.gods = {
	{ key = "asceticism", name = "Holobore, Spirit of Asceticism", icon = {21,18},
		desc = { "+15% base CpS.", "+10% base CpS.", "+5% base CpS." },
		after = "If a golden cookie is clicked, this spirit is unslotted and all worship swaps will be used up.",
		quote = "An immortal life spent focusing on the inner self, away from the distractions of material wealth." },
	{ key = "decadence", name = "Vomitrax, Spirit of Decadence", icon = {22,18},
		desc = { "Golden and wrath cookie effect duration +7%. Buildings grant -7% CpS.", "Golden and wrath cookie effect duration +5%. Buildings grant -5% CpS.", "Golden and wrath cookie effect duration +2%. Buildings grant -2% CpS." },
		quote = "This sleazy spirit revels in the lust for quick easy gain and contempt for the value of steady work." },
	{ key = "ruin", name = "Godzamok, Spirit of Ruin", icon = {23,18},
		before = "Selling buildings triggers a buff boosted by how many buildings were sold.",
		desc = { "Buff boosts clicks by +1% for every building sold for 10 seconds.", "Buff boosts clicks by +0.5% for every building sold for 10 seconds.", "Buff boosts clicks by +0.25% for every building sold for 10 seconds." },
		quote = "The embodiment of natural disasters. An impenetrable motive drives the devastation caused by this spirit." },
	{ key = "ages", name = "Cyclius, Spirit of Ages", icon = {24,18},
		before = "CpS bonus fluctuating between +15% and -15% over time.",
		desc = { "Effect cycles over 3 hours.", "Effect cycles over 12 hours.", "Effect cycles over 24 hours." },
		quote = "This spirit knows about everything you'll ever do, and enjoys dispensing a harsh judgment." },
	{ key = "seasons", name = "Selebrak, Spirit of Festivities", icon = {25,18},
		before = "Some seasonal effects are boosted.",
		desc = { "Large boost. Switching seasons is 100% pricier.", "Medium boost. Switching seasons is 50% pricier.", "Small boost. Switching seasons is 25% pricier." },
		quote = "This is the spirit of merry getaways and regretful Monday mornings." },
	{ key = "creation", name = "Dotjeiess, Spirit of Creation", icon = {26,18},
		desc = { "All buildings are 7% cheaper. Heavenly chips have 30% less effect.", "All buildings are 5% cheaper. Heavenly chips have 20% less effect.", "All buildings are 2% cheaper. Heavenly chips have 10% less effect." },
		quote = "All things that be and ever will be were scripted long ago by this spirit's inscrutable tendrils." },
	{ key = "labor", name = "Muridal, Spirit of Labor", icon = {27,18},
		desc = { "Clicking is 15% more powerful. Buildings produce 3% less.", "Clicking is 10% more powerful. Buildings produce 2% less.", "Clicking is 5% more powerful. Buildings produce 1% less." },
		quote = "This spirit enjoys a good cheese after a day of hard work." },
	{ key = "industry", name = "Jeremy, Spirit of Industry", icon = {28,18},
		desc = { "Buildings produce 10% more. Golden and wrath cookies appear 10% less.", "Buildings produce 6% more. Golden and wrath cookies appear 6% less.", "Buildings produce 3% more. Golden and wrath cookies appear 3% less." },
		quote = "While this spirit has many regrets, helping you rule the world through constant industrialization is not one of them." },
	{ key = "mother", name = "Mokalsium, Mother Spirit", icon = {29,18},
		desc = { "Milk is 10% more powerful. Golden and wrath cookies appear 15% less.", "Milk is 5% more powerful. Golden and wrath cookies appear 10% less.", "Milk is 3% more powerful. Golden and wrath cookies appear 5% less." },
		quote = "A caring spirit said to contain itself, inwards infinitely." },
	{ key = "scorn", name = "Skruuia, Spirit of Scorn", icon = {21,19},
		before = "All golden cookies are wrath cookies with a greater chance of a negative effect.",
		desc = { "Wrinklers appear 150% faster and digest 15% more cookies.", "Wrinklers appear 100% faster and digest 10% more cookies.", "Wrinklers appear 50% faster and digest 5% more cookies." },
		quote = "This spirit enjoys poking foul beasts and watching them squirm, but has no love for its own family." },
	{ key = "order", name = "Rigidel, Spirit of Order", icon = {22,19},
		desc = { "Sugar lumps ripen 1 hour sooner.", "Sugar lumps ripen 40 minutes sooner.", "Sugar lumps ripen 20 minutes sooner." },
		after = "Effect is only active when your total amount of buildings ends with 0.",
		quote = "You will find that life gets just a little bit sweeter if you can motivate this spirit with tidy numbers and properly-filled tax returns." },
}
P.byKey = {}
for i, g in ipairs(P.gods) do
	g.id = i
	P.byKey[g.key] = g
end
P.slotNames = { "Diamond", "Ruby", "Jade" }
P.slotGems = { {23,15}, {24,15}, {23,16} }

function P:load(fresh)
	local st = self.state
	if fresh or not st.slot then
		st.slot = { 0, 0, 0 }
		st.swaps = 3
		st.swapT = 0
	end
	Game.hasGodFunc = function(key)
		return P:hasGod(key)
	end
	Game.forceUnslotGod = function(key)
		return P:forceUnslot(key)
	end
	Game.useSwap = function(n)
		P:useSwap(n)
	end
end

-- Slot level 1..3 of a god, 0 when unslotted (Supreme Intellect: jade acts as ruby, ruby as diamond).
function P:hasGod(key)
	local god = self.byKey[key]
	if not god or not self.state then
		return 0
	end
	for i = 1, 3 do
		if self.state.slot[i] == god.id then
			if Game:HasAura("Supreme Intellect") then
				return math.max(1, i - 1)
			end
			return i
		end
	end
	return 0
end

function P:godSlot(god)
	if not self.state then
		return 0
	end
	for i = 1, 3 do
		if self.state.slot[i] == god.id then
			return i
		end
	end
	return 0
end

function P:useSwap(n)
	local st = self.state
	if not st then
		return
	end
	st.swapT = Game.save.runTime or 0
	st.swaps = math.max(0, (st.swaps or 0) - n)
end

-- Put a god in a slot (0 = unslot), swapping with whoever was there.
function P:slotGod(god, slot)
	local st = self.state
	if not st then
		return false
	end
	local current = self:godSlot(god)
	if slot == current then
		return false
	end
	if slot ~= 0 and st.slot[slot] ~= 0 then
		local other = st.slot[slot]
		if current ~= 0 then
			st.slot[current] = other
		end
	elseif current ~= 0 then
		st.slot[current] = 0
	end
	if slot ~= 0 then
		st.slot[slot] = god.id
	end
	Game.recalc = true
	Game:Changed()
	return true
end

function P:forceUnslot(key)
	local god = self.byKey[key]
	if not god or self:godSlot(god) == 0 then
		return false
	end
	self:slotGod(god, 0)
	return true
end

-- Seconds until the next swap comes back (bakery time).
function P:swapWait()
	local st = self.state
	if not st then
		return 60 * 60
	end
	local t = 60 * 60
	if st.swaps == 0 then t = 60 * 60 * 16 elseif st.swaps == 1 then t = 60 * 60 * 4 end
	return t
end

function P:logic(dt)
	local st = self.state
	if (st.swaps or 3) < 3 then
		local elapsed = (Game.save.runTime or 0) - (st.swapT or 0)
		if elapsed >= self:swapWait() then
			st.swaps = st.swaps + 1
			st.swapT = Game.save.runTime or 0
		end
	end
end

function P:reset(hard)
	local st = self.state
	if st then
		st.swaps = 3
		st.swapT = 0
		st.slot = { 0, 0, 0 }
	end
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

function P:render(panel)
	local UI = NS.UI
	NS.Minigames:Decorate(panel, "BGpantheon")
	panel.Title:SetText("Pantheon")
	panel.Slots = {}
	for i = 1, 3 do
		local c = NS.Minigames:Crate(panel, 48)
		c.slot = i
		c:SetPoint("TOP", panel, "TOP", (i - 2) * 72, -36)
		c.Gem = c:CreateTexture(nil, "OVERLAY")
		c.Gem:SetSize(20, 20)
		c.Gem:SetPoint("BOTTOMLEFT", -4, -4)
		NS.SetIcon(c.Gem, self.slotGems[i])
		c.Label:SetText(self.slotNames[i])
		c:SetScript("OnClick", function(self)
			local id = P.state and P.state.slot[self.slot] or 0
			if id ~= 0 then
				P:askSlot(P.gods[id])
			end
		end)
		UI.SetTooltip(c, function(self)
			local id = P.state and P.state.slot[self.slot] or 0
			GameTooltip:SetText(P.slotNames[self.slot] .. " slot")
			if id ~= 0 then
				P:godTooltipLines(P.gods[id], self.slot)
			else
				GameTooltip:AddLine("Click a spirit below to assign it to a slot.", 1, 1, 1, true)
			end
		end)
		panel.Slots[i] = c
	end
	panel.Swaps = UI.Text(panel, 11, "OUTLINE")
	panel.Swaps:SetPoint("TOP", 0, -112)
	panel.Swaps:SetJustifyH("CENTER")
	panel.Refill = NS.Minigames:RefillButton(panel, "Click to refill all your worship swaps for 1 sugar lump.", function()
		if P.state then
			P.state.swaps = 3
			P.state.swapT = Game.save.runTime or 0
		end
	end)
	panel.Refill:SetPoint("TOPRIGHT", -8, -28)
	panel.Gods = {}
	local per = 6
	for i, god in ipairs(self.gods) do
		local c = NS.Minigames:Crate(panel, 40)
		c.god = god
		NS.SetIcon(c.Icon, god.icon)
		c.Label:SetText("")
		local col, row = (i - 1) % per, math.floor((i - 1) / per)
		c:SetPoint("TOPLEFT", panel, "TOP", -per * 56 / 2 + col * 56 + 8, -(136 + row * 66))
		c:SetScript("OnClick", function(self)
			P:askSlot(self.god)
		end)
		UI.SetTooltip(c, function(self)
			GameTooltip:SetText(self.god.name)
			P:godTooltipLines(self.god, P:godSlot(self.god))
		end)
		panel.Gods[i] = c
	end
	panel.Info = UI.Text(panel, 10, "")
	panel.Info:SetPoint("BOTTOM", 0, 6)
	panel.Info:SetJustifyH("CENTER")
	panel.Info:SetTextColor(0.7, 0.7, 0.7)
	panel.Info:SetText("Click a spirit to slot it. The diamond slot gives the strongest effect.")
end

function P:godTooltipLines(god, slot)
	if god.before then
		GameTooltip:AddLine(god.before, 1, 1, 1, true)
	end
	for i = 1, 3 do
		local active = slot == i
		GameTooltip:AddLine(NS.IconString(self.slotGems[i], 14) .. " " .. god.desc[i], active and 1 or 0.6, active and 1 or 0.6, active and 0.6 or 0.6, true)
	end
	if god.after then
		GameTooltip:AddLine(god.after, 1, 0.4, 0.4, true)
	end
	if god.key == "ages" and slot > 0 then
		local lvl = self:hasGod("ages")
		local period = lvl == 1 and 3 or lvl == 2 and 12 or 24
		local mult = 0.15 * math.sin((time() / (60 * 60 * period)) * math.pi * 2)
		GameTooltip:AddLine(string.format("Current bonus: %s%.2f%%", mult < 0 and "-" or "+", math.abs(mult) * 100), 0.6, 0.9, 1)
	elseif god.key == "order" and slot > 0 then
		local n = Game:BuildingsOwned()
		GameTooltip:AddLine(string.format("Buildings owned: %s. Effect is %s.", NS.Commas(n), n % 10 == 0 and "active" or "inactive"), 0.6, 0.9, 1)
	end
	GameTooltip:AddLine(god.quote, 0.6, 0.6, 0.6, true)
end

function P:askSlot(god)
	local st = self.state
	if not st then
		return
	end
	local current = self:godSlot(god)
	local chosen = nil
	local grid = {}
	for i = 1, 3 do
		if i ~= current then
			table.insert(grid, { icon = self.slotGems[i], name = self.slotNames[i] .. " slot", onPick = function()
				chosen = i
			end })
		end
	end
	local buttons = {
		{ "Slot", function()
			if not chosen then
				return
			end
			if (st.swaps or 0) <= 0 then
				NS.Notify("Pantheon", "No worship swaps left.", {23,18}, true)
				return
			end
			P:useSwap(1)
			P:slotGod(god, chosen)
			NS.Minigames:Refresh()
		end },
	}
	if current ~= 0 then
		table.insert(buttons, { "Unslot", function()
			P:slotGod(god, 0)
			NS.Minigames:Refresh()
		end })
	end
	table.insert(buttons, { "Cancel" })
	NS.UI:Prompt(god.name, string.format("Pick a slot for this spirit, then press Slot. Slotting uses one worship swap (%d left); unslotting is free.", st.swaps or 0), buttons, grid)
end

function P:refresh(panel)
	local st = self.state
	if not st or not panel.Slots then
		return
	end
	for i, c in ipairs(panel.Slots) do
		local id = st.slot[i]
		if id ~= 0 then
			NS.SetIcon(c.Icon, self.gods[id].icon)
			c.Icon:Show()
		else
			c.Icon:Hide()
		end
	end
	for _, c in ipairs(panel.Gods) do
		local slotted = self:godSlot(c.god) ~= 0
		c:SetAlpha(slotted and 0.35 or 1)
	end
	local wait = ""
	if (st.swaps or 3) < 3 then
		local left = self:swapWait() - ((Game.save.runTime or 0) - (st.swapT or 0))
		wait = " (next in " .. NS.FormatDuration(math.max(0, left)) .. ")"
	end
	panel.Swaps:SetText(string.format("Worship swaps: %d/3%s", st.swaps or 0, wait))
end

NS.Minigames:Register(P)
