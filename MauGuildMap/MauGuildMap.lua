-- MauGuildMap: guild members on the world map.
--
-- Every guild member running this addon broadcasts a tiny position message
-- on the guild addon channel (Comm.lua).  Everyone else keeps those in a
-- roster (Roster.lua) and draws a race icon per member on Blizzard's world
-- map (MapPins.lua).  Members inside a dungeon are drawn at the spot where
-- they entered it.  /mgm test simulates a few members (Test.lua).
-- See CLAUDE.md for the full picture.

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

function NS.MapName(mapID)
	if mapID and mapID > 0 and C_Map and C_Map.GetMapInfo then
		local info = C_Map.GetMapInfo(mapID)
		if info and info.name then
			return info.name
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauGuildMapDB = MauGuildMapDB or {}
	MauGuildMapDB.settings = MauGuildMapDB.settings or {}
	local s = MauGuildMapDB.settings
	if s.broadcast == nil then
		s.broadcast = true
	end
end

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
		NS.Roster:Start()
		NS.Comm:Start()
		NS.Map:TryInit()
	elseif event == "PLAYER_LOGOUT" then
		NS.Comm:SendBye()
	end
end)

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_MAUGUILDMAP1 = "/mgm"
SLASH_MAUGUILDMAP2 = "/mauguildmap"
SlashCmdList.MAUGUILDMAP = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local settings = NS.GetSettings()
	if msg == "test" then
		NS.Test:Toggle()
	elseif msg == "hide" then
		settings.broadcast = false
		NS.Comm:SendBye()
		NS.Print("Broadcasting off: guild members no longer see you. /mgm show turns it back on.")
	elseif msg == "show" then
		settings.broadcast = true
		NS.Comm:ForceSend()
		NS.Print("Broadcasting on.")
	elseif msg == "list" then
		NS.Roster:PrintList()
	else
		NS.Print("%d guild member(s) on the map, broadcasting %s%s.",
			NS.Roster:Count(),
			settings.broadcast and "on" or "off",
			IsInGuild() and "" or " (you are not in a guild)")
		NS.Print("/mgm list - who is shown and where.  /mgm hide | show - stop or resume sending your position.  /mgm test - simulate a few members.")
	end
end
