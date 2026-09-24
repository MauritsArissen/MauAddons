-- MauUndercut price database.
--
-- One number per item: the lowest unit price seen on the auction house, kept in
-- the saved variables so it survives logouts.  It is fed by
--   * every auction search result that reaches the client, whether the Buy
--     tab, the posting tab or another addon asked for it,
--   * browse results (the list the Buy tab shows before an item is opened),
--   * every full scan (a bulk update of everything in the dump).
-- Vendor purchase prices are recorded from merchant windows so the crafting
-- profit can price vendor-sold reagents.
--
-- Memory rules (the 0.4 price cache was removed because memory grew and the
-- frame rate dropped, see CLAUDE.md section 9): integer item IDs as keys,
-- plain numbers as values, no table per item, no work per frame, no
-- allocation on the tooltip path beyond the text itself.

local _, NS = ...

local Prices = CreateFrame("Frame")
NS.Prices = Prices

-- Bumped on every change; consumers cache against it.
Prices.version = 0

-- Search results are read in full, but never more than this many entries per
-- event; the cheapest listing is at the top of any price-sorted list anyway.
local MAX_RESULTS_PER_EVENT = 1000

local function DB()
	if not MauUndercutDB or not MauUndercutDB.market then
		NS.InitDB()
	end
	return MauUndercutDB
end

-------------------------------------------------------------------------------
-- Reading
-------------------------------------------------------------------------------

-- Lowest auction price per unit in copper and the time it was seen.
function Prices:Get(itemID)
	if not itemID then
		return nil
	end
	local db = DB()
	local price = db.market[itemID]
	if price then
		return price, db.marketTime[itemID]
	end
	return nil
end

-- Price per unit a vendor charges, if a vendor selling it has been visited.
function Prices:GetVendorBuy(itemID)
	if not itemID then
		return nil
	end
	return DB().vendorBuy[itemID]
end

-- Cheapest known way to obtain one unit: auction or vendor, whichever is
-- lower.  nil when neither is known.
function Prices:GetUnitCost(itemID)
	local auction = self:Get(itemID)
	local vendor = self:GetVendorBuy(itemID)
	if auction and vendor then
		return math.min(auction, vendor)
	end
	return auction or vendor
end

function Prices:Count()
	local n = 0
	for _ in pairs(DB().market) do
		n = n + 1
	end
	return n
end

-------------------------------------------------------------------------------
-- Writing
-------------------------------------------------------------------------------

function Prices:Set(itemID, price, now)
	if not itemID or not price or price <= 0 then
		return false
	end
	local db = DB()
	db.market[itemID] = math.floor(price + 0.5)
	db.marketTime[itemID] = now or time()
	return true
end

function Prices:Changed()
	self.version = self.version + 1
	if NS.Crafting and NS.Crafting.OnPricesChanged then
		NS.Crafting:OnPricesChanged()
	end
end

-- Results of a commodity search (any caller).  Lowest unit price wins.
function Prices:RecordCommodityResults(itemID)
	if not itemID then
		return false
	end
	local num = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
	if num == 0 then
		return false
	end
	local best
	for i = 1, math.min(num, MAX_RESULTS_PER_EVENT) do
		local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		local price = result and result.unitPrice
		if price and price > 0 and (not best or price < best) then
			best = price
		end
	end
	return self:Set(itemID, best)
end

-- Results of an item search (any caller).  Variants of the same item ID
-- (suffixes, item levels) share one price: the lowest buyout per unit.
function Prices:RecordItemResults(itemKey)
	local itemID = itemKey and itemKey.itemID
	if not itemID then
		return false
	end
	local num = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
	if num == 0 then
		return false
	end
	local best
	for i = 1, math.min(num, MAX_RESULTS_PER_EVENT) do
		local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		local buyout = result and result.buyoutAmount
		if buyout and buyout > 0 then
			local price = buyout / math.max(result.quantity or 1, 1)
			if not best or price < best then
				best = price
			end
		end
	end
	return self:Set(itemID, best)
end

-- Browse results carry the lowest price per item key straight from the server.
function Prices:RecordBrowseResults(results)
	if type(results) ~= "table" then
		return false
	end
	local now = time()
	local changed = false
	for i = 1, math.min(#results, MAX_RESULTS_PER_EVENT) do
		local result = results[i]
		local key = result and result.itemKey
		if key and key.itemID and result.minPrice and result.minPrice > 0 then
			if self:Set(key.itemID, result.minPrice, now) then
				changed = true
			end
		end
	end
	return changed
end

-- Called by the scanner with its per-item records (rec.low = lowest unit
-- price).  One version bump for the whole batch.
function Prices:UpdateFromScan(byItem)
	if type(byItem) ~= "table" then
		return 0
	end
	local now = time()
	local n = 0
	for itemID, rec in pairs(byItem) do
		if rec.low and rec.low > 0 and self:Set(itemID, rec.low, now) then
			n = n + 1
		end
	end
	if n > 0 then
		self:Changed()
	end
	return n
end

-- Vendor purchase prices from the open merchant window.  Items with an
-- extended cost (currencies, tokens) are ignored.
function Prices:RecordMerchant()
	local num = GetMerchantNumItems and GetMerchantNumItems() or 0
	if num == 0 then
		return
	end
	local db = DB()
	local changed = false
	for i = 1, num do
		local itemID = GetMerchantItemID and GetMerchantItemID(i)
		if itemID then
			local price, stack, extended, currencyID
			if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
				local info = C_MerchantFrame.GetItemInfo(i)
				if info then
					price, stack, extended, currencyID = info.price, info.stackCount, info.hasExtendedCost, info.currencyID
				end
			elseif GetMerchantItemInfo then
				local _, _, p, s, _, _, _, ext, cur = GetMerchantItemInfo(i)
				price, stack, extended, currencyID = p, s, ext, cur
			end
			if price and price > 0 and not extended and not currencyID then
				local unit = math.floor(price / math.max(stack or 1, 1) + 0.5)
				if db.vendorBuy[itemID] ~= unit then
					db.vendorBuy[itemID] = unit
					changed = true
				end
			end
		end
	end
	if changed then
		self:Changed()
	end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

Prices:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
Prices:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
Prices:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
Prices:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
Prices:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Prices:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
Prices:RegisterEvent("MERCHANT_SHOW")
Prices:RegisterEvent("MERCHANT_UPDATE")

Prices:SetScript("OnEvent", function(self, event, arg1)
	local changed = false
	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
		changed = self:RecordCommodityResults(arg1)
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
		changed = self:RecordItemResults(arg1)
	elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
		changed = self:RecordBrowseResults(C_AuctionHouse.GetBrowseResults())
	elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		changed = self:RecordBrowseResults(arg1)
	elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		self:RecordMerchant()
	end
	if changed then
		self:Changed()
	end
end)
