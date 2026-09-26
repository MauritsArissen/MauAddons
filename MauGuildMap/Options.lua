-- MauGuildMap options: a category in the game's Settings > AddOns panel.
--
-- Every switch is a Blizzard addon setting bound straight to a key of
-- MauGuildMapDB.settings (Settings.RegisterAddOnSetting), so the panel reads
-- and writes the saved variables itself; the callbacks only react to changes.
-- /mgm opens the category.

local _, NS = ...

local Options = {}
NS.Options = Options

local function Header(layout, text)
	if CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

function Options:Register()
	if self.category then
		return
	end
	if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting or not Settings.CreateCheckbox then
		return
	end
	local settings = NS.GetSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MauGuildMap")
	self.category = category

	local function Checkbox(key, name, tooltip)
		local setting = Settings.RegisterAddOnSetting(category, "MauGuildMap_" .. key, key, settings, Settings.VarType.Boolean, name, NS.DEFAULTS[key])
		setting:SetValueChangedCallback(function()
			Options:OnChanged(key)
		end)
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	Header(layout, "Map")
	Checkbox("display", "Show guild members on the map", "Draw the guild members who run MauGuildMap on the world map. Turning this off keeps listening, so turning it back on shows everyone at once.")
	Checkbox("labels", "Name labels under the icons", "Write each member's name under their icon, in their class colour.")
	Checkbox("ring", "Class-coloured ring around the icons", "A thin ring in the member's class colour around the race icon.")
	Checkbox("deathMarkers", "Skull on dead members", "Show a skull on members who are dead. Their icon stays where they died until they are back on their feet.")

	if Settings.CreateSlider and Settings.CreateSliderOptions then
		local setting = Settings.RegisterAddOnSetting(category, "MauGuildMap_pinScale", "pinScale", settings, Settings.VarType.Number, "Icon size", NS.DEFAULTS.pinScale)
		setting:SetValueChangedCallback(function()
			Options:OnChanged("pinScale")
		end)
		local sliderOptions = Settings.CreateSliderOptions(0.6, 1.6, 0.1)
		if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
			sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
				return string.format("%d%%", value * 100 + 0.5)
			end)
		end
		Settings.CreateSlider(category, setting, sliderOptions, "Size of the icons on the map.")
	end

	Header(layout, "Tooltip")
	Checkbox("showHealth", "Show health", "Show a member's health in the tooltip, if they share it.")
	Checkbox("showPower", "Show mana, rage or energy", "Show a member's mana, rage, energy or focus in the tooltip, if they share it.")
	Checkbox("showXP", "Show experience", "Show a member's experience towards the next level in the tooltip, if they share it.")

	Header(layout, "Privacy: what you send to the guild")
	Checkbox("broadcast", "Send my position", "Send your position to guild members who run MauGuildMap. Off means nobody sees you on their map.")
	Checkbox("shareHealth", "Share my health", "Include your current and maximum health in what you send.")
	Checkbox("sharePower", "Share my mana, rage or energy", "Include your current and maximum mana, rage, energy or focus in what you send.")
	Checkbox("shareXP", "Share my experience", "Include your experience towards the next level in what you send.")

	Settings.RegisterAddOnCategory(category)
end

function Options:OnChanged(key)
	if key == "broadcast" then
		if NS.GetSettings().broadcast then
			NS.Comm:ForceSend()
		else
			NS.Comm:SendBye()
		end
	elseif key == "shareHealth" or key == "sharePower" or key == "shareXP" then
		-- Tell everyone right away what is and is not shared any more.
		NS.Comm:ForceSend()
	else
		NS.Map:RequestRefresh()
	end
end

function Options:Open()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	else
		NS.Print("Options are under Escape > Options > AddOns > MauGuildMap.")
	end
end
