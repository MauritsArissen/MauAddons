-- MauGuildMap communication: what goes over the guild addon channel.
--
-- Wire format, one line, fields separated by ":":
--   1:<mapID>:<x>:<y>:<level>:<raceFile>:<sex>:<classFile>:<flag>:<instanceName>
--   x and y are the map position times 10000.  flag is O (outdoors, the
--   position is where the player stands) or I (inside an instance, the
--   position is the last outdoor spot, i.e. the entrance).  A plain "B" means
--   goodbye.  Under 60 bytes; the channel allows 255.
--
-- Sending: every SEND_INTERVAL seconds the position is sampled and a message
-- goes out if anything changed, otherwise every HEARTBEAT seconds.  Inside an
-- instance the client refuses to give a map position, so the last outdoor
-- sample (taken at most SEND_INTERVAL seconds before the loading screen) is
-- what gets sent; if the addon was loaded while already inside, the encounter
-- journal is asked for the instance's entrance.

local _, NS = ...

local Comm = CreateFrame("Frame")
NS.Comm = Comm

local VERSION = "1"
local SCALE = 10000
local MOVE_EPSILON = 0.0005

local RESULT_SUCCESS = (Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success) or 0

-------------------------------------------------------------------------------
-- Encoding
-------------------------------------------------------------------------------

function Comm:Encode(s)
	return table.concat({
		VERSION,
		s.mapID or 0,
		math.floor((s.x or 0) * SCALE + 0.5),
		math.floor((s.y or 0) * SCALE + 0.5),
		s.level or 0,
		s.race or "",
		s.sex or 2,
		s.class or "",
		s.flag or "O",
		s.instance or "",
	}, ":")
end

function Comm:Decode(text)
	if text == "B" then
		return { bye = true }
	end
	local version, mapID, x, y, level, race, sex, class, flag, instance =
		text:match("^(%d+):(%d+):(%d+):(%d+):(%d+):(%w*):(%d+):(%w*):(%a):(.*)$")
	if version ~= VERSION then
		return nil
	end
	return {
		mapID = tonumber(mapID),
		x = tonumber(x) / SCALE,
		y = tonumber(y) / SCALE,
		level = tonumber(level),
		race = race,
		sex = tonumber(sex),
		class = class,
		inInstance = (flag == "I"),
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

	local inInstance = IsInInstance()
	if not inInstance then
		local mapID, x, y = self:SampleOutdoor()
		if mapID then
			self.lastOutdoor = self.lastOutdoor or {}
			self.lastOutdoor.mapID, self.lastOutdoor.x, self.lastOutdoor.y = mapID, x, y
		end
		state.flag = "O"
		state.instance = ""
	else
		state.flag = "I"
		state.instance = GetInstanceInfo() or "instance"
		if not self.lastOutdoor then
			local mapID, x, y = self:FindEntrance()
			if mapID then
				self.lastOutdoor = { mapID = mapID, x = x, y = y }
			end
		end
	end

	local outdoor = self.lastOutdoor
	state.mapID = outdoor and outdoor.mapID or 0
	state.x = outdoor and outdoor.x or 0
	state.y = outdoor and outdoor.y or 0
	state.level = UnitLevel("player") or 0
	local _, raceFile = UnitRace("player")
	state.race = raceFile or ""
	state.sex = UnitSex("player") or 2
	local _, classFile = UnitClass("player")
	state.class = classFile or ""
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
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)
	end
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self.ticker = C_Timer.NewTicker(NS.SEND_INTERVAL, function()
		self:Tick()
	end)
	self:Tick()
end

local function Changed(a, b)
	if not a then
		return true
	end
	return a.flag ~= b.flag or a.mapID ~= b.mapID or a.level ~= b.level or a.instance ~= b.instance
		or math.abs(a.x - b.x) > MOVE_EPSILON or math.abs(a.y - b.y) > MOVE_EPSILON
end

function Comm:Tick()
	if not NS.GetSettings().broadcast or not IsInGuild() then
		return
	end
	local state = self:CurrentState()
	local now = GetTime()
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
		self.lastSent = self.lastSent or {}
		for k, v in pairs(state) do
			self.lastSent[k] = v
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
	if not isTest and name == self.playerName then
		return
	end
	local data = self:Decode(text)
	if not data then
		return
	end
	if data.bye then
		NS.Roster:Remove(name, "logged out")
		return
	end
	data.test = isTest or nil
	NS.Roster:Update(name, data)
end

Comm:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == NS.PREFIX and channel == "GUILD" then
			self:OnMessage(text, sender)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- After a loading screen tell everyone where we ended up.
		self.lastSendTime = 0
	elseif event == "PLAYER_LEVEL_UP" then
		self.lastSendTime = 0
	end
end)
