-- MauCookie: Cookie Clicker in game.
--
-- Click the big cookie for cookies, spend them on buildings that bake
-- cookies every second (prices rise 15% per building), buy upgrades that
-- double a building's output, click the golden cookie when it shows up for
-- a frenzy or a lucky windfall, collect achievements (each one adds 1% to
-- production).  The bakery keeps running while the window is closed, and
-- time spent logged out is paid out at half rate for up to eight hours.
-- Data.lua holds the buildings, upgrades and achievements, Game.lua the
-- rules and the tick, UI.lua the window, Options.lua the settings page.
-- /mck toggles the window.  See CLAUDE.md.

local ADDON_NAME, NS = ...
_G.MauCookie = NS

NS.ADDON_NAME = ADDON_NAME

NS.DEFAULTS = {
	sounds = true,
	popups = true,      -- "+1" texts on the cookie
	offline = true,     -- cookies for time logged out
	scale = 100,
}

NS.RANGES = {
	scale = { 60, 150, 5 },
}

NS.OFFLINE_RATE = 0.5
NS.OFFLINE_CAP = 8 * 3600
NS.PRICE_GROWTH = 1.15

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

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.NewSave()
	local now = NS.Now()
	return {
		cookies = 0, baked = 0, clicks = 0, handmade = 0,
		buildings = {}, upgrades = {}, achievements = {},
		golden = 0, playTime = 0, started = now, lastSeen = now,
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
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			NS.InitDB()
		end
	elseif event == "PLAYER_LOGIN" then
		NS.InitDB()
		NS.Game:Start()
		NS.Options:Register()
	elseif event == "PLAYER_LOGOUT" then
		NS.Game:Save()
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
