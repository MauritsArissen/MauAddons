-- MauGuildMap roster: the guild members currently known, keyed by short name.
--
-- An entry is created or refreshed on every message, dropped when a "bye"
-- arrives, when the guild reports the member offline, or when no message has
-- arrived for NS.TIMEOUT seconds.  Each entry also keeps a world position
-- (continent + world coordinates) so it can be placed on any map that shows
-- that spot, not only the zone the member is in.

local _, NS = ...

local Roster = CreateFrame("Frame")
NS.Roster = Roster

Roster.members = {}
Roster.count = 0

local PRESENCE_OFFLINE = (Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline) or 3

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function Roster:Start()
	if self.started then
		return
	end
	self.started = true
	self:RegisterEvent("CLUB_MEMBER_PRESENCE_UPDATED")
	self.ticker = C_Timer.NewTicker(5, function()
		self:Expire()
	end)
end

function Roster:Count()
	return self.count
end

function Roster:Iterate()
	return pairs(self.members)
end

function Roster:Get(name)
	return self.members[name]
end

-------------------------------------------------------------------------------
-- Updates
-------------------------------------------------------------------------------

local function ComputeWorldPosition(entry)
	entry.continentID = nil
	entry.world = nil
	if not entry.mapID or entry.mapID <= 0 or not C_Map or not C_Map.GetWorldPosFromMapPos then
		return
	end
	local ok, continentID, world = pcall(C_Map.GetWorldPosFromMapPos, entry.mapID, CreateVector2D(entry.x, entry.y))
	if ok and continentID and world then
		entry.continentID = continentID
		entry.world = world
	end
end

-- data: mapID, x, y (0-1), level, race, sex, class, inInstance, instance, test
function Roster:Update(name, data)
	local entry = self.members[name]
	if not entry then
		entry = { name = name }
		self.members[name] = entry
		self.count = self.count + 1
	end
	local moved = entry.mapID ~= data.mapID or entry.x ~= data.x or entry.y ~= data.y
	entry.mapID = data.mapID or 0
	entry.x = data.x or 0
	entry.y = data.y or 0
	entry.level = data.level or 0
	entry.race = data.race or ""
	entry.sex = data.sex or 2
	entry.class = data.class or ""
	entry.inInstance = data.inInstance and true or false
	entry.instance = data.instance or ""
	entry.test = data.test or nil
	entry.seen = GetTime()
	if moved or not entry.world then
		ComputeWorldPosition(entry)
	end
	self:Changed()
end

function Roster:Remove(name, reason)
	local entry = self.members[name]
	if not entry then
		return false
	end
	self.members[name] = nil
	self.count = self.count - 1
	if entry.test and reason then
		NS.Print("%s removed from the map (%s).", name, reason)
	end
	self:Changed()
	return true
end

function Roster:RemoveTestEntries()
	for name, entry in pairs(self.members) do
		if entry.test then
			self.members[name] = nil
			self.count = self.count - 1
		end
	end
	self:Changed()
end

function Roster:Expire()
	local now = GetTime()
	for name, entry in pairs(self.members) do
		if now - (entry.seen or 0) > NS.TIMEOUT then
			self:Remove(name, "no update for " .. NS.TIMEOUT .. " s")
		end
	end
end

function Roster:Changed()
	if NS.Map and NS.Map.RequestRefresh then
		NS.Map:RequestRefresh()
	end
end

-------------------------------------------------------------------------------
-- Placement
-------------------------------------------------------------------------------

local MAP_TYPE_WORLD = (Enum and Enum.UIMapType and Enum.UIMapType.World) or 1

local continentOfMap = {}

-- Game continent ID of a ui map (probe the centre of the map).  Cached.
local function ContinentOfMap(mapID)
	local cached = continentOfMap[mapID]
	if cached ~= nil then
		return cached or nil
	end
	local result = false
	if C_Map and C_Map.GetWorldPosFromMapPos then
		local ok, continentID = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
		if ok and continentID then
			result = continentID
		end
	end
	continentOfMap[mapID] = result
	return result or nil
end

local function IsWorldOrCosmic(mapID)
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	return info and info.mapType and info.mapType <= MAP_TYPE_WORLD
end

-- Normalised position of an entry on the given map, or nil when the member
-- is not within that map.
function Roster:GetPositionOnMap(entry, mapID)
	if not entry.mapID or entry.mapID <= 0 then
		return nil
	end
	if entry.mapID == mapID then
		return entry.x, entry.y
	end
	if not entry.continentID or not entry.world or not C_Map.GetMapPosFromWorldPos then
		return nil
	end
	-- Zone and continent maps only show members on the same game continent;
	-- the world map may show everyone.
	if not IsWorldOrCosmic(mapID) then
		local continent = ContinentOfMap(mapID)
		if continent ~= entry.continentID then
			return nil
		end
	end
	local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, entry.continentID, entry.world, mapID)
	if not ok or not pos then
		return nil
	end
	local x, y = pos:GetXY()
	if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		return x, y
	end
	return nil
end

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

function Roster:Describe(entry)
	local where
	local zone = NS.MapName(entry.mapID)
	if entry.inInstance then
		where = string.format("in %s, shown at the entrance%s", entry.instance ~= "" and entry.instance or "an instance", zone and (" in " .. zone) or "")
	elseif zone then
		where = zone
	else
		where = "position unknown"
	end
	return where
end

function Roster:PrintList()
	if self.count == 0 then
		NS.Print("No guild members with the addon are sending their position right now.")
		return
	end
	local names = {}
	for name in pairs(self.members) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local e = self.members[name]
		local r, g, b = NS.ClassColor(e.class)
		local colored = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
		NS.Print("%s - level %d %s %s - %s - updated %s%s", colored, e.level, NS.RaceName(e.race), NS.ClassName(e.class, e.sex),
			self:Describe(e), NS.FormatAge(GetTime() - (e.seen or 0)), e.test and " (test)" or "")
	end
end

-------------------------------------------------------------------------------
-- Guild presence: drop members the moment the guild sees them go offline
-------------------------------------------------------------------------------

Roster:SetScript("OnEvent", function(self, event, clubId, memberId, presence)
	if event ~= "CLUB_MEMBER_PRESENCE_UPDATED" or presence ~= PRESENCE_OFFLINE then
		return
	end
	if not C_Club or not C_Club.GetGuildClubId or clubId ~= C_Club.GetGuildClubId() then
		return
	end
	local info = C_Club.GetMemberInfo and C_Club.GetMemberInfo(clubId, memberId)
	local name = info and NS.ShortName(info.name)
	if name then
		self:Remove(name, "logged out")
	end
end)
