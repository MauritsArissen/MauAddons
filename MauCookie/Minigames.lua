-- MauCookie minigames host: the Garden (Farm), Stock market (Bank),
-- Pantheon (Temple) and Grimoire (Wizard tower) register here; a minigame
-- loads once its building reaches level 1, keeps its state in
-- save.minigames[building], ticks from Game:Tick (logic), feeds CpS
-- effects into CalculateGains (effs) and draws into the building row's
-- panel when the store's minigame button opens it.  Timers run on bakery
-- time like everything else that is not a sugar lump.

local _, NS = ...

local Minigames = { list = {}, byBuilding = {} }
NS.Minigames = Minigames
local Game = NS.Game

function Minigames:Register(def)
	table.insert(self.list, def)
	self.byBuilding[def.building] = def
	def.loaded = false
	def.height = def.height or 300
end

function Minigames:Load(def)
	if def.loaded then
		return
	end
	local S = Game.save
	S.minigames = S.minigames or {}
	local state = S.minigames[def.building]
	local fresh = state == nil
	if fresh then
		state = {}
		S.minigames[def.building] = state
	end
	def.state = state
	def.loaded = true
	Game.minigames = Game.minigames or {}
	Game.minigames[def.building] = def
	if def.load then
		def:load(fresh)
	end
	Game.recalc = true
end

-- Game:Start calls this once the save is bound.
function Minigames:Start()
	Game.minigames = {}
	for _, def in ipairs(self.list) do
		def.loaded = false
		def.state = nil
		if Game:Level(def.building) >= 1 then
			self:Load(def)
		end
	end
end

function Game:OnBuildingLevel(b, level)
	local def = Minigames.byBuilding[b.name]
	if def then
		if level >= 1 and not def.loaded then
			Minigames:Load(def)
		end
		if def.loaded and def.onLevel then
			def:onLevel(level)
		end
	end
end

function Minigames:PanelHeight(b)
	local def = self.byBuilding[b.name]
	return def and def.height or 300
end

-- The store's minigame button: build the panel once, then refresh it.
function Minigames:OnToggle(b, open, panel)
	local def = self.byBuilding[b.name]
	if not def or not def.loaded or not panel then
		return
	end
	if open then
		panel:SetHeight(def.height)
		if not panel.built then
			panel.built = true
			panel.Note:SetText("")
			if def.render then
				NS.Guard("minigame " .. def.name, def.render, def, panel)
			end
		end
		def.panel = panel
		if def.refresh then
			NS.Guard("minigame " .. def.name, def.refresh, def, panel)
		end
	else
		def.panel = nil
	end
end

function Minigames:Refresh()
	for _, def in ipairs(self.list) do
		if def.loaded and def.panel and def.panel:IsShown() and def.refresh then
			NS.Guard("minigame " .. def.name, def.refresh, def, def.panel)
		end
	end
end

-- Shared panel look: the minigame background strip under shaded borders.
function Minigames:Decorate(panel, bgKey)
	panel.Bg:SetTexture(NS.Art(bgKey), "REPEAT", "REPEAT")
	panel.Bg:SetHorizTile(true)
	panel.Bg:SetVertTile(true)
	panel.Bg:SetTexCoord(0, (panel:GetWidth() or 366) / 512, 0, (panel:GetHeight() or 300) / 128)
	if not panel.Shade then
		panel.Shade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
		NS.SetArt(panel.Shade, "shadedBorders")
		panel.Shade:SetAllPoints()
		panel.Shade:SetAlpha(0.8)
	end
end

-- A 48 px icon crate on a panel (spells, gods, seeds).
function Minigames:Crate(panel, size)
	local c = CreateFrame("Button", nil, panel)
	c:SetSize(size or 48, size or 48)
	c.Bg = c:CreateTexture(nil, "BACKGROUND")
	NS.SetArt(c.Bg, "spellBG")
	c.Bg:SetPoint("TOPLEFT", -6, 8)
	c.Bg:SetPoint("BOTTOMRIGHT", 6, -18)
	c.Bg:SetTexCoord(0, 60 / 256, 0, 74 / 256)
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetAllPoints()
	c.Label = NS.UI.Text(c, 10, "OUTLINE")
	c.Label:SetPoint("TOP", c, "BOTTOM", 0, -2)
	c.Label:SetJustifyH("CENTER")
	c:SetHighlightTexture(NS.UI.WHITE)
	c:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	return c
end

-- The lump refill button every minigame has.
function Minigames:RefillButton(panel, tooltipText, onRefill)
	local b = CreateFrame("Button", nil, panel)
	b:SetSize(28, 28)
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetAllPoints()
	NS.SetIcon(b.Icon, { 29, 14 })
	b:SetHighlightTexture(NS.UI.WHITE)
	b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
	b:SetScript("OnClick", function()
		if not Game:CanRefillLump() then
			return
		end
		NS.UI:ConfirmLumps(1, "refill", function()
			Game:RefillLump(1, onRefill)
			NS.UI:Refresh(true)
		end)
	end)
	NS.UI.SetTooltip(b, function()
		GameTooltip:SetText("Sugar lump refill")
		GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
		if Game:CanRefillLump() then
			GameTooltip:AddLine("(can be done once every " .. NS.FormatDuration(Game:LumpRefillMax()) .. ")", 0.6, 0.6, 0.6)
		else
			GameTooltip:AddLine("(usable again in " .. NS.FormatDuration(Game.save.lumpRefill or 0) .. ")", 1, 0.4, 0.4)
		end
	end)
	return b
end
