-- MauGuildMap world map pins.
--
-- A map canvas data provider (Blizzard's own mechanism for everything drawn
-- on the world map) that puts one pin per roster entry on whatever map is
-- being looked at, and a pin mixin that shows the race icon, a class ring,
-- an optional name label, a skull when dead, and a tooltip with whatever the
-- member shares.  The pin template lives in MauGuildMap.xml; its mixin table
-- is filled at PLAYER_LOGIN so the Blizzard base mixins are guaranteed to
-- exist.

local _, NS = ...

local Map = {}
NS.Map = Map

local TEMPLATE = "MauGuildMapPinTemplate"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Fraction of the race icon cropped away in total (half on each side), so the
-- rim of Blizzard's round icon stays outside the visible square.
local ICON_ZOOM = 0.30

-- Globals referenced by the XML template (filled in TryInit).
MauGuildMapPinMixin = {}
MauGuildMapDataProviderMixin = {}

-- Show an atlas zoomed in: take the atlas region from the client and shrink
-- the texture coordinates towards its centre.  Falls back to the plain atlas
-- when the region cannot be read.
local function SetZoomedAtlas(texture, atlas)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
	local file = info and (info.file or info.filename)
	if not file or not info.leftTexCoord then
		texture:SetAtlas(atlas)
		return
	end
	local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local insetX = (right - left) * ICON_ZOOM / 2
	local insetY = (bottom - top) * ICON_ZOOM / 2
	texture:SetTexture(file)
	texture:SetTexCoord(left + insetX, right - insetX, top + insetY, bottom - insetY)
end

-------------------------------------------------------------------------------
-- Data provider
-------------------------------------------------------------------------------

local Provider = {}

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function Provider:RefreshAllData(fromOnShow)
	local map = self:GetMap()
	map:RemoveAllPinsByTemplate(TEMPLATE)
	local mapID = map:GetMapID()
	if not mapID or NS.Roster:Count() == 0 or not NS.GetSettings().display then
		return
	end
	for _, entry in NS.Roster:Iterate() do
		local x, y = NS.Roster:GetPositionOnMap(entry, mapID)
		if x then
			local pin = map:AcquirePin(TEMPLATE, entry)
			pin:SetPosition(x, y)
		end
	end
end

function Provider:OnShow()
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(5, function()
			if not NS.IsBackground() then
				self:RefreshAllData()
			end
		end)
	end
end

function Provider:OnHide()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

-------------------------------------------------------------------------------
-- Pin
-------------------------------------------------------------------------------

local Pin = {}

function Pin:OnLoad()
	-- Constant on-screen size at every zoom level; the size itself is a
	-- setting and applied in OnAcquired.
	self:SetScalingLimits(1, 1.0, 1.0)
	-- Below quest markers, above flight points (see CLAUDE.md 5).
	self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function Pin:OnAcquired(entry)
	self.entry = entry
	local settings = NS.GetSettings()

	local scale = settings.pinScale or 1
	self:SetScalingLimits(1, scale, scale)

	local atlas = NS.RaceAtlas(entry.race, entry.sex)
	if atlas then
		SetZoomedAtlas(self.Icon, atlas)
	else
		-- Pins are pooled; undo any crop left by a previous member.
		self.Icon:SetTexture(FALLBACK_ICON)
		self.Icon:SetTexCoord(0, 1, 0, 1)
	end

	local r, g, b = NS.ClassColor(entry.class)
	self.Ring:SetVertexColor(r, g, b)
	self.Ring:SetShown(settings.ring)

	local dead = entry.dead and settings.deathMarkers
	self.Skull:SetShown(dead)
	self.Icon:SetDesaturated(entry.inInstance or dead)
	self:SetAlpha((entry.inInstance and not dead) and 0.8 or 1)

	if settings.labels then
		self.Label:SetText(entry.name)
		self.Label:SetTextColor(r, g, b)
		self.Label:Show()
	else
		self.Label:Hide()
	end

	if self:GetMap() then
		self:ApplyCurrentScale()
	end
end

local XP_COLOR = { 0.6, 0.4, 1 }
-- Only mention the age of an update once it is getting old.
local STALE_AFTER = 30

local function HasStat(value, max)
	return value ~= nil and max ~= nil and max > 0
end

local function AddStatLine(tooltip, label, value, max, r, g, b)
	local fraction = value / max
	tooltip:AddLine(string.format("%s: %s / %s (%d%%)", label, NS.FormatNumber(value), NS.FormatNumber(max), fraction * 100 + 0.5), r, g, b)
end

