-- MauGuildMap communication: what goes over the guild addon channel.
--
-- Wire format, one line, fields separated by ":":
--   3:<token>:<mapID>:<x>:<y>:<level>:<raceFile>:<sex>:<classFile>:<flags>
--    :<hp>:<hpMax>:<power>:<powerMax>:<powerType>:<xp>:<xpMax>:<instanceName>
--   token   random hex id chosen at login; the guild channel echoes our own
--           messages back and this is how they are recognised.
--   x, y    map position times 10000.
--   flags   O outdoors (the position is where the player stands) or I inside
--           an instance (the position is the last outdoor spot, i.e. the
--           entrance), plus D when dead (the position is where they died).
--   hp ... xpMax  whole numbers, or empty when the sender does not share
--           them, is at max level (xp) or the client protected the value.
--   powerType is the Enum.PowerType number (0 mana, 1 rage, 3 energy ...).
--   A plain "B" means goodbye.  Around 80 bytes; the channel allows 255.
--
-- Sending: every SEND_INTERVAL seconds the state is sampled and a message
-- goes out if the position, level, flags or instance changed or health moved
-- by ten points of percent, otherwise every HEARTBEAT seconds.  Inside an
-- instance the client refuses to give a map position, so the last outdoor
-- sample (taken at most SEND_INTERVAL seconds before the loading screen) is
-- what gets sent; if the addon was loaded while already inside, the encounter
-- journal is asked for the instance's entrance.  While dead the position is
-- frozen where the player died.
--
-- While the game is in the background (NS.IsBackground) nothing is sampled
-- and only a heartbeat with the last state goes out; incoming messages are
-- kept, latest per sender, and applied when the game is back.

local _, NS = ...

local Comm = CreateFrame("Frame")
NS.Comm = Comm

local VERSION = "3"
local SCALE = 10000
local MOVE_EPSILON = 0.0005
local HEALTH_EPSILON = 0.10
-- Token used for simulated members (Test.lua); never equal to our own.
local TEST_TOKEN = "0"

local RESULT_SUCCESS = (Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success) or 0

-------------------------------------------------------------------------------
-- Encoding
-------------------------------------------------------------------------------

local function Optional(value)
	if value == nil then
		return ""
	end
	return tostring(math.floor(value))
end

function Comm:Encode(s)
	return table.concat({
		VERSION,
		s.token or TEST_TOKEN,
		s.mapID or 0,
		math.floor((s.x or 0) * SCALE + 0.5),
		math.floor((s.y or 0) * SCALE + 0.5),
		s.level or 0,
		s.race or "",
		s.sex or 2,
		s.class or "",
		s.flags or "O",
		Optional(s.hp),
		Optional(s.hpMax),
		Optional(s.power),
		Optional(s.powerMax),
		Optional(s.powerType),
		Optional(s.xp),
		Optional(s.xpMax),
		s.instance or "",
	}, ":")
end

function Comm:Decode(text)
	if text == "B" then
		return { bye = true }
	end
	local version, token, mapID, x, y, level, race, sex, class, flags, hp, hpMax, power, powerMax, powerType, xp, xpMax, instance =
		text:match("^(%d+):(%x+):(%d+):(%d+):(%d+):(%d+):(%w*):(%d+):(%w*):(%a+):(%d*):(%d*):(%d*):(%d*):(%d*):(%d*):(%d*):(.*)$")
	if version ~= VERSION then
		return nil
	end
	return {
		token = token,
		mapID = tonumber(mapID),
		x = tonumber(x) / SCALE,
		y = tonumber(y) / SCALE,
		level = tonumber(level),
		race = race,
		sex = tonumber(sex),
		class = class,
		inInstance = flags:find("I", 1, true) ~= nil,
		dead = flags:find("D", 1, true) ~= nil,
		hp = tonumber(hp),
		hpMax = tonumber(hpMax),
		power = tonumber(power),
		powerMax = tonumber(powerMax),
		powerType = tonumber(powerType),
		xp = tonumber(xp),
		xpMax = tonumber(xpMax),
		instance = instance,
	}
end

-------------------------------------------------------------------------------
-- Position sampling
-------------------------------------------------------------------------------

function Comm:SampleOutdoor()
	if not C_Map or not C_Map.GetBestMapForUnit then
		return nil
	end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		return nil
	end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then
		return nil
	end
	local x, y = pos:GetXY()
	if not x or not y then
		return nil
	end
	return mapID, x, y
end

