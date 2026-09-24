-- MauUndercut: bulk auction posting and vendor-price scanning for
-- World of Warcraft: Forever.
--
-- Forever (1.60.x, interface 16001) runs the modern auction house API
-- (C_AuctionHouse) even though it is a Classic-era world.  This file holds the
-- shared helpers, saved variables, bag scanning and the auction house tab
-- injection.  Poster.lua/UI.lua are the posting tab, Scanner.lua/ScanUI.lua the
-- auction house scanner tab.  See CLAUDE.md for the full picture.

local ADDON_NAME, NS = ...
_G.MauUndercut = NS

NS.ADDON_NAME = ADDON_NAME
NS.TAB_TEXT = "MauUndercut"
NS.SCAN_TAB_TEXT = "MauScan"

local COPPER_PER_SILVER = COPPER_PER_SILVER or 100
local COPPER_PER_GOLD = COPPER_PER_GOLD or 10000

-------------------------------------------------------------------------------
-- Small helpers
-------------------------------------------------------------------------------

function NS.Print(fmt, ...)
	local msg = fmt
	if select("#", ...) > 0 then
		msg = string.format(fmt, ...)
	end
	print("|cff9ecbffMauUndercut:|r " .. tostring(msg))
end

function NS.SupportsCopper()
	if C_AuctionHouse and C_AuctionHouse.SupportsCopperValues then
		return C_AuctionHouse.SupportsCopperValues()
	end
	return true
end

function NS.MinimumPrice()
	return NS.SupportsCopper() and 1 or COPPER_PER_SILVER
end

-- Clamp/round a price so the auction house accepts it.
function NS.SanitizePrice(price)
	price = math.floor((tonumber(price) or 0) + 0.5)
	local minimum = NS.MinimumPrice()
	if price < minimum then
		price = minimum
	end
	if not NS.SupportsCopper() then
		price = math.ceil(price / COPPER_PER_SILVER) * COPPER_PER_SILVER
	end
	return price
end

