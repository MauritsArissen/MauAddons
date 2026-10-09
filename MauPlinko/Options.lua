-- MauPlinko options: a category in the game's Settings > AddOns panel.
-- /mpk options opens it.  Same pattern as MauGuildMap and MauLootbox.

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

local function Seconds(value)
	return string.format("%.2f s", value)
end

local function Times(value)
	return string.format("%dx", value + 0.5)
end

function Options:Register()
	if self.category then
		return
	end
	if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting or not Settings.CreateCheckbox then
		return
	end
	local settings = NS.GetSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MauPlinko")
	self.category = category

	local function Register(key, varType, name)
		local setting = Settings.RegisterAddOnSetting(category, "MauPlinko_" .. key, key, settings, varType, name, NS.DEFAULTS[key])
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

	Header(layout, "Game")
	Slider("speed", "Ball speed", "How fast the balls fall. 100% is the normal speed.", Percent)
	Slider("autoDelay", "Auto drop interval", "Time between two balls in auto mode. Takes effect the next time you press Start.", Seconds)
	Checkbox("sounds", "Sounds", "All sounds: the peg ticks, the landing and the fanfares.")
	Checkbox("pegSounds", "Tick on every peg", "A small click each time a ball hits a peg. Landing sounds stay on.")

	Header(layout, "Window")
	Slider("scale", "Window size", "Scale of the Plinko window. Drag the window to move it.", Percent)

	Header(layout, "Guild")
	Checkbox("shareScores", "Share my scores with the guild", "Guild members who use MauPlinko see your best hit, biggest win, number of drops and net result on their Guild tab, and you see theirs. Nothing is sent to anyone else.")
	Checkbox("announceGuild", "Announce big hits in guild chat", "Posts one line in guild chat when a ball lands on a big multiplier.")
	Slider("announceFrom", "Announce hits from", "The multiplier from which a hit is posted in guild chat.", Times)

	Settings.RegisterAddOnCategory(category)
end

function Options:OnChanged(key)
	if key == "scale" then
		NS.UI:ApplyScale()
	elseif key == "shareScores" then
		if NS.GetSettings().shareScores then
			NS.Comm.lastAsk = nil
			NS.Comm:Ask()
			NS.Comm:SendScore(true)
		end
		NS.UI:RefreshGuild()
	end
end

function Options:Open()
	if self.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	else
		NS.Print("Options are under Escape > Options > AddOns > MauPlinko.")
	end
end
