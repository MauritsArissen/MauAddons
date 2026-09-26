-- MauGuildMap: guild members on the world map.
--
-- Every guild member running this addon broadcasts a tiny status message
-- on the guild addon channel (Comm.lua): position, level, and optionally
-- health, power and experience.  Everyone else keeps those in a roster
-- (Roster.lua) and draws a race icon per member on Blizzard's world map
-- (MapPins.lua).  Members inside a dungeon are drawn at the spot where they
-- entered it, dead members get a skull.  All switches live in the game's
-- Settings > AddOns panel (Options.lua); /mgm opens it.  /mgm test
-- simulates a guild (Test.lua).  See CLAUDE.md for the full picture.

local ADDON_NAME, NS = ...
_G.MauGuildMap = NS

NS.ADDON_NAME = ADDON_NAME
NS.PREFIX = "MauGuildMap"

-- Seconds between position checks; a message goes out when something changed.
NS.SEND_INTERVAL = 2
-- Seconds between messages when nothing changed (keeps the member "alive").
NS.HEARTBEAT = 20
-- Seconds without any message before a member is dropped from the map.
NS.TIMEOUT = 60

-- Every setting with its default.  "share*" is what I send, the rest is what
-- I see.  Everything is on by default except the name labels.
NS.DEFAULTS = {
	broadcast = true,
	shareHealth = true,
	sharePower = true,
	shareXP = true,
	display = true,
	deathMarkers = true,
	iconSize = 20,        -- pixels
	iconZoom = 30,        -- percent of the race icon cropped away (hides its rim)
	instanceAlpha = 80,   -- percent opacity for members inside an instance
	ring = true,
	ringWidth = 1,        -- pixels
	labels = false,
	labelFont = "friz",
	labelSize = 10,
	labelOutline = "none",
	labelPosition = "below",
	labelOffset = 1,      -- pixels between icon and label
	labelClassColor = true,
	showHealth = true,
	showPower = true,
	showXP = true,
}

-- Allowed ranges for the numeric settings (also the slider ranges).
NS.RANGES = {
	iconSize = { 12, 40, 1 },
	iconZoom = { 0, 50, 5 },
	instanceAlpha = { 20, 100, 5 },
	ringWidth = { 1, 4, 1 },
	labelSize = { 6, 20, 1 },
	labelOffset = { 0, 12, 1 },
}

