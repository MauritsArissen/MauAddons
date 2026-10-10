-- MauCookie Grimoire (Wizard tower level 1), ported from minigameGrimoire.js:
-- a magic meter that refills slowly, nine spells with costs in magic and a
-- 15% chance to backfire.

local _, NS = ...

local Game = NS.Game
local Choose = NS.Choose

local G = { building = "Wizard tower", name = "Grimoire", height = 230 }

G.spells = {
	{ key = "conjure baked goods", name = "Conjure Baked Goods", icon = {21,11}, costMin = 2, costPercent = 0.4,
		desc = "Summon half an hour worth of your CpS, capped at 15% of your cookies owned.", failDesc = "Trigger a 15-minute clot and lose 15 minutes of CpS." },
	{ key = "hand of fate", name = "Force the Hand of Fate", icon = {22,11}, costMin = 10, costPercent = 0.6,
		desc = "Summon a random golden cookie. Each existing golden cookie makes this spell +15% more likely to backfire.", failDesc = "Summon an unlucky wrath cookie." },
	{ key = "stretch time", name = "Stretch Time", icon = {23,11}, costMin = 8, costPercent = 0.2,
		desc = "All active buffs gain 10% more time (up to 5 more minutes).", failDesc = "All active buffs are shortened by 20% (up to 10 minutes shorter)." },
	{ key = "spontaneous edifice", name = "Spontaneous Edifice", icon = {24,11}, costMin = 20, costPercent = 0.75,
		desc = "The spell picks a random building you could afford if you had twice your current cookies, and gives it to you for free. The building selected must be under 400, and cannot be your most-built one (unless it is your only one).", failDesc = "Lose a random building." },
	{ key = "haggler's charm", name = "Haggler's Charm", icon = {25,11}, costMin = 10, costPercent = 0.1,
		desc = "Upgrades are 2% cheaper for 1 minute.", failDesc = "Upgrades are 2% more expensive for an hour." },
	{ key = "summon crafty pixies", name = "Summon Crafty Pixies", icon = {26,11}, costMin = 10, costPercent = 0.2,
		desc = "Buildings are 2% cheaper for 1 minute.", failDesc = "Buildings are 2% more expensive for an hour." },
	{ key = "gambler's fever dream", name = "Gambler's Fever Dream", icon = {27,11}, costMin = 3, costPercent = 0.05,
		desc = "Cast a random spell at half the magic cost, with twice the chance of backfiring." },
	{ key = "resurrect abomination", name = "Resurrect Abomination", icon = {28,11}, costMin = 20, costPercent = 0.1,
		desc = "Instantly summon a wrinkler if conditions are fulfilled.", failDesc = "Pop one of your wrinklers." },
	{ key = "diminish ineptitude", name = "Diminish Ineptitude", icon = {29,11}, costMin = 5, costPercent = 0.2,
		desc = "Spells backfire 10 times less for the next 5 minutes.", failDesc = "Spells backfire 5 times more for the next 10 minutes." },
}
G.byKey = {}
for i, s in ipairs(G.spells) do
	s.id = i
	G.byKey[s.key] = s
end

local function Say(text)
	NS.Notify("Grimoire", text, {28,12}, true)
end

function G:load(fresh)
	local st = self.state
	self:computeMagicM()
	if fresh or st.magic == nil then
		st.magic = self.magicM
		st.spellsCast = 0
		st.spellsCastTotal = 0
	end
	st.magic = math.min(st.magic, self.magicM)
end

function G:computeMagicM()
	local towers = math.max(Game:Count("Wizard tower"), 1)
	local lvl = math.max(Game:Level("Wizard tower"), 1)
	self.magicM = math.floor(4 + towers ^ 0.6 + math.log((towers + (lvl - 1) * 10) / 15 + 1) * 15)
	if self.state then
		self.state.magic = math.min(self.magicM, self.state.magic or self.magicM)
	end
end

function G:getFailChance(spell)
	local failChance = 0.15
	if Game:HasBuff("Magic adept") then failChance = failChance * 0.1 end
	if Game:HasBuff("Magic inept") then failChance = failChance * 5 end
	failChance = failChance * (1 + 0.1 * Game:AuraMult("Supreme Intellect"))
	if spell.key == "hand of fate" then
		failChance = failChance + 0.15 * Game:GoldenOnScreen()
	end
	return failChance
end

function G:getSpellCost(spell)
	local out = spell.costMin
	if spell.costPercent then
		out = out + self.magicM * spell.costPercent
	end
	out = out * (1 - 0.1 * Game:AuraMult("Supreme Intellect"))
	return math.floor(out)
