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

local function Percent(value)
	return string.format("%d%%", value + 0.5)
end

local function Pixels(value)
	return string.format("%d px", value + 0.5)
end

local function Points(value)
	return string.format("%d", value + 0.5)
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

	local function Register(key, varType, name)
		local setting = Settings.RegisterAddOnSetting(category, "MauGuildMap_" .. key, key, settings, varType, name, NS.DEFAULTS[key])
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

	-- entries: list of { value, label, ... }
	local function Dropdown(key, name, tooltip, entries)
		if not Settings.CreateDropdown or not Settings.CreateControlTextContainer then
			return
		end
		local setting = Register(key, Settings.VarType.String, name)
		local function GetOptions()
			local container = Settings.CreateControlTextContainer()
			for _, entry in ipairs(entries) do
				container:Add(entry[1], entry[2])
			end
			return container:GetData()
		end
		Settings.CreateDropdown(category, setting, GetOptions, tooltip)
	end

	Header(layout, "Map")
	Checkbox("display", "Show guild members on the map", "Draw the guild members who run MauGuildMap on the world map. Turning this off keeps listening, so turning it back on shows everyone at once.")
	Checkbox("deathMarkers", "Skull on dead members", "Show a skull on members who are dead. Their icon stays where they died until they are back on their feet.")
	Slider("iconSize", "Icon size", "Size of the race icon in pixels.", Pixels)
	Slider("iconZoom", "Icon zoom", "How much of the race icon's rim is cropped away. 0% shows Blizzard's icon as it is.", Percent)
	Slider("instanceAlpha", "Opacity inside instances", "How solid the icon of a member inside a dungeon, raid or battleground is drawn.", Percent)

	Header(layout, "Class ring")
	Checkbox("ring", "Ring around the icons", "A ring in the member's class colour around the race icon.")
	Slider("ringWidth", "Ring width", "Thickness of the class-coloured ring in pixels.", Pixels)

	Header(layout, "Name labels")
	Checkbox("labels", "Name under the icons", "Write each member's name next to their icon.")
	Dropdown("labelFont", "Font", "Typeface of the name.", NS.FONTS)
	Slider("labelSize", "Text size", "Size of the name in points.", Points)
	Dropdown("labelOutline", "Outline", "Outline around the letters. None uses a drop shadow instead.", NS.OUTLINES)
	Dropdown("labelPosition", "Position", "Where the name goes relative to the icon.", NS.LABEL_POSITIONS)
	Slider("labelOffset", "Distance from the icon", "Gap between the icon and the name in pixels.", Pixels)
	Checkbox("labelClassColor", "Class colour", "Colour the name by the member's class. Off writes it in white.")

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