-- Fonts that ship with every client, by key: label, path.
NS.FONTS = {
	{ "friz", "Friz Quadrata (game default)", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
	{ "arial", "Arial Narrow", "Fonts\\ARIALN.TTF" },
	{ "skurri", "Skurri", "Fonts\\skurri.ttf" },
	{ "morpheus", "Morpheus", "Fonts\\MORPHEUS.ttf" },
}

NS.OUTLINES = {
	{ "none", "None (shadow)", "" },
	{ "outline", "Outline", "OUTLINE" },
	{ "thick", "Thick outline", "THICKOUTLINE" },
}

NS.LABEL_POSITIONS = {
	{ "below", "Below the icon" },
	{ "above", "Above the icon" },
}

local function Lookup(list, key, column)
	for _, row in ipairs(list) do
		if row[1] == key then
			return row[column]
		end
	end
	return list[1][column]
end

function NS.FontPath(key)
	return Lookup(NS.FONTS, key, 3)
end

function NS.OutlineFlags(key)
	return Lookup(NS.OUTLINES, key, 3)
end

-------------------------------------------------------------------------------
-- Background detection
--
-- The client has no "window lost focus" API, but it caps the frame rate hard
-- while the window is in the background (the "Max Background FPS" setting,
-- 8 by default).  A smoothed frame time above BACKGROUND_FRAME_TIME therefore
-- means alt-tabbed, or a game that is crawling for another reason; either
-- way the addon should do as little as possible: no position sampling, no
-- map work, incoming messages queued and applied when the game is back.
-------------------------------------------------------------------------------

local BACKGROUND_FRAME_TIME = 0.1
local FRAME_TIME_SMOOTHING = 0.1

local activity = CreateFrame("Frame")
local averageFrameTime = 1 / 60
local inBackground = false

activity:SetScript("OnUpdate", function(_, elapsed)
	averageFrameTime = averageFrameTime + (elapsed - averageFrameTime) * FRAME_TIME_SMOOTHING
	local background = averageFrameTime > BACKGROUND_FRAME_TIME
	if background ~= inBackground then
		inBackground = background
		if not background and NS.Comm and NS.Comm.OnForeground then
			NS.Comm:OnForeground()
		end
	end
end)

function NS.IsBackground()
	return inBackground
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cff9ecbffMauGuildMap:|r " .. tostring(msg))
end

-- "Name-Realm" -> "Name".  Guild members are on the same or a connected
-- realm, so the short name is the key used everywhere.
function NS.ShortName(name)
	if not name or name == "" then
		return nil
	end
	if Ambiguate then
		return Ambiguate(name, "short")
	end
	return name:match("^([^%-]+)") or name
end

function NS.ClassColor(classFile)
	local color
	if C_ClassColor and C_ClassColor.GetClassColor then
		color = C_ClassColor.GetClassColor(classFile)
	end
	if not color and RAID_CLASS_COLORS then
		color = RAID_CLASS_COLORS[classFile]
	end
	if color then
		return color.r or 1, color.g or 1, color.b or 1
	end
	return 1, 1, 1
end

function NS.ClassName(classFile, sex)
	local names = (sex == 3) and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
	local name = names and names[classFile]
	if name then
		return name
	end
	classFile = classFile or ""
	return classFile:sub(1, 1):upper() .. classFile:sub(2):lower()
end

-- "NightElf" -> "Night Elf", "Scourge" -> "Undead".
function NS.RaceName(raceFile)
	if not raceFile or raceFile == "" then
		return "Unknown"
	end
	if raceFile == "Scourge" then
		return "Undead"
	end
	return (raceFile:gsub("(%l)(%u)", "%1 %2"))
end

-- Atlas name of Blizzard's round race icon, or nil if the client lacks it.
function NS.RaceAtlas(raceFile, sex)
	if not raceFile or raceFile == "" or not GetRaceAtlas then
		return nil
	end
	local gender = (sex == 3) and "female" or "male"
	local atlas = GetRaceAtlas(string.lower(raceFile), gender)
	if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
		return atlas
	end
	return nil
end

function NS.FormatAge(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds < 60 then
		return string.format("%d s ago", seconds)
	end
	return string.format("%d min ago", math.floor(seconds / 60))
end

function NS.FormatNumber(n)
	n = math.floor(tonumber(n) or 0)
	if BreakUpLargeNumbers then
		return BreakUpLargeNumbers(n)
	end
	return tostring(n)
end

function NS.MapName(mapID)
	if mapID and mapID > 0 and C_Map and C_Map.GetMapInfo then
		local info = C_Map.GetMapInfo(mapID)
		if info and info.name then
			return info.name
		end
	end
	return nil
end

function NS.MaxLevel()
	if GetMaxLevelForPlayerExpansion then
		local level = GetMaxLevelForPlayerExpansion()
		if level and level > 0 then
			return level
		end
	end
	if GetMaxPlayerLevel then
		return GetMaxPlayerLevel() or 60
	end
	return 60
end

-- A plain integer, or nil when the value is missing or protected.  On this
-- client unit health and power can come back as "secret" values in combat;
-- those cannot be read, formatted or sent, so they are treated as unknown.
function NS.SafeNumber(value)
	if value == nil then
		return nil
	end
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	if type(value) ~= "number" then
		return nil
	end
	local ok, result = pcall(math.floor, value)
	if ok then
		return result
	end
	return nil
end

local POWER_NAMES = {
	[0] = { "Mana", "MANA" },
	[1] = { "Rage", "RAGE" },
	[2] = { "Focus", "FOCUS" },
	[3] = { "Energy", "ENERGY" },
	[6] = { "Runic Power", "RUNIC_POWER" },
}

-- Display name and colour of a power type number (Enum.PowerType).
function NS.PowerInfo(powerType)
	local info = POWER_NAMES[powerType or -1]
	local name = info and info[1] or "Power"
	local color = info and PowerBarColor and PowerBarColor[info[2]]
	if color then
		return name, color.r or 1, color.g or 1, color.b or 1
	end
	return name, 1, 1, 1
end

function NS.Colorize(text, r, g, b)
	return string.format("|cff%02x%02x%02x%s|r", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255, text)
end

-- Green above half, yellow above a quarter, red below.
function NS.HealthColor(fraction)
	if fraction >= 0.5 then
		return 0.2, 1, 0.2
	elseif fraction >= 0.25 then
		return 1, 0.85, 0.2
	end
	return 1, 0.3, 0.3
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauGuildMapDB = MauGuildMapDB or {}
	MauGuildMapDB.settings = MauGuildMapDB.settings or {}
	local s = MauGuildMapDB.settings
	for key, default in pairs(NS.DEFAULTS) do
		if s[key] == nil or type(s[key]) ~= type(default) then
			s[key] = default
		end
	end
	for key, range in pairs(NS.RANGES) do
		s[key] = math.max(range[1], math.min(range[2], s[key]))
	end
	-- 0.2.x stored the icon size as a scale factor.
	s.pinScale = nil
end

-- The settings table is handed to the Settings panel by reference, so it
-- must be created once and never replaced.
function NS.GetSettings()
	if not MauGuildMapDB or not MauGuildMapDB.settings then
		NS.InitDB()
	end
	return MauGuildMapDB.settings
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			NS.InitDB()
		end
	elseif event == "PLAYER_LOGIN" then
		NS.InitDB()
		NS.Roster:Start()
		NS.Comm:Start()
		NS.Map:TryInit()
		NS.Options:Register()
	elseif event == "PLAYER_LOGOUT" then
		NS.Comm:SendBye()
	end
end)

-------------------------------------------------------------------------------
-- Slash command: /mgm opens the options.  "test" and "list" exist for
-- development and are deliberately not announced anywhere.
-------------------------------------------------------------------------------

SLASH_MAUGUILDMAP1 = "/mgm"
SLASH_MAUGUILDMAP2 = "/mauguildmap"
SlashCmdList.MAUGUILDMAP = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "test" then
		NS.Test:Toggle()
	elseif msg == "list" then
		NS.Roster:PrintList()
	else
		NS.Options:Open()
	end
end