-- Where the entrance of the current instance is, via the encounter journal:
-- walk up from the instance's own map until a parent lists an entrance for
-- this instance.  Only used when no outdoor sample exists.
function Comm:FindEntrance()
	if not C_EncounterJournal or not C_EncounterJournal.GetDungeonEntrancesForMap or not C_EncounterJournal.GetInstanceForGameMap then
		return nil
	end
	local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
	local journalID = instanceMapID and C_EncounterJournal.GetInstanceForGameMap(instanceMapID)
	if not journalID then
		return nil
	end
	local mapID = C_Map.GetBestMapForUnit("player")
	for _ = 1, 8 do
		if not mapID or mapID == 0 then
			return nil
		end
		local ok, entrances = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
		if ok and type(entrances) == "table" then
			for _, entrance in ipairs(entrances) do
				if entrance.journalInstanceID == journalID and entrance.position then
					local x, y = entrance.position:GetXY()
					if x and y then
						return mapID, x, y
					end
				end
			end
		end
		local info = C_Map.GetMapInfo(mapID)
		mapID = info and info.parentMapID or nil
	end
	return nil
end

function Comm:CurrentState()
	local state = self.state or {}
	self.state = state
	local settings = NS.GetSettings()

	local inInstance = IsInInstance()
	if not inInstance then
		local mapID, x, y = self:SampleOutdoor()
		if mapID then
			self.lastOutdoor = self.lastOutdoor or {}
			self.lastOutdoor.mapID, self.lastOutdoor.x, self.lastOutdoor.y = mapID, x, y
		end
		state.instance = ""
	else
		local name, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		state.instance = name or "instance"
		-- The journal lookup is tried once per instance, not every tick.
		if not self.lastOutdoor and self.entranceLookedUpFor ~= instanceMapID then
			self.entranceLookedUpFor = instanceMapID
			local mapID, x, y = self:FindEntrance()
			if mapID then
				self.lastOutdoor = { mapID = mapID, x = x, y = y }
			end
		end
	end

	-- Dead: freeze the position where it happened until alive again.
	local dead = UnitIsDeadOrGhost("player") and true or false
	if dead then
		if not self.deathPos and self.lastOutdoor then
			self.deathPos = { mapID = self.lastOutdoor.mapID, x = self.lastOutdoor.x, y = self.lastOutdoor.y }
		end
	else
		self.deathPos = nil
	end

	local position = (dead and self.deathPos) or self.lastOutdoor
	state.token = self.token
	state.mapID = position and position.mapID or 0
	state.x = position and position.x or 0
	state.y = position and position.y or 0
	state.flags = (inInstance and "I" or "O") .. (dead and "D" or "")
	state.level = UnitLevel("player") or 0
	local _, raceFile = UnitRace("player")
	state.race = raceFile or ""
	state.sex = UnitSex("player") or 2
	local _, classFile = UnitClass("player")
	state.class = classFile or ""

	-- Shared stats; nil when not shared, unknown or protected (see SafeNumber).
	state.hp, state.hpMax = nil, nil
	if settings.shareHealth then
		state.hp = NS.SafeNumber(UnitHealth("player"))
		state.hpMax = NS.SafeNumber(UnitHealthMax("player"))
	end
	state.power, state.powerMax, state.powerType = nil, nil, nil
	if settings.sharePower then
		state.power = NS.SafeNumber(UnitPower("player"))
		state.powerMax = NS.SafeNumber(UnitPowerMax("player"))
		state.powerType = NS.SafeNumber((UnitPowerType("player")))
	end
	state.xp, state.xpMax = nil, nil
	if settings.shareXP and state.level < NS.MaxLevel() then
		state.xp = NS.SafeNumber(UnitXP("player"))
		state.xpMax = NS.SafeNumber(UnitXPMax("player"))
	end
	return state
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

function Comm:Start()
	if self.started then
		return
	end
	self.started = true
	self.playerName = NS.ShortName(UnitName("player"))
	self.token = string.format("%x", math.random(1, 0xffffff))
	self.queue = {}
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)
	end
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("PLAYER_ALIVE")
	self:RegisterEvent("PLAYER_UNGHOST")
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self.inGuild = IsInGuild() and true or false
	self.ticker = C_Timer.NewTicker(NS.SEND_INTERVAL, function()
		self:Tick()
	end)
	self:Tick()
end

