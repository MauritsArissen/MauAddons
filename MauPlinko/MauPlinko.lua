-- MauPlinko: Plinko in game, for whenever you are bored.
--
-- A ball drops down a board of pegs, bounces left or right at every row and
-- lands in one of the buckets at the bottom, each of which pays a multiple of
-- the bet (Tables.lua).  Bets are placed in chips, a made-up currency that
-- lives in the saved variables and has nothing to do with gold; when the bank
-- runs dry a top-up is one click away.  Game.lua holds the rules and the
-- bank, Board.lua draws the pegs, buckets and bouncing balls, UI.lua is the
-- window around it, Comm.lua shares scores with guild members who run the
-- addon and Options.lua is the page in Settings > AddOns.  /mpk toggles the
-- window, /mpk options opens the settings.  See CLAUDE.md.

local ADDON_NAME, NS = ...
_G.MauPlinko = NS

NS.ADDON_NAME = ADDON_NAME

NS.START_BALANCE = 1000
NS.TOP_UP = 1000
NS.MIN_BET = 10
NS.MAX_BET = 1000000
NS.MAX_BALLS = 40        -- in flight at the same time
NS.HISTORY_SIZE = 12

NS.DEFAULTS = {
	sounds = true,
	pegSounds = true,       -- the tick on every peg
	speed = 100,            -- percent; higher makes the balls fall faster
	autoDelay = 0.3,        -- seconds between balls in auto mode
	scale = 100,            -- percent
	shareScores = true,     -- send best hit, drops and net to guild members
	announceGuild = false,  -- post big hits in guild chat
	announceFrom = 100,     -- multiplier from which a hit counts as big
}

NS.RANGES = {
	speed = { 50, 200, 10 },
	autoDelay = { 0.1, 1, 0.05 },
	scale = { 60, 150, 5 },
	announceFrom = { 10, 1000, 10 },
}

-- Where the player left the board last time (MauPlinkoDB.game).
NS.GAME_DEFAULTS = {
	bet = 10,
	risk = "medium",
	rows = 12,
	autoCount = 10,
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cffffd100MauPlinko:|r " .. tostring(msg))
end

-- Run f and report any Lua error in chat, so a failure shows up even when
-- the game's script error display is off.
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

function NS.Round(x)
	return math.floor(x + 0.5)
end

-- 1234567 -> "1,234,567"
function NS.Commas(n)
	n = NS.Round(n or 0)
	local s = tostring(math.abs(n))
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (n < 0 and "-" or "") .. s
end

-- "+1,234", "-56" or "0"
function NS.Signed(n)
	n = NS.Round(n or 0)
	if n > 0 then
		return "+" .. NS.Commas(n)
	end
	return NS.Commas(n)
end

-- Multipliers are written the way the tables have them: 0.2, 1.1, 26, 1000.
function NS.FormatMult(m)
	m = m or 0
	if m >= 100 or m == math.floor(m) then
		return string.format("%d", m)
	end
	return string.format("%.1f", m)
end

-- Probability 0..1 as text with as many decimals as it needs.
function NS.FormatPercent(p)
	p = (p or 0) * 100
	if p >= 10 then
		return string.format("%.1f%%", p)
	elseif p >= 1 then
		return string.format("%.2f%%", p)
	elseif p >= 0.01 then
		return string.format("%.3f%%", p)
	end
	return string.format("%.5f%%", p)
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

function NS.NewStats()
	return {
		drops = 0,
		wagered = 0,
		returned = 0,
		bestMult = 0,
		bestMultRows = 0,
		bestMultRisk = nil,
		bestWin = 0,
		bestWinBet = 0,
		bestWinMult = 0,
		hist = {},          -- hist[rows][bucket] = landings
	}
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauPlinkoDB = MauPlinkoDB or {}
	local db = MauPlinkoDB

	db.settings = db.settings or {}
	for key, default in pairs(NS.DEFAULTS) do
		if db.settings[key] == nil or type(db.settings[key]) ~= type(default) then
			db.settings[key] = default
		end
	end
	for key, range in pairs(NS.RANGES) do
		db.settings[key] = math.max(range[1], math.min(range[2], db.settings[key]))
	end

	db.game = db.game or {}
	for key, default in pairs(NS.GAME_DEFAULTS) do
		if type(db.game[key]) ~= type(default) then
			db.game[key] = default
		end
	end
	if not NS.TABLES[db.game.risk] then
		db.game.risk = NS.GAME_DEFAULTS.risk
	end
	db.game.rows = math.max(NS.MIN_ROWS, math.min(NS.MAX_ROWS, math.floor(db.game.rows)))
	db.game.bet = math.max(NS.MIN_BET, math.min(NS.MAX_BET, math.floor(db.game.bet)))
	db.game.autoCount = math.max(0, math.floor(db.game.autoCount))

	db.bank = db.bank or {}
	if type(db.bank.balance) ~= "number" then
		db.bank.balance = NS.START_BALANCE
	end
	db.bank.topUps = db.bank.topUps or 0

	db.stats = db.stats or NS.NewStats()
	for key, default in pairs(NS.NewStats()) do
		if db.stats[key] == nil then
			db.stats[key] = default
		end
	end
	db.history = db.history or {}
end

function NS.GetSettings()
	if not MauPlinkoDB or not MauPlinkoDB.settings then
		NS.InitDB()
	end
	return MauPlinkoDB.settings
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
		NS.Comm:Start()
	elseif event == "PLAYER_LOGOUT" then
		-- Balls still in the air are paid out so the bank is saved complete.
		NS.Game:SettleAll()
	end
end)

SLASH_MAUPLINKO1 = "/mpk"
SLASH_MAUPLINKO2 = "/plinko"
SLASH_MAUPLINKO3 = "/mauplinko"
SlashCmdList.MAUPLINKO = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "options" or msg == "config" or msg == "settings" then
		NS.Options:Open()
	elseif msg == "drop" then
		NS.Game:DropFromBinding()
	else
		NS.UI:Toggle()
	end
end

-- Key bindings (Bindings.xml) show these names in the key binding settings.
BINDING_HEADER_MAUPLINKO = "MauPlinko"
BINDING_NAME_MAUPLINKO_TOGGLE = "MauPlinko: open or close the board"
BINDING_NAME_MAUPLINKO_DROP = "MauPlinko: drop a ball"

-- Entry in the minimap's addon compartment (## AddonCompartmentFunc).
function MauPlinko_OnAddonCompartmentClick()
	NS.UI:Toggle()
end
