-- MauLootbox loot handling: the bridge between the loot window and the reel.
--
-- LOOT_OPENED: read every slot.  Coins (and anything below the minimum
-- quality) are taken at once; the rest goes to the reel in slot order.  When
-- the reel lands on an item, LootSlot is called for it.  LOOT_SLOT_CLEARED
-- confirms the take; a slot that does not clear (bags full, not ours) ends
-- up in a leftover list with click-to-take buttons.  LOOT_CLOSED (walked
-- away, or everything taken) ends the show.  Bind-on-pickup confirmations
-- are answered by us when solo, left to Blizzard's dialog in a group.
--
-- With the game's own auto-loot (or a shift-click) the client takes the
-- items itself the instant the window opens; the reel still plays as a
-- reveal and the already-cleared slots are simply not taken again.

local _, NS = ...

local Loot = CreateFrame("Frame")
NS.Loot = Loot

local SLOT_MONEY = (Enum and Enum.LootSlotType and Enum.LootSlotType.Money) or 2
local CLEAR_TIMEOUT = 0.8

Loot.state = "idle" -- idle | showing | leftovers

function Loot:Start()
	if self.started then
		return
	end
	self.started = true
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_SLOT_CLEARED")
	self:RegisterEvent("LOOT_CLOSED")
	self:RegisterEvent("LOOT_BIND_CONFIRM")
	self:RegisterEvent("UI_ERROR_MESSAGE")
end

-------------------------------------------------------------------------------
-- Reading the window
-------------------------------------------------------------------------------

local function ReadSlot(slot)
	local texture, name, quantity, _, quality, locked, isQuestItem, _, _, isCoin = GetLootSlotInfo(slot)
	if not texture then
		return nil
	end
	local slotType = GetLootSlotType and GetLootSlotType(slot)
	return {
		slot = slot,
		texture = texture,
		name = name or "",
		quantity = quantity or 1,
		quality = quality or 1,
		locked = locked and true or false,
		quest = isQuestItem and true or false,
		coin = (isCoin or slotType == SLOT_MONEY) and true or false,
		link = GetLootSlotLink and GetLootSlotLink(slot) or nil,
	}
end

function Loot:OnLootOpened(autoLoot, isFromItem)
	if not NS.GetSettings().enabled or self.testMode then
		return
	end
	local settings = NS.GetSettings()
	self.entries = {}
	self.cleared = {}
	self.pending = {}
	self.bagsFull = false
	self.autoLoot = autoLoot and true or false

	local show = {}
	for slot = 1, GetNumLootItems() do
		local entry = ReadSlot(slot)
		if entry then
			self.entries[slot] = entry
			if entry.locked then
				entry.reason = "Not yours to take"
			elseif entry.coin and settings.coinsInstant then
				self:Take(entry)
			elseif entry.quality < settings.minQuality then
				self:Take(entry)
			else
				show[#show + 1] = entry
			end
		end
	end

	if #show == 0 then
		self:Finish()
		return
	end

	self.state = "showing"
	NS.Reel:Begin(show, {
		onLanded = function(entry)
			self:Take(entry)
		end,
		onFinished = function()
			self:Finish()
		end,
		onSkip = function()
			NS.Reel:FinishNow()
		end,
		onClose = function()
			self:Close()
		end,
	})
end

-------------------------------------------------------------------------------
-- Taking items
-------------------------------------------------------------------------------

function Loot:Take(entry)
	if self.testMode or not entry or self.cleared[entry.slot] or entry.locked then
		return
	end
	if self.bagsFull and not entry.coin then
		entry.reason = "Bags full"
		return
	end
	self.pending[entry.slot] = GetTime()
	LootSlot(entry.slot)
end

function Loot:OnSlotCleared(slot)
	if self.testMode then
		return
	end
	self.cleared = self.cleared or {}
	self.cleared[slot] = true
	if self.pending then
		self.pending[slot] = nil
	end
end

-- The reel is done: anything still on the corpse is shown as leftovers;
-- otherwise the client closes the window by itself once it is empty, with a
-- nudge from us if it does not.
function Loot:Finish()
	if self.testMode then
		return
	end
	C_Timer.After(CLEAR_TIMEOUT, function()
		if self.state == "idle" then
			return
		end
		local leftovers = {}
		for slot = 1, GetNumLootItems() do
			local entry = self.entries and self.entries[slot]
			if entry and not self.cleared[slot] then
				local texture = GetLootSlotInfo(slot)
				if texture then
					entry.reason = entry.reason or (self.bagsFull and "Bags full" or "Could not be taken")
					leftovers[#leftovers + 1] = entry
				end
			end
		end
		if #leftovers > 0 then
			self.state = "leftovers"
			NS.Reel:ShowLeftovers(leftovers, function(entry)
				-- A click is a hardware event, so this works even where the
				-- automatic take did not.
				self.bagsFull = false
				self.pending[entry.slot] = GetTime()
				LootSlot(entry.slot)
			end)
		else
			self:Close()
		end
	end)
end

function Loot:Close()
	self.state = "idle"
	NS.Reel:HideLeftovers()
	NS.Reel:Abort()
	if not self.testMode then
		CloseLoot()
	end
end

function Loot:OnLootClosed()
	if self.testMode then
		return
	end
	self.state = "idle"
	self.entries = nil
	NS.Reel:HideLeftovers()
	NS.Reel:Abort()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

Loot:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "LOOT_OPENED" then
		self:OnLootOpened(arg1, arg2)
	elseif event == "LOOT_SLOT_CLEARED" then
		self:OnSlotCleared(arg1)
	elseif event == "LOOT_CLOSED" then
		self:OnLootClosed()
	elseif event == "LOOT_BIND_CONFIRM" then
		if self.state ~= "idle" and NS.GetSettings().autoConfirmBind and not IsInGroup() and ConfirmLootSlot then
			ConfirmLootSlot(arg1)
			if StaticPopup_Hide then
				StaticPopup_Hide("LOOT_BIND")
			end
		end
	elseif event == "UI_ERROR_MESSAGE" then
		if self.state ~= "idle" and arg2 == ERR_INV_FULL then
			self.bagsFull = true
		end
	end
end)