end

-- Returns -1 when the spell had nothing to do (magic refunded), true on success.
local EFFECTS = {}

EFFECTS["conjure baked goods"] = {
	win = function()
		local S = Game.save
		local val = math.max(7, math.min(S.cookies * 0.15, (Game.cps or 0) * 60 * 30))
		Game:Earn(val)
		NS.Notify("Conjure Baked Goods!", "You magic " .. NS.Beautify(val) .. " cookies out of thin air.", {21,11}, true)
	end,
	fail = function()
		local S = Game.save
		local buff = Game:GainBuff("clot", 60 * 15, 0.5)
		local val = math.min(S.cookies * 0.15, (Game.cps or 0) * 60 * 15) + 13
		val = math.min(S.cookies, val)
		Game:Spend(val)
		NS.Notify(buff.name, "Backfire! Summoning failed! Lost " .. NS.Beautify(val) .. " cookies!", buff.icon, true)
	end,
}

EFFECTS["hand of fate"] = {
	win = function()
		local me = Game:SpawnShimmer("golden", { noWrath = true })
		local choices = { "frenzy", "multiply cookies" }
		if not Game:HasBuff("Dragonflight") then table.insert(choices, "click frenzy") end
		if math.random() < 0.1 then table.insert(choices, "cookie storm") table.insert(choices, "cookie storm") table.insert(choices, "blab") end
		if Game:BuildingsOwned() >= 10 and math.random() < 0.25 then table.insert(choices, "building special") end
		if math.random() < 0.15 then choices = { "cookie storm drop" } end
		if math.random() < 0.0001 then table.insert(choices, "free sugar lump") end
		me.force = Choose(choices)
		if me.force == "cookie storm drop" then
			me.sizeMult = math.random() * 0.75 + 0.25
		end
		Say("Promising fate!")
	end,
	fail = function()
		local me = Game:SpawnShimmer("golden", { wrath = true })
		local choices = { "clot", "ruin cookies" }
		if math.random() < 0.1 then table.insert(choices, "cursed finger") table.insert(choices, "blood frenzy") end
		if math.random() < 0.003 then table.insert(choices, "free sugar lump") end
		if math.random() < 0.1 then choices = { "blab" } end
		me.force = Choose(choices)
		Say("Backfire! Sinister fate!")
	end,
}

EFFECTS["stretch time"] = {
	win = function()
		local changed = 0
		for _, buff in ipairs(Game:Buffs()) do
			local gain = math.min(60 * 5, buff.maxTime * 0.1)
			buff.maxTime = buff.maxTime + gain
			buff.time = buff.time + gain
			changed = changed + 1
		end
		if changed == 0 then
			Say("No buffs to alter!")
			return -1
		end
		Say("Zap! Buffs lengthened.")
	end,
	fail = function()
		local changed = 0
		for _, buff in ipairs(Game:Buffs()) do
			local loss = math.min(60 * 10, buff.time * 0.2)
			buff.time = math.max(0, buff.time - loss)
			changed = changed + 1
		end
		if changed == 0 then
			Say("No buffs to alter!")
			return -1
		end
		Say("Backfire! Fizz! Buffs shortened.")
	end,
}

EFFECTS["spontaneous edifice"] = {
	win = function()
		local S = Game.save
		local max, n = 0, 0
		for _, b in ipairs(NS.BUILDINGS) do
			local c = Game:Count(b.name)
			if c > max then max = c end
			if c > 0 then n = n + 1 end
		end
		local list = {}
		for _, b in ipairs(NS.BUILDINGS) do
			local c = Game:Count(b.name)
			if (c < max or n == 1) and Game:BuildingPrice(b) <= S.cookies * 2 and c < 400 then
				table.insert(list, b)
			end
		end
		if #list == 0 then
			Say("No buildings to improve!")
			return -1
		end
		local b = Choose(list)
		local r = Game:Bld(b.name)
		r.n = r.n + 1
		r.bought = r.bought + 1
		r.highest = math.max(r.highest, r.n)
		Game.recalc = true
		Game:OnBuildingBought(b)
		Say("A new " .. b.single .. " bursts out of the ground.")
	end,
	fail = function()
		if Game:BuildingsOwned() == 0 then
			Say("Backfired, but no buildings to destroy!")
			return -1
		end
		local list = {}
		for _, b in ipairs(NS.BUILDINGS) do
			if Game:Count(b.name) > 0 then table.insert(list, b) end
		end
		local b = Choose(list)
		Game:Sacrifice(b, 1)
		Say("Backfire! One of your " .. b.plural .. " disappears in a puff of smoke.")
	end,
}

