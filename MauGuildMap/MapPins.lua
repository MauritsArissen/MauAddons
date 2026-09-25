-- MauGuildMap world map pins.
--
-- A map canvas data provider (Blizzard's own mechanism for everything drawn
-- on the world map) that puts one pin per roster entry on whatever map is
-- being looked at, and a pin mixin that shows the race icon and a tooltip.
-- The pin template lives in MauGuildMap.xml; its mixin table is filled at
-- PLAYER_LOGIN so the Blizzard base mixins are guaranteed to exist.

local _, NS = ...

local Map = {}
NS.Map = Map

local TEMPLATE = "MauGuildMapPinTemplate"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Fraction of the race icon cropped away in total (half on each side), so the
-- rim of Blizzard's round icon stays outside the visible square.
local ICON_ZOOM = 0.30

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

-- Globals referenced by the XML template (filled in TryInit).
MauGuildMapPinMixin = {}
MauGuildMapDataProviderMixin = {}

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
	if not mapID or NS.Roster:Count() == 0 then
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
			self:RefreshAllData()
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
	-- Constant on-screen size at every zoom level.
	self:SetScalingLimits(1, 1.0, 1.0)
	self:UseFrameLevelType("PIN_FRAME_LEVEL_GROUP_MEMBER")
end

function Pin:OnAcquired(entry)
	self.entry = entry
	local atlas = NS.RaceAtlas(entry.race, entry.sex)
	if atlas then
		SetZoomedAtlas(self.Icon, atlas)
	else
		-- Pins are pooled; undo any crop left by a previous member.
		self.Icon:SetTexture(FALLBACK_ICON)
		self.Icon:SetTexCoord(0, 1, 0, 1)
	end
	self.Icon:SetDesaturated(entry.inInstance)
	self:SetAlpha(entry.inInstance and 0.8 or 1)
end

function Pin:OnMouseEnter()
	local e = self.entry
	if not e then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local r, g, b = NS.ClassColor(e.class)
	GameTooltip:AddLine(e.name, r, g, b)
	GameTooltip:AddLine(string.format("Level %d %s %s", e.level or 0, NS.RaceName(e.race), NS.ClassName(e.class, e.sex)), 1, 1, 1)
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

-- Roster changed: redraw soon if the map is open (coalesced).
function Map:RequestRefresh()
	if not self.provider or self.refreshQueued or not WorldMapFrame or not WorldMapFrame:IsShown() then
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
