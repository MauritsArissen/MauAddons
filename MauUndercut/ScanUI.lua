-- MauUndercut scanner panel: the content of the "MauScan" auction house tab.
--
-- One button runs the full auction house dump.  The list shows every item in
-- the dump with its lowest listed price; items that have auctions below their
-- vendor sell price come first and show the profit of buying and vendoring
-- those auctions.  Clicking a row opens that item on the Buy tab.

local _, NS = ...

local ScanUI = {}
NS.ScanUI = ScanUI

local ROW_HEIGHT = 22
local COL_QTY = 56
local COL_EACH = 96
local COL_VENDOR = 96
local COL_PROFIT = 110

local function MakeButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height or 22)
	button:SetText(text)
	return button
end

local function MakeLabel(parent, text, template)
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetText(text or "")
	return label
end

local function MakeColumn(row, width, anchorTo, justify)
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetWidth(width)
	text:SetJustifyH(justify or "RIGHT")
	text:SetWordWrap(false)
	if anchorTo then
		text:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0)
	else
		text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	end
	return text
end

local function MakeEditBox(name, parent, width, numeric)
	local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	box:SetSize(width, 22)
	box:SetAutoFocus(false)
	if numeric then
		box:SetNumeric(true)
		box:SetMaxLetters(8)
	end
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	return box
end

-------------------------------------------------------------------------------
-- Panel construction
-------------------------------------------------------------------------------

function NS.CreateScanPanel(parent)
	local panel = CreateFrame("Frame", "MauUndercutScanPanel", parent)
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -32)
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 30)
	panel:SetFrameLevel(parent:GetFrameLevel() + 5)
	panel:Hide()
	ScanUI.panel = panel
	ScanUI:Build(panel)
	panel:SetScript("OnShow", function()
		ScanUI:OnShow()
	end)
	panel:SetScript("OnHide", function()
		ScanUI:OnHide()
	end)
	return panel
end

function ScanUI:Build(panel)
	local scan = MakeButton(panel, "Scan auction house", 180, 24)
	scan:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
	scan:SetScript("OnClick", function()
		ScanUI:OnScan()
	end)
	self.scanButton = scan

	local status = MakeLabel(panel, "", "GameFontHighlight")
	status:SetPoint("LEFT", scan, "RIGHT", 10, 0)
	status:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(false)
	self.statusText = status

	-- Filters
	local onlyDeals = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	onlyDeals:SetSize(24, 24)
	onlyDeals:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
	onlyDeals.Text:SetText("Only items below vendor price")
	onlyDeals:SetScript("OnClick", function(check)
		NS.GetScanSettings().onlyDeals = check:GetChecked() and true or false
		ScanUI:Refresh(true)
	end)
	self.onlyDealsCheck = onlyDeals

	local filterLabel = MakeLabel(panel, "Filter")
	filterLabel:SetPoint("LEFT", onlyDeals.Text, "RIGHT", 24, 0)
	local filterBox = MakeEditBox("MauUndercutScanFilter", panel, 150, false)
	filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 12, 0)
	filterBox:SetScript("OnTextChanged", function(box, userInput)
		if userInput then
			ScanUI.filterText = (box:GetText() or ""):lower()
			ScanUI:Refresh(true)
		end
	end)
	self.filterBox = filterBox

	local minLabel = MakeLabel(panel, "Hide deals under")
	minLabel:SetPoint("LEFT", filterBox, "RIGHT", 16, 0)
	local minBox = MakeEditBox("MauUndercutScanMinProfit", panel, 64, true)
	minBox:SetPoint("LEFT", minLabel, "RIGHT", 12, 0)
	minBox:SetScript("OnTextChanged", function(box, userInput)
		if userInput then
			NS.GetScanSettings().minProfit = math.max(0, box:GetNumber() or 0)
			ScanUI:Refresh(true)
		end
	end)
	self.minProfitBox = minBox
	local minUnit = MakeLabel(panel, "copper profit", "GameFontHighlightSmall")
	minUnit:SetPoint("LEFT", minBox, "RIGHT", 6, 0)

	local summary = MakeLabel(panel, "", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -64)
	summary:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
	summary:SetJustifyH("LEFT")
	summary:SetWordWrap(false)
	self.summaryText = summary

	-- Column headers
	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -80)
	header:SetPoint("RIGHT", panel, "RIGHT", -26, 0)
	header:SetHeight(16)
	local hProfit = MakeColumn(header, COL_PROFIT)
	local hVendor = MakeColumn(header, COL_VENDOR, hProfit)
	local hEach = MakeColumn(header, COL_EACH, hVendor)
	local hQty = MakeColumn(header, COL_QTY, hEach)
	hProfit:SetText("Vendor profit")
	hVendor:SetText("Vendor each")
	hEach:SetText("Lowest each")
	hQty:SetText("Listed")
	local hName = MakeLabel(header, "Item (click: open on Buy tab, shift-click: link)", "GameFontHighlightSmall")
	hName:SetPoint("LEFT", header, "LEFT", 26, 0)
	hName:SetPoint("RIGHT", hQty, "LEFT", -4, 0)
	hName:SetJustifyH("LEFT")
	for _, text in ipairs({ hProfit, hVendor, hEach, hQty, hName }) do
		text:SetFontObject("GameFontNormalSmall")
	end

	local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -98)
	inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	self.inset = inset

	local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 4)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -4)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 4)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, data)
		ScanUI:InitRow(row, data)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	self.scrollBox = scrollBox

	local empty = MakeLabel(inset, "", "GameFontDisableSmall")
	empty:SetPoint("CENTER")
	empty:SetWidth(500)
	self.emptyText = empty
