-- MauPlinko guild scores.
--
-- Guild members who run the addon exchange their best hit, biggest win,
-- number of drops and net result over the guild addon channel, which the
-- window shows as a leaderboard.  Messages:
--   S:<token>:<class>:<bestMult>:<bestWin>:<drops>:<net>   a score
--   Q:<token>                                              please send yours
-- A score goes out after a drop changed it (at most every SEND_GAP seconds),
-- on login and in answer to a Q.  The token tells our own echoed messages
-- apart from everybody else's.  Nothing is sent when score sharing is off
-- or the player is not in a guild.

local _, NS = ...

NS.PREFIX = "MauPlinko"

local Comm = CreateFrame("Frame")
NS.Comm = Comm
Comm.scores = {}

local SEND_GAP = 15
local ASK_GAP = 60

function Comm:Start()
	if self.started then
		return
	end
	self.started = true
	self.playerName = NS.ShortName(UnitName("player"))
	self.token = string.format("%x", math.random(1, 0xffffff))
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)
	end
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:SetScript("OnEvent", function(frame, event, ...)
		NS.Guard("Comm " .. event, frame.OnEvent, frame, event, ...)
	end)
end

function Comm:Enabled()
	return self.started and IsInGuild() and NS.GetSettings().shareScores
end

function Comm:Send(text)
	if not IsInGuild() or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
		return
	end
	pcall(C_ChatInfo.SendAddonMessage, NS.PREFIX, text, "GUILD")
end

local function Signature()
	local st = MauPlinkoDB.stats
	return string.format("%g:%d:%d:%d", st.bestMult, NS.Round(st.bestWin), st.drops, NS.Round(st.returned - st.wagered))
end

-- `force` sends even when nothing changed since the last time.
function Comm:SendScore(force)
	if not self:Enabled() or MauPlinkoDB.stats.drops == 0 then
		return
	end
	local sig = Signature()
	if not force and sig == self.lastSig then
		return
	end
	local _, classFile = UnitClass("player")
	self:Send(string.format("S:%s:%s:%s", self.token, classFile or "", sig))
	self.lastSig = sig
	self.lastSend = GetTime()
end

-- A drop or a reset changed the score: send it soon, but not more often
-- than every SEND_GAP seconds.
function Comm:OnScoreChanged()
	if not self:Enabled() or self.pending then
		return
	end
	local wait = math.max(1, SEND_GAP - (GetTime() - (self.lastSend or 0)))
	self.pending = true
	C_Timer.After(wait, function()
		Comm.pending = nil
		Comm:SendScore()
	end)
end

function Comm:Ask()
	if not self.started or not IsInGuild() then
		return
	end
	local now = GetTime()
	if now - (self.lastAsk or 0) < ASK_GAP then
		return
	end
	self.lastAsk = now
	self:Send("Q:" .. self.token)
end

function Comm:OnMessage(text, sender)
	local name = NS.ShortName(sender)
	if not name then
		return
	end
	local kind, token, rest = text:match("^(%a):([^:]*):?(.*)$")
	if not kind or token == self.token then
		return
	end
	if self.playerName and name:lower() == self.playerName:lower() then
		return
	end
	if kind == "Q" then
		if self:Enabled() then
			C_Timer.After(0.5 + math.random() * 2, function()
				Comm:SendScore(true)
			end)
		end
	elseif kind == "S" then
		local class, bestMult, bestWin, drops, net = rest:match("^([^:]*):([^:]+):([^:]+):([^:]+):([^:]+)$")
		if not bestMult then
			return
		end
		self.scores[name] = {
			name = name,
			class = class ~= "" and class or nil,
			bestMult = tonumber(bestMult) or 0,
			bestWin = tonumber(bestWin) or 0,
			drops = tonumber(drops) or 0,
			net = tonumber(net) or 0,
			seen = GetTime(),
		}
		NS.UI:RefreshGuild()
	end
end

function Comm:OnEvent(event, prefix, text, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == NS.PREFIX and channel == "GUILD" and type(text) == "string" then
			self:OnMessage(text, sender)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(5, function()
			Comm:Ask()
			Comm:SendScore(true)
		end)
	elseif event == "PLAYER_GUILD_UPDATE" then
		if not IsInGuild() then
			self.scores = {}
			NS.UI:RefreshGuild()
		else
			self.lastAsk = nil
			self:Ask()
			self:SendScore(true)
		end
	end
end

-- Everybody known, including ourselves, best hit first.
function Comm:SortedScores()
	local list = {}
	for _, entry in pairs(self.scores) do
		table.insert(list, entry)
	end
	local st = MauPlinkoDB.stats
	local _, classFile = UnitClass("player")
	table.insert(list, {
		name = self.playerName or NS.ShortName(UnitName("player")) or "You",
		class = classFile,
		bestMult = st.bestMult,
		bestWin = st.bestWin,
		drops = st.drops,
		net = st.returned - st.wagered,
		me = true,
	})
	table.sort(list, function(a, b)
		if a.bestMult ~= b.bestMult then
			return a.bestMult > b.bestMult
		end
		if a.net ~= b.net then
			return a.net > b.net
		end
		return a.name < b.name
	end)
	return list
end
