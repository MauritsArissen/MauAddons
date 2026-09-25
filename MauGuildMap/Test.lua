-- MauGuildMap test mode: /mgm test
--
-- Simulates a guild spread over the Eastern Kingdoms: members idling in
-- cities, members inside dungeons (drawn at the real entrance when the
-- encounter journal knows it), and members wandering through zones.  Their
-- messages go through the same decoder and roster as real ones, so the wire
-- format, the map pins on zone/continent/world maps, the entrance display,
-- the goodbye message and the timeout are all exercised without a second
-- player.  Zones, cities and entrances are looked up from the client's map
-- data at start, nothing is hard-coded except names to look for.
--
-- Timeline (seconds after start):
--    0  everyone appears; wanderers move every 2 s, the rest send heartbeats
--   60  one city idler logs out (goodbye) and disappears at once
--   60  one wanderer stops sending; dropped after NS.TIMEOUT seconds
--  end  a few seconds after that the test stops and removes its members

local _, NS = ...

local Test = {}
NS.Test = Test

local CONTINENT_NAME = "Eastern Kingdoms"
local CONTINENT_FALLBACK_ID = 1415
local WORLD_MAP_ID = 947

local MAP_TYPE_CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local MAP_TYPE_ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

-- Preferred places; anything missing on this client falls back to whatever
-- zones and entrances exist.
local CITIES = {
	Alliance = { "Stormwind City", "Ironforge" },
	Horde = { "Undercity", "Stranglethorn Vale" },
}
local WANDER_ZONES = {
	Alliance = { "Elwynn Forest", "Redridge Mountains", "Duskwood" },
	Horde = { "Tirisfal Glades", "Silverpine Forest", "Hillsbrad Foothills" },
}
local PREFERRED_DUNGEONS = { "The Deadmines", "Shadowfang Keep", "Scarlet Monastery", "Blackrock Depths", "The Stockade", "Gnomeregan" }

local MEMBERS = {
	Alliance = {
		{ name = "Testalice", race = "NightElf", sex = 3, class = "HUNTER", level = 23, role = "wander" },
		{ name = "Testbob", race = "Dwarf", sex = 2, class = "PALADIN", level = 40, role = "dungeon" },
		{ name = "Testcarol", race = "Human", sex = 3, class = "MAGE", level = 60, role = "city" },
		{ name = "Testdave", race = "Gnome", sex = 2, class = "WARLOCK", level = 31, role = "wander" },
		{ name = "Testerin", race = "Human", sex = 3, class = "PRIEST", level = 47, role = "dungeon" },
		{ name = "Testfrank", race = "Dwarf", sex = 2, class = "WARRIOR", level = 55, role = "city" },
		{ name = "Testgwen", race = "NightElf", sex = 3, class = "ROGUE", level = 19, role = "wander" },
		{ name = "Testhank", race = "Human", sex = 2, class = "WARRIOR", level = 36, role = "dungeon" },
	},
	Horde = {
		{ name = "Testalice", race = "Troll", sex = 3, class = "HUNTER", level = 23, role = "wander" },
		{ name = "Testbob", race = "Orc", sex = 2, class = "WARRIOR", level = 40, role = "dungeon" },
		{ name = "Testcarol", race = "Scourge", sex = 3, class = "MAGE", level = 60, role = "city" },
		{ name = "Testdave", race = "Tauren", sex = 2, class = "DRUID", level = 31, role = "wander" },
		{ name = "Testerin", race = "Scourge", sex = 3, class = "PRIEST", level = 47, role = "dungeon" },
		{ name = "Testfrank", race = "Orc", sex = 2, class = "SHAMAN", level = 55, role = "city" },
		{ name = "Testgwen", race = "Troll", sex = 3, class = "ROGUE", level = 19, role = "wander" },
		{ name = "Testhank", race = "Tauren", sex = 2, class = "WARRIOR", level = 36, role = "dungeon" },
	},
}

local LOGOUT_AT = 60
local SILENT_AT = 60
local LOGOUT_NAME = "Testcarol"
local SILENT_NAME = "Testalice"
local STEP = 0.004

local function Clamp(v)
	return math.max(0.05, math.min(0.95, v))
end

-------------------------------------------------------------------------------
-- Map data lookup
-------------------------------------------------------------------------------

