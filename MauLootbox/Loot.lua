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
--
-- Every event handler runs under NS.Guard so a Lua error is printed to chat
-- instead of silently killing the loot; /mlb debug prints each step.

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
	local entry = {
		slot = slot,
		texture = texture,
		name = name or "",
		quantity = quantity or 1,
		quality = quality or 1,
		locked = locked and true or false,
		quest = isQuestItem and true or false,
		coin = (isCoin or slotType == SLOT_MONEY) and true or false,
		slotType = slotType,
	}
	if GetLootSlotLink and not entry.coin then
		entry.link = GetLootSlotLink(slot)
	end
	return entry
end

function Loot:OnLootOpened(autoLoot, isFromItem)
	if not NS.GetSettings().enabled or self.testMode then
		return
	end
	local settings = NS.GetSettings()
	local numItems = GetNumLootItems() or 0
	NS.Debug("LOOT_OPENED autoLoot=%s fromItem=%s slots=%d", tostring(autoLoot), tostring(isFromItem), numItems)

	self.entries = {}
	self.cleared = {}
	self.pending = {}
	self.bagsFull = false
	self.autoLoot = autoLoot and true or false

	local show, instant = {}, {}
	for slot = 1, numItems do
		local entry = ReadSlot(slot)
		if entry then
			self.entries[slot] = entry
			NS.Debug("slot %d: %s  type=%s coin=%s locked=%s quality=%s x%s", slot, entry.name, tostring(entry.slotType),
				tostring(entry.coin), tostring(entry.locked), tostring(entry.quality), tostring(entry.quantity))
			if entry.locked then
				entry.reason = "Not yours to take"
			elseif (entry.coin and settings.coinsInstant) or entry.quality < settings.minQuality then
				instant[#instant + 1] = entry
			else
				show[#show + 1] = entry
			end
		else
			NS.Debug("slot %d: empty", slot)
		end
	end

	-- Instant takes go out just after the event has been fully processed,
	-- not from inside the handler.
	if #instant > 0 then
		C_Timer.After(0, function()
			for _, entry in ipairs(instant) do
				NS.Guard("instant take", self.Take, self, entry)
			end
		end)
	end

	if #show == 0 then
		NS.Debug("nothing to spin, finishing")
		self.state = "showing"
		self:Finish()
		return
	end

	self.state = "showing"
	NS.Debug("spinning %d item(s)", #show)
	NS.Reel:Begin(show, {
		onLanded = function(entry)
			NS.Guard("take on landing", self.Take, self, entry)
		end,
		onFinished = function()
			NS.Guard("finish", self.Finish, self)
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
	if self.testMode or not entry or entry.locked then
		return
	end
	if self.cleared[entry.slot] then
		NS.Debug("slot %d already cleared", entry.slot)
		return
	end
	if self.bagsFull and not entry.coin then
		entry.reason = "Bags full"
		NS.Debug("slot %d not taken: bags full", entry.slot)
		return
	end
	if not GetLootSlotInfo(entry.slot) then
		NS.Debug("slot %d is gone", entry.slot)
		self.cleared[entry.slot] = true
		return
	end
	self.pending[entry.slot] = GetTime()
	NS.Debug("LootSlot(%d) %s", entry.slot, entry.name)
	LootSlot(entry.slot)
end

function Loot:OnSlotCleared(slot)
	if self.testMode then
		return
	end
	NS.Debug("slot %d cleared", slot)
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
		NS.Debug("finish: %d leftover(s)", #leftovers)
		if #leftovers > 0 then
			self.state = "leftovers"
			NS.Reel:ShowLeftovers(leftovers, function(entry)
				-- A click is a hardware event, so this works even where the
				-- automatic take did not.
				self.bagsFull = false
				self.pending[entry.slot] = GetTime()
				NS.Debug("LootSlot(%d) by click", entry.slot)
				LootSlot(entry.slot)
			end)
		else
			self:Close()
		end
	end)
end

function Loot:Close()
	NS.Debug("close")
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
	NS.Debug("LOOT_CLOSED")
	self.state = "idle"
	self.entries = nil
	NS.Reel:HideLeftovers()
	NS.Reel:Abort()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local function HandleEvent(self, event, arg1, arg2)
	if event == "LOOT_OPENED" then
		self:OnLootOpened(arg1, arg2)
	elseif event == "LOOT_SLOT_CLEARED" then
		self:OnSlotCleared(arg1)
	elseif event == "LOOT_CLOSED" then
		self:OnLootClosed()
	elseif event == "LOOT_BIND_CONFIRM" then
		NS.Debug("LOOT_BIND_CONFIRM slot %s", tostring(arg1))
		if self.state ~= "idle" and NS.GetSettings().autoConfirmBind and not IsInGroup() and ConfirmLootSlot then
			ConfirmLootSlot(arg1)
			if StaticPopup_Hide then
				StaticPopup_Hide("LOOT_BIND")
			end
		end
	elseif event == "UI_ERROR_MESSAGE" then
		if self.state ~= "idle" then
			NS.Debug("UI error: %s", tostring(arg2))
			if arg2 == ERR_INV_FULL then
				self.bagsFull = true
			end
		end
	end
end

Loot:SetScript("OnEvent", function(self, event, arg1, arg2)
	NS.Guard(event, HandleEvent, self, event, arg1, arg2)
end)
