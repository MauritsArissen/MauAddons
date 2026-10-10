-- MauCookie: Cookie Clicker in game, rebuilt to match the original.
--
-- The data (buildings, upgrades, achievements, heavenly tree, seasons,
-- dragon) is generated from the original's main.js into Data_*.lua; the
-- rules are ported function by function (Game.lua and friends); the window
-- follows the original's three-column layout with its art (UI_*.lua).
-- The bakery runs only while you are logged in, window open or not; nothing
-- is produced while logged out (the user's wish).  Comm.lua is the guild
-- board, Options.lua the settings page.  /mck toggles the window.  See
-- CLAUDE.md for everything.

local ADDON_NAME, NS = ...
_G.MauCookie = NS

NS.ADDON_NAME = ADDON_NAME
NS.SAVE_VERSION = 2

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
	shortNumbers = false,   -- 1.5M instead of 1.5 million
	particles = true,       -- falling cookies and milk animation
}

NS.RANGES = {
	scale = { 50, 150, 5 },
}

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

-- The original's number names (short scale), one per 10^3 from a million.
local NAMES = { "million", "billion", "trillion", "quadrillion", "quintillion", "sextillion", "septillion", "octillion", "nonillion", "decillion", "undecillion", "duodecillion", "tredecillion", "quattuordecillion", "quindecillion", "sexdecillion", "septendecillion", "octodecillion", "novemdecillion", "vigintillion", "unvigintillion", "duovigintillion", "trevigintillion", "quattuorvigintillion", "quinvigintillion", "sexvigintillion", "septenvigintillion", "octovigintillion", "novemvigintillion", "trigintillion" }
local SHORT = { "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "ODc", "NDc", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OVg", "NVg", "Tg" }

-- 1234 -> "1,234"; 1234567 -> "1.235 million" (short: "1.235M").
function NS.Beautify(n, floats)
	n = n or 0
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	local out
	if n < 1e6 then
		if floats and n < 1000 then
			out = string.format("%." .. floats .. "f", n):gsub("0+$", ""):gsub("%.$", "")
		else
			out = NS.Commas(n)
		end
	else
		local e = NS.Clamp(math.floor(math.log10(n) / 3) - 1, 1, #NAMES)
		local v = n / (10 ^ (3 * (e + 1)))
		local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
		if NS.GetSettings().shortNumbers then
			out = s .. SHORT[e]
		else
			out = s .. " " .. NAMES[e]
		end
	end
	return (negative and "-" or "") .. out
end

-- Rates keep a decimal while they are small.
function NS.BeautifyRate(x)
	x = x or 0
	if x < 100 then
		local s = string.format("%.1f", x):gsub("%.0$", "")
		return s
	end
	return NS.Beautify(x)
end

function NS.FormatDuration(seconds)
	seconds = math.floor((seconds or 0) + 0.5)
	if seconds < 60 then
		return string.format("%d second%s", seconds, seconds == 1 and "" or "s")
	elseif seconds < 3600 then
		local m = math.floor(seconds / 60)
		return string.format("%d minute%s", m, m == 1 and "" or "s")
	elseif seconds < 86400 then
		local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
		if m == 0 then
			return string.format("%d hour%s", h, h == 1 and "" or "s")
		end
		return string.format("%d hour%s %d min", h, h == 1 and "" or "s", m)
	end
	local d, h = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600)
	if h == 0 then
		return string.format("%d day%s", d, d == 1 and "" or "s")
	end
	return string.format("%d day%s %d h", d, d == 1 and "" or "s", h)
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

-- A cell of the original icon sheet, cut into Textures\icon_<col>_<row>.tga
-- (48 px inside a 64 px square, so draw it with NS.ICON_INSET texcoords).
NS.ICON_INSET = 8 / 64
function NS.Icon(cell)
	return NS.ART_ROOT .. "icon_" .. cell[1] .. "_" .. cell[2] .. ".tga"
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.NewSave()
	local now = NS.Now()
	return {
		v = NS.SAVE_VERSION,
		cookies = 0, earned = 0, reset = 0, clicks = 0, handmade = 0,
		goldenClicks = 0, goldenClicksLocal = 0, missedGolden = 0, reindeerClicked = 0,
		bld = {}, up = {}, unl = {}, ach = {}, buffs = {}, vault = {}, perma = {},
		prestige = 0, chips = 0, chipsSpent = 0, resets = 0,
		startDate = now, fullDate = now, playTime = 0, runTime = 0,
		pledges = 0, pledgeT = 0, elderWrath = 0, nextResearch = false, researchT = 0,
		season = "", seasonT = 0, seasonUses = 0,
		wrinklers = {}, wrinklersPopped = 0, cookiesSucked = 0,
		santaLevel = 0, dragonLevel = 0, dragonAura = 0, dragonAura2 = 0,
		lumps = -1, lumpsTotal = -1, lumpT = now, lumpRefill = 0, lumpType = 0,
		milkType = 0, bgType = 0, chimeType = 0,
		fortuneGC = false, fortuneCPS = false, tickerClicks = 0,
		onAscend = false, ascensionMode = 0, nextAscensionMode = 0, cpsHighest = 0, sold = 0,
		minigames = {},
	}