-- Joined or left a guild: start announcing at once, or forget the old
-- guild's members.  Checked on the guild events and on every tick, so it
-- works whatever the event payload looks like on this client.
function Comm:CheckGuild()
	local inGuild = IsInGuild() and true or false
	if inGuild == self.inGuild then
		return
	end
	self.inGuild = inGuild
	self.lastSent = nil
	if inGuild then
		self.lastSendTime = 0
		self:Tick()
	else
		NS.Roster:Clear()
	end
end

-- Someone new showed up (a member who just joined the guild, logged in or
-- installed the addon): answer soon with our own state so they see us right
-- away instead of after our next heartbeat.  A little jitter keeps a whole
-- guild from answering in the same instant.
function Comm:AnnounceSoon()
	if self.announceQueued then
		return
	end
	self.announceQueued = true
	C_Timer.After(0.5 + math.random() * 1.5, function()
		self.announceQueued = false
		self:ForceSend()
	end)
end

local function Fraction(value, max)
	if value and max and max > 0 then
		return value / max
	end
	return 0
end

local function Changed(a, b)
	if not a then
		return true
	end
	return a.flags ~= b.flags or a.mapID ~= b.mapID or a.level ~= b.level or a.instance ~= b.instance
		or math.abs(a.x - b.x) > MOVE_EPSILON or math.abs(a.y - b.y) > MOVE_EPSILON
		or math.abs(Fraction(a.hp, a.hpMax) - Fraction(b.hp, b.hpMax)) >= HEALTH_EPSILON
end

function Comm:Tick()
	self:CheckGuild()
	if not NS.GetSettings().broadcast or not self.inGuild then
		return
	end
	local now = GetTime()
	if NS.IsBackground() then
		-- Nothing moves while alt-tabbed: no sampling, just the heartbeat with
		-- the last state so guild mates keep the pin.
		if self.lastSent and now - (self.lastSendTime or 0) >= NS.HEARTBEAT then
			self:Send(self.lastSent, now)
		end
		return
	end
	local state = self:CurrentState()
	if Changed(self.lastSent, state) or now - (self.lastSendTime or 0) >= NS.HEARTBEAT then
		self:Send(state, now)
	end
end

function Comm:Send(state, now)
	if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
		return false
	end
	local result = C_ChatInfo.SendAddonMessage(NS.PREFIX, self:Encode(state), "GUILD")
	local ok = result == true or result == RESULT_SUCCESS or result == nil
	if ok then
		if state ~= self.lastSent then
			self.lastSent = self.lastSent or {}
			wipe(self.lastSent)
			for k, v in pairs(state) do
				self.lastSent[k] = v
			end
		end
		self.lastSendTime = now or GetTime()
	end
	return ok
end

function Comm:ForceSend()
	self.lastSendTime = 0
	self:Tick()
end

function Comm:SendBye()
	if not self.started or not IsInGuild() or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
		return
	end
	C_ChatInfo.SendAddonMessage(NS.PREFIX, "B", "GUILD")
	self.lastSent = nil
end

-------------------------------------------------------------------------------
-- Receiving
-------------------------------------------------------------------------------

-- isTest marks simulated members (Test.lua); they bypass the own-name check.
function Comm:OnMessage(text, sender, isTest)
	local name = NS.ShortName(sender)
	if not name then
		return
	end
	if NS.IsBackground() and self.queue then
		-- Keep only the latest message per sender until the game is back.
		self.queue[name] = { text = text, test = isTest or nil }
		return
	end
	if not isTest and self.playerName and string.lower(name) == string.lower(self.playerName) then
		return
	end
	local data = self:Decode(text)
	if not data then
		return
	end
	-- The guild channel echoes our own messages; the token is the sure test.
	if not isTest and data.token and data.token == self.token then
		return
	end
	if data.bye then
		NS.Roster:Remove(name, "logged out")
		return
	end
	data.test = isTest or nil
	NS.Roster:Update(name, data)
end

-- Back from the background: apply what arrived meanwhile and send our state.
function Comm:OnForeground()
	local queue = self.queue
	if not queue then
		return
	end
	self.queue = {}
	for name, item in pairs(queue) do
		self:OnMessage(item.text, name, item.test)
	end
	self.lastSendTime = 0
end

Comm:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == NS.PREFIX and channel == "GUILD" then
			self:OnMessage(text, sender)
		end
	elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
		self:CheckGuild()
	else
		-- Loading screens, level-ups, deaths and resurrections: tell everyone
		-- at the next tick rather than waiting for the heartbeat.
		self.lastSendTime = 0
	end
end)
