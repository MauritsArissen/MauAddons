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

-- Globals referenced by the XML template (filled in TryInit).
MauGuildMapPinMixin = {}
MauGuildMapDataProviderMixin = {}

-- Show an atlas zoomed in: take the atlas region from the client and shrink
-- the texture coordinates towards its centre by "zoom" (0-1 of the region,
-- half on each side) so the rim of Blizzard's round icon stays outside the
-- visible square.  Falls back to the plain atlas when the region cannot be
-- read.
local function SetZoomedAtlas(texture, atlas, zoom)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
	local file = info and (info.file or info.filename)
	if not file or not info.leftTexCoord or zoom <= 0 then
		texture:SetAtlas(atlas)
		return
	end
	local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local insetX = (right - left) * zoom / 2
	local insetY = (bottom - top) * zoom / 2
	texture:SetTexture(file)
	texture:SetTexCoord(left + insetX, right - insetX, top + insetY, bottom - insetY)
end

-- Font, size, outline, position and colour of the name label, all settings.
local function ApplyLabel(pin, entry, settings, r, g, b)
	local label = pin.Label
	if not settings.labels then
		label:Hide()
		return
	end
	local flags = NS.OutlineFlags(settings.labelOutline)
	local size = settings.labelSize
	if not label:SetFont(NS.FontPath(settings.labelFont), size, flags) then
		label:SetFont(NS.FontPath("friz"), size, flags)
	end
	if flags == "" then
		label:SetShadowOffset(1, -1)
	else
		label:SetShadowOffset(0, 0)
	end
	label:ClearAllPoints()
	if settings.labelPosition == "above" then
		label:SetPoint("BOTTOM", pin, "TOP", 0, settings.labelOffset)
	else
		label:SetPoint("TOP", pin, "BOTTOM", 0, -settings.labelOffset)
	end
	label:SetText(entry.name)
	if settings.labelClassColor then
		label:SetTextColor(r, g, b)
	else
		label:SetTextColor(1, 1, 1)
	end
	label:Show()
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
	-- Constant on-screen size at every zoom level; the pixel sizes are
	-- settings and applied in OnAcquired.
	self:SetScalingLimits(1, 1.0, 1.0)
	-- Below quest markers, above flight points (see CLAUDE.md 5).
	self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

-- Everything visual comes from the settings, applied on every acquire so a
-- change in the options shows on the next refresh.
function Pin:OnAcquired(entry)
	self.entry = entry
	local settings = NS.GetSettings()

	local iconSize = settings.iconSize
	local ringWidth = settings.ring and settings.ringWidth or 0
	local outerSize = iconSize + 2 * ringWidth
	self:SetSize(outerSize, outerSize)
	self.Icon:SetSize(iconSize, iconSize)
	self.Ring:SetSize(outerSize, outerSize)
	self.Skull:SetSize(math.max(10, iconSize - 2), math.max(10, iconSize - 2))

	local atlas = NS.RaceAtlas(entry.race, entry.sex)
	if atlas then
		SetZoomedAtlas(self.Icon, atlas, settings.iconZoom / 100)
	else
		-- Pins are pooled; undo any crop left by a previous member.
		self.Icon:SetTexture(FALLBACK_ICON)
		self.Icon:SetTexCoord(0, 1, 0, 1)
	end

	local r, g, b = NS.ClassColor(entry.class)
	self.Ring:SetVertexColor(r, g, b)
	self.Ring:SetShown(ringWidth > 0)

	local dead = entry.dead and settings.deathMarkers
	self.Skull:SetShown(dead)
	self.Icon:SetDesaturated(entry.inInstance or dead)
	self:SetAlpha((entry.inInstance and not dead) and (settings.instanceAlpha / 100) or 1)

	ApplyLabel(self, entry, settings, r, g, b)

	if self:GetMap() then
		self:ApplyCurrentScale()
	end
end

local XP_COLOR = { 0.6, 0.4, 1 }

local function HasStat(value, max)
	return value ~= nil and max ~= nil and max > 0
end

-- "HP 62%   Mana 40%   XP 31%" for whatever the member shares and the viewer
-- wants to see; nil when there is nothing to show.
local function StatsLine(e, settings)
	local parts = {}
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
		return table.concat(parts, "   ")
	end
	return nil
end

function Pin:OnMouseEnter()
	local e = self.entry
	if not e then
		return
	end
	local settings = NS.GetSettings()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local r, g, b = NS.ClassColor(e.class)
	GameTooltip:AddLine(e.name, r, g, b)
	GameTooltip:AddLine(string.format("Level %d %s %s", e.level or 0, NS.RaceName(e.race), NS.ClassName(e.class, e.sex)), 1, 1, 1)
	if e.dead then
		GameTooltip:AddLine(e.inInstance and "Dead" or "Dead, the icon marks where", 1, 0.3, 0.3)
	end
	local stats = StatsLine(e, settings)
	if stats then
		GameTooltip:AddLine(stats)
	end
	local zone = NS.MapName(e.mapID)
	if e.inInstance then
		GameTooltip:AddLine(string.format("In %s", e.instance ~= "" and e.instance or "an instance"), 1, 0.82, 0)
		GameTooltip:AddLine("Shown at the entrance" .. (zone and (" in " .. zone) or ""), 0.6, 0.6, 0.6)
	elseif zone then
		GameTooltip:AddLine(zone, 1, 0.82, 0)
	end
	GameTooltip:AddLine("Updated " .. NS.FormatAge(GetTime() - (e.seen or 0)) .. (e.test and " (test member)" or ""), 0.6, 0.6, 0.6)
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