end

-- 0.4.0 saves kept ids of their own; the rebuild keys everything by the
-- original's names.  Buildings, upgrades and achievements that exist in
-- the original carry over, cookies and totals carry over, prestige is
-- recomputed with the original's formula (a trillion cookies per level,
-- so it will be lower) and every chip is refunded to spend again.
local OLD_BUILDINGS = {
	cursor = "Cursor", grandma = "Grandma", farm = "Farm", mine = "Mine", factory = "Factory", bank = "Bank", temple = "Temple",
	wizard = "Wizard tower", shipment = "Shipment", alchemy = "Alchemy lab", portal = "Portal", timemachine = "Time machine",
	antimatter = "Antimatter condenser", prism = "Prism", chancemaker = "Chancemaker", fractal = "Fractal engine",
	javascript = "Javascript console", idleverse = "Idleverse", cortex = "Cortex baker", you = "You",
}
local OLD_CURSOR_TIERS = { "Reinforced index finger", "Carpal tunnel prevention cream", "Ambidextrous", "Thousand fingers", "Million fingers" }
local OLD_MICE = { "Plastic mouse", "Iron mouse", "Titanium mouse", "Adamantium mouse", "Unobtainium mouse" }
local OLD_FLAVOURS = { "Plain cookies", "Sugar cookies", "Oatmeal raisin cookies", "Peanut butter cookies", "Coconut cookies", "White chocolate cookies", "Macadamia nut cookies", "Double-chip cookies", "White chocolate macadamia nut cookies", "All-chocolate cookies", "Dark chocolate-coated cookies", "White chocolate-coated cookies" }
local OLD_KITTENS = { "Kitten helpers", "Kitten workers", "Kitten engineers", "Kitten overseers", "Kitten managers", "Kitten accountants", "Kitten specialists", "Kitten experts" }
local OLD_SYNERGIES = { "Future almanacs", "Rain prayer", "Seismic magic", "Asteroid mining", "Quantum electronics", "Temporal overclocking", "Contracts from beyond", "Printing presses", "Paganism", "God particle", "Arcane knowledge", "Magical botany", "Fossil fuels", "Shipyards", "Primordial ores", "Gold fund", "Infernal crops", "Abysmal glimmer", "Relativistic parsec-skipping", "Primeval glow", "Extra physics funding", "Chemical proficiency", "Light magic", "Mystical energies", "Gemmed talismans", "Charm quarks", "Recursive mirrors", "Mice clicking mice", "Boolean fiction", "Reverse-engineered trade routes", "Thoughts & prayers", "Self-help cults" }
local OLD_MISC = {
	luck1 = "Lucky day", luck2 = "Serendipity", luck3 = "Get lucky", bingo = "Bingo center/Research facility",
	research1 = "Specialized chocolate chips", research2 = "Designer cocoa beans", research3 = "Ritual rolling pins", research4 = "Underworld ovens",
	research5 = "One mind", research6 = "Exotic nuts", research7 = "Communal brainsweep", research8 = "Arcane sugar", research9 = "Elder Pact",
	research10 = "Sacrificial rolling pins",
}
local OLD_BAKED = { "Wake and bake", "Making some dough", "So baked right now", "Fledgling bakery", "Affluent bakery", "World-famous bakery", "Cosmic bakery", "Galactic bakery", "Universal bakery", "Timeless bakery", "Infinite bakery", "Immortal bakery", "Don't stop me now", "You can stop now", "Cookies all the way down", "Overdose" }
local OLD_CPS = { "Casual baking", "Hardcore baking", "Steady tasty stream", "Cookie monster", "Mass producer", "Cookie vortex", "Cookie pulsar", "Cookie quasar", "Oh hey, you're still here", "Let's never bake again", "Sacrifice" }
local OLD_HAND = { "Clicktastic", "Clickathlon", "Clickolympics", "Clickorama", "Clickasmic" }
local OLD_TOTAL = { "Builder", "Architect", "Engineer" }
local OLD_GOLDEN = { "Golden cookie", "Lucky cookie", "A stroke of luck", "Fortune", "Leprechaun" }
local OLD_UPG = { "Enhancer", "Augmenter", "Upgrader" }
local OLD_ACH = {
	grandmas50 = "Grandma's cookies", grandmas100 = "Retirement home", cursors100 = "Click delegation", oneofeach = "One with everything",
	asc1 = "Rebirth", elder = "Elder", eldernap = "Elder nap", elderslumber = "Elder slumber", eldercalm = "Elder calm",
	wrinkler1 = "Itchscratcher", wrinkler50 = "Wrinklesquisher", wrinkler200 = "Moistburster", justwrong = "Just wrong", chain = "Four-leaf cookie",
}

