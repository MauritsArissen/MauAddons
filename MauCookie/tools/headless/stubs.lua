-- WoW API stubs for the headless MauCookie run (Lua 5.3 under fengari, so
-- a few 5.1 conveniences are shimmed).
unpack = unpack or table.unpack
math.log10 = math.log10 or function(x) return math.log(x, 10) end
do
	local orig = string.format
	string.format = function(fmt, ...)
		local ok, res = pcall(orig, fmt, ...)
		if ok then return res end
		local n = select("#", ...)
		local args = { ... }
		for i = 1, n do
			if type(args[i]) == "number" then args[i] = math.floor(args[i]) end
		end
		return orig(fmt, unpack(args, 1, n))
	end
end

__clock = 0
function GetTime() return __clock end
function GetServerTime() return os.time() end
function strsplit(sep, s)
	local out = {}
	for part in (s .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do out[#out + 1] = part end
	return unpack(out)
end
function tinsert(t, v) table.insert(t, v) end
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function UnitName() return "Tester" end
function UnitClass() return "Mage", "MAGE" end
function UnitOnTaxi() return false end
function IsFlying() return false end
function IsInGuild() return false end
function GetGuildInfo() return nil end
function IsShiftKeyDown() return false end
function PlaySound() end
function GetCursorPosition() return 100, 100 end
function GetNumGuildMembers() return 0 end
function GetGuildRosterInfo() return nil end
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "font"
RAID_CLASS_COLORS = { MAGE = { r = 0.4, g = 0.8, b = 0.9 } }
C_ChatInfo = { RegisterAddonMessagePrefix = function() end, SendAddonMessage = function() end }
C_GuildInfo = { GuildRoster = function() end }
C_ClassColor = { GetClassColor = function() return { r = 0.4, g = 0.8, b = 0.9 } end }
C_Timer = { After = function(delay, f) __timers = __timers or {}; table.insert(__timers, { at = __clock + delay, f = f }) end }
function __flushTimers()
	local list = __timers or {}
	__timers = {}
	for _, t in ipairs(list) do t.f() end
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- Frames: tables whose unknown methods are no-ops returning the frame;
-- a few return numbers or booleans so arithmetic and conditions work.
local NUMERIC = { GetWidth = 100, GetHeight = 100, GetFrameLevel = 1, GetEffectiveScale = 1, GetLeft = 0, GetBottom = 0, GetTop = 100, GetRight = 100, GetVerticalScroll = 0, GetStringHeight = 20, GetStringWidth = 50, GetScale = 1, GetAlpha = 1, GetID = 1 }
local function Frame(kind)
	local f = { __kind = kind, shown = false }
	setmetatable(f, { __index = function(t, k)
		if type(k) ~= "string" or not __METHODS[k] then return nil end
		if NUMERIC[k] ~= nil then return function() return NUMERIC[k] end end
		if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
		if k == "Show" then return function(self) self.shown = true; if self.__onShow then self.__onShow(self) end end end
		if k == "Hide" then return function(self) self.shown = false end end
		if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
		if k == "GetText" then return function() return "" end end
		if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
		if k == "GetCenter" then return function() return 50, 50 end end
		if k == "GetParent" then return function(self) return self.__parent or Frame("parent") end end
		if k == "CreateTexture" or k == "CreateFontString" or k == "CreateMaskTexture" then return function(self) local c = Frame(k); c.__parent = self; return c end end
		if k == "SetScript" then return function(self, name, fn) self.__scripts = self.__scripts or {}; self.__scripts[name] = fn; if name == "OnShow" then self.__onShow = fn end end end
		if k == "GetScript" then return function(self, name) return self.__scripts and self.__scripts[name] end end
		if k == "RegisterEvent" or k == "UnregisterEvent" then return function() end end
		return function(self) return self end
	end })
	return f
end
__Frame = Frame
function CreateFrame(kind, name, parent)
	local f = Frame(kind)
	f.__parent = parent
	if name then _G[name] = f end
	return f
end
UIParent = Frame("UIParent")
GameTooltip = Frame("GameTooltip")
Minimap = nil
Settings = nil
MauCookieDB = nil
function date(fmt, t) return os.date(fmt, t) end
function time() return os.time() end

-- Capture prints so the harness can grep for errors.
__log = {}
local rawprint = print
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	local line = table.concat(parts, " ")
	__log[#__log + 1] = line
	rawprint(line)
end
