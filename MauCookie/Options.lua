-- MauCookie options: a category in the game's Settings > AddOns panel.
-- /mck options opens it.  Same pattern as the other Mau addons.

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
	local category, layout = Settings.RegisterVerticalLayoutCategory("MauCookie")
	self.category = category

	local function Register(key, varType, name)
		local setting = Settings.RegisterAddOnSetting(category, "MauCookie_" .. key, key, settings, varType, name, NS.DEFAULTS[key])
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

	Header(layout, "Bakery")
	Checkbox("sounds", "Sounds", "Clicks, purchases, golden cookies, achievements and ascension.")
	Checkbox("popups", "Click popups", "A small +cookies text where you click the cookie.")

	Header(layout, "Window")
	Slider("scale", "Window size", "Scale of the bakery window. Drag the window to move it.", Percent)
	Checkbox("customArt", "Use my own art from the Textures folder", "Reads cookie, golden and building_<id> image files (TGA, BLP or PNG) from Interface\\AddOns\\MauCookie\\Textures. New files need a full client restart. See the README for the names.")

	Header(layout, "Guild")
	Checkbox("shareScores", "Share my bakery with the guild", "A snapshot of your bakery (cookies baked, per second, prestige, buildings, achievements) goes to guild members who use MauCookie, and you keep and pass on theirs. Nothing goes to guild chat.")

	Settings.RegisterAddOnCategory(category)
end

function Options:OnChanged(key)
	if key == "scale" then
		NS.UI:ApplyScale()
	elseif key == "customArt" then
		NS.UI:ApplyArt()
	elseif key == "shareScores" then
		if NS.GetSettings().shareScores then
			NS.Comm:Announce()
		end
		NS.UI:OnGuildDataChanged()
	end
end

function Options:Open()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	else
		NS.Print("Options are under Escape > Options > AddOns > MauCookie.")
	end
end