-- Three lines: "Name            23", "Race Class     Zone", "HP 62%  Mana 40%  XP 31%".
local function FillCompactTooltip(tooltip, e, settings)
	local r, g, b = NS.ClassColor(e.class)
	tooltip:AddDoubleLine(e.name .. (e.test and " (test)" or ""), tostring(e.level or 0), r, g, b, 1, 0.82, 0)

	local where = NS.MapName(e.mapID)
	if e.inInstance then
		where = (e.instance ~= "" and e.instance or "Instance") .. " (entrance)"
	end
	tooltip:AddDoubleLine(NS.RaceName(e.race) .. " " .. NS.ClassName(e.class, e.sex), where or "", 1, 1, 1, 1, 0.82, 0)

	local parts = {}
	if e.dead then
		parts[#parts + 1] = NS.Colorize("Dead", 1, 0.3, 0.3)
	end
	if settings.showHealth and HasStat(e.hp, e.hpMax) then
		local fraction = e.hp / e.hpMax
		parts[#parts + 1] = NS.Colorize(string.format("HP %d%%", fraction * 100 + 0.5), NS.HealthColor(fraction))
	end
	if settings.showPower and HasStat(e.power, e.powerMax) then
		local name, pr, pg, pb = NS.PowerInfo(e.powerType)
		parts[#parts + 1] = NS.Colorize(string.format("%s %d%%", name, e.power / e.powerMax * 100 + 0.5), pr, pg, pb)
	end
	if settings.showXP and HasStat(e.xp, e.xpMax) then
		parts[#parts + 1] = NS.Colorize(string.format("XP %d%%", e.xp / e.xpMax * 100 + 0.5), XP_COLOR[1], XP_COLOR[2], XP_COLOR[3])
	end
	if #parts > 0 then
		tooltip:AddLine(table.concat(parts, "   "))
	end

	local age = GetTime() - (e.seen or 0)
	if age > STALE_AFTER then
		tooltip:AddLine("No update for " .. NS.FormatAge(age):gsub(" ago$", ""), 0.6, 0.6, 0.6)
	end
end

-- The full version: numbers, zone details, age of the update.
local function FillDetailedTooltip(tooltip, e, settings)
	local r, g, b = NS.ClassColor(e.class)
	tooltip:AddLine(e.name, r, g, b)
	tooltip:AddLine(string.format("Level %d %s %s", e.level or 0, NS.RaceName(e.race), NS.ClassName(e.class, e.sex)), 1, 1, 1)

	if e.dead then
		tooltip:AddLine(e.inInstance and "Dead" or "Dead, the icon marks where", 1, 0.3, 0.3)
	end
	if settings.showHealth and HasStat(e.hp, e.hpMax) then
		AddStatLine(tooltip, "Health", e.hp, e.hpMax, NS.HealthColor(e.hp / e.hpMax))
	end
	if settings.showPower and HasStat(e.power, e.powerMax) then
		local name, pr, pg, pb = NS.PowerInfo(e.powerType)
		AddStatLine(tooltip, name, e.power, e.powerMax, pr, pg, pb)
	end
	if settings.showXP and HasStat(e.xp, e.xpMax) then
		AddStatLine(tooltip, "Experience", e.xp, e.xpMax, XP_COLOR[1], XP_COLOR[2], XP_COLOR[3])
		tooltip:AddLine(string.format("%s to level %d", NS.FormatNumber(e.xpMax - e.xp), (e.level or 0) + 1), 0.6, 0.6, 0.6)
	end

	local zone = NS.MapName(e.mapID)
	if e.inInstance then
		tooltip:AddLine(string.format("In %s", e.instance ~= "" and e.instance or "an instance"), 1, 0.82, 0)
		tooltip:AddLine("Shown at the entrance" .. (zone and (" in " .. zone) or ""), 0.6, 0.6, 0.6)
	elseif zone then
		tooltip:AddLine(zone, 1, 0.82, 0)
	end
	tooltip:AddLine("Updated " .. NS.FormatAge(GetTime() - (e.seen or 0)) .. (e.test and " (test member)" or ""), 0.6, 0.6, 0.6)
end

function Pin:OnMouseEnter()
	local e = self.entry
	if not e then
		return
	end
	local settings = NS.GetSettings()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if settings.detailedTooltip then
		FillDetailedTooltip(GameTooltip, e, settings)
	else
		FillCompactTooltip(GameTooltip, e, settings)
	end
	GameTooltip:Show()
end

function Pin:OnMouseLeave()
	GameTooltip:Hide()
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

function Map:TryInit()
	if self.initialized then
		return
	end
	if not WorldMapFrame or not WorldMapFrame.AddDataProvider or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then
		NS.Print("The world map frame was not found; members cannot be drawn.")
		return
	end
	self.initialized = true
	Mixin(MauGuildMapPinMixin, MapCanvasPinMixin, Pin)
	Mixin(MauGuildMapDataProviderMixin, MapCanvasDataProviderMixin, Provider)
	self.provider = CreateFromMixins(MauGuildMapDataProviderMixin)
	WorldMapFrame:AddDataProvider(self.provider)
end

-- Roster or settings changed: redraw soon if the map is open (coalesced).
function Map:RequestRefresh()
	if not self.provider or self.refreshQueued or not WorldMapFrame or not WorldMapFrame:IsShown() or NS.IsBackground() then
		return
	end
	self.refreshQueued = true
	C_Timer.After(0.25, function()
		self.refreshQueued = false
		if WorldMapFrame:IsShown() then
			self.provider:RefreshAllData()
		end
	end)
end
