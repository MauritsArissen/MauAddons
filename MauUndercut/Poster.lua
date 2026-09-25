-- MauUndercut posting state machine.
--
-- Flow for every queued bag stack:
--   Next() -> validate the stack is still there
--          -> BeginSearch(): wait for item key info, wait for the throttle
--          -> SendSearch(): C_AuctionHouse.SendSearchQuery / SendSellSearchQuery
--          -> results event -> ProcessCommodityResults / ProcessItemResults
--          -> ApplySearchResult(): suggested price = lowest - undercut
--          -> state "ready": the UI shows the price, the user clicks OK
--          -> Post(): C_AuctionHouse.PostCommodity / PostItem (needs the click)
--          -> Next()
--
-- Only Post() needs a hardware event; everything else runs on events/timers so
-- the next price is usually on screen by the time the previous post is sent.

local _, NS = ...

local COPPER_PER_SILVER = COPPER_PER_SILVER or 100

local Poster = CreateFrame("Frame")
NS.Poster = Poster

Poster.state = "idle"
Poster.running = false
Poster.queue = {}
Poster.index = 0
Poster.generation = 0
Poster.awaitingCreate = {}

local SORT_ORDER_PRICE = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
local SORT_ORDER_BUYOUT = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Buyout) or 4
local SORTS_PRICE = { { sortOrder = SORT_ORDER_PRICE, reverseSort = false } }
local SORTS_BUYOUT = { { sortOrder = SORT_ORDER_BUYOUT, reverseSort = false } }

local MAX_SEARCH_ATTEMPTS = 4
local MAX_EXTRA_PAGES = 5
-- Seconds to wait for an answer before the query is sent again.  The server
-- normally answers within a second or two; a query it silently ignored (see
-- BeginSearch) never answers at all, so this must stay short.
local SEARCH_TIMEOUT = 6

local EVENTS = {
	"COMMODITY_SEARCH_RESULTS_UPDATED",
	"COMMODITY_SEARCH_RESULTS_ADDED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_ADDED",
	"ITEM_KEY_ITEM_INFO_RECEIVED",
	"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
	"AUCTION_HOUSE_BROWSE_FAILURE",
	"AUCTION_HOUSE_AUCTION_CREATED",
	"AUCTION_HOUSE_POST_ERROR",
	"AUCTION_HOUSE_SHOW_ERROR",
	"AUCTION_MULTISELL_START",
	"AUCTION_MULTISELL_UPDATE",
	"AUCTION_MULTISELL_FAILURE",
}

local function RegisterEvents(frame)
	for _, event in ipairs(EVENTS) do
		frame:RegisterEvent(event)
	end
end

local function UnregisterEvents(frame)
	for _, event in ipairs(EVENTS) do
		frame:UnregisterEvent(event)
	end
end

local function IsOnlyMine(result)
	if not result or not result.containsOwnerItem then
		return false
	end
	if result.owners and #result.owners == 1 and result.owners[1] == "player" then
		return true
	end
	return (result.totalNumberOfOwners or 0) <= 1
end

-------------------------------------------------------------------------------
-- Timers / notifications
-------------------------------------------------------------------------------

function Poster:ClearTimer()
	if self.timer then
		self.timer:Cancel()
		self.timer = nil
	end
end

function Poster:SetTimer(delay, callback)
	self:ClearTimer()
	local generation = self.generation
	self.timer = C_Timer.NewTimer(delay, function()
		self.timer = nil
		if generation == self.generation then
			callback()
		end
	end)
end

function Poster:Notify()
	if NS.UI and NS.UI.Refresh then
		NS.UI:Refresh()
	end
end

function Poster:Log(message)
	if NS.UI and NS.UI.AddLog then
		NS.UI:AddLog(message)
	end
end

-------------------------------------------------------------------------------
-- Run control
-------------------------------------------------------------------------------

