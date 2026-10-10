-- MauCookie store column (the original's #sectionRight): section headers
-- on the panel strip, 48 px upgrade crates in 60 px frames (Upgrades,
-- Switches, Research, Vault), the bulk buttons and the 300 x 64 building
-- products on the store tile.  Everything scrolls.

local _, NS = ...

local UI = NS.UI
local W, TOP, RIGHT_W, CONTENT_H = UI.W, UI.TOP, UI.RIGHT_W, UI.CONTENT_H
local FONT, WHITE = UI.FONT, UI.WHITE
local STORE_W = 300
local CRATE, FRAME, PER_ROW = 48, 60, 5
local SECTION_H = 24
local PRODUCT_H = 64
local AMOUNTS = { 1, 10, 100, -1 }

local TAG_COLORS = { prestige = "|cffefa438", tech = "|cff36a4ff", debug = "|cff00c462" }

local function HexToRGB(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-------------------------------------------------------------------------------
-- Tooltips
-------------------------------------------------------------------------------

-- The original's crateTooltip for upgrades (context "store" or "stats").
function UI:UpgradeTooltip(u, context)
	local game = NS.Game
	local S = game.save
	local bought = S.up[u.name]
	GameTooltip:SetText(u.name, 1, 1, 1)
	local tags = {}
	if u.pool == "prestige" then table.insert(tags, TAG_COLORS.prestige .. "[Heavenly]|r")
	elseif u.pool == "tech" then table.insert(tags, TAG_COLORS.tech .. "[Tech]|r")
	elseif u.pool == "cookie" then table.insert(tags, "[Cookie]")
	elseif u.pool == "debug" then table.insert(tags, TAG_COLORS.debug .. "[Debug]|r")
	elseif u.pool == "toggle" then table.insert(tags, "[Switch]")
	else table.insert(tags, "[Upgrade]") end
	if u.tier and u.tier ~= 0 and NS.TIERS[u.tier] and game:Has("Label printer") then
		local t = NS.TIERS[u.tier]
		local r, g, b = HexToRGB(t.color)
		table.insert(tags, string.format("|cff%02x%02x%02xTier: %s|r", r * 255, g * 255, b * 255, t.name))
	end
	if game:IsVaulted(u) then table.insert(tags, "|cff4e7566Vaulted|r") end
	if bought then
		table.insert(tags, u.pool == "tech" and "Researched" or "Purchased")
	end
	if u.lasting and S.unl[u.name] then table.insert(tags, "|cfff2ff87Unlocked forever|r") end
	GameTooltip:AddLine(table.concat(tags, "  "), 0.7, 0.7, 0.7)
	-- Price.
	if not (bought and context == "store") then
		if (u.lumps or 0) > 0 then
			local can = (S.lumps or 0) >= u.lumps
			GameTooltip:AddLine(NS.IconString({ 29, 14 }, 14) .. " " .. u.lumps .. " sugar lump" .. (u.lumps == 1 and "" or "s"), can and 0.4 or 1, can and 1 or 0.4, can and 0.4 or 0.4)
		elseif u.pool == "prestige" then
			local price = game:UpgradePrice(u)
			local can = bought or (S.chips or 0) >= price
			GameTooltip:AddLine(NS.IconString({ 19, 7 }, 14) .. " " .. NS.Beautify(price) .. " heavenly chip" .. (price == 1 and "" or "s"), can and 0.6 or 1, can and 0.9 or 0.5, 1)
		else
			local price = game:UpgradePrice(u)
			if price > 0 then
				local can = S.cookies >= price
				local line = "|TInterface\\AddOns\\MauCookie\\Textures\\money.tga:14:14|t " .. NS.Beautify(price)
				if game:Has("Genius accounting") and (game.cps or 0) > 0 and not can then
					line = line .. "  |cff888888(" .. NS.FormatDuration((price - S.cookies) / game.cps) .. ")|r"
				end
				GameTooltip:AddLine(line, can and 0.4 or 1, can and 1 or 0.4, 0.4)
			end
		end
	end
	-- Owned switches show their timers.
	if bought and context == "store" then
		if u.name == "Elder Pledge" then
			GameTooltip:AddLine("Time remaining until pledge runs out: " .. NS.FormatDuration(S.pledgeT or 0), 1, 0.9, 0.6, true)
		elseif u.seasonTrigger then
			GameTooltip:AddLine("Time remaining: " .. (game:Has("Eternal seasons") and "forever" or NS.FormatDuration(S.seasonT or 0)) .. " (click again to cancel the season)", 1, 0.9, 0.6, true)
		end
	end
	-- Description extras.
	if u.name == "Elder Pledge" then
		GameTooltip:AddLine((S.pledges or 0) == 0 and "You haven't pledged to the elders yet." or string.format("You've pledged to the elders %d times.", S.pledges), 0.8, 0.8, 0.8, true)
	elseif NS.SELECTORS[u.name] then
		local current
		if u.name == "Milk selector" then current = NS.MILKS[(S.milkType or 0) + 1]
		elseif u.name == "Background selector" then current = NS.BGS[(S.bgType or 0) + 1]
		elseif u.name == "Golden cookie sound selector" then current = NS.CHIMES[(S.chimeType or 0) + 1] end
		if current then
			GameTooltip:AddLine("Current: " .. NS.IconString(current.icon, 14) .. " " .. current.name, 0.8, 0.8, 0.8)
		end
	elseif NS.PERMANENT_SLOT_INDEX[u.name] then
		local slotName = S.perma[NS.PERMANENT_SLOT_INDEX[u.name]]
		if slotName then
			GameTooltip:AddLine("Current: " .. NS.IconString(NS.U[slotName] and NS.U[slotName].icon, 14) .. " " .. slotName, 0.8, 0.8, 0.8)
		end
	elseif u.name == "Golden switch [off]" and game:Has("Residual luck") then
		local bonus = 0
		for _, name in ipairs(NS.GOLDEN_UPGRADES) do
			if game:Has(name) then bonus = bonus + 1 end
		end
		GameTooltip:AddLine(string.format("The effective boost is +%d%% thanks to residual luck.", 50 + bonus * 10), 0.8, 0.8, 0.8, true)
	elseif u.name == "Century egg" then
		local day = math.max(0, math.min(100, math.floor((time() - (S.startDate or time())) / 10) * 10 / 60 / 60 / 24))
		GameTooltip:AddLine(string.format("Current boost: +%.1f%%", (1 - (1 - day / 100) ^ 3) * 10), 0.8, 0.8, 0.8)
	elseif u.name == "Sugar crystal cookies" then
		GameTooltip:AddLine(string.format("Current: +%d%%", game:CookiePower(u)), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(u.desc, 1, 1, 1, true)
	if u.quote and u.quote ~= "" then
		GameTooltip:AddLine(u.quote, 0.6, 0.6, 0.6, true)
	end
	if context == "store" then
		if u.pool == "toggle" and NS.SELECTORS[u.name] then
			GameTooltip:AddLine("Click to open selector.", 0.5, 0.5, 0.5)
		elseif u.pool == "toggle" then
			GameTooltip:AddLine("Click to toggle.", 0.5, 0.5, 0.5)
		elseif u.pool == "tech" then
			GameTooltip:AddLine("Click to research.", 0.5, 0.5, 0.5)
		elseif game:Has("Inspired checklist") then
			GameTooltip:AddLine(game:IsVaulted(u) and "Upgrade is vaulted and will not be auto-purchased. Click to purchase. Shift-click to unvault." or "Click to purchase. Shift-click to vault.", 0.5, 0.5, 0.5, true)
		else
			GameTooltip:AddLine("Click to purchase.", 0.5, 0.5, 0.5)
		end
	end
end

function UI:AchievementTooltip(a)
	local game = NS.Game
	local won = game:HasAchiev(a.name)
	GameTooltip:SetText(a.name, 1, 1, 1)
	local tag = a.pool == "shadow" and "|cff9700cf[Shadow Achievement]|r" or "[Achievement]"
	GameTooltip:AddLine(tag .. "  " .. (won and "Unlocked" or "Locked"), 0.7, 0.7, 0.7)
	if won or a.pool ~= "shadow" or true then
		GameTooltip:AddLine(a.desc, 1, 1, 1, true)
		if a.quote and a.quote ~= "" then
			GameTooltip:AddLine(a.quote, 0.6, 0.6, 0.6, true)
		end
	end
end

-- The original's building tooltip.
function UI:ProductTooltip(b)
	local game = NS.Game
	local S = game.save
	local r = game:Bld(b.name)
	local name, desc = b.name, b.desc
	if S.season == "fools" then
		local fool = NS.FOOL_OBJECTS[b.name] or NS.FOOL_OBJECTS.Unknown
		name, desc = fool.name, fool.desc
	end
	local locked = self:ProductLocked(b)
	if locked then
		GameTooltip:SetText("???", 1, 1, 1)
		GameTooltip:AddLine("???", 0.7, 0.7, 0.7)
		return
	end
	GameTooltip:SetText(name, 1, 1, 1)
	local amount = self.bulk == -1 and (self.mode == "sell" and math.max(1, r.n) or 1) or self.bulk
	if self.mode == "sell" then
		local n = self.bulk == -1 and r.n or math.min(self.bulk, r.n)
		if n > 0 then
			GameTooltip:AddLine(string.format("|TInterface\\AddOns\\MauCookie\\Textures\\money.tga:14:14|t %s  for selling %d", NS.Beautify(game:ReverseSumPrice(b, n)), n), 1, 0.8, 0.4)
		end
	else
		local price = self.bulk == -1 and game:SumPrice(b, self:MaxAffordable(b)) or game:SumPrice(b, amount)
		local can = S.cookies >= price and price > 0
		local line = "|TInterface\\AddOns\\MauCookie\\Textures\\money.tga:14:14|t " .. NS.Beautify(price)
		if game:Has("Genius accounting") and not can and (game.cps or 0) > 0 then
			line = line .. "  |cff888888(" .. NS.FormatDuration((price - S.cookies) / game.cps) .. ")|r"
		end
		GameTooltip:AddLine(line, can and 0.4 or 1, can and 1 or 0.4, 0.4)
	end
	GameTooltip:AddLine("[owned: " .. NS.Commas(r.n) .. "]", 0.6, 0.6, 0.6)
	GameTooltip:AddLine(desc, 0.75, 0.75, 0.75, true)
	if r.total > 0 or r.n > 0 then
		local entry = game.cpsBy[b.name]
		local gm = game.globalMult or 1
		if r.n > 0 and entry then
			GameTooltip:AddLine(string.format("each %s produces %s cookies per second", b.single, NS.Beautify(entry.each * gm, 1)), 1, 1, 1, true)
			local share = (game.cps or 0) > 0 and (entry.total * gm / game.cps * 100) or 0
			GameTooltip:AddLine(string.format("%s %s producing %s cookies per second (%.1f%% of total CpS)", NS.Commas(r.n), r.n == 1 and b.single or b.plural, NS.Beautify(entry.total * gm, 1), share), 1, 1, 1, true)
		end
		GameTooltip:AddLine(string.format("%s cookies %s so far", NS.Beautify(r.total), b.bplural and "produced" or "produced"), 0.8, 0.8, 0.8, true)
	end
	if r.level > 0 then
		GameTooltip:AddLine(string.format("Level %d: +%d%% CpS", r.level, r.level), 0.6, 0.8, 1)
	end
end

-------------------------------------------------------------------------------
-- Building the column
-------------------------------------------------------------------------------

function UI:CreateStore(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(RIGHT_W, CONTENT_H)
	p:SetPoint("TOPRIGHT", 0, -TOP)
	self.store = p
	p.Bg = UI.Solid(p, "BACKGROUND", 0, 0, 0, 0.5)
	p.Bg:SetAllPoints()
	local scroll = UI.Scroll(p, RIGHT_W, CONTENT_H)
	scroll:SetPoint("TOPLEFT")
	p.Scroll = scroll
	local c = scroll.Child
	c:SetWidth(RIGHT_W)
	self.mode, self.bulk = "buy", 1

	-- Section headers (pooled).
	p.Sections = {}
	for i = 1, 5 do
		local s = CreateFrame("Frame", nil, c)
		s:SetSize(STORE_W, SECTION_H)
		s.Strip = s:CreateTexture(nil, "BACKGROUND")
		s.Strip:SetTexture(NS.Art("panelHorizontal"), "REPEAT", "CLAMP")
		s.Strip:SetHorizTile(true)
		s.Strip:SetPoint("TOPLEFT")
		s.Strip:SetPoint("TOPRIGHT")
		s.Strip:SetHeight(16)
		s.Strip:SetTexCoord(0, STORE_W / 512, 0, 1)
		s.Title = s:CreateFontString(nil, "OVERLAY")
		s.Title:SetFont(FONT, 13, "OUTLINE")
		s.Title:SetPoint("TOP", 0, -3)
		s.Title:SetTextColor(0.96, 0.85, 0.72)
		s:Hide()
		p.Sections[i] = s
	end

	-- Bulk controls.
	local bulk = CreateFrame("Frame", nil, c)
	bulk:SetSize(STORE_W, 32)
	bulk.Buy = UI.FancyButton(bulk, "Buy", 54, 14, function()
		UI.mode = "buy"
		UI:RefreshStore(true)
	end)
	bulk.Buy:SetPoint("TOPLEFT", 2, -1)
	bulk.Sell = UI.FancyButton(bulk, "Sell", 54, 14, function()
		UI.mode = "sell"
		UI:RefreshStore(true)
	end)
	bulk.Sell:SetPoint("BOTTOMLEFT", 2, 1)
	bulk.Amounts = {}
	for i, amount in ipairs(AMOUNTS) do
		local b = UI.FancyButton(bulk, amount == -1 and "all" or tostring(amount), 50, 22, function()
			UI.bulk = amount
			UI:RefreshStore(true)
		end)
		b:SetPoint("LEFT", 62 + (i - 1) * 56, 0)
		b.amount = amount
		bulk.Amounts[i] = b
	end
	p.Bulk = bulk

	-- Buy all (Inspired checklist).
	p.BuyAll = UI.FancyButton(c, "Buy all upgrades", 160, 20, function()
		NS.Game:BuyAllUpgrades()
	end)
	UI.SetTooltip(p.BuyAll, function()
		GameTooltip:SetText("Buy all upgrades")
		GameTooltip:AddLine("Will instantly purchase every upgrade you can afford, starting from the cheapest one. Upgrades in the vault will not be auto-purchased.", 1, 1, 1, true)
	end)
	p.BuyAll:Hide()

	p.Crates = {}
	p.Products = {}
	for _, b in ipairs(NS.BUILDINGS) do
		local prod = CreateFrame("Button", nil, c)
		prod:SetSize(STORE_W, PRODUCT_H)
		prod.building = b
		prod.Bg = prod:CreateTexture(nil, "BACKGROUND")
		prod.Bg:SetTexture(NS.Art("storeTile"), "REPEAT", "REPEAT")
		prod.Bg:SetHorizTile(true)
		prod.Bg:SetVertTile(true)
		prod.Bg:SetAllPoints()
		prod.Bg:SetTexCoord(0, STORE_W / 256, (b.id % 4) * PRODUCT_H / 256, (b.id % 4 + 1) * PRODUCT_H / 256)
		prod.Line = UI.Solid(prod, "BORDER", 0, 0, 0, 0.5)
		prod.Line:SetPoint("BOTTOMLEFT")
		prod.Line:SetPoint("BOTTOMRIGHT")
		prod.Line:SetHeight(1)
		prod.Icon = prod:CreateTexture(nil, "ARTWORK")
		prod.Icon:SetSize(64, 64)
		prod.Icon:SetPoint("LEFT")
		prod.Title = prod:CreateFontString(nil, "OVERLAY")
		prod.Title:SetFont(FONT, 15, "")
		prod.Title:SetShadowOffset(1, -1)
		prod.Title:SetPoint("TOPLEFT", 70, -8)
		prod.Title:SetPoint("RIGHT", -60, 0)
		prod.Title:SetJustifyH("LEFT")
		prod.Title:SetWordWrap(false)
		prod.Money = prod:CreateTexture(nil, "OVERLAY")
		prod.Money:SetSize(14, 14)
		prod.Money:SetPoint("BOTTOMLEFT", 70, 10)
		NS.SetArt(prod.Money, "money")
		prod.Price = prod:CreateFontString(nil, "OVERLAY")
		prod.Price:SetFont(FONT, 13, "")
		prod.Price:SetShadowOffset(1, -1)
		prod.Price:SetPoint("LEFT", prod.Money, "RIGHT", 3, 0)
		prod.Owned = prod:CreateFontString(nil, "OVERLAY")
		prod.Owned:SetFont(FONT, 36, "")
		prod.Owned:SetPoint("BOTTOMRIGHT", -8, 2)
		prod.Owned:SetTextColor(0, 0, 0, 0.3)
		prod.Owned:SetShadowColor(1, 1, 1, 0.3)
		prod.Owned:SetShadowOffset(0, 0)
		prod.Level = prod:CreateFontString(nil, "OVERLAY")
		prod.Level:SetFont(FONT, 10, "")
		prod.Level:SetPoint("TOPRIGHT", -8, -6)
		prod.Level:SetTextColor(0.6, 0.8, 1)
		prod.LevelUp = CreateFrame("Button", nil, prod)
		prod.LevelUp:SetSize(33, 19)
		prod.LevelUp:SetPoint("TOPRIGHT", -6, -18)
		prod.LevelUp.Icon = prod.LevelUp:CreateTexture(nil, "ARTWORK")
		prod.LevelUp.Icon:SetAllPoints()
		NS.SetArt(prod.LevelUp.Icon, "levelUp")
		prod.LevelUp:SetScript("OnClick", function(self)
			local bb = self:GetParent().building
			local need = NS.Game:Level(bb.name) + 1
			UI:ConfirmLumps(need, "level up your " .. bb.plural, function()
				NS.Game:LevelUp(bb)
			end)
		end)
		UI.SetTooltip(prod.LevelUp, function(self)
			local bb = self:GetParent().building
			local level = NS.Game:Level(bb.name)
			GameTooltip:SetText(string.format("Level %d %s", level, bb.plural))
			GameTooltip:AddLine(string.format("Each level grants +1%% %s CpS. Leveling up costs %d sugar lump%s.", bb.single, level + 1, level == 0 and "" or "s"), 1, 1, 1, true)
			if level == 0 and bb.minigame then
				GameTooltip:AddLine("Level 1 unlocks the " .. bb.minigame .. " minigame.", 0.6, 0.8, 1, true)
			end
		end)
		prod.LevelUp:Hide()
		prod.Minigame = UI.FancyButton(prod, "View", 54, 16, function(self)
			UI:ToggleMinigame(self:GetParent().building)
		end)
		prod.Minigame:SetPoint("TOPRIGHT", -44, -6)
		prod.Minigame:Hide()
		prod:SetHighlightTexture(WHITE)
		prod:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
		prod:RegisterForClicks("LeftButtonUp")
		prod:SetScript("OnClick", function(self)
			local bb = self.building
			if UI:ProductLocked(bb) then
				return
			end
			if UI.mode == "sell" then
				NS.Game:SellBuilding(bb, UI.bulk)
			else
				NS.Game:BuyBuilding(bb, UI.bulk)
			end
		end)
		UI.SetTooltip(prod, function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			UI:ProductTooltip(self.building)
		end)
		prod:Hide()
		p.Products[b.id] = prod
	end
	p.lastList = {}
end

function UI:ProductLocked(b)
	local game = NS.Game
	local r = game:Bld(b.name)
	return not (game.save.earned >= b.basePrice or r.bought > 0 or r.n > 0)
end

function UI:MaxAffordable(b)
	local game = NS.Game
	local r = game:Bld(b.name)
	local cookies = game.save.cookies
	local n = 0
	local total = 0
	while n < 1000 do
		local price = math.ceil(game:ModifyBuildingPrice(b, b.basePrice * (game.priceIncrease ^ math.max(0, r.n + n - r.free))))
		if total + price > cookies then
			break
		end
		total = total + price
		n = n + 1
	end
	return n
end

local function GetCrate(self, i)
	local p = self.store
	local c = p.Crates[i]
	if c then
		return c
	end
	c = CreateFrame("Button", nil, p.Scroll.Child)
	c:SetSize(CRATE, CRATE)
	c.Frame = c:CreateTexture(nil, "BORDER")
	c.Frame:SetPoint("TOPLEFT", -6, 6)
	c.Frame:SetPoint("BOTTOMRIGHT", 6, -6)
	c.Shade = UI.Solid(c, "BACKGROUND", 0, 0, 0, 0.25)
	c.Shade:SetAllPoints()
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetAllPoints()
	c.Pie = c:CreateTexture(nil, "OVERLAY")
	c.Pie:SetAllPoints()
	c.Pie:SetAlpha(0.5)
	c.Pie:Hide()
	c:RegisterForClicks("LeftButtonUp")
	c:SetScript("OnClick", function(self)
		if not self.upgrade then
			return
		end
		if IsShiftKeyDown() and NS.Game:Has("Inspired checklist") and self.upgrade.pool ~= "toggle" and self.upgrade.pool ~= "tech" then
			NS.Game:ToggleVault(self.upgrade)
			UI:RebuildStore()
			return
		end
		NS.Game:BuyUpgrade(self.upgrade)
	end)
	c:SetScript("OnEnter", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 2, 0)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if self.upgrade then
			NS.Guard("tooltip", UI.UpgradeTooltip, UI, self.upgrade, "store")
			GameTooltip:Show()
		end
	end)
	c:SetScript("OnLeave", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 0, 0)
		GameTooltip:Hide()
	end)
	p.Crates[i] = c
	return c
end

-- Lay the column out again: sections, crates, bulk controls and products.
function UI:RebuildStore()
	local p = self.store
	if not p then
		return
	end
	local game = NS.Game
	local list = game:UpgradesInStore()
	local groups = { normal = {}, toggle = {}, tech = {}, vault = {} }
	local hasChecklist = game:Has("Inspired checklist")
	for _, u in ipairs(list) do
		if u.pool == "toggle" then
			table.insert(groups.toggle, u)
		elseif u.pool == "tech" then
			table.insert(groups.tech, u)
		elseif hasChecklist and game:IsVaulted(u) then
			table.insert(groups.vault, u)
		else
			table.insert(groups.normal, u)
		end
	end
	local c = p.Scroll.Child
	local y = 0
	local crateIndex = 0
	local sectionIndex = 0
	for _, s in ipairs(p.Sections) do
		s:Hide()
	end
	local function Section(title, crates, extra)
		sectionIndex = sectionIndex + 1
		local s = p.Sections[sectionIndex]
		s.Title:SetText(title)
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
		s:Show()
		y = y + SECTION_H + (extra or 0)
		if crates then
			for i, u in ipairs(crates) do
				crateIndex = crateIndex + 1
				local crate = GetCrate(self, crateIndex)
				crate.upgrade = u
				NS.SetIcon(crate.Icon, u.icon)
				NS.SetSheetCell(crate.Frame, "upgradeFrame", 60, 60, 0, 0)
				local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
				crate:ClearAllPoints()
				crate:SetPoint("TOPLEFT", c, "TOPLEFT", 6 + col * FRAME, -(y + 6 + row * FRAME))
				crate:Show()
			end
			y = y + math.ceil(#crates / PER_ROW) * FRAME + 4
		end
	end
	if hasChecklist then
		Section("Upgrades", nil, 24)
		p.BuyAll:ClearAllPoints()
		p.BuyAll:SetPoint("TOPLEFT", c, "TOPLEFT", (STORE_W - 160) / 2, -(y - 22))
		p.BuyAll:Show()
		for i, u in ipairs(groups.normal) do
			crateIndex = crateIndex + 1
			local crate = GetCrate(self, crateIndex)
			crate.upgrade = u
			NS.SetIcon(crate.Icon, u.icon)
			NS.SetSheetCell(crate.Frame, "upgradeFrame", 60, 60, 0, 0)
			local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
			crate:ClearAllPoints()
			crate:SetPoint("TOPLEFT", c, "TOPLEFT", 6 + col * FRAME, -(y + 6 + row * FRAME))
			crate:Show()
		end
		y = y + math.ceil(#groups.normal / PER_ROW) * FRAME + 4
	else
		p.BuyAll:Hide()
		Section("Upgrades", groups.normal)
	end
	if #groups.toggle > 0 then
		Section("Switches", groups.toggle)
	end
	if #groups.tech > 0 then
		Section("Research", groups.tech)
	end
	if #groups.vault > 0 then
		Section("Vault", groups.vault)
	end
	for i = crateIndex + 1, #p.Crates do
		p.Crates[i].upgrade = nil
		p.Crates[i]:Hide()
	end
	p.crateCount = crateIndex
	-- Buildings.
	Section("Buildings", nil)
	p.Bulk:ClearAllPoints()
	p.Bulk:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
	y = y + 32
	local locked = 0
	for _, b in ipairs(NS.BUILDINGS) do
		local prod = p.Products[b.id]
		local isLocked = self:ProductLocked(b)
		if isLocked then
			locked = locked + 1
		end
		if isLocked and locked > 2 then
			prod:Hide()
		else
			prod:ClearAllPoints()
			prod:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			prod:Show()
			y = y + PRODUCT_H
		end
	end
	y = y + 16
	p.Scroll:SetContentHeight(y)
	self:RefreshStore(true)
end

-- Cheap per-tick update: affordability, prices, counts.
function UI:RefreshStore(force)
	local p = self.store
	if not p then
		return
	end
	local game = NS.Game
	local S = game.save
	local cookies = S.cookies
	for i = 1, p.crateCount or 0 do
		local crate = p.Crates[i]
		local u = crate.upgrade
		if u then
			local owned = S.up[u.name]
			local can = owned or game:CanBuyUpgrade(u)
			if can then
				crate.Icon:SetDesaturated(false)
				crate:SetAlpha(1)
			else
				crate.Icon:SetDesaturated(true)
				crate:SetAlpha(0.6)
			end
			-- Pie timers on the owned switches.
			local frac
			if owned and u.name == "Elder Pledge" then
				frac = 1 - (S.pledgeT or 0) / math.max(1, game:PledgeDuration())
			elseif owned and u.seasonTrigger and not game:Has("Eternal seasons") then
				frac = 1 - (S.seasonT or 0) / math.max(1, game:SeasonDuration())
			end
			if frac then
				local T = (frac * 144) % 144
				NS.SetSheetCell(crate.Pie, "pieFill", 48, 48, math.floor(T % 18), math.floor(T / 18))
				crate.Pie:Show()
			else
				crate.Pie:Hide()
			end
		end
	end
	-- Bulk buttons.
	local bulk = p.Bulk
	for _, b in ipairs(bulk.Amounts) do
		b.Label:SetTextColor(b.amount == self.bulk and 1 or 0.6, b.amount == self.bulk and 0.9 or 0.6, b.amount == self.bulk and 0.6 or 0.6)
	end
	bulk.Buy.Label:SetTextColor(self.mode == "buy" and 1 or 0.6, self.mode == "buy" and 0.9 or 0.6, 0.6)
	bulk.Sell.Label:SetTextColor(self.mode == "sell" and 1 or 0.6, self.mode == "sell" and 0.7 or 0.6, 0.6)
	-- Products.
	local fools = S.season == "fools"
	local canLumps = game:CanLumps() and (S.lumpsTotal or -1) > -1
	for _, b in ipairs(NS.BUILDINGS) do
		local prod = p.Products[b.id]
		if prod:IsShown() then
			local r = game:Bld(b.name)
			local locked = self:ProductLocked(b)
			if locked then
				prod.Title:SetText("???")
				prod.Price:SetText("")
				prod.Money:Hide()
				prod.Owned:SetText("")
				prod.Icon:SetVertexColor(1, 1, 1)
				NS.SetBuildingIcon(prod.Icon, fools and 3 or 1, b.icon)
				prod:SetAlpha(0.5)
				prod.Level:SetText("")
				prod.LevelUp:Hide()
				prod.Minigame:Hide()
			else
				local name = b.name
				if fools then
					local fool = NS.FOOL_OBJECTS[b.name]
					name = fool and fool.name or NS.FOOL_OBJECTS.Unknown.name
				end
				prod.Title:SetText(name)
				prod.Money:Show()
				local enabled
				if self.mode == "sell" then
					local n = self.bulk == -1 and r.n or math.min(self.bulk, r.n)
					enabled = n > 0
					prod.Price:SetText(n > 0 and NS.Beautify(game:ReverseSumPrice(b, n)) or "0")
					prod.Price:SetTextColor(enabled and 1 or 0.6, enabled and 0.8 or 0.4, 0.4)
				else
					local n = self.bulk == -1 and math.max(1, self:MaxAffordable(b)) or self.bulk
					local price = game:SumPrice(b, n)
					enabled = cookies >= price
					prod.Price:SetText(NS.Beautify(price))
					prod.Price:SetTextColor(enabled and 0.4 or 1, enabled and 1 or 0.4, 0.4)
				end
				if b.id == 1 and (S.elderWrath or 0) > 0 then
					local rows = { [1] = { 0, 2 }, [2] = { 1, 2 }, [3] = { 2, 2 } }
					local cell = rows[math.min(3, S.elderWrath)]
					NS.SetBuildingIcon(prod.Icon, cell[1], cell[2])
				else
					NS.SetBuildingIcon(prod.Icon, enabled and (fools and 2 or 0) or (fools and 3 or 1), b.icon)
				end
				prod:SetAlpha(enabled and 1 or 0.6)
				prod.Owned:SetText(r.n > 0 and NS.Commas(r.n) or "")
				if canLumps then
					prod.Level:SetText(r.level > 0 and ("lvl " .. r.level) or "")
					prod.LevelUp:Show()
					prod.LevelUp:SetAlpha((S.lumps or 0) >= r.level + 1 and 1 or 0.4)
				else
					prod.Level:SetText("")
					prod.LevelUp:Hide()
				end
				if b.minigame and r.level > 0 then
					prod.Minigame:SetText((self.openMinigame == b.name) and "Close" or b.minigame)
					prod.Minigame:Show()
				else
					prod.Minigame:Hide()
				end
			end
		end
	end
end
