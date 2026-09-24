-- MauUndercut panel: the content of the "MauUndercut" auction house tab.
--
-- Left side: every auctionable stack in your bags with a checkbox.
-- Right side: the item currently being posted, the lowest price found, your
-- price (pre-filled with the undercut), quantity, duration and the OK button.

local _, NS = ...

local UI = {}
NS.UI = UI

local ROW_HEIGHT = 22
local LEFT_WIDTH = 320
local MAX_LOG_LINES = 8

UI.selected = {}    -- bag:slot key -> itemID
UI.items = {}
UI.lastStatus = {}  -- bag:slot key -> last run status, survives rescans
UI.logLines = {}

-------------------------------------------------------------------------------
-- Widget helpers
-------------------------------------------------------------------------------

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

local function MakeNumericBox(name, parent, width)
	local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	box:SetSize(width, 22)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(6)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	return box
end

-- Mirrors what LargeMoneyInputFrameTemplate does when useAuctionHouseCopperValue
-- is set from XML (we cannot pass key values through CreateFrame).
local function ApplyCopperVisibility(frame)
	if NS.SupportsCopper() then
		return
	end
	frame.hideCopper = true
	frame.CopperBox:Hide()
	frame.SilverBox:ClearAllPoints()
	frame.SilverBox:SetPoint("RIGHT", frame.CopperBox, "RIGHT")
	frame.GoldBox.nextEditBox = frame.SilverBox
	frame.SilverBox.previousEditBox = frame.GoldBox
	frame.SilverBox.nextEditBox = nil
end

-------------------------------------------------------------------------------
-- Panel construction
-------------------------------------------------------------------------------

function NS.CreatePanel(parent)
	local panel = CreateFrame("Frame", "MauUndercutAuctionPanel", parent)
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -32)
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 30)
	panel:SetFrameLevel(parent:GetFrameLevel() + 5)
	panel:Hide()
	UI.panel = panel

	UI:BuildLeft(panel)
	UI:BuildRight(panel)

	panel:SetScript("OnShow", function()
		UI:OnShow()
	end)
	panel:SetScript("OnHide", function()
		UI:OnHide()
	end)

	UI.eventFrame = CreateFrame("Frame")
	UI.eventFrame:SetScript("OnEvent", function(_, event)
		if event == "BAG_UPDATE_DELAYED" then
			UI:OnBagUpdate()
		end
	end)

	return panel
end

function UI:BuildLeft(panel)
	local title = MakeLabel(panel, "Items in your bags")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -6)

	local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
	inset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 30)
	inset:SetWidth(LEFT_WIDTH)
	self.leftInset = inset

	local none = MakeButton(panel, "None", 50, 20)
	none:SetPoint("BOTTOMRIGHT", inset, "TOPRIGHT", 0, 2)
	none:SetScript("OnClick", function()
		UI:SelectAll(false)
	end)
	local all = MakeButton(panel, "All", 50, 20)
	all:SetPoint("RIGHT", none, "LEFT", -2, 0)
	all:SetScript("OnClick", function()
		UI:SelectAll(true)
	end)
	local refresh = MakeButton(panel, "Refresh", 64, 20)
	refresh:SetPoint("RIGHT", all, "LEFT", -2, 0)
	refresh:SetScript("OnClick", function()
		UI:RefreshBagList()
	end)
	self.noneButton, self.allButton, self.refreshButton = none, all, refresh

	local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 4)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -4)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 4)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, entry)
		UI:InitRow(row, entry)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	self.scrollBox = scrollBox

	local empty = MakeLabel(inset, "Nothing in your bags can be auctioned.", "GameFontDisableSmall")
	empty:SetPoint("CENTER")
	empty:Hide()
	self.emptyText = empty

	local start = MakeButton(panel, "Start posting", LEFT_WIDTH, 24)
	start:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 2)
	start:SetScript("OnClick", function()
		UI:OnStart()
	end)
	self.startButton = start

	local stop = MakeButton(panel, "Stop", LEFT_WIDTH, 24)
	stop:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 2)
	stop:SetScript("OnClick", function()
		NS.Poster:Stop("stopped")
	end)
	stop:Hide()
	self.stopButton = stop
end