function Poster:Start(entries)
	if self.running then
		self:Stop("restart")
	end
	self.queue = {}
	for i, entry in ipairs(entries) do
		entry.status = nil
		self.queue[i] = entry
	end
	self.index = 0
	self.current = nil
	self.awaitingCreate = {}
	self.postedItemIDs = {}
	self.multisellActive = false
	self.counts = { posted = 0, skipped = 0, failed = 0 }
	self.running = true
	RegisterEvents(self)
	self:Log(string.format("Started with %d stack(s).", #self.queue))
	self:Next()
end

function Poster:Stop(reason)
	self.generation = self.generation + 1
	self:ClearTimer()
	self.running = false
	self.state = "idle"
	self.current = nil
	self.pendingSearch = false
	self.expectedKey = nil
	UnregisterEvents(self)
	if reason == "done" then
		local c = self.counts or {}
		local summary = string.format("Done: %d posted, %d skipped, %d failed or missing.", c.posted or 0, c.skipped or 0, c.failed or 0)
		NS.Print(summary)
		self:Log(summary)
	elseif reason == "stopped" then
		self:Log("Stopped.")
	elseif reason == "closed" then
		self:Log("Auction house closed, run stopped.")
	end
	self:Notify()
end

function Poster:OnAuctionHouseClosed()
	if self.running then
		self:Stop("closed")
	end
end

function Poster:Skip()
	local entry = self.current
	if not self.running or not entry then
		return
	end
	entry.status = "skipped"
	self.counts.skipped = self.counts.skipped + 1
	self:Log("Skipped " .. entry.name .. ".")
	self:Next()
end

function Poster:ValidateEntry(entry)
	local location = entry.location
	if location and C_Item.DoesItemExist(location) and C_Item.GetItemID(location) == entry.itemID and C_AuctionHouse.IsSellItemValid(location, false) then
		entry.count = C_Item.GetStackCount(location) or entry.count
		return true
	end
	local used = {}
	for i = self.index + 1, #self.queue do
		used[self.queue[i].key] = true
	end
	if NS.RelocateEntry(entry, used) and C_AuctionHouse.IsSellItemValid(entry.location, false) then
		return true
	end
	return false
end

function Poster:Next()
	self.generation = self.generation + 1
	self:ClearTimer()
	self.pendingSearch = false
	self.expectedKey = nil

	while true do
		self.index = self.index + 1
		local entry = self.queue[self.index]
		if not entry then
			self.current = nil
			self:Stop("done")
			return
		end
		if self:ValidateEntry(entry) then
			self.current = entry
			break
		end
		if self.postedItemIDs[entry.itemID] then
			-- A previous post of the same item already took this stack.
			entry.status = "merged"
			self:Log(entry.name .. " was already included in an earlier post.")
		else
			entry.status = "missing"
			self.counts.failed = self.counts.failed + 1
			self:Log(entry.name .. " is no longer in your bags, skipped.")
		end
	end

	local entry = self.current
	entry.lowest = nil
	entry.lowestIsMine = nil
	entry.suggested = nil
	entry.priceSource = nil
	entry.searchError = nil
	entry.numResults = nil
	entry.searchAttempts = 0
	entry.extraPages = 0
	entry.keyWaits = 0
	entry.itemKey = C_AuctionHouse.GetItemKeyFromItem(entry.location)

	self.state = "searching"
	self:Notify()
	self:BeginSearch()
end

-------------------------------------------------------------------------------
-- Searching
-------------------------------------------------------------------------------

function Poster:BeginSearch()
	local entry = self.current
	if not entry or not self.running then
		return
	end

	local info = C_AuctionHouse.GetItemKeyInfo(entry.itemKey)
	if not info then
		entry.keyWaits = (entry.keyWaits or 0) + 1
		if entry.keyWaits > 20 then
			self:SearchFailed("Could not load auction data for this item.")
			return
		end
		self.state = "waitingKey"
		self:Notify()
		self:SetTimer(0.5, function()
			self:BeginSearch()
		end)
		return
	end

	entry.keyInfo = info
	entry.isCommodity = info.isCommodity and true or false
	entry.isEquipment = info.isEquipment and true or false

	-- The key the query is sent with.  Commodity and equipment searches go by
	-- item ID (Blizzard: "ItemKey should have its iLVL and suffix cleared"),
	-- so for equipment it differs from the bag item's own key.  The client
	-- silently ignores a search for a key whose info it has not cached yet,
	-- which is what made green gear with a random suffix time out and fall
	-- back to vendor price x2: the info for the full key was there, the info
	-- for the cleared key was not.  Blizzard's own sell frame asks for the
	-- cleared key's info before querying; do the same and wait for it.
	local key = entry.itemKey
	if entry.isCommodity or entry.isEquipment then
		entry.searchKey = C_AuctionHouse.MakeItemKey(key.itemID)
	else
		entry.searchKey = C_AuctionHouse.MakeItemKey(key.itemID, key.itemLevel or 0, key.itemSuffix or 0, key.battlePetSpeciesID or 0)
	end
	if not NS.SameItemKey(entry.searchKey, key) and not C_AuctionHouse.GetItemKeyInfo(entry.searchKey) then
		entry.keyWaits = (entry.keyWaits or 0) + 1
		if entry.keyWaits > 20 then
			self:SearchFailed("Could not load auction data for this item.")
			return
		end
		self.state = "waitingKey"
		self:Notify()
		self:SetTimer(0.5, function()
			self:BeginSearch()
		end)
		return
	end

	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		self.throttleWaits = 0
		self:WaitForThrottle()
		return
	end
	self:SendSearch()
end

function Poster:WaitForThrottle()
	self.state = "waitingThrottle"
	self.pendingSearch = true
	self.throttleWaits = (self.throttleWaits or 0) + 1
	self:Notify()
	self:SetTimer(1, function()
		if self.state ~= "waitingThrottle" then
			return
		end
		if C_AuctionHouse.IsThrottledMessageSystemReady() then
			self:SendSearch()
		elseif self.throttleWaits < 20 then
			self:WaitForThrottle()
		else
			self:SearchFailed("The auction house stayed busy for too long.")
		end
	end)
end

function Poster:SendSearch()
	local entry = self.current
	if not entry or not self.running then
		return
	end
	self.pendingSearch = false
	self.throttleWaits = 0
	entry.searchAttempts = (entry.searchAttempts or 0) + 1

	self.expectedKey = entry.searchKey
	if entry.isCommodity then
		C_AuctionHouse.SendSearchQuery(self.expectedKey, SORTS_PRICE, true)
	elseif entry.isEquipment then
		-- Sell search by item ID: the results carry the real keys (item level
		-- and suffix) so the exact variant can still be matched.
		C_AuctionHouse.SendSellSearchQuery(self.expectedKey, SORTS_BUYOUT, true)
	else
		C_AuctionHouse.SendSearchQuery(self.expectedKey, SORTS_BUYOUT, true)
	end

	self.state = "searching"
	self:Notify()
	self:SetTimer(SEARCH_TIMEOUT, function()
		if self.state == "searching" and self.current == entry then
			-- No answer: the query may have been ignored, send it again.
			self:RetrySearch("No answer from the auction house.")
		end
	end)
end

function Poster:RetrySearch(reason)
	local entry = self.current
	if not entry or not self.running then
		return
	end
	if (entry.searchAttempts or 0) >= MAX_SEARCH_ATTEMPTS then
		self:SearchFailed(reason or "The auction house returned no usable results.")
		return
	end
	self.state = "searching"
	self:SetTimer(0.75, function()
		if not C_AuctionHouse.IsThrottledMessageSystemReady() then
			self.throttleWaits = 0
			self:WaitForThrottle()
		else
			self:SendSearch()
		end
	end)
end

function Poster:SearchFailed(reason)
	local entry = self.current
	if not entry then
		return
	end
	entry.searchError = reason
	self:ApplySearchResult(nil, 0)
end

function Poster:ProcessCommodityResults(itemID)
	local key = self.expectedKey
	local has = C_AuctionHouse.HasSearchResults(key)
	local full = C_AuctionHouse.HasFullCommoditySearchResults(itemID)
	local quantity = C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID)
	if (not has) or (has and not full and quantity == 0) then
		self:RetrySearch()
		return
	end

	local num = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
	local best
	for i = 1, num do
		local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if result and result.unitPrice and result.unitPrice > 0 then
			if not best or result.unitPrice < best.unitPrice then
				best = result
			end
		end
	end

	if best then
		self:ApplySearchResult({ price = best.unitPrice, mine = IsOnlyMine(best), exact = true }, num)
	else
		self:ApplySearchResult(nil, num)
	end
end

function Poster:ProcessItemResults(itemKey)
	local entry = self.current
	local has = C_AuctionHouse.HasSearchResults(itemKey)
	local full = C_AuctionHouse.HasFullItemSearchResults(itemKey)
	local quantity = C_AuctionHouse.GetItemSearchResultsQuantity(itemKey)
	if (not has) or (has and not full and quantity == 0) then
		self:RetrySearch()
		return
	end

	local num = C_AuctionHouse.GetNumItemSearchResults(itemKey)
	local myKey = entry.itemKey
	local ignoreLevel = entry.keyInfo and entry.keyInfo.isPet
	local bestExact, bestVariant
	local numExact = 0

	for i = 1, num do
		local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		if result and result.buyoutAmount and result.buyoutAmount > 0 then
			local perItem = result.buyoutAmount / math.max(result.quantity or 1, 1)
			local exact = true
			if entry.isEquipment and not ignoreLevel and result.itemKey then
				exact = (result.itemKey.itemLevel or 0) == (myKey.itemLevel or 0)
					and (result.itemKey.itemSuffix or 0) == (myKey.itemSuffix or 0)
			end
			if exact then
				numExact = numExact + 1
				if not bestExact or perItem < bestExact.perItem then
					bestExact = { perItem = perItem, result = result }
				end
			elseif not bestVariant or perItem < bestVariant.perItem then
				bestVariant = { perItem = perItem, result = result }
			end
		end
	end

	if not bestExact and not full and (entry.extraPages or 0) < MAX_EXTRA_PAGES then
		entry.extraPages = (entry.extraPages or 0) + 1
		-- Returns true when everything is already loaded; then no further
		-- results event will come and what we have is all there is.
		local alreadyFull = C_AuctionHouse.RequestMoreItemSearchResults(itemKey)
		if not alreadyFull then
			self:SetTimer(SEARCH_TIMEOUT, function()
				if self.state == "searching" and self.current == entry then
					self:RetrySearch("No answer from the auction house.")
				end
			end)
			return
		end
	end

	if bestExact then
		self:ApplySearchResult({ price = bestExact.perItem, mine = IsOnlyMine(bestExact.result), exact = true }, numExact)
	elseif bestVariant then
		self:ApplySearchResult({ price = bestVariant.perItem, mine = IsOnlyMine(bestVariant.result), exact = false }, 0)
	else
		self:ApplySearchResult(nil, 0)
	end
end

function Poster:ApplySearchResult(lowest, numResults)
	local entry = self.current
	if not entry then
		return
	end
	self:ClearTimer()
	entry.numResults = numResults

	if lowest then
		entry.lowest = lowest.price
		entry.lowestIsMine = lowest.mine
		entry.lowestIsVariant = not lowest.exact
		if lowest.mine then
			entry.suggested = lowest.price
			entry.priceSource = "own"
		else
			entry.suggested = lowest.price - NS.GetUndercut()
			entry.priceSource = "undercut"
		end
	else
		local remembered = NS.GetRememberedPrice(entry)
		if remembered and remembered > 0 then
			entry.suggested = remembered
			entry.priceSource = "memory"
		else
			entry.suggested = NS.DefaultPrice(entry)
			entry.priceSource = "fallback"
		end
	end

	if entry.suggested and entry.suggested > 0 then
		entry.suggested = NS.SanitizePrice(entry.suggested)
	else
		entry.suggested = 0
	end

	-- Never offer a price below what a vendor pays: skip the stack instead.
	local vendor = NS.GetVendorPrice(entry)
	if entry.suggested > 0 and vendor and vendor > 0 and entry.suggested < vendor then
		entry.status = "belowvendor"
		self.counts.skipped = self.counts.skipped + 1
		self:Log(string.format("%s skipped: undercut price %s is below the vendor price %s.", entry.name, NS.FormatMoney(entry.suggested), NS.FormatMoney(vendor)))
		self:Next()
		return
	end

	self.state = "ready"
	self:Notify()
end

-- Re-run the search for the current item (user pressed Retry).
function Poster:Research()
	local entry = self.current
	if not entry or not self.running then
		return
	end
	entry.searchAttempts = 0
	entry.extraPages = 0
	entry.searchError = nil
	self.generation = self.generation + 1
	self:ClearTimer()
	self.state = "searching"
	self:Notify()
	self:BeginSearch()
end

-------------------------------------------------------------------------------
-- Posting
-------------------------------------------------------------------------------

-- Everything you own of this item, not just the selected stack: the modern
-- auction house pulls from every stack in the bags when posting.
function Poster:GetMaxQuantity(entry)
	if not entry or not entry.location or not C_Item.DoesItemExist(entry.location) then
		return 1
	end
	local available = C_AuctionHouse.GetAvailablePostCount(entry.location) or 1
	return math.max(1, available)
end

function Poster:GetDefaultQuantity(entry)
	return self:GetMaxQuantity(entry)
end

function Poster:GetDeposit(entry, quantity, duration)
	if not entry or not entry.location or not C_Item.DoesItemExist(entry.location) then
		return 0
	end
	quantity = math.max(1, tonumber(quantity) or 1)
	duration = tonumber(duration) or 2
	local deposit
	if entry.isCommodity then
		deposit = C_AuctionHouse.CalculateCommodityDeposit(entry.itemID, duration, quantity)
	else
		deposit = C_AuctionHouse.CalculateItemDeposit(entry.location, duration, quantity)
	end
	return deposit or 0
end

function Poster:CanPost(price, quantity, duration)
	local entry = self.current
	if not self.running or not entry then
		return false, "Select items and press Start."
	end
	if self.state == "searching" or self.state == "waitingKey" or self.state == "waitingThrottle" then
		return false, "Looking up the current price..."
	end
	if self.state ~= "ready" then
		return false, "Not ready."
	end
	if self.multisellActive then
		return false, "The previous multi-item post is still being created."
	end
	if not entry.location or not C_Item.DoesItemExist(entry.location) then
		return false, "The item is no longer in your bags."
	end
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return false, "The auction house is busy, one moment."
	end

	price = math.floor(tonumber(price) or 0)
	quantity = math.floor(tonumber(quantity) or 0)
	duration = tonumber(duration) or 0

	if price <= 0 then
		return false, "Enter a price."
	end
	if not NS.SupportsCopper() and price % COPPER_PER_SILVER ~= 0 then
		return false, "Prices must be whole silver on this realm."
	end
	local maxQuantity = self:GetMaxQuantity(entry)
	if quantity < 1 or quantity > maxQuantity then
		return false, string.format("Quantity must be between 1 and %d.", maxQuantity)
	end
	if duration < 1 or duration > 3 then
		return false, "Pick a duration."
	end
	if GetMoney() < (self:GetDeposit(entry, quantity, duration) or 0) then
		return false, "Not enough money for the deposit."
	end
	return true
end

-- Must be called from a hardware event (the OK button click).
function Poster:Post(price, quantity, duration)
	local ok, reason = self:CanPost(price, quantity, duration)
	if not ok then
		return false, reason
	end

	local entry = self.current
	price = math.floor(tonumber(price))
	quantity = math.floor(tonumber(quantity))
	duration = tonumber(duration)

	local needsConfirmation
	if entry.isCommodity then
		needsConfirmation = C_AuctionHouse.PostCommodity(entry.location, duration, quantity, price)
		if needsConfirmation and AuctionHouseFrame and AuctionHouseFrame.CommoditiesSellFrame and AuctionHouseFrame.CommoditiesSellFrame.CachePendingPost then
			-- Blizzard's confirmation popup confirms whatever the sell frame
			-- cached, so hand it our parameters.
			AuctionHouseFrame.CommoditiesSellFrame:CachePendingPost(entry.location, duration, quantity, price)
		end
	else
		needsConfirmation = C_AuctionHouse.PostItem(entry.location, duration, quantity, nil, price)
		if needsConfirmation and AuctionHouseFrame and AuctionHouseFrame.ItemSellFrame and AuctionHouseFrame.ItemSellFrame.CachePendingPost then
			AuctionHouseFrame.ItemSellFrame:CachePendingPost(entry.location, duration, quantity, nil, price)
		end
	end

	entry.status = needsConfirmation and "confirm" or "pending"
	entry.postedPrice = price
	entry.postedQuantity = quantity
	entry.createdCount = 0
	table.insert(self.awaitingCreate, entry)
	self.postedItemIDs[entry.itemID] = true
	NS.RememberPrice(entry, price)

	local suffix = quantity > 1 and (" x" .. quantity) or ""
	if needsConfirmation then
		self:Log(string.format("%s%s at %s, waiting for your confirmation.", entry.name, suffix, NS.FormatMoney(price)))
	else
		self:Log(string.format("Posted %s%s at %s each.", entry.name, suffix, NS.FormatMoney(price)))
	end

	self:Next()
	return true
end

-------------------------------------------------------------------------------
-- Post result bookkeeping
-------------------------------------------------------------------------------

local function FindAwaiting(list, auctionID)
	local itemID
	if auctionID and C_AuctionHouse.GetAuctionInfoByID then
		local ok, info = pcall(C_AuctionHouse.GetAuctionInfoByID, auctionID)
		if ok and info and info.itemKey then
			itemID = info.itemKey.itemID
		end
	end
	if itemID then
		for i, entry in ipairs(list) do
			if entry.itemID == itemID then
				return i, entry
			end
		end
	end
	if list[1] then
		return 1, list[1]
	end
	return nil
end

function Poster:OnAuctionCreated(auctionID)
	local index, entry = FindAwaiting(self.awaitingCreate, auctionID)
	if not entry then
		return
	end
	entry.createdCount = (entry.createdCount or 0) + 1
	local expected = (not entry.isCommodity and entry.postedQuantity) or 1
	if entry.createdCount >= expected then
		table.remove(self.awaitingCreate, index)
		if entry.status ~= "posted" then
			entry.status = "posted"
			self.counts.posted = self.counts.posted + 1
		end
	end
	self:Notify()
end

function Poster:OnPostFailed(reason)
	local entry = self.awaitingCreate[1]
	if not entry then
		return
	end
	table.remove(self.awaitingCreate, 1)
	entry.status = "failed"
	self.counts.failed = self.counts.failed + 1
	self:Log(string.format("Posting %s failed%s", entry.name, reason and (": " .. reason) or "."))
	self:Notify()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

Poster:SetScript("OnEvent", function(self, event, ...)
	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
		local itemID = ...
		if self.state == "searching" and self.current and self.current.isCommodity and self.expectedKey and itemID == self.expectedKey.itemID then
			self:ProcessCommodityResults(itemID)
		end

	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
		local itemKey = ...
		if self.state == "searching" and self.current and not self.current.isCommodity and self.expectedKey and itemKey then
			-- Equipment searches go by item ID, so match on that alone; the
			-- level and suffix in the event key are not ours to care about.
			local matches
			if self.current.isEquipment then
				matches = itemKey.itemID == self.expectedKey.itemID
			else
				matches = NS.SameItemKey(itemKey, self.expectedKey)
			end
			if matches then
				self:ProcessItemResults(itemKey)
			end
		end

	elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
		local itemID = ...
		if self.state == "waitingKey" and self.current and self.current.itemKey and self.current.itemKey.itemID == itemID then
			self:BeginSearch()
		end

	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if self.state == "waitingThrottle" and self.pendingSearch then
			self:SendSearch()
		else
			self:Notify()
		end

	elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" or event == "AUCTION_HOUSE_BROWSE_FAILURE" then
		if self.state == "searching" then
			self:RetrySearch()
		end

	elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT" or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED" then
		self:Notify()

	elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
		local auctionID = ...
		self:OnAuctionCreated(auctionID)

	elseif event == "AUCTION_HOUSE_POST_ERROR" then
		self:OnPostFailed()

	elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
		local errorType = ...
		local text
		if AuctionHouseUtil and AuctionHouseUtil.GetErrorText then
			local ok, result = pcall(AuctionHouseUtil.GetErrorText, errorType)
			if ok then
				text = result
			end
		end
		if self.awaitingCreate[1] then
			self:OnPostFailed(text)
		end

	elseif event == "AUCTION_MULTISELL_START" then
		self.multisellActive = true
		self:Notify()

	elseif event == "AUCTION_MULTISELL_UPDATE" then
		local created, total = ...
		if created and total and created >= total then
			self.multisellActive = false
		end
		self:Notify()

	elseif event == "AUCTION_MULTISELL_FAILURE" then
		self.multisellActive = false
		self:OnPostFailed("multi-item post interrupted")
	end
end)
