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
	-- broadcast: send my own position to the guild.  display: draw the others.
	if s.broadcast == nil then
		s.broadcast = true
	end
	if s.display == nil then
		s.display = true
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
	elseif msg == "disable" then
		settings.display = false
		NS.Map:RequestRefresh()
		NS.Print("Display off: other members are no longer drawn on the map. /mgm enable turns it back on.")
	elseif msg == "enable" then
		settings.display = true
		NS.Map:RequestRefresh()
		NS.Print("Display on.")
	elseif msg == "list" then
		NS.Roster:PrintList()
	else
		NS.Print("%d guild member(s) known%s. Sending my position: %s. Showing others: %s.",
			NS.Roster:Count(),
			IsInGuild() and "" or " (you are not in a guild)",
			settings.broadcast and "|cff33ff33on|r" or "|cffff3333off|r",
			settings.display and "|cff33ff33on|r" or "|cffff3333off|r")
		local function Line(command, text)
			print(string.format("  |cffffd100%s|r - %s", command, text))
		end
		Line("/mgm hide", "stop sending your position to the guild")
		Line("/mgm show", "send your position again")
		Line("/mgm disable", "stop showing other members on the map")
		Line("/mgm enable", "show other members again")
		Line("/mgm list", "who is known, where they are and when they last updated")
		Line("/mgm test", "simulate three members for about two minutes (run again to stop)")
	end
end
