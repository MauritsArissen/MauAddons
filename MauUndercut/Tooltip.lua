-- MauUndercut tooltip line.
--
-- Adds "Auction price" with the lowest price the price database knows for the
-- hovered item.  While Shift is held the line shows the value of the whole
-- stack (the hovered bag stack, or a full stack for links and lists).
--
-- The post call does one table lookup and builds one line; nothing is cached
-- or allocated per hover beyond the text.  Bag tooltips are rebuilt by
-- Blizzard every 0.2 s anyway; MODIFIER_STATE_CHANGED rebuilds the others
-- so the Shift variant appears immediately.

local _, NS = ...

local Tooltip = CreateFrame("Frame")
NS.Tooltip = Tooltip

local ITEM_TYPE = (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) or 0

-- How many units the hovered thing represents: the bag stack when the tooltip
-- belongs to a bag or bank button, the button's count otherwise, and a full
-- stack when nothing better is known.  Second value: whether it is an exact
-- stack rather than the item's maximum stack size.
local function StackCount(tooltip, itemID)
	local owner = tooltip:GetOwner()
	if owner then
		if owner.GetBagID and owner.GetID then
			local ok, bag = pcall(owner.GetBagID, owner)
			if ok and bag then
				local info = C_Container.GetContainerItemInfo(bag, owner:GetID())
				if info and info.itemID == itemID and info.stackCount then
					return info.stackCount, true
				end
			end
		end
		local count = owner.count
		if type(count) == "number" and count >= 1 then
			return math.floor(count), true
		end
	end
	local max = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID)
	if max and max > 1 then
		return max, false
	end
	return 1, true
end

local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	local itemID = data and data.id
	if not itemID or not NS.Prices then
		return
	end
	local price, seen = NS.Prices:Get(itemID)
	if not price then
		return
	end

	local left = "Auction price"
	local total = price
	if IsShiftKeyDown() then
		local count, exact = StackCount(tooltip, itemID)
		if count > 1 then
			total = price * count
			left = string.format("Auction price x%d%s", count, exact and "" or " (full stack)")
		end
	end
	if seen then
		left = left .. " |cff808080(" .. NS.FormatAge(time() - seen) .. ")|r"
	end
	tooltip:AddDoubleLine(left, NS.FormatMoney(total), 1, 0.82, 0, 1, 1, 1)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
	TooltipDataProcessor.AddTooltipPostCall(ITEM_TYPE, OnItemTooltip)
end

local function RefreshIfItem(tooltip)
	if tooltip and tooltip:IsShown() and tooltip.RefreshData and tooltip.IsTooltipType and tooltip:IsTooltipType(ITEM_TYPE) then
		tooltip:RefreshData()
	end
end

Tooltip:RegisterEvent("MODIFIER_STATE_CHANGED")
Tooltip:SetScript("OnEvent", function(_, _, key)
	if key == "LSHIFT" or key == "RSHIFT" then
		RefreshIfItem(GameTooltip)
		RefreshIfItem(ItemRefTooltip)
	end
end)