EFFECTS["haggler's charm"] = {
	win = function()
		Game:KillBuff("Haggler's misery")
		Game:GainBuff("haggler luck", 60, 2)
		Say("Upgrades are cheaper!")
	end,
	fail = function()
		Game:KillBuff("Haggler's luck")
		Game:GainBuff("haggler misery", 60 * 60, 2)
		Say("Backfire! Upgrades are pricier!")
	end,
}

EFFECTS["summon crafty pixies"] = {
	win = function()
		Game:KillBuff("Nasty goblins")
		Game:GainBuff("pixie luck", 60, 2)
		Say("Crafty pixies! Buildings are cheaper!")
	end,
	fail = function()
		Game:KillBuff("Crafty pixies")
		Game:GainBuff("pixie misery", 60 * 60, 2)
		Say("Backfire! Nasty goblins! Buildings are pricier!")
	end,
}

EFFECTS["gambler's fever dream"] = {
	win = function()
		local st = G.state
		local selfCost = G:getSpellCost(G.byKey["gambler's fever dream"])
		local spells = {}
		for _, s in ipairs(G.spells) do
			if s.key ~= "gambler's fever dream" and (st.magic - selfCost) >= G:getSpellCost(s) * 0.5 then
				table.insert(spells, s)
			end
		end
		if #spells == 0 then
			Say("No eligible spells!")
			return -1
		end
		local spell = Choose(spells)
		local cost = G:getSpellCost(spell) * 0.5
		Say("Casting " .. spell.name .. " for " .. NS.Beautify(cost) .. " magic...")
		-- The original casts a second later; here right away, after paying for the dream.
		st.magic = st.magic - selfCost
		local out = G:castSpell(spell, { cost = cost, failChanceMax = 0.5, passthrough = true })
		if not out then
			st.magic = st.magic + selfCost
			Say("That's too bad! Magic refunded.")
		end
		return -1
	end,
}

EFFECTS["resurrect abomination"] = {
	win = function()
		local out = Game:SpawnWrinkler()
		if not out then
			Say("Unable to spawn a wrinkler!")
			return -1
		end
		Say("Rise, my precious!")
	end,
	fail = function()
		local out = Game:PopRandomWrinkler()
		if not out then
			Say("Backfire! But no wrinkler was harmed.")
			return -1
		end
		Say("Backfire! So long, ugly...")
	end,
}

EFFECTS["diminish ineptitude"] = {
	win = function()
		Game:KillBuff("Magic inept")
		Game:GainBuff("magic adept", 5 * 60, 10)
		Say("Ineptitude diminished!")
	end,
	fail = function()
		Game:KillBuff("Magic adept")
		Game:GainBuff("magic inept", 10 * 60, 5)
		Say("Backfire! Ineptitude magnified!")
	end,
}

function G:castSpell(spell, obj)
	obj = obj or {}
	local st = self.state
	local cost = obj.cost or self:getSpellCost(spell)
	if st.magic < cost then
		return false
	end
	local failChance = self:getFailChance(spell)
	if obj.failChanceMax then
		failChance = math.max(failChance, obj.failChanceMax)
	end
	local effects = EFFECTS[spell.key]
	local out, fail
	if not effects.fail or math.random() < (1 - failChance) then
		out = effects.win()
	else
		fail = true
		out = effects.fail()
	end
	if out ~= -1 then
		if not obj.passthrough then
			st.spellsCast = (st.spellsCast or 0) + 1
			st.spellsCastTotal = (st.spellsCastTotal or 0) + 1
			if st.spellsCastTotal >= 9 then Game:Win("Bibbidi-bobbidi-boo") end
			if st.spellsCastTotal >= 99 then Game:Win("I'm the wiz") end
			if st.spellsCastTotal >= 999 then Game:Win("A wizard is you") end
		end
		st.magic = math.max(0, st.magic - cost)
		NS.PlayKit(fail and "IG_MAINMENU_OPTION_CHECKBOX_OFF" or "UI_EPICLOOT_TOAST")
		Game:Changed()
		return true
	end
	return false
end

function G:reset(hard)
	self:computeMagicM()
	if self.state then
		self.state.magic = self.magicM
		self.state.spellsCast = 0
		if hard then
			self.state.spellsCastTotal = 0
		end
	end
end

