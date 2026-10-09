-- MauPeggle: Peggle in game.
--
-- A board of pegs, a launcher at the top, ten balls.  Aim with the mouse,
-- click to shoot; the ball bounces off pegs and walls under gravity and
-- lights every peg it touches, lit pegs are cleared when the ball is gone.
-- Clear all the orange pegs to finish the level: the last one starts the
-- fever and the ball drops into a bonus bin.  A moving bucket at the bottom
-- catches the ball for a free ball, 25,000 points in one shot gives another.
-- Green pegs trigger a power, the purple peg is worth extra and moves every
-- shot.  Physics.lua is the simulation, Levels.lua the boards, Game.lua the
-- rules and scoring, Comm.lua the guild board, Board.lua the drawing,
-- UI.lua the window, Options.lua the settings page.  /pgl toggles the
-- window.  See CLAUDE.md.

local ADDON_NAME, NS = ...
_G.MauPeggle = NS

NS.ADDON_NAME = ADDON_NAME

NS.DEFAULTS = {
	sounds = true,
	popups = true,          -- "+120" at every lit peg
	slowmo = true,          -- slow motion when the last orange peg falls
	scale = 100,            -- percent
	shareScores = true,     -- guild board: send and relay scores
	powerMode = "level",    -- "level": each level's own power; "chosen": always chosenPower
	chosenPower = "guide",
}

NS.RANGES = {
	scale = { 60, 150, 5 },
}

NS.POWERS = { "guide", "multiball", "fire", "blast", "spooky", "flower" }
NS.POWER_INFO = {
	guide = { name = "Super Guide", desc = "A green peg shows the whole path of the ball, bounces included, for the next three shots." },
	multiball = { name = "Multiball", desc = "A green peg splits off a second ball." },
	fire = { name = "Fireball", desc = "A green peg turns the next ball into a fireball that burns straight through every peg in its way." },
	blast = { name = "Space Blast", desc = "A green peg lights every peg around it." },
	spooky = { name = "Spooky Ball", desc = "A green peg makes the ball come back in from the top once it falls off the bottom." },
	flower = { name = "Flower Power", desc = "A green peg lights one in ten of the pegs still on the board." },
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cffff9a3cMauPeggle:|r " .. tostring(msg))
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

function NS.Commas(n)
	n = math.floor((n or 0) + 0.5)
	local s = tostring(math.abs(n))
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (n < 0 and "-" or "") .. s
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

function NS.Now()
	if GetServerTime then
		return GetServerTime()
	end
	return time()
end

function NS.NewStats()
	return { levelsCleared = 0, shots = 0, pegs = 0, fevers = 0, freeBalls = 0, bestShot = 0, bestLevel = 0 }
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauPeggleDB = MauPeggleDB or {}
	local db = MauPeggleDB
	db.settings = db.settings or {}
	for key, default in pairs(NS.DEFAULTS) do
		if db.settings[key] == nil or type(db.settings[key]) ~= type(default) then
			db.settings[key] = default
		end
	end
	for key, range in pairs(NS.RANGES) do
		db.settings[key] = NS.Clamp(db.settings[key], range[1], range[2])
	end
	if db.settings.powerMode ~= "level" and db.settings.powerMode ~= "chosen" then
		db.settings.powerMode = "level"
	end
	if not NS.POWER_INFO[db.settings.chosenPower] then
		db.settings.chosenPower = NS.DEFAULTS.chosenPower
	end

	db.progress = db.progress or {}
	local p = db.progress
	p.unlocked = math.max(1, math.floor(p.unlocked or 1))
	p.last = math.max(1, math.min(p.unlocked, math.floor(p.last or 1)))
	p.best = p.best or {}
	p.total = p.total or 0
	if not p.updated then
		-- Existing progress from before the guild board gets a timestamp so it
		-- can be shared.
		p.updated = next(p.best) and NS.Now() or 0
	end

	db.stats = db.stats or NS.NewStats()
	for key, default in pairs(NS.NewStats()) do
		if type(db.stats[key]) ~= "number" then
			db.stats[key] = default
		end
	end
	db.guild = db.guild or {}   -- guild name -> player name -> record (Comm.lua)
end

function NS.GetSettings()
	if not MauPeggleDB or not MauPeggleDB.settings then
		NS.InitDB()
	end
	return MauPeggleDB.settings
end

-------------------------------------------------------------------------------
-- Events, slash command, key binding, addon compartment
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
		NS.Options:Register()
	end
end)

SLASH_MAUPEGGLE1 = "/pgl"
SLASH_MAUPEGGLE2 = "/peggle"
SLASH_MAUPEGGLE3 = "/maupeggle"
SlashCmdList.MAUPEGGLE = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "options" or msg == "config" or msg == "settings" then
		NS.Options:Open()
	else
		NS.UI:Toggle()
	end
end

BINDING_HEADER_MAUPEGGLE = "MauPeggle"
BINDING_NAME_MAUPEGGLE_TOGGLE = "MauPeggle: open or close the game"

function MauPeggle_OnAddonCompartmentClick()
	NS.UI:Toggle()
end
