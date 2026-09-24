-- MauUndercut crafting profit.
--
-- For every recipe in Blizzard's professions window: reagent cost (auction
-- price or vendor price per reagent, whichever is lower) against the auction
-- price of the product, after the auction house cut.  Shown as a value at the
-- right of each recipe row and as a line under the selected recipe's name.
--
-- Blizzard_Professions is load-on-demand; hooks are installed once it is
-- loaded.  Rows are decorated through ScrollUtil's initialized-frame callback
-- (runs after Blizzard's own row initializer), the detail line through a hook
-- on the schematic form's Init.  Results are cached per recipe and
-- invalidated by the price database's version counter.

local _, NS = ...

local COPPER_PER_SILVER = COPPER_PER_SILVER or 100
local COPPER_PER_GOLD = COPPER_PER_GOLD or 10000

local Crafting = CreateFrame("Frame")
NS.Crafting = Crafting

-- Share of the sale price the auction house keeps.
local AH_CUT = 0.05

local REAGENT_BASIC = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1
local RECIPE_ITEM = (Enum and Enum.TradeskillRecipeType and Enum.TradeskillRecipeType.Item) or 1

Crafting.cache = {}

-------------------------------------------------------------------------------
-- Calculation
-------------------------------------------------------------------------------

-- Returns nil for recipes without an item product (enchants, gathering).
-- Otherwise a record with cost, missing (reagents without a known price),
-- quantity (average units per craft), sell (unit price of the product, if
-- known), net (sale after the cut) and profit (only when everything is known).
function Crafting:Compute(recipeID)
	local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or type(schematic) ~= "table" then
		return nil
	end
	if schematic.recipeType ~= RECIPE_ITEM or not schematic.outputItemID then
		return nil
	end

	local result = { itemID = schematic.outputItemID, cost = 0, missing = 0, reagents = 0 }
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		if slot.reagentType == REAGENT_BASIC then
			local reagent = slot.reagents and slot.reagents[1]
			local itemID = reagent and reagent.itemID
			if itemID then
				result.reagents = result.reagents + 1
				local unit = NS.Prices:GetUnitCost(itemID)
				if unit then
					result.cost = result.cost + unit * (slot.quantityRequired or 1)
				else
					result.missing = result.missing + 1
				end
			end
		end
	end

	local quantityMin = schematic.quantityMin or 1
	local quantityMax = schematic.quantityMax or quantityMin
	result.quantity = (quantityMin + quantityMax) / 2

	local sell = NS.Prices:Get(schematic.outputItemID)
	if sell then
		result.sell = sell
		result.net = sell * result.quantity * (1 - AH_CUT)
		if result.missing == 0 then
			result.profit = result.net - result.cost
		end
	end
	return result
end

function Crafting:Get(recipeID)
	if not recipeID then
		return nil
	end
	local version = NS.Prices.version
	local entry = self.cache[recipeID]
	if entry and entry.version == version then
		return entry.result
	end
	local result = self:Compute(recipeID)
	self.cache[recipeID] = { version = version, result = result }
	return result
end

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

local function CompactMoney(copper)
	local sign = copper < 0 and "-" or "+"
	local abs = math.abs(copper)
	if abs >= COPPER_PER_GOLD then
		return string.format("%s%.1fg", sign, abs / COPPER_PER_GOLD)
	elseif abs >= COPPER_PER_SILVER then
		return string.format("%s%ds", sign, math.floor(abs / COPPER_PER_SILVER))
	end
	return string.format("%s%dc", sign, math.floor(abs))
end

local function SignedMoney(copper)
	local color = copper >= 0 and "|cff33ff33" or "|cffff3333"
	local sign = copper >= 0 and "+" or "-"
	return color .. sign .. NS.FormatMoney(math.abs(copper)) .. "|r"
end

-------------------------------------------------------------------------------
-- Recipe list rows
-------------------------------------------------------------------------------

function Crafting:DecorateRow(row, node)
	local data = node and ((node.GetData and node:GetData()) or node.data)
	local recipeInfo = data and data.recipeInfo
	local text = row.mauProfit
	if not recipeInfo then
		if text then
			text:Hide()
		end
		return
	end

	local shown = recipeInfo
	if Professions and Professions.GetHighestLearnedRecipe then
		shown = Professions.GetHighestLearnedRecipe(recipeInfo) or recipeInfo
	end
	local result = self:Get(shown.recipeID)
	if not result then
		if text then
			text:Hide()
		end
		return
	end

	if not text then
		text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetJustifyH("RIGHT")
		row.mauProfit = text
	end

	if result.profit then
		text:SetText(CompactMoney(result.profit))
		if result.profit >= 0 then
			text:SetTextColor(0.2, 1, 0.2)
		else
			text:SetTextColor(1, 0.3, 0.3)
		end
	else
		text:SetText("?")
		text:SetTextColor(0.5, 0.5, 0.5)
	end

	local locked = row.LockedIcon and row.LockedIcon:IsShown()
	text:ClearAllPoints()
	if locked then
		text:SetPoint("RIGHT", row.LockedIcon, "LEFT", -2, 0)
	else
		text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	end
	text:Show()

	-- Keep the recipe name from running under the value (mirrors the width
	-- calculation in ProfessionsRecipeListRecipeMixin:Init).
	local label = row.Label
	if label then
		local reserved = text:GetStringWidth() + 12
		if locked then
			reserved = reserved + row.LockedIcon:GetWidth()
		end
		local countWidth = (row.Count and row.Count:IsShown()) and row.Count:GetStringWidth() or 0
		local skillWidth = row.SkillUps and row.SkillUps:GetWidth() or 0
		local available = row:GetWidth() - (skillWidth + countWidth + 10 + reserved)
		if available > 10 and label:GetWidth() > available then
			label:SetWidth(available)
		end
	end
end

-------------------------------------------------------------------------------
-- Recipe detail (schematic form)
-------------------------------------------------------------------------------

function Crafting:UpdateForm(form, recipeInfo)
	local text = form.mauProfit
	local result = recipeInfo and self:Get(recipeInfo.recipeID)
	if not result then
		if text then
			text:Hide()
		end
		return
	end

	if not text then
		text = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetJustifyH("LEFT")
		text:SetWidth(430)
		text:SetPoint("TOPLEFT", form.OutputText, "BOTTOMLEFT", 0, -4)
		form.mauProfit = text
	end

	local parts = {}
	local reagents = "Reagents: " .. NS.FormatMoney(result.cost)
	if result.missing > 0 then
		reagents = reagents .. string.format(" |cff808080(%d without a known price)|r", result.missing)
	end
	parts[#parts + 1] = reagents

	if result.sell then
		local sells = "Sells for: " .. NS.FormatMoney(result.sell)
		if result.quantity ~= 1 then
			sells = sells .. string.format(" |cff808080x%s|r", string.format("%g", result.quantity))
		end
		parts[#parts + 1] = sells
		if result.profit then
			parts[#parts + 1] = string.format("Profit: %s |cff808080(after %d%% cut)|r", SignedMoney(result.profit), AH_CUT * 100)
		else
			parts[#parts + 1] = "Profit: |cff808080unknown|r"
		end
	else
		parts[#parts + 1] = "Sells for: |cff808080no auction price known|r"
	end

	text:SetText(table.concat(parts, "  |cff808080-|r  "))
	text:Show()
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function Crafting:TryInit()
	if self.initialized then
		return
	end
	local frame = ProfessionsFrame
	local page = frame and frame.CraftingPage
	if not page or not page.RecipeList or not page.RecipeList.ScrollBox or not page.SchematicForm then
		return
	end
	if not (ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then
		return
	end
	self.initialized = true
	self.scrollBox = page.RecipeList.ScrollBox
	self.form = page.SchematicForm

	ScrollUtil.AddInitializedFrameCallback(self.scrollBox, function(_, row, node)
		self:DecorateRow(row, node)
	end, self, false)

	hooksecurefunc(self.form, "Init", function(form, recipeInfo)
		self:UpdateForm(form, recipeInfo)
	end)
end

-- Prices changed (search, scan, merchant): redo what is on screen, coalesced.
function Crafting:OnPricesChanged()
	if not self.initialized or self.refreshQueued or not ProfessionsFrame or not ProfessionsFrame:IsShown() then
		return
	end
	self.refreshQueued = true
	C_Timer.After(0.2, function()
		self.refreshQueued = false
		if not ProfessionsFrame:IsShown() then
			return
		end
		self.scrollBox:ForEachFrame(function(row, node)
			self:DecorateRow(row, node)
		end)
		local recipeInfo = self.form.GetRecipeInfo and self.form:GetRecipeInfo()
		self:UpdateForm(self.form, recipeInfo)
	end)
end

Crafting:RegisterEvent("ADDON_LOADED")
Crafting:RegisterEvent("PLAYER_LOGIN")
Crafting:RegisterEvent("TRADE_SKILL_SHOW")
Crafting:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Blizzard_Professions" then
			self:TryInit()
		end
	elseif event == "PLAYER_LOGIN" then
		if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
			self:TryInit()
		end
	elseif event == "TRADE_SKILL_SHOW" then
		self:TryInit()
	end
end)