function G:logic(dt)
	local st = self.state
	self.acc = (self.acc or 0) + dt
	if self.acc >= 5 then
		self.acc = 0
		self:computeMagicM()
	end
	local magicPS = math.max(0.002, (st.magic / math.max(self.magicM, 100)) ^ 0.5) * 0.002 * 30
	st.magic = math.min(st.magic + magicPS * dt, self.magicM)
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

function G:render(panel)
	local UI = NS.UI
	NS.Minigames:Decorate(panel, "BGgrimoire")
	panel.Title:SetText("Grimoire")
	panel.Bar = CreateFrame("Frame", nil, panel)
	panel.Bar:SetSize(300, 16)
	panel.Bar:SetPoint("TOP", 0, -30)
	panel.Bar.Bg = UI.Solid(panel.Bar, "BACKGROUND", 0, 0, 0, 0.6)
	panel.Bar.Bg:SetAllPoints()
	panel.Bar.Fill = UI.Solid(panel.Bar, "ARTWORK", 0.4, 0.6, 1, 0.9)
	panel.Bar.Fill:SetPoint("TOPLEFT")
	panel.Bar.Fill:SetPoint("BOTTOMLEFT")
	panel.Bar.Fill:SetWidth(1)
	panel.Bar.Text = UI.Text(panel.Bar, 11, "OUTLINE")
	panel.Bar.Text:SetPoint("CENTER")
	panel.Bar.Text:SetJustifyH("CENTER")
	panel.Refill = NS.Minigames:RefillButton(panel, "Click to refill 100 units of your magic meter for 1 sugar lump.", function()
		G.state.magic = math.min(G.state.magic + 100, G.magicM)
	end)
	panel.Refill:SetPoint("LEFT", panel.Bar, "RIGHT", 4, 0)
	panel.Spells = {}
	local per = 5
	for i, spell in ipairs(self.spells) do
		local c = NS.Minigames:Crate(panel, 48)
		c.spell = spell
		NS.SetIcon(c.Icon, spell.icon)
		local col, row = (i - 1) % per, math.floor((i - 1) / per)
		c:SetPoint("TOPLEFT", panel, "TOP", -per * 64 / 2 + col * 64 + 8, -(60 + row * 82))
		c:SetScript("OnClick", function(self)
			if G:castSpell(self.spell) then
				G:refresh(panel)
			end
		end)
		UI.SetTooltip(c, function(self)
			local s = self.spell
			local cost = G:getSpellCost(s)
			GameTooltip:SetText(s.name)
			GameTooltip:AddLine(string.format("Magic cost: %s  (%d magic +%d%% of max magic)", NS.Beautify(cost), s.costMin, math.ceil((s.costPercent or 0) * 100)), cost <= G.state.magic and 0.4 or 1, cost <= G.state.magic and 1 or 0.4, 0.4)
			if s.failDesc then
				GameTooltip:AddLine(string.format("Chance to backfire: %d%%", math.ceil(100 * G:getFailChance(s))), 1, 0.4, 0.4)
			end
			GameTooltip:AddLine("Effect: " .. s.desc, 0.4, 1, 0.4, true)
			if s.failDesc then
				GameTooltip:AddLine("Backfire: " .. s.failDesc, 1, 0.4, 0.4, true)
			end
		end)
		panel.Spells[i] = c
	end
	panel.Info = UI.Text(panel, 11, "")
	panel.Info:SetPoint("BOTTOM", 0, 8)
	panel.Info:SetJustifyH("CENTER")
	panel.Info:SetTextColor(0.75, 0.75, 0.75)
end

function G:refresh(panel)
	local st = self.state
	local frac = self.magicM > 0 and st.magic / self.magicM or 0
	panel.Bar.Fill:SetWidth(math.max(1, 300 * frac))
	panel.Bar.Text:SetText(string.format("%s/%s", NS.Beautify(math.floor(st.magic)), NS.Beautify(self.magicM)))
	for _, c in ipairs(panel.Spells) do
		local cost = self:getSpellCost(c.spell)
		c.Label:SetText(NS.Beautify(cost))
		local ok = st.magic >= cost
		c.Label:SetTextColor(ok and 1 or 1, ok and 1 or 0.3, ok and 1 or 0.3)
		c:SetAlpha(ok and 1 or 0.7)
	end
	panel.Info:SetText(string.format("Spells cast: %s (total: %s)", NS.Commas(st.spellsCast or 0), NS.Commas(st.spellsCastTotal or 0)))
end

NS.Minigames:Register(G)