function UI:InitRow(row, entry)
	if not row.Check then
		row.Check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.Check:SetSize(22, 22)
		row.Check:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.Check:SetScript("OnClick", function(check)
			UI:SetSelected(check:GetParent().entry, check:GetChecked())
		end)

		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(18, 18)
		row.Icon:SetPoint("LEFT", row.Check, "RIGHT", 2, 0)
		row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.Status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		row.Status:SetWidth(64)
		row.Status:SetJustifyH("RIGHT")

		row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
		row.Name:SetPoint("RIGHT", row.Status, "LEFT", -4, 0)
		row.Name:SetJustifyH("LEFT")
		row.Name:SetWordWrap(false)

		row.Current = row:CreateTexture(nil, "BACKGROUND")
		row.Current:SetAllPoints()
		row.Current:SetColorTexture(1, 0.82, 0, 0.18)
		row.Current:Hide()

		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)

		row:SetScript("OnClick", function(r)
			if NS.Poster.running then
				return
			end
			local checked = not r.Check:GetChecked()
			r.Check:SetChecked(checked)
			UI:SetSelected(r.entry, checked)
		end)
		row:SetScript("OnEnter", function(r)
			if r.entry then
				GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
				GameTooltip:SetBagItem(r.entry.bag, r.entry.slot)
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	row.entry = entry
	row.Check:SetChecked(self.selected[entry.key] ~= nil)
	row.Check:SetEnabled(not NS.Poster.running)
	row.Icon:SetTexture(entry.icon)
	local label = NS.ColorByQuality(entry.name, entry.quality)
	if (entry.count or 1) > 1 then
		label = label .. " |cffaaaaaax" .. entry.count .. "|r"
	end
	row.Name:SetText(label)
	row.Status:SetText(NS.StatusText(entry))
	row.Current:SetShown(NS.Poster.current == entry)
end

function UI:BuildRight(panel)
	local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_WIDTH + 8, 0)
	inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	self.rightInset = inset

	local header = MakeLabel(inset, "Current item")
	header:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -10)
	local progress = MakeLabel(inset, "", "GameFontHighlight")
	progress:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -12, -10)
	progress:SetJustifyH("RIGHT")
	self.progressText = progress

	local iconButton = CreateFrame("Button", nil, inset)
	iconButton:SetSize(40, 40)
	iconButton:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -32)
	iconButton.Icon = iconButton:CreateTexture(nil, "ARTWORK")
	iconButton.Icon:SetAllPoints()
	iconButton.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	iconButton:SetScript("OnEnter", function(button)
		local entry = NS.Poster.current
		if entry and entry.bag then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetBagItem(entry.bag, entry.slot)
			GameTooltip:Show()
		end
	end)
	iconButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self.iconButton = iconButton

	local name = MakeLabel(inset, "", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 8, -2)
	name:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	self.nameText = name

	local sub = MakeLabel(inset, "", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
	sub:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
	sub:SetJustifyH("LEFT")
	self.subText = sub

	local lowest = MakeLabel(inset, "", "GameFontHighlight")
	lowest:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -84)
	lowest:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
	lowest:SetJustifyH("LEFT")
	self.lowestText = lowest

	-- Price
	local priceLabel = MakeLabel(inset, "Your price")
	priceLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -122)
	local price = CreateFrame("Frame", "MauUndercutPriceInput", inset, "LargeMoneyInputFrameTemplate")
	price:SetSize(220, 33)
	price:SetPoint("LEFT", inset, "TOPLEFT", 112, -129)
	ApplyCopperVisibility(price)
	price:SetOnValueChangedCallback(function()
		UI:UpdatePostState()
	end)
	for _, box in ipairs({ price.GoldBox, price.SilverBox, price.CopperBox }) do
		if box then
			box:HookScript("OnEnterPressed", function()
				UI:OnEnterPressed()
			end)
		end
	end
	self.priceInput = price
	local perItem = MakeLabel(inset, "per item", "GameFontNormalSmall")
	perItem:SetPoint("LEFT", price, "RIGHT", 6, 0)

	-- Quantity
	local quantityLabel = MakeLabel(inset, "Quantity")
	quantityLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -164)
	local quantity = MakeNumericBox("MauUndercutQuantityInput", inset, 60)
	quantity:SetPoint("LEFT", inset, "TOPLEFT", 118, -171)
	quantity:SetScript("OnTextChanged", function(_, userInput)
		if userInput then
			UI:UpdatePostState()
		end
	end)
	quantity:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
		UI:OnEnterPressed()
	end)
	self.quantityInput = quantity
	local max = MakeButton(inset, "Max", 44, 20)
	max:SetPoint("LEFT", quantity, "RIGHT", 6, 0)
	max:SetScript("OnClick", function()
		local entry = NS.Poster.current
		if entry then
			quantity:SetNumber(NS.Poster:GetMaxQuantity(entry))
			UI:UpdatePostState()
		end
	end)
	local available = MakeLabel(inset, "", "GameFontHighlightSmall")
	available:SetPoint("LEFT", max, "RIGHT", 8, 0)
	self.availableText = available

	-- Duration
	local durationLabel = MakeLabel(inset, "Duration")
	durationLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -200)
	self.durationButtons = {}
	local durationNames = { "2 hours", "8 hours", "24 hours" }
	for i = 1, 3 do
		local check = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("LEFT", inset, "TOPLEFT", 108 + (i - 1) * 100, -207)
		check.Text:SetText(durationNames[i])
		check:SetScript("OnClick", function()
			UI:SetDuration(i)
		end)
		self.durationButtons[i] = check
	end

	-- Deposit / total
	local deposit = MakeLabel(inset, "", "GameFontHighlight")
	deposit:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -236)
	self.depositText = deposit
	local total = MakeLabel(inset, "", "GameFontHighlight")
	total:SetPoint("TOPLEFT", inset, "TOPLEFT", 220, -236)
	self.totalText = total

	-- Undercut setting
	local undercutLabel = MakeLabel(inset, "Undercut by")
	undercutLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -266)
	local undercut = MakeNumericBox("MauUndercutUndercutInput", inset, 50)
	undercut:SetPoint("LEFT", inset, "TOPLEFT", 118, -273)
	undercut:SetScript("OnTextChanged", function(box, userInput)
		if userInput then
			UI:OnUndercutChanged(box:GetNumber())
		end
	end)
	undercut:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
	end)
	self.undercutInput = undercut
	local undercutUnit = MakeLabel(inset, "", "GameFontHighlightSmall")
	undercutUnit:SetPoint("LEFT", undercut, "RIGHT", 6, 0)
	self.undercutUnitText = undercutUnit

	-- Buttons
	local ok = MakeButton(inset, "OK", 110, 26)
	ok:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -300)
	ok:SetScript("OnClick", function()
		UI:OnOK()
	end)
	self.okButton = ok
	local skip = MakeButton(inset, "Skip", 80, 26)
	skip:SetPoint("LEFT", ok, "RIGHT", 6, 0)
	skip:SetScript("OnClick", function()
		NS.Poster:Skip()
	end)
	self.skipButton = skip
	local retry = MakeButton(inset, "Retry search", 110, 26)
	retry:SetPoint("LEFT", skip, "RIGHT", 6, 0)
	retry:SetScript("OnClick", function()
		NS.Poster:Research()
	end)
	self.retryButton = retry

	local hint = MakeLabel(inset, "", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -334)
	hint:SetPoint("RIGHT", inset, "RIGHT", -12, 0)
	hint:SetJustifyH("LEFT")
	self.hintText = hint

	local logHeader = MakeLabel(inset, "Log", "GameFontNormalSmall")
	logHeader:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -358)
	local log = MakeLabel(inset, "", "GameFontHighlightSmall")
	log:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -372)
	log:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -12, 8)
	log:SetJustifyH("LEFT")
	log:SetJustifyV("TOP")
	self.logText = log