end

function ScanUI:InitRow(row, data)
	if not row.Icon then
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(18, 18)
		row.Icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		row.Profit = MakeColumn(row, COL_PROFIT)
		row.Vendor = MakeColumn(row, COL_VENDOR, row.Profit)
		row.Each = MakeColumn(row, COL_EACH, row.Vendor)
		row.Qty = MakeColumn(row, COL_QTY, row.Each)

		row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
		row.Name:SetPoint("RIGHT", row.Qty, "LEFT", -4, 0)
		row.Name:SetJustifyH("LEFT")
		row.Name:SetWordWrap(false)

		row.Deal = row:CreateTexture(nil, "BACKGROUND")
		row.Deal:SetAllPoints()
		row.Deal:SetColorTexture(0.2, 1, 0.2, 0.06)

		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)

		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(r)
			if not r.data then
				return
			end
			if IsModifiedClick() then
				local _, link = C_Item.GetItemInfo(r.data.itemID)
				if link then
					HandleModifiedItemClick(link)
				end
				return
			end
			ScanUI:OpenItem(r.data)
		end)
		row:SetScript("OnEnter", function(r)
			if r.data then
				GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
				GameTooltip:SetItemByID(r.data.itemID)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format("%s listed, lowest %s each.", NS.FormatNumber(r.data.quantity), NS.FormatMoney(r.data.low)), 1, 0.82, 0)
				if r.data.dealQuantity > 0 then
					GameTooltip:AddLine(string.format("%d auction(s) with %s item(s) below vendor price, cheapest %s each: %s profit if bought and vendored.",
						r.data.dealCount, NS.FormatNumber(r.data.dealQuantity), NS.FormatMoney(r.data.dealCheapest or r.data.low), NS.FormatMoney(r.data.profit)), 0.2, 1, 0.2, true)
				end
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	row.data = data
	row.Icon:SetTexture(data.icon)
	row.Name:SetText(NS.ColorByQuality(data.name, data.quality))
	row.Qty:SetText(NS.FormatNumber(data.quantity))
	row.Each:SetText(NS.FormatMoney(data.low))
	if data.vendor > 0 then
		row.Vendor:SetText(NS.FormatMoney(data.vendor))
	else
		row.Vendor:SetText("|cff666666-|r")
	end
	if data.dealQuantity > 0 then
		row.Profit:SetText("|cff33ff33" .. NS.FormatMoney(data.profit) .. "|r")
		row.Deal:Show()
	else
		row.Profit:SetText("")
		row.Deal:Hide()
	end
end

-------------------------------------------------------------------------------
-- Behaviour
-------------------------------------------------------------------------------

function ScanUI:OnShow()
	local settings = NS.GetScanSettings()
	self.minProfitBox:SetNumber(settings.minProfit or 0)
	self.onlyDealsCheck:SetChecked(settings.onlyDeals and true or false)
	self.filterText = (self.filterBox:GetText() or ""):lower()
	self:Refresh(true)
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(1, function()
			ScanUI:RefreshButton()
		end)
	end
