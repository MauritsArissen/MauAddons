-- MauCookie: Cookie Clicker in game.
--
-- Click the big cookie for cookies, spend them on buildings that bake
-- cookies every second (prices rise 15% per building), buy upgrades that
-- double a building's output, click the golden cookie when it shows up for
-- a frenzy or a lucky windfall, collect achievements (each one adds 1% to
-- production), and ascend for heavenly chips once the numbers get big.
-- The bakery keeps running while the window is closed, as long as you are
-- logged in; nothing happens while you are logged out.  Data.lua holds the
-- buildings, upgrades, heavenly upgrades and achievements, Game.lua the
-- rules and the tick, Comm.lua the guild board, UI.lua the window,
-- Options.lua the settings page.  /mck toggles the window.  See CLAUDE.md.

local ADDON_NAME, NS = ...
_G.MauCookie = NS

NS.ADDON_NAME = ADDON_NAME

NS.DEFAULTS = {
	sounds = true,
	popups = true,          -- "+1" texts on the cookie
	shareScores = true,     -- guild board
	autoOpenTaxi = true,    -- open the bakery when a flight path starts
	autoOpenFlying = true,  -- and when flying on a mount
	autoClose = true,       -- close it again when the flight ends (only if it opened itself)
	minimapButton = true,
	minimapAngle = 200,     -- degrees around the minimap
	scale = 100,
}

NS.RANGES = {
	scale = { 60, 150, 5 },
}

NS.PRICE_GROWTH = 1.15
NS.PRESTIGE_BASE = 1e10     -- prestige level = cube root of (all cookies ever / this)
NS.ART_ROOT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cffd9a066MauCookie:|r " .. tostring(msg))
end

function NS.Guard(where, f, ...)
	local ok, err = pcall(f, ...)
	if not ok then
		NS.Print("|cffff3333Error in %s:|r %s", where, tostring(err))
	end
	return ok
end

function NS.PlayKit(key)
	if not key or not NS.GetSettings().sounds or not SOUNDKIT or not SOUNDKIT[key] then
		return
	end
	PlaySound(SOUNDKIT[key])
end

function NS.Clamp(value, lo, hi)
	return math.max(lo, math.min(hi, value))
end

function NS.Now()
	if GetServerTime then
		return GetServerTime()
	end
	return time()
end

function NS.Commas(n)
	n = math.floor((n or 0) + 0.5)
	local s = string.format("%.0f", math.abs(n))
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (n < 0 and "-" or "") .. s
end

local NAMES = { "million", "billion", "trillion", "quadrillion", "quintillion", "sextillion", "septillion", "octillion", "nonillion", "decillion", "undecillion", "duodecillion" }
local SHORT = { "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd" }

-- 1234 -> "1,234"; 1234567 -> "1.235 million" (short: "1.235M").
function NS.Beautify(n, short)
	n = math.floor(n or 0)
	if n < 1e6 then
		return NS.Commas(n)
	end
	local e = NS.Clamp(math.floor(math.log10(n) / 3) - 1, 1, #NAMES)
	local v = n / (10 ^ (3 * (e + 1)))
	local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
	if short then
		return s .. SHORT[e]
	end
	return s .. " " .. NAMES[e]
end

-- Rates keep a decimal while they are small.
function NS.BeautifyRate(x, short)
	x = x or 0
	if x < 100 then
		local s = string.format("%.1f", x):gsub("%.0$", "")
		return s
	end
	return NS.Beautify(x, short)
end

function NS.FormatDuration(seconds)
	seconds = math.floor(seconds or 0)
	if seconds < 60 then
		return string.format("%d s", seconds)
	elseif seconds < 3600 then
		return string.format("%d min", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%d h %d min", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
	end
	return string.format("%d d %d h", math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600))
end

-- "Name-Realm" -> "Name"
function NS.ShortName(name)
	if not name or name == "" then
		return nil
	end
	return (name:match("^([^%-]+)"))
end

function NS.ClassColor(classFile)
	local color
	if classFile and C_ClassColor and C_ClassColor.GetClassColor then
		color = C_ClassColor.GetClassColor(classFile)
	end
	if not color and classFile and RAID_CLASS_COLORS then
		color = RAID_CLASS_COLORS[classFile]
	end
	if color then
		return color.r, color.g, color.b
	end
	return 0.8, 0.8, 0.8
end

-- Path of an image in the addon's Textures folder.  Without an extension
-- the client looks for .blp and .tga only (a .png would have to be named
-- in full), so the images are TGA.
function NS.Art(key)
	return NS.ART_ROOT .. key .. ".tga"
end

-- A cell of the original icon sheet, cut into Texturesicon_<col>_<row>.tga
-- (48 px inside a 64 px square, so draw it with NS.ICON_INSET texcoords).
NS.ICON_INSET = 8 / 64
function NS.Icon(cell)
	return NS.ART_ROOT .. "icon_" .. cell[1] .. "_" .. cell[2] .. ".tga"
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.NewSave()
	return {
		cookies = 0, baked = 0, clicks = 0, handmade = 0,
		buildings = {}, upgrades = {}, achievements = {},
		golden = 0, playTime = 0, started = NS.Now(),
		prestige = 0, chips = 0, heavenly = {}, allTime = 0, ascensions = 0,
		wrinklers = {}, wrinklersPopped = 0, pledges = 0, pledgeUntil = 0, covenant = false, covenantEver = false,
		researchReadyAt = 0, goldenSwitch = false, sold = 0, grandmasSold = 0, chains = 0,
	}
end

function NS.InitDB()
	MauCookieDB = MauCookieDB or {}
	local db = MauCookieDB
	db.settings = db.settings or {}
	for key, default in pairs(NS.DEFAULTS) do
		if db.settings[key] == nil or type(db.settings[key]) ~= type(default) then
			db.settings[key] = default
		end
	end
	for key, range in pairs(NS.RANGES) do
		db.settings[key] = NS.Clamp(db.settings[key], range[1], range[2])
	end
	db.save = db.save or NS.NewSave()
	local s = db.save
	for key, default in pairs(NS.NewSave()) do
		if type(s[key]) ~= type(default) then
			s[key] = default
		end
	end
	db.guild = db.guild or {}   -- guild name -> player name -> record (Comm.lua)
end

function NS.GetSettings()
	if not MauCookieDB or not MauCookieDB.settings then
		NS.InitDB()
	end
	return MauCookieDB.settings
end

-------------------------------------------------------------------------------
-- Events, slash command, key bindings, addon compartment
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			NS.InitDB()
		end
	elseif event == "PLAYER_LOGIN" then
		NS.InitDB()
		NS.Game:Start()
		NS.Comm:Start()
		NS.Minimap:Create()
		NS.Options:Register()
	end
end)

SLASH_MAUCOOKIE1 = "/mck"
SLASH_MAUCOOKIE2 = "/cookie"
SLASH_MAUCOOKIE3 = "/maucookie"
SlashCmdList.MAUCOOKIE = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "options" or msg == "config" or msg == "settings" then
		NS.Options:Open()
	else
		NS.UI:Toggle()
	end
end

BINDING_HEADER_MAUCOOKIE = "MauCookie"
BINDING_NAME_MAUCOOKIE_TOGGLE = "MauCookie: open or close the bakery"
BINDING_NAME_MAUCOOKIE_CLICK = "MauCookie: click the cookie"

function MauCookie_OnAddonCompartmentClick()
	NS.UI:Toggle()
end