function NS.MigrateSave(old)
	local s = NS.NewSave()
	local function num(v)
		return type(v) == "number" and v == v and v or 0
	end
	s.cookies = num(old.cookies)
	s.earned = num(old.baked)
	s.reset = num(old.allTime)
	s.clicks = num(old.clicks)
	s.handmade = num(old.handmade)
	s.goldenClicks = num(old.golden)
	s.playTime = num(old.playTime)
	s.runTime = num(old.playTime)
	s.startDate = num(old.started) > 0 and old.started or s.startDate
	s.fullDate = s.startDate
	s.pledges = num(old.pledges)
	s.wrinklersPopped = num(old.wrinklersPopped)
	s.resets = num(old.ascensions)
	s.sold = num(old.sold)
	local upgrades = type(old.upgrades) == "table" and old.upgrades or {}
	local function own(name)
		if name and NS.U[name] then
			s.up[name] = true
			s.unl[name] = true
		end
	end
	for oldId, name in pairs(OLD_BUILDINGS) do
		local n = num(type(old.buildings) == "table" and old.buildings[oldId])
		if n > 0 then
			s.bld[name] = { n = n, bought = n, highest = n, free = 0, total = 0, level = 0 }
		end
		for tier = 1, 5 do
			if upgrades[oldId .. tier] then
				if oldId == "cursor" then
					own(OLD_CURSOR_TIERS[tier])
				else
					local b = NS.B[name]
					own(b and b.tiered[tier])
				end
			end
		end
		if upgrades["gtype_" .. oldId] and NS.B[name] then
			own(NS.B[name].grandma)
		end
	end
	for i, name in ipairs(OLD_MICE) do if upgrades["mouse" .. i] then own(name) end end
	for i, name in ipairs(OLD_FLAVOURS) do if upgrades["flavour" .. i] then own(name) end end
	for i, name in ipairs(OLD_KITTENS) do if upgrades["kitten" .. i] then own(name) end end
	for i, name in ipairs(OLD_SYNERGIES) do if upgrades["syn" .. i] then own(name) end end
	for oldId, name in pairs(OLD_MISC) do if upgrades[oldId] then own(name) end end
	if old.covenant then
		own("Elder Covenant")
	end
	local achievements = type(old.achievements) == "table" and old.achievements or {}
	local function win(name)
		if name and NS.A[name] then
			s.ach[name] = true
		end
	end
	for i, name in ipairs(OLD_BAKED) do if achievements["baked" .. i] then win(name) end end
	for i, name in ipairs(OLD_CPS) do if achievements["cps" .. i] then win(name) end end
	for i, name in ipairs(OLD_HAND) do if achievements["hand" .. i] then win(name) end end
	for i, name in ipairs(OLD_TOTAL) do if achievements["total" .. i] then win(name) end end
	for i, name in ipairs(OLD_GOLDEN) do if achievements["golden" .. i] then win(name) end end
	for i, name in ipairs(OLD_UPG) do if achievements["upg" .. i] then win(name) end end
	for oldId, name in pairs(OLD_ACH) do if achievements[oldId] then win(name) end end
	-- Grandmapocalypse state.
	local stage = 0
	if upgrades.research5 then stage = 1 end
	if upgrades.research7 then stage = 2 end
	if upgrades.research9 then stage = 3 end
	local pledgeLeft = num(old.pledgeUntil) - num(old.playTime)
	if pledgeLeft > 0 and stage > 0 then
		s.pledgeT = pledgeLeft
		s.up["Elder Pledge"] = true
		s.unl["Elder Pledge"] = true
	elseif not old.covenant then
		s.elderWrath = stage
	end
	if stage > 0 then
		s.unl["Elder Pledge"] = true
	end
	-- Prestige with the original's curve; every chip refunded.
	s.prestige = math.floor((s.reset / 1e12) ^ (1 / 3))
	s.chips = s.prestige
	s.migrated = true
	return s
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
	if db.save and db.save.v ~= NS.SAVE_VERSION and NS.U then
		db.save_v1 = db.save
		db.save = NS.MigrateSave(db.save)
		NS.Print("Your bakery was carried over to the rebuilt game. Prestige now follows the original's formula and every heavenly chip has been refunded to spend again.")
	end
	db.save = db.save or NS.NewSave()
	local s = db.save
	for key, default in pairs(NS.NewSave()) do
		-- nextResearch holds an upgrade name while research runs, false otherwise.
		if s[key] == nil or (key ~= "nextResearch" and type(s[key]) ~= type(default)) then
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