end

-------------------------------------------------------------------------------
-- Show / hide / bag list
-------------------------------------------------------------------------------

function UI:OnShow()
	self:LoadSettings()
	self:RefreshBagList()
	self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	self:Refresh()
end

function UI:OnHide()
	self.eventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
	GameTooltip:Hide()
end

function UI:OnBagUpdate()
	if not NS.Poster.running then
		self:RefreshBagList()
	end
end

function UI:LoadSettings()
	local settings = NS.GetSettings()
	self.undercutInput:SetNumber(settings.undercut or 1)
	for i, check in ipairs(self.durationButtons) do
		check:SetChecked(i == (settings.duration or 2))
	end
	if NS.SupportsCopper() then
		self.undercutUnitText:SetText("copper below the lowest price")
	else
		self.undercutUnitText:SetText("copper below the lowest price (this realm rounds to whole silver)")
	end
end

function UI:RefreshBagList()
	if NS.Poster.running then
		return
	end
	self.items = NS.ScanBags()
	local byKey = {}
	for _, entry in ipairs(self.items) do
		byKey[entry.key] = entry
		entry.status = self.lastStatus[entry.key]
	end
	for key, itemID in pairs(self.selected) do
		local entry = byKey[key]
		if not entry or entry.itemID ~= itemID then
			self.selected[key] = nil
		end
	end
	local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
	self.scrollBox:SetDataProvider(CreateDataProvider(self.items), retain)
	self.emptyText:SetShown(#self.items == 0)
	self:Refresh()
end

-------------------------------------------------------------------------------
-- Selection
-------------------------------------------------------------------------------

function UI:SetSelected(entry, selected)
	if not entry or NS.Poster.running then
		return
	end
	self.selected[entry.key] = selected and entry.itemID or nil
	self:Refresh()
end

function UI:SelectAll(selected)
	if NS.Poster.running then
		return
	end
	for _, entry in ipairs(self.items) do
		self.selected[entry.key] = selected and entry.itemID or nil
	end
	self:Refresh()
end

function UI:CountSelected()
	local count = 0
	for _ in pairs(self.selected) do
		count = count + 1
	end
	return count
end

function UI:GetSelectedEntries()
	local entries = {}
	for _, entry in ipairs(self.items) do
		if self.selected[entry.key] then
			entries[#entries + 1] = entry
		end
	end
	return entries
end

function UI:OnStart()
	if NS.Poster.running then
		return
	end
	local entries = self:GetSelectedEntries()
	if #entries == 0 then
		return
	end
	for _, entry in ipairs(entries) do
		self.lastStatus[entry.key] = nil
	end
	self.shownEntry = nil
	self.logLines = {}
	self.logText:SetText("")
	NS.Poster:Start(entries)
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function UI:Refresh()
	if not self.panel or not self.panel:IsShown() then
		return
	end
	local poster = NS.Poster

	if self.scrollBox and self.scrollBox.ForEachFrame then
		self.scrollBox:ForEachFrame(function(row)
			if row.entry then
				UI:InitRow(row, row.entry)
			end
		end)
	end

	if not poster.running then
		for _, entry in ipairs(self.items) do
			if entry.status then
				self.lastStatus[entry.key] = entry.status
			end
		end
	end

	local selectedCount = self:CountSelected()
	self.startButton:SetShown(not poster.running)
	self.stopButton:SetShown(poster.running)
	self.startButton:SetEnabled(selectedCount > 0)
	if selectedCount > 0 then
		self.startButton:SetText(string.format("Start posting (%d)", selectedCount))
	else
		self.startButton:SetText("Start posting")
	end
	self.allButton:SetEnabled(not poster.running)
	self.noneButton:SetEnabled(not poster.running)
	self.refreshButton:SetEnabled(not poster.running)

	self:RefreshCurrent()
end

function UI:LowestText(entry, state)
	if state == "searching" then
		return "Searching the auction house..."
	elseif state == "waitingKey" then
		return "Loading item data..."
	elseif state == "waitingThrottle" then
		return "Waiting for the auction house to accept queries..."
	elseif state ~= "ready" then
		return ""
	end

	if entry.lowest then
		local text = "Lowest listed: " .. NS.FormatMoney(entry.lowest) .. " per item"
		if entry.lowestIsMine then
			return text .. "  |cff33ff33(your own auction, matching it)|r"
		elseif entry.lowestIsVariant then
			return text .. "  |cffffd100(similar item, no exact match listed)|r"
		end
		return text .. string.format("  |cff33ff33(undercut by %s)|r", NS.FormatMoney(NS.GetUndercut()))
	end

	local reason = entry.searchError and (entry.searchError .. " ") or "No auctions found. "
	if entry.priceSource == "memory" then
		return reason .. "Using the price you last posted."
	elseif entry.priceSource == "fallback" and (entry.suggested or 0) > 0 then
		return reason .. "Using vendor price x2 as a fallback."
	end
	return reason .. "Enter a price or skip."
end

function UI:RefreshCurrent()
	local poster = NS.Poster
	local entry = poster.current

	if entry ~= self.shownEntry then
		self.shownEntry = entry
		self.priceApplied = false
		if entry then
			self.iconButton.Icon:SetTexture(entry.icon)
			self.nameText:SetText(NS.ColorByQuality(entry.name, entry.quality))
			self.quantityInput:SetNumber(poster:GetDefaultQuantity(entry))
		else
			self.iconButton.Icon:SetTexture(nil)
			self.nameText:SetText("")
			self.quantityInput:SetText("")
		end
		self.priceInput:Clear()
	end

	if entry then
		self.progressText:SetText(string.format("%d / %d", poster.index, #poster.queue))
		local stack = entry.count or 1
		if entry.location and C_Item.DoesItemExist(entry.location) then
			stack = C_Item.GetStackCount(entry.location) or stack
		end
		local kind = "item"
		if entry.isCommodity then
			kind = "commodity"
		elseif entry.isEquipment then
			kind = "equipment"
		end
		self.subText:SetText(string.format("Stack of %d  |cff888888(bag %d, slot %d, %s)|r", stack, entry.bag, entry.slot, kind))
		self.availableText:SetText(string.format("of %d", poster:GetMaxQuantity(entry)))
		self.lowestText:SetText(self:LowestText(entry, poster.state))
		if poster.state == "ready" and not self.priceApplied then
			self.priceApplied = true
			if (entry.suggested or 0) > 0 then
				self.priceInput:SetAmount(entry.suggested)
			else
				self.priceInput:Clear()
			end
		end
	else
		self.progressText:SetText("")
		if poster.running then
			self.subText:SetText("")
		else
			self.subText:SetText("Select items on the left and press Start posting.")
		end
		self.availableText:SetText("")
		self.lowestText:SetText("")
	end

	self.skipButton:SetEnabled(poster.running and entry ~= nil)
	self.retryButton:SetEnabled(poster.running and entry ~= nil and poster.state == "ready")
	self:UpdatePostState()
end

function UI:UpdatePostState()
	local poster = NS.Poster
	local entry = poster.current
	if not entry then
		self.okButton:SetEnabled(false)
		self.hintText:SetText("")
		self.depositText:SetText("")
		self.totalText:SetText("")
		return
	end

	local price = self.priceInput:GetAmount()
	local quantity = self.quantityInput:GetNumber() or 0
	local duration = self:GetDuration()
	local ok, reason = poster:CanPost(price, quantity, duration)
	self.okButton:SetEnabled(ok)

	local hint = ""
	if not ok then
		if poster.state == "ready" then
			hint = "|cffff4444" .. (reason or "") .. "|r"
		else
			hint = reason or ""
		end
	else
		local vendor = NS.GetVendorPrice(entry)
		if vendor and vendor > 0 and price < vendor then
			hint = "|cffffd100Below vendor price (" .. NS.FormatMoney(vendor) .. " per item).|r"
		end
	end
	self.hintText:SetText(hint)
	self.depositText:SetText("Deposit: " .. NS.FormatMoney(poster:GetDeposit(entry, math.max(quantity, 1), duration)))
	self.totalText:SetText("Total: " .. NS.FormatMoney(price * math.max(quantity, 0)))
end

-------------------------------------------------------------------------------
-- Input handlers
-------------------------------------------------------------------------------

function UI:GetDuration()
	return NS.GetSettings().duration or 2
end

function UI:SetDuration(index)
	NS.GetSettings().duration = index
	for i, check in ipairs(self.durationButtons) do
		check:SetChecked(i == index)
	end
	self:UpdatePostState()
end

function UI:OnUndercutChanged(value)
	value = math.max(1, math.floor(tonumber(value) or 1))
	NS.GetSettings().undercut = value
	local poster = NS.Poster
	local entry = poster.current
	if entry and poster.state == "ready" and entry.priceSource == "undercut" and entry.lowest then
		entry.suggested = NS.SanitizePrice(entry.lowest - NS.GetUndercut())
		self.priceInput:SetAmount(entry.suggested)
	end
	self:RefreshCurrent()
end

function UI:OnOK()
	local price = self.priceInput:GetAmount()
	local quantity = self.quantityInput:GetNumber() or 0
	local ok, reason = NS.Poster:Post(price, quantity, self:GetDuration())
	if not ok then
		self.hintText:SetText("|cffff4444" .. (reason or "Could not post.") .. "|r")
	end
end

function UI:OnEnterPressed()
	if self.okButton:IsEnabled() then
		self.okButton:Click()
	end
end

function UI:AddLog(message)
	table.insert(self.logLines, 1, date("%H:%M:%S") .. "  " .. message)
	while #self.logLines > MAX_LOG_LINES do
		table.remove(self.logLines)
	end
	if self.logText then
		self.logText:SetText(table.concat(self.logLines, "\n"))
	end
end