local function FindContinent()
	if C_Map.GetMapChildrenInfo then
		local continents = C_Map.GetMapChildrenInfo(WORLD_MAP_ID, MAP_TYPE_CONTINENT)
		for _, info in ipairs(continents or {}) do
			if info.name == CONTINENT_NAME then
				return info.mapID
			end
		end
	end
	return CONTINENT_FALLBACK_ID
end

local function ZonesOf(continentID)
	local zones = C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(continentID, MAP_TYPE_ZONE) or {}
	table.sort(zones, function(a, b)
		return (a.name or "") < (b.name or "")
	end)
	return zones
end

local function ZoneByName(zones, name)
	for _, zone in ipairs(zones) do
		if zone.name == name then
			return zone
		end
	end
	return nil
end

-- Named zones first, then whatever else exists, so there is always something.
local function PickZones(zones, wanted, count, used)
	local picked = {}
	for _, name in ipairs(wanted) do
		local zone = ZoneByName(zones, name)
		if zone and not used[zone.mapID] then
			used[zone.mapID] = true
			picked[#picked + 1] = zone
			if #picked == count then
				return picked
			end
		end
	end
	for _, zone in ipairs(zones) do
		if not used[zone.mapID] then
			used[zone.mapID] = true
			picked[#picked + 1] = zone
			if #picked == count then
				return picked
			end
		end
	end
	return picked
end

-- Every dungeon entrance the encounter journal knows on the continent's zones.
local function FindEntrances(zones)
	local entrances = {}
	if not C_EncounterJournal or not C_EncounterJournal.GetDungeonEntrancesForMap then
		return entrances
	end
	for _, zone in ipairs(zones) do
		local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, zone.mapID)
		if ok and type(list) == "table" then
			for _, entrance in ipairs(list) do
				if entrance.position then
					local x, y = entrance.position:GetXY()
					if x and y then
						entrances[#entrances + 1] = { mapID = zone.mapID, zone = zone.name, x = x, y = y, name = entrance.name or "a dungeon" }
					end
				end
			end
		end
	end
	return entrances
end

local function PickEntrances(entrances, count)
	local picked, used = {}, {}
	for _, wanted in ipairs(PREFERRED_DUNGEONS) do
		for i, entrance in ipairs(entrances) do
			if not used[i] and entrance.name == wanted then
				used[i] = true
				picked[#picked + 1] = entrance
				break
			end
		end
		if #picked == count then
			return picked
		end
	end
	for i, entrance in ipairs(entrances) do
		if not used[i] then
			used[i] = true
			picked[#picked + 1] = entrance
			if #picked == count then
				return picked
			end
		end
	end
	return picked
end

-------------------------------------------------------------------------------
-- Building the cast
-------------------------------------------------------------------------------

local function CountRole(defs, role)
	local n = 0
	for _, def in ipairs(defs) do
		if def.role == role then
			n = n + 1
		end
	end
	return n
end

function Test:Build()
	local faction = (UnitFactionGroup("player") == "Horde") and "Horde" or "Alliance"
	local defs = MEMBERS[faction]
	local continentID = FindContinent()
	local zones = ZonesOf(continentID)
	if #zones == 0 then
		return nil, "The client returned no zones for the Eastern Kingdoms (map " .. continentID .. ")."
	end

	local used = {}
	local cityZones = PickZones(zones, CITIES[faction], CountRole(defs, "city"), used)
	local wanderZones = PickZones(zones, WANDER_ZONES[faction], CountRole(defs, "wander"), used)
	local entrances = PickEntrances(FindEntrances(zones), CountRole(defs, "dungeon"))
	local fallbackDungeons = false
	if #entrances < CountRole(defs, "dungeon") then
		-- No (or not enough) journal data: put them at the centre of a zone
		-- and give the dungeon a made-up name.
		fallbackDungeons = true
		local extra = PickZones(zones, {}, CountRole(defs, "dungeon") - #entrances, used)
		for i, zone in ipairs(extra) do
			entrances[#entrances + 1] = { mapID = zone.mapID, zone = zone.name, x = 0.5, y = 0.5, name = "Test Dungeon " .. i }
		end
	end

	local fakes = {}
	local cityIndex, wanderIndex, dungeonIndex = 0, 0, 0
	for _, def in ipairs(defs) do
		local fake = { name = def.name, race = def.race, sex = def.sex, class = def.class, level = def.level, role = def.role, alive = true, silent = false }
		if def.role == "city" then
			cityIndex = cityIndex + 1
			local zone = cityZones[cityIndex]
			if zone then
				fake.mapID, fake.zone, fake.x, fake.y = zone.mapID, zone.name, 0.5, 0.5
			end
		elseif def.role == "wander" then
			wanderIndex = wanderIndex + 1
			local zone = wanderZones[wanderIndex]
			if zone then
				fake.mapID, fake.zone = zone.mapID, zone.name
				fake.x, fake.y = 0.35 + math.random() * 0.3, 0.35 + math.random() * 0.3
			end
		else
			dungeonIndex = dungeonIndex + 1
			local entrance = entrances[dungeonIndex]
			if entrance then
				fake.mapID, fake.zone, fake.x, fake.y = entrance.mapID, entrance.zone, entrance.x, entrance.y
				fake.instance = entrance.name
			end
		end
		if fake.mapID then
			fakes[#fakes + 1] = fake
		end
	end
	if #fakes == 0 then
		return nil, "No usable zones were found on the Eastern Kingdoms map (map " .. continentID .. ")."
	end
	return fakes, nil, fallbackDungeons
end

-------------------------------------------------------------------------------
-- Running
-------------------------------------------------------------------------------

function Test:Toggle()
	if self.running then
		self:Stop("stopped")
	else
		self:Start()
	end
end

function Test:Start()
	local fakes, err, fallbackDungeons = self:Build()
	if not fakes then
		NS.Print(err)
		return
	end
	self.fakes = fakes
	self.t = 0
	self.running = true

	NS.Print("Test started with %d test members across the Eastern Kingdoms. Open the map (M) and zoom out to the continent.", #fakes)
	for _, fake in ipairs(fakes) do
		local where
		if fake.role == "city" then
			where = "idle in " .. fake.zone
		elseif fake.role == "wander" then
			where = "wandering through " .. fake.zone
		else
			where = "inside " .. fake.instance .. " (entrance in " .. fake.zone .. ")"
		end
		NS.Print("  %s, level %d %s %s: %s", fake.name, fake.level, NS.RaceName(fake.race), NS.ClassName(fake.class, fake.sex), where)
	end
	if fallbackDungeons then
		NS.Print("The encounter journal had no entrance data for some dungeons, so those members sit at a zone centre instead.")
	end
	NS.Print("%s logs out at %d s; %s stops sending at %d s and is dropped %d s later.", LOGOUT_NAME, LOGOUT_AT, SILENT_NAME, SILENT_AT, NS.TIMEOUT)
	if not NS.GetSettings().display then
		NS.Print("Note: display is off, so nothing is drawn. /mgm enable turns it on.")
	end

	self.ticker = C_Timer.NewTicker(1, function()
		self:Tick()
	end)
	self:Tick()
end

function Test:Stop(reason)
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	self.running = false
	self.fakes = nil
	NS.Roster:RemoveTestEntries()
	NS.Print("Test %s; test members removed.", reason or "stopped")
end

local function Send(fake)
	local text = NS.Comm:Encode({
		mapID = fake.mapID,
		x = fake.x,
		y = fake.y,
		level = fake.level,
		race = fake.race,
		sex = fake.sex,
		class = fake.class,
		flag = fake.instance and "I" or "O",
		instance = fake.instance or "",
	})
	NS.Comm:OnMessage(text, fake.name, true)
end

function Test:Tick()
	if not self.running then
		return
	end
	local t = self.t
	self.t = t + 1

	for _, fake in ipairs(self.fakes) do
		if fake.name == LOGOUT_NAME and t == LOGOUT_AT and fake.alive then
			fake.alive = false
			NS.Comm:OnMessage("B", fake.name, true)
		end
		if fake.name == SILENT_NAME and t == SILENT_AT and not fake.silent then
			fake.silent = true
			NS.Print("%s stopped sending; removed after %d s without an update.", fake.name, NS.TIMEOUT)
		end

		if fake.alive and not fake.silent then
			if fake.role == "wander" then
				-- Moving members report every SEND_INTERVAL seconds, like the real thing.
				if t % NS.SEND_INTERVAL == 0 then
					fake.x = Clamp(fake.x + (math.random() - 0.5) * STEP * NS.SEND_INTERVAL)
					fake.y = Clamp(fake.y + (math.random() - 0.5) * STEP * NS.SEND_INTERVAL)
					Send(fake)
				end
			elseif t % NS.HEARTBEAT == 0 then
				-- Idle and in-dungeon members only send heartbeats.
				Send(fake)
			end
		end
	end

	if t >= SILENT_AT + NS.TIMEOUT + 8 then
		self:Stop("finished")
	end
end
