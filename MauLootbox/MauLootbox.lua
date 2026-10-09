-- MauLootbox: every loot window becomes a lootbox.
--
-- Blizzard's loot window is kept from opening; instead, when loot is
-- available, a single-column slot machine reel (Reel.lua) spins once per item
-- and lands on it, and only then is the item taken (Loot.lua).  Coins and
-- items below a chosen quality are taken at once.  The game's own auto-loot
-- is switched off while the addon is enabled, because the client takes
-- everything the instant the window opens when it is on and nothing can
-- delay that from Lua; the addon does the auto-looting itself after the
-- show.  Options live in Settings > AddOns (Options.lua); /mlb opens them,
-- /mlb test plays a demo with made-up items.  See CLAUDE.md.

local ADDON_NAME, NS = ...
_G.MauLootbox = NS

NS.ADDON_NAME = ADDON_NAME

NS.DEFAULTS = {
	enabled = true,
	minQuality = 0,         -- Enum.ItemQuality; items below are taken without a spin
	coinsInstant = true,    -- money is taken without a spin
	speed = 100,            -- percent; lower is faster
	sounds = true,
	autoConfirmBind = true, -- confirm bind-on-pickup by ourselves when not in a group
	scale = 100,            -- percent
}

NS.RANGES = {
	speed = { 50, 200, 10 },
	scale = { 60, 150, 5 },
}

NS.QUALITIES = {
	{ 0, "Poor (everything spins)" },
	{ 1, "Common" },
	{ 2, "Uncommon" },
	{ 3, "Rare" },
	{ 4, "Epic" },
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cff9ecbffMauLootbox:|r " .. tostring(msg))
end

-- Step-by-step chat output, toggled with /mlb debug (MauLootboxDB.debug).
function NS.Debug(fmt, ...)
	if MauLootboxDB and MauLootboxDB.debug then
		NS.Print("|cff808080" .. string.format(fmt, ...) .. "|r")
	end
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

function NS.QualityColor(quality)
	quality = quality or 1
	if C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then
			return r, g, b
		end
	end
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then
		return color.r or 1, color.g or 1, color.b or 1
	end
	return 1, 1, 1
end

function NS.QualityName(quality)
	local name = _G["ITEM_QUALITY" .. tostring(quality or 1) .. "_DESC"]
	return name or "Item"
end

-- Does the game's own auto-loot flag say "take everything at once"?
function NS.GameAutoLootOn()
	return GetCVarBool and GetCVarBool("autoLootDefault") or false
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauLootboxDB = MauLootboxDB or {}
	MauLootboxDB.settings = MauLootboxDB.settings or {}
	local s = MauLootboxDB.settings
	for key, default in pairs(NS.DEFAULTS) do
		if s[key] == nil or type(s[key]) ~= type(default) then
			s[key] = default
		end
	end
	for key, range in pairs(NS.RANGES) do
		s[key] = math.max(range[1], math.min(range[2], s[key]))
	end
	MauLootboxDB.position = MauLootboxDB.position or nil
end

function NS.GetSettings()
	if not MauLootboxDB or not MauLootboxDB.settings then
		NS.InitDB()
	end
	return MauLootboxDB.settings
end

-------------------------------------------------------------------------------
-- Taking over from Blizzard's loot window and the game's auto-loot
--
-- LootFrame's OnHide calls CloseLoot(), so it must never open while we run
-- the show: its LOOT_OPENED registration is removed.  The autoLootDefault
-- option is remembered and switched off; it is restored when the addon is
-- disabled in its options.
-------------------------------------------------------------------------------

function NS.ApplyTakeover()
	local settings = NS.GetSettings()
	if not LootFrame then
		return
	end
	if settings.enabled then
		LootFrame:UnregisterEvent("LOOT_OPENED")
		if GetCVar and SetCVar then
			local current = GetCVar("autoLootDefault")
			if current == "1" then
				MauLootboxDB.savedAutoLoot = current
				SetCVar("autoLootDefault", "0")
			end
		end
	else
		LootFrame:RegisterEvent("LOOT_OPENED")
		if MauLootboxDB.savedAutoLoot and SetCVar then
			SetCVar("autoLootDefault", MauLootboxDB.savedAutoLoot)
			MauLootboxDB.savedAutoLoot = nil
		end
	end
end

-------------------------------------------------------------------------------
-- Events and slash command
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
		NS.ApplyTakeover()
		NS.Loot:Start()
		NS.Options:Register()
	end
end)

SLASH_MAULOOTBOX1 = "/mlb"
SLASH_MAULOOTBOX2 = "/maulootbox"
SlashCmdList.MAULOOTBOX = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "test" then
		NS.Test:Run()
	elseif msg == "debug" then
		MauLootboxDB.debug = not MauLootboxDB.debug
		NS.Print("Debug output %s.", MauLootboxDB.debug and "on: loot something and the steps are printed here" or "off")
	else
		NS.Options:Open()
	end
end