end

function ScanUI:OnHide()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	GameTooltip:Hide()
end

function ScanUI:OnScan()
	local ok, reason = NS.Scanner:Start()
	if not ok then
		self.statusText:SetText("|cffff4444" .. (reason or "") .. "|r")
	end
	self:RefreshButton()
end

function ScanUI:RefreshButton()
	local scanner = NS.Scanner
	local ok = scanner:CanStart()
	self.scanButton:SetEnabled(ok)
	if scanner:IsBusy() then
		self.scanButton:SetText("Scanning...")
	elseif not ok and scanner:SecondsUntilAllowed() > 0 then
		local wait = scanner:SecondsUntilAllowed()
		self.scanButton:SetText(string.format("Next scan in %d:%02d", math.floor(wait / 60), wait % 60))
	else
		self.scanButton:SetText("Scan auction house")
	end
end

function ScanUI:Refresh(rebuild)
	if not self.panel or not self.panel:IsShown() then
		return
	end
	local scanner = NS.Scanner
	self:RefreshButton()

	if scanner.message then
		self.statusText:SetText(scanner.message)
	else
		self.statusText:SetText("Dumps the whole auction house: every item with its lowest price, deals below vendor price first.")
	end

	local settings = NS.GetScanSettings()
	if rebuild or self.shownResults ~= scanner.results then
		self.shownResults = scanner.results
		local onlyDeals = settings.onlyDeals and true or false
		local minProfit = settings.minProfit or 0
		local filter = self.filterText or ""
		local rows = {}
		local deals, dealProfit = 0, 0
		for _, data in ipairs(scanner.results or {}) do
			local isDeal = data.dealQuantity > 0 and data.profit >= minProfit
			if (isDeal or not onlyDeals) and (filter == "" or (data.key or ""):find(filter, 1, true)) then
				if isDeal or not onlyDeals then
					rows[#rows + 1] = data
					if isDeal then
						deals = deals + 1
						dealProfit = dealProfit + data.profit
					end
				end
			end
		end
		local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
		self.scrollBox:SetDataProvider(CreateDataProvider(rows), retain)
		self.shownCount = #rows
		self.shownDeals = deals
		self.shownProfit = dealProfit
	end

	local stats = scanner.stats
	if stats then
		self.summaryText:SetText(string.format("Last scan %s: %s auctions, %s items. Showing %s items, %d below vendor price worth %s if bought and vendored.",
			date("%H:%M", stats.time), NS.FormatNumber(stats.auctions), NS.FormatNumber(stats.items),
			NS.FormatNumber(self.shownCount or 0), self.shownDeals or 0, NS.FormatMoney(self.shownProfit or 0)))
	else
		self.summaryText:SetText("")
	end

	if (self.shownCount or 0) > 0 then
		self.emptyText:Hide()
	else
		if scanner:IsBusy() then
			self.emptyText:SetText("Scanning...")
		elseif stats then
			self.emptyText:SetText("Nothing matches the current filter.")
		else
			self.emptyText:SetText("Press Scan auction house. The server allows one full dump every 15 minutes.")
		end
		self.emptyText:Show()
	end
end

-- Jump to the item on the Buy tab.  Commodities can be opened directly with
-- their price; other items are found through a name search, because the dump
-- does not give us their exact item key.
function ScanUI:OpenItem(data)
	if not AuctionHouseFrame or not AuctionHouseFrameDisplayMode then
		return
	end
	local itemKey = C_AuctionHouse.MakeItemKey(data.itemID)
	local keyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)
	if keyInfo and keyInfo.isCommodity and AuctionHouseFrame.SelectBrowseResult then
		AuctionHouseFrame:SelectBrowseResult({
			itemKey = itemKey,
			minPrice = data.dealCheapest or data.low,
			totalQuantity = data.quantity,
			containsOwnerItem = false,
		})
		return
	end

	AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
	local searchBar = AuctionHouseFrame.SearchBar
	if searchBar and searchBar.SetSearchText and searchBar.StartSearch then
		searchBar:SetSearchText(data.name)
		searchBar:StartSearch()
	end
end
