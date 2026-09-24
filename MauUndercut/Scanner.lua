-- MauUndercut auction scanner.
--
-- C_AuctionHouse.ReplicateItems() asks the server for a dump of every auction
-- (the server allows this once per 15 minutes).  The dump is walked twice in
-- small batches and only a handful of numbers is kept per item, never a table
-- per auction, so memory grows with the number of different items rather than
-- the number of auctions:
--   pass 1:    lowest unit price and total listed quantity per item
--   item data: names, icons and vendor prices (loaded from the server if the
--              client has not seen the item yet)
--   pass 2:    for items with a vendor price, how much is listed below it
-- The only thing a scan writes to the saved variables is the lowest price per
-- item, handed to the price database (Prices.lua) in one batch at the end.

local _, NS = ...

local Scanner = CreateFrame("Frame")
NS.Scanner = Scanner

-- The Forever server, like retail, ignores a second ReplicateItems request
-- within 15 minutes (tested 2026-09-24), so mirror that here.
local REPLICATE_COOLDOWN = 15 * 60
local BATCH_SIZE = 500
local REPLICATE_TIMEOUT = 90
local ITEM_LOAD_TIMEOUT = 40
local NOTIFY_INTERVAL = 0.25

Scanner.state = "idle" -- idle | waiting | pass1 | loading | pass2 | done | failed
Scanner.results = {}
Scanner.generation = 0

local loader = CreateFrame("Frame")

-------------------------------------------------------------------------------
-- State helpers
-------------------------------------------------------------------------------

function Scanner:Notify(force)
	if not force then
		local now = GetTime()
		if self.lastNotify and now - self.lastNotify < NOTIFY_INTERVAL then
			return
		end
		self.lastNotify = now
	end
	if NS.ScanUI and NS.ScanUI.Refresh then
		NS.ScanUI:Refresh()
	end
end

function Scanner:IsBusy()
	return self.state == "waiting" or self.state == "pass1" or self.state == "loading" or self.state == "pass2"
end

function Scanner:SecondsUntilAllowed()
	local last = NS.GetScanSettings().lastScanTime
	if not last then
		return 0
	end
	local remaining = REPLICATE_COOLDOWN - (time() - last)
	if remaining < 0 then
		remaining = 0
	end
	return remaining
end

function Scanner:CanStart()
	if self:IsBusy() then
		return false, "A scan is already running."
	end
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
		return false, "Open the auction house first."
	end
	local wait = self:SecondsUntilAllowed()
	if wait > 0 then
		return false, string.format("The auction house allows one full scan every 15 minutes. Next one in %d:%02d.", math.floor(wait / 60), wait % 60)
	end
	return true
end

function Scanner:TimeSinceLastScanText()
	local last = NS.GetScanSettings().lastScanTime
	if not last then
		return "no earlier scan"
	end
	return "last scan " .. NS.FormatAge(time() - last)
end

function Scanner:Clear()
	self.byItem = nil
	self.pendingItems = nil
	self.pendingCount = 0
end

function Scanner:Start()
	local ok, reason = self:CanStart()
	if not ok then
		NS.Print(reason)
		return false, reason
	end

	local sinceText = self:TimeSinceLastScanText()
	NS.GetScanSettings().lastScanTime = time()
	self.generation = self.generation + 1
	local generation = self.generation
	self.requestedAt = GetTime()

	self.state = "waiting"
	self.message = "Requesting the full auction list from the server (" .. sinceText .. ")..."
	self.results = {}
	self.stats = nil
	self:Clear()
	self:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
	C_AuctionHouse.ReplicateItems()
	NS.Print("Full scan requested, %s.", sinceText)

	C_Timer.After(REPLICATE_TIMEOUT, function()
		if self.generation == generation and self.state == "waiting" then
			self:Fail(string.format("No auction list arrived within %d seconds (%s).", REPLICATE_TIMEOUT, sinceText))
		end
	end)

	self:Notify(true)
	return true
end

function Scanner:Fail(message)
	self.state = "failed"
	self.message = message
	self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
	self:StopItemLoader()
	self:Clear()
	NS.Print(message)
	self:Notify(true)
end

function Scanner:OnAuctionHouseClosed()
	if self:IsBusy() then
		self.generation = self.generation + 1
		self:Fail("Auction house closed before the scan finished.")
	end
end

-------------------------------------------------------------------------------
-- Pass 1: lowest price and quantity per item
-------------------------------------------------------------------------------

