-- MauLootbox options: a category in the game's Settings > AddOns panel.
-- /mlb opens it.

local _, NS = ...

local Options = {}
NS.Options = Options

local function Header(layout, text)
	if CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

local function Percent(value)
	return string.format("%d%%", value + 0.5)
end

function Options:Register()
	if self.category then
		return
	end
	if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting or not Settings.CreateCheckbox then
		return
	end
	local settings = NS.GetSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MauLootbox")
	self.category = category

	local function Register(key, varType, name)
		local setting = Settings.RegisterAddOnSetting(category, "MauLootbox_" .. key, key, settings, varType, name, NS.DEFAULTS[key])
		setting:SetValueChangedCallback(function()
			Options:OnChanged(key)
		end)
		return setting
	end

	local function Checkbox(key, name, tooltip)
		Settings.CreateCheckbox(category, Register(key, Settings.VarType.Boolean, name), tooltip)
	end

	local function Slider(key, name, tooltip, formatter)
		if not Settings.CreateSlider or not Settings.CreateSliderOptions then
			return
		end
		local range = NS.RANGES[key]
		local setting = Register(key, Settings.VarType.Number, name)
		local sliderOptions = Settings.CreateSliderOptions(range[1], range[2], range[3])
		if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
			sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
		end
		Settings.CreateSlider(category, setting, sliderOptions, tooltip)
	end

	local function Dropdown(key, name, tooltip, entries)
		if not Settings.CreateDropdown or not Settings.CreateControlTextContainer then
			return
		end
		local setting = Register(key, Settings.VarType.Number, name)
		local function GetOptions()
			local container = Settings.CreateControlTextContainer()
			for _, entry in ipairs(entries) do
				container:Add(entry[1], entry[2])
			end
			return container:GetData()
		end
		Settings.CreateDropdown(category, setting, GetOptions, tooltip)
	end

	Header(layout, "Lootbox")
	Checkbox("enabled", "Replace the loot window with the lootbox", "Off restores Blizzard's loot window and your previous auto-loot setting.")
	Dropdown("minQuality", "Spin for items of at least", "Items below this quality are taken at once without a spin.", NS.QUALITIES)
	Checkbox("coinsInstant", "Take coins without a spin", "Money is taken at once; off makes coins spin too.")
	Slider("speed", "Spin length", "How long each spin takes. 100% is the normal length, lower is faster.", Percent)
	Checkbox("sounds", "Sounds", "The whirr while spinning and the fanfare on landing.")
	Checkbox("autoConfirmBind", "Confirm bind-on-pickup for me when solo", "When you are not in a group, bind-on-pickup items are confirmed automatically. In a group the normal dialog appears.")

	Header(layout, "Window")
	Slider("scale", "Window size", "Scale of the lootbox window. Drag the window to move it.", Percent)

	Settings.RegisterAddOnCategory(category)
end

function Options:OnChanged(key)
	if key == "enabled" then
		NS.ApplyTakeover()
	elseif key == "scale" then
		NS.Reel:ApplyScale()
	end
end

function Options:Open()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	else
		NS.Print("Options are under Escape > Options > AddOns > MauLootbox.")
	end
end