function NS.FormatMoney(copper)
	copper = math.floor((tonumber(copper) or 0) + 0.5)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
		if ok and text then
			return text
		end
	end
	local gold = math.floor(copper / COPPER_PER_GOLD)
	local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local cop = copper % COPPER_PER_SILVER
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
	end
	if gold > 0 or silver > 0 then
		parts[#parts + 1] = silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
	end
	parts[#parts + 1] = cop .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
	return table.concat(parts, " ")
end

function NS.FormatNumber(n)
	n = math.floor(tonumber(n) or 0)
	if BreakUpLargeNumbers then
		return BreakUpLargeNumbers(n)
	end
	return tostring(n)
end

function NS.FormatAge(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return string.format("%d min ago", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%d h ago", math.floor(seconds / 3600))
	end
	return string.format("%d d ago", math.floor(seconds / 86400))
end

function NS.ColorByQuality(text, quality)
	quality = quality or 1
	if ColorManager and ColorManager.GetColorDataForItemQuality then
		local data = ColorManager.GetColorDataForItemQuality(quality)
		if data and data.color and data.color.WrapTextInColorCode then
			return data.color:WrapTextInColorCode(text)
		end
	end
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local c = ITEM_QUALITY_COLORS[quality]
		if c.color and c.color.WrapTextInColorCode then
			return c.color:WrapTextInColorCode(text)
		elseif c.hex then
			return c.hex .. text .. "|r"
		end
	end
	return text
end

function NS.ItemKeyString(key)
	if not key then
		return "nil"
	end
	return string.format("%d:%d:%d:%d", key.itemID or 0, key.itemLevel or 0, key.itemSuffix or 0, key.battlePetSpeciesID or 0)
end

function NS.SameItemKey(a, b)
	if not a or not b then
		return false
	end
	return a.itemID == b.itemID
		and (a.itemLevel or 0) == (b.itemLevel or 0)
		and (a.itemSuffix or 0) == (b.itemSuffix or 0)
		and (a.battlePetSpeciesID or 0) == (b.battlePetSpeciesID or 0)
end

function NS.StatusText(entry)
	local s = entry and entry.status
	if s == "posted" then
		return "|cff33ff33posted|r"
	elseif s == "pending" then
		return "|cffffd100posting...|r"
	elseif s == "confirm" then
		return "|cffffd100confirm|r"
	elseif s == "failed" then
		return "|cffff3333failed|r"
	elseif s == "skipped" then
		return "|cff999999skipped|r"
	elseif s == "missing" then
		return "|cffff3333not found|r"
	elseif s == "merged" then
		return "|cff33ff33included|r"
	elseif s == "belowvendor" then
		return "|cffff8800below vendor|r"
	end
	return ""
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

function NS.InitDB()
	MauUndercutDB = MauUndercutDB or {}
	MauUndercutDB.prices = MauUndercutDB.prices or {}
	MauUndercutDB.settings = MauUndercutDB.settings or {}
	MauUndercutDB.scan = MauUndercutDB.scan or {}
	-- Data of removed features (0.4 price cache, 0.3 sales ledger); drop it.
	MauUndercutDB.priceCache = nil
	MauUndercutDB.ledger = nil
	local s = MauUndercutDB.settings
	s.tooltip = nil
	if type(s.undercut) ~= "number" or s.undercut < 1 then
		s.undercut = 1
	end
	if type(s.duration) ~= "number" or s.duration < 1 or s.duration > 3 then
		local ok, value = pcall(GetCVar, "auctionHouseDurationDropdown")
		local cvar = ok and tonumber(value) or nil
		s.duration = (cvar and cvar >= 1 and cvar <= 3) and cvar or 2
	end
	local scan = MauUndercutDB.scan
	if type(scan.minProfit) ~= "number" or scan.minProfit < 0 then
		scan.minProfit = 0
	end
	if scan.onlyDeals == nil then
		scan.onlyDeals = false
	end
end

function NS.GetSettings()
	if not MauUndercutDB or not MauUndercutDB.settings then
		NS.InitDB()
	end
	return MauUndercutDB.settings
end

function NS.GetScanSettings()
	if not MauUndercutDB or not MauUndercutDB.scan then
		NS.InitDB()
	end
	return MauUndercutDB.scan
end

-- Undercut amount in copper.  Realms without copper support are forced to
-- whole silver steps.
function NS.GetUndercut()
	local undercut = NS.GetSettings().undercut or 1
	if not NS.SupportsCopper() then
		undercut = math.max(COPPER_PER_SILVER, math.ceil(undercut / COPPER_PER_SILVER) * COPPER_PER_SILVER)
	end
	return undercut
end

function NS.PriceMemoryKey(entry)
	if entry.itemKey then
		return NS.ItemKeyString(entry.itemKey)
	end
	return tostring(entry.itemID)
end

function NS.RememberPrice(entry, price)
	if not MauUndercutDB then
		NS.InitDB()
	end
	MauUndercutDB.prices[NS.PriceMemoryKey(entry)] = { price = price, time = time() }
end

function NS.GetRememberedPrice(entry)
	if not MauUndercutDB then
		NS.InitDB()
	end
	local record = MauUndercutDB.prices[NS.PriceMemoryKey(entry)]
	return record and record.price or nil
end

-- Same fallback Blizzard uses when nothing is listed: vendor price times a
-- multiplier.  Returns 0 when there is no vendor price (user has to type one).
function NS.DefaultPrice(entry)
	if not entry.link then
		return 0
	end
	local vendorPrice = select(11, C_Item.GetItemInfo(entry.link))
	if vendorPrice and vendorPrice > 0 then
		local multiplier = 2
		if Constants and Constants.AuctionConstants and Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER then
			multiplier = Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER
		end
		return NS.SanitizePrice(vendorPrice * multiplier)
	end
	return 0
end

function NS.GetVendorPrice(entry)
	if not entry or not entry.link then
		return nil
	end
	local vendorPrice = select(11, C_Item.GetItemInfo(entry.link))
	return vendorPrice
end

-------------------------------------------------------------------------------
-- Bag scanning
-------------------------------------------------------------------------------

local function GetBagRange()
	local first = 0
	if Enum and Enum.BagIndex and Enum.BagIndex.Backpack then
		first = Enum.BagIndex.Backpack
	elseif BACKPACK_CONTAINER then
		first = BACKPACK_CONTAINER
	end
	local extra = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	return first, first + extra
end

local function EntryName(info, location)
	-- The full name (including random suffixes) is what sale mail reports, so
	-- prefer it; the ledger matches sales by this name.
	local name = C_Item.GetItemName and C_Item.GetItemName(location)
	if name and name ~= "" then
		return name
	end
	if info.itemName and info.itemName ~= "" then
		return info.itemName
	end
	if info.hyperlink then
		name = C_Item.GetItemInfo(info.hyperlink)
		if name then
			return name
		end
	end
	return "item:" .. tostring(info.itemID)
end

-- Returns a sorted list of bag stacks that the auction house will accept.
function NS.ScanBags()
	local items = {}
	local first, last = GetBagRange()
	for bag = first, last do
		local numSlots = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, numSlots do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				if C_Item.DoesItemExist(location) and C_AuctionHouse.IsSellItemValid(location, false) then
					items[#items + 1] = {
						bag = bag,
						slot = slot,
						key = bag .. ":" .. slot,
						itemID = info.itemID,
						link = info.hyperlink,
						name = EntryName(info, location),
						icon = info.iconFileID,
						count = info.stackCount or 1,
						quality = info.quality or 1,
						location = location,
					}
				end
			end
		end
	end
	table.sort(items, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.bag ~= b.bag then
			return a.bag < b.bag
		end
		return a.slot < b.slot
	end)
	return items
end

-- The stack moved (or was partially consumed by a commodity post that pulled
-- from several stacks).  Try to find the same item somewhere else in the bags,
-- avoiding slots that other queued entries still point at.
function NS.RelocateEntry(entry, usedKeys)
	local first, last = GetBagRange()
	for bag = first, last do
		local numSlots = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, numSlots do
			local key = bag .. ":" .. slot
			if not usedKeys[key] then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and info.itemID == entry.itemID and (entry.link == nil or info.hyperlink == entry.link) then
					entry.bag, entry.slot, entry.key = bag, slot, key
					entry.location = ItemLocation:CreateFromBagAndSlot(bag, slot)
					entry.count = info.stackCount or 1
					return true
				end
			end
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- Auction house tabs
-------------------------------------------------------------------------------

NS.tabs = {}

local function GetLibAHTab()
	if LibStub and LibStub.GetLibrary then
		return LibStub:GetLibrary("LibAHTab-1-0", true)
	end
	return nil
end

-- Two integration paths:
--  * If Auctionator (or anything else shipping LibAHTab) is installed we use
--    that library so all the extra tabs line up next to each other.
--  * Otherwise we register a real display mode with Blizzard's frame, which is
--    exactly how the built-in Buy/Sell/Auctions tabs work.
local nativeHooked = false

local function NativeAddTab(id, panel, text)
	local mode = {}
	AuctionHouseFrameDisplayMode[id] = mode

	local tab = CreateFrame("Button", "MauUndercut" .. id .. "Tab", AuctionHouseFrame, "AuctionHouseFrameDisplayModeTabTemplate")
	tab.displayMode = mode
	tab:SetText(text)

	-- PanelTabButtonTemplate has parentArray="Tabs", so the frame is normally
	-- already inside AuctionHouseFrame.Tabs; make sure either way.
	AuctionHouseFrame.Tabs = AuctionHouseFrame.Tabs or {}
	local index
	for i, existing in ipairs(AuctionHouseFrame.Tabs) do
		if existing == tab then
			index = i
		end
	end
	if not index then
		table.insert(AuctionHouseFrame.Tabs, tab)
		index = #AuctionHouseFrame.Tabs
	end
	tab:SetID(index)

	AuctionHouseFrame.tabsForDisplayMode = AuctionHouseFrame.tabsForDisplayMode or {}
	AuctionHouseFrame.tabsForDisplayMode[mode] = index
	PanelTemplates_SetNumTabs(AuctionHouseFrame, #AuctionHouseFrame.Tabs)
	PanelTemplates_TabResize(tab, 20, nil, 70)
	PanelTemplates_DeselectTab(tab)

	panel:Hide()
	table.insert(NS.tabs, { id = id, panel = panel, text = text, mode = mode, button = tab })

	if not nativeHooked then
		nativeHooked = true
		hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(frame)
			local current = frame:GetDisplayMode()
			for _, info in ipairs(NS.tabs) do
				local active = current == info.mode
				info.panel:SetShown(active)
				if active then
					frame:SetTitle(info.text)
				end
			end
		end)
	end
end

function NS.AddTab(id, panel, text)
	local lib = GetLibAHTab()
	if lib then
		lib:CreateTab(id, panel, text, text)
		table.insert(NS.tabs, { id = id, panel = panel, text = text, button = lib:GetButton(id), lib = true })
	else
		NativeAddTab(id, panel, text)
	end
end

function NS.SelectTab(id)
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
		return false
	end
	for _, info in ipairs(NS.tabs) do
		if info.id == id then
			if info.lib then
				GetLibAHTab():SetSelected(id)
			else
				AuctionHouseFrame:SetDisplayMode(info.mode)
			end
			return true
		end
	end
	return false
end

function NS.TryInitAHTab()
	if NS.tabInitialized then
		return
	end
	if not AuctionHouseFrame or not AuctionHouseFrameDisplayMode then
		return
	end
	NS.tabInitialized = true
	NS.AddTab("MauUndercutPost", NS.CreatePanel(AuctionHouseFrame), NS.TAB_TEXT)
	NS.AddTab("MauUndercutScan", NS.CreateScanPanel(AuctionHouseFrame), NS.SCAN_TAB_TEXT)
end

-------------------------------------------------------------------------------
-- Events and slash command
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			NS.InitDB()
		elseif arg1 == "Blizzard_AuctionHouseUI" then
			NS.TryInitAHTab()
		end
	elseif event == "PLAYER_LOGIN" then
		if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
			NS.TryInitAHTab()
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		NS.TryInitAHTab()
	elseif event == "AUCTION_HOUSE_CLOSED" then
		if NS.Poster then
			NS.Poster:OnAuctionHouseClosed()
		end
		if NS.Scanner then
			NS.Scanner:OnAuctionHouseClosed()
		end
	end
end)

SLASH_MAUUNDERCUT1 = "/mauundercut"
SLASH_MAUUNDERCUT2 = "/mu"
SlashCmdList.MAUUNDERCUT = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local id = (msg == "scan") and "MauUndercutScan" or "MauUndercutPost"
	if not NS.SelectTab(id) then
		NS.Print("Open the auction house, then click the %s or %s tab (or use /mu and /mu scan).", NS.TAB_TEXT, NS.SCAN_TAB_TEXT)
	end
end