function Scanner:BeginProcessing()
	self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
	self.state = "pass1"
	self.numItems = C_AuctionHouse.GetNumReplicateItems() or 0
	if self.requestedAt then
		NS.Print("Auction list arrived after %.1f seconds with %s entries.", GetTime() - self.requestedAt, NS.FormatNumber(self.numItems))
	end
	self.cursor = 0
	self.byItem = {}
	self.numUnique = 0
	self.numAuctions = 0
	self.playerName = UnitName("player")
	self.message = string.format("Reading auctions... 0 / %s", NS.FormatNumber(self.numItems))
	self:Notify(true)
	self:RunPass1()
end

function Scanner:RunPass1()
	local generation = self.generation
	local stop = math.min(self.cursor + BATCH_SIZE, self.numItems)
	local byItem = self.byItem

	-- Replicate indices are zero based.
	for index = self.cursor, stop - 1 do
		local name, texture, count, quality, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(index)
		if itemID and count and count > 0 and buyout and buyout > 0 then
			local unit = buyout / count
			local rec = byItem[itemID]
			if not rec then
				rec = {
					itemID = itemID,
					name = name,
					icon = texture,
					quality = quality,
					low = unit,
					quantity = count,
					vendor = 0,
					dealQuantity = 0,
					dealCount = 0,
					profit = 0,
				}
				byItem[itemID] = rec
				self.numUnique = self.numUnique + 1
			else
				if not rec.name and name then
					rec.name = name
					rec.icon = texture
					rec.quality = quality
				end
				if unit < rec.low then
					rec.low = unit
				end
				rec.quantity = rec.quantity + count
			end
			self.numAuctions = self.numAuctions + 1
		end
	end

	self.cursor = stop
	self.message = string.format("Reading auctions... %s / %s", NS.FormatNumber(self.cursor), NS.FormatNumber(self.numItems))
	self:Notify()

	if self.cursor >= self.numItems then
		self:ResolveItemInfo()
	else
		C_Timer.After(0, function()
			if self.generation == generation and self.state == "pass1" then
				self:RunPass1()
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- Item data (names, icons, vendor prices)
-------------------------------------------------------------------------------

function Scanner:FillItemInfo(rec)
	local name, _, quality, _, _, _, _, _, _, icon, sellPrice = C_Item.GetItemInfo(rec.itemID)
	if not name then
		return false
	end
	rec.name = rec.name or name
	rec.icon = rec.icon or icon
	rec.quality = rec.quality or quality
	rec.vendor = sellPrice or 0
	return true
end

function Scanner:ResolveItemInfo()
	self.state = "loading"
	self.pendingItems = {}
	self.pendingCount = 0
	for itemID, rec in pairs(self.byItem) do
		if not self:FillItemInfo(rec) then
			self.pendingItems[itemID] = true
			self.pendingCount = self.pendingCount + 1
		end
	end
	if self.pendingCount == 0 then
		self:StartPass2()
		return
	end
	self.message = string.format("Loading item data for %s items...", NS.FormatNumber(self.pendingCount))
	self:Notify(true)
	self:StartItemLoader()
end

function Scanner:ResolvePending(itemID)
	local rec = self.byItem and self.byItem[itemID]
	if rec and self:FillItemInfo(rec) then
		self.pendingItems[itemID] = nil
		self.pendingCount = self.pendingCount - 1
		return true
	end
	return false
end

function Scanner:StartItemLoader()
	local generation = self.generation

	loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	loader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	loader:SetScript("OnEvent", function(_, _, itemID, success)
		if self.generation ~= generation or self.state ~= "loading" then
			return
		end
		if itemID and self.pendingItems[itemID] then
			if success == false then
				-- Item does not exist; it keeps whatever the dump told us.
				self.pendingItems[itemID] = nil
				self.pendingCount = self.pendingCount - 1
			else
				self:ResolvePending(itemID)
			end
			if self.pendingCount <= 0 then
				self:StartPass2()
			end
		end
	end)

	local function RequestBatch()
		if self.generation ~= generation or self.state ~= "loading" then
			return
		end
		local requested = 0
		for itemID in pairs(self.pendingItems) do
			if not self:ResolvePending(itemID) then
				C_Item.RequestLoadItemDataByID(itemID)
				requested = requested + 1
				if requested >= 250 then
					break
				end
			end
		end
		self.message = string.format("Loading item data for %s items...", NS.FormatNumber(self.pendingCount))
		self:Notify()
		if self.pendingCount <= 0 then
			self:StartPass2()
		end
	end

	RequestBatch()
	self.loaderTicker = C_Timer.NewTicker(0.5, RequestBatch)

	C_Timer.After(ITEM_LOAD_TIMEOUT, function()
		if self.generation == generation and self.state == "loading" then
			-- Whatever is still missing keeps the dump's name and no vendor price.
			self.pendingItems = {}
			self.pendingCount = 0
			self:StartPass2()
		end
	end)
end

function Scanner:StopItemLoader()
	if self.loaderTicker then
		self.loaderTicker:Cancel()
		self.loaderTicker = nil
	end
	loader:UnregisterAllEvents()
	loader:SetScript("OnEvent", nil)
end

-------------------------------------------------------------------------------
-- Pass 2: auctions below vendor price
-------------------------------------------------------------------------------

function Scanner:StartPass2()
	if self.state ~= "loading" then
		return
	end
	self:StopItemLoader()
	self.pendingItems = nil
	self.state = "pass2"
	self.cursor = 0
	self.message = "Comparing with vendor prices..."
	self:Notify(true)
	self:RunPass2()
end

function Scanner:RunPass2()
	local generation = self.generation
	local stop = math.min(self.cursor + BATCH_SIZE, self.numItems)
	local byItem = self.byItem
	local playerName = self.playerName

	for index = self.cursor, stop - 1 do
		local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(index)
		local rec = itemID and byItem[itemID]
		-- Own auctions are never a deal.
		if rec and rec.vendor > 0 and count and count > 0 and buyout and buyout > 0 and (owner == nil or owner ~= playerName) then
			local vendorTotal = rec.vendor * count
			if buyout < vendorTotal then
				rec.dealQuantity = rec.dealQuantity + count
				rec.dealCount = rec.dealCount + 1
				rec.profit = rec.profit + (vendorTotal - buyout)
				local unit = buyout / count
				if not rec.dealCheapest or unit < rec.dealCheapest then
					rec.dealCheapest = unit
				end
			end
		end
	end

	self.cursor = stop
	self.message = string.format("Comparing with vendor prices... %s / %s", NS.FormatNumber(self.cursor), NS.FormatNumber(self.numItems))
	self:Notify()

	if self.cursor >= self.numItems then
		self:Finish()
	else
		C_Timer.After(0, function()
			if self.generation == generation and self.state == "pass2" then
				self:RunPass2()
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- Results
-------------------------------------------------------------------------------

function Scanner:Finish()
	if self.state ~= "pass2" then
		return
	end

	local rows = {}
	local deals, totalProfit = 0, 0
	for _, rec in pairs(self.byItem) do
		rec.name = rec.name or ("item:" .. rec.itemID)
		rec.key = rec.name:lower()
		rec.low = math.floor(rec.low + 0.5)
		if rec.dealQuantity > 0 then
			deals = deals + 1
			totalProfit = totalProfit + rec.profit
			rec.dealCheapest = math.floor((rec.dealCheapest or rec.low) + 0.5)
		end
		rows[#rows + 1] = rec
	end

	table.sort(rows, function(a, b)
		local aDeal, bDeal = a.dealQuantity > 0, b.dealQuantity > 0
		if aDeal ~= bDeal then
			return aDeal
		end
		if aDeal and a.profit ~= b.profit then
			return a.profit > b.profit
		end
		return a.key < b.key
	end)

	self.results = rows
	self.stats = {
		time = time(),
		auctions = self.numAuctions or 0,
		items = self.numUnique or 0,
		deals = deals,
		totalProfit = totalProfit,
	}
	-- Bulk update of the price database with the lowest price of every item.
	if NS.Prices and NS.Prices.UpdateFromScan then
		NS.Prices:UpdateFromScan(self.byItem)
	end
	self:Clear()
	self.state = "done"
	self.message = string.format("Scanned %s auctions, %s items, %d below vendor price.",
		NS.FormatNumber(self.stats.auctions), NS.FormatNumber(self.stats.items), deals)
	NS.Print(self.message)
	-- The two passes leave a lot of short-lived garbage behind; reclaim it now
	-- instead of letting it pile up until the next incremental sweep.
	collectgarbage("collect")
	self:Notify(true)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

Scanner:SetScript("OnEvent", function(self, event)
	if event == "REPLICATE_ITEM_LIST_UPDATE" and self.state == "waiting" then
		self:BeginProcessing()
	end
end)
