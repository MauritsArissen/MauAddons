-- MauPeggle guild board: scores shared with guild members over the addon
-- channel, kept in the saved variables, relayed for people who are offline.
--
-- The trick that keeps this simple is that a player's record only ever goes
-- up: best score per level, highest level unlocked, total, and the time of
-- the last change.  So any copy from anyone can be merged by taking the
-- maximum of every field, duplicates are harmless, nothing needs an owner
-- and anybody may relay anybody.  Messages (fields split by ':'):
--
--   R:<token>:<name>:<class>:<unlocked>:<total>:<ts>:<l>=<s>,<l>=<s>...
--       a record (chunked over several messages when long; each chunk
--       merges on its own)
--   I:<token>:<name>=<ts>,<name>=<ts>...     inventory: who I know and how fresh
--   Q:<token>:<name>,<name>...               please send these records
--
-- Traffic: a new best sends your own record (one or two messages, at most
-- every 10 s).  Logging in sends your record and an inventory; peers answer
-- only with records that are newer than what you listed, after a random
-- delay, and skip when somebody else already sent that record (every
-- record seen on the channel is remembered for 30 s).  Things you have that
-- a peer lacks are asked for with a Q, again with jitter and suppression,
-- and you broadcast them once for everyone.  An inventory also goes out
-- when the guild board is opened (at most every 5 min) and every 15 min if
-- anything changed.  All outgoing messages leave through a queue at four a
-- second.  The token tells our own echo apart from everyone else's.

local _, NS = ...

NS.PREFIX = "MauPeggle"

local Comm = CreateFrame("Frame")
NS.Comm = Comm

local MAX_PAYLOAD = 235
local SEND_RATE = 0.25
local OWN_GAP = 10
local INVENTORY_GAP = 300
local PERIODIC = 900
local RECENT_WINDOW = 30
local ASKED_WINDOW = 10
local ONLINE_WINDOW = 600
local QUEUE_CAP = 60

function Comm:Start()
	if self.started then
		return
	end
	self.started = true
	self.playerName = NS.ShortName(UnitName("player"))
	self.token = string.format("%x", math.random(1, 0xffffff))
	self.queue = {}
	self.recent = {}          -- name -> { ts, at }: records seen on the channel
	self.pendingRecords = {}  -- name -> GetTime() at which to send it
	self.wanted = {}          -- names to ask for
	self.askedByOthers = {}   -- name -> GetTime() someone else asked
	self.seen = {}            -- name -> GetTime() of their last message
	self.roster = {}          -- name -> true when the guild roster says online
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)
	end
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:SetScript("OnEvent", function(frame, event, ...)
		NS.Guard("Comm " .. event, frame.OnEvent, frame, event, ...)
	end)
	self:SetScript("OnUpdate", function(frame, elapsed)
		NS.Guard("Comm tick", frame.OnTick, frame, elapsed)
	end)
end

function Comm:Enabled()
	return self.started and IsInGuild() and NS.GetSettings().shareScores
end

-- The store for the current guild (nil outside a guild).
function Comm:Store()
	if not IsInGuild() then
		return nil
	end
	local guild = GetGuildInfo("player")
	if not guild then
		return nil
	end
	MauPeggleDB.guild[guild] = MauPeggleDB.guild[guild] or {}
	return MauPeggleDB.guild[guild]
end

-------------------------------------------------------------------------------
-- Records
-------------------------------------------------------------------------------

function Comm:OwnRecord()
	local p = MauPeggleDB.progress
	local _, classFile = UnitClass("player")
	return { name = self.playerName, class = classFile, unlocked = p.unlocked, total = p.total, ts = p.updated or 0, best = p.best }
end

-- Max-merge a record into the store.  Returns true when anything changed.
function Comm:Merge(rec)
	local store = self:Store()
	if not store or not rec.name or rec.name == "" then
		return false
	end
	local cur = store[rec.name]
	local changed = false
	if not cur then
		cur = { best = {} }
		store[rec.name] = cur
		changed = true
	end
	cur.best = cur.best or {}
	if rec.class and rec.class ~= "" and cur.class ~= rec.class then
		cur.class = rec.class
		changed = true
	end
	if (rec.unlocked or 0) > (cur.unlocked or 0) then
		cur.unlocked = rec.unlocked
		changed = true
	end
	if (rec.total or 0) > (cur.total or 0) then
		cur.total = rec.total
		changed = true
	end
	if (rec.ts or 0) > (cur.ts or 0) then
		cur.ts = rec.ts
		changed = true
	end
	for level, score in pairs(rec.best or {}) do
		if score > (cur.best[level] or 0) then
			cur.best[level] = score
			changed = true
		end
	end
	if changed then
		self.dirty = true
	end
	return changed
end

function Comm:RefreshOwn()
	if self.playerName then
		self:Merge(self:OwnRecord())
	end
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

function Comm:Enqueue(msg)
	if #self.queue < QUEUE_CAP then
		table.insert(self.queue, msg)
	end
end

-- Splits items over as many messages as the payload limit needs.  With no
-- items one message with just the header goes out when `always` is set.
function Comm:SendChunked(header, items, separator, always)
	local parts, len = {}, 0
	for _, item in ipairs(items) do
		if #parts > 0 and #header + len + #item + 1 > MAX_PAYLOAD then
			self:Enqueue(header .. table.concat(parts, separator))
			parts, len = {}, 0
		end
		table.insert(parts, item)
		len = len + #item + 1
	end
	if #parts > 0 then
		self:Enqueue(header .. table.concat(parts, separator))
	elseif always then
		self:Enqueue(header)
	end
end

function Comm:SendRecord(rec)
	local header = string.format("R:%s:%s:%s:%d:%d:%d:", self.token, rec.name, rec.class or "", rec.unlocked or 1, rec.total or 0, rec.ts or 0)
	local levels = {}
	for level in pairs(rec.best or {}) do
		table.insert(levels, level)
	end
	table.sort(levels)
	local items = {}
	for _, level in ipairs(levels) do
		table.insert(items, string.format("%d=%d", level, rec.best[level]))
	end
	self:SendChunked(header, items, ",", true)
	self.recent[rec.name] = { ts = rec.ts or 0, at = GetTime() }
	if rec.name == self.playerName then
		self.lastOwn = GetTime()
	end
end

function Comm:SendOwn()
	if not self:Enabled() then
		return
	end
	self:RefreshOwn()
	local store = self:Store()
	local rec = store and store[self.playerName]
	if rec and (rec.ts or 0) > 0 then
		self:SendRecord(rec)
	end
end

-- Game.lua: a best score or unlock changed.  Coalesced to one send per 10 s.
function Comm:OnProgressChanged()
	self:RefreshOwn()
	if not self:Enabled() or self.ownPending then
		return
	end
	local wait = math.max(1, OWN_GAP - (GetTime() - (self.lastOwn or 0)))
	self.ownPending = true
	C_Timer.After(wait, function()
		Comm.ownPending = nil
		Comm:SendOwn()
	end)
end

function Comm:SendInventory(force)
	if not self:Enabled() then
		return
	end
	local now = GetTime()
	if not force and now - (self.lastInventory or 0) < INVENTORY_GAP then
		return
	end
	self:RefreshOwn()
	local store = self:Store()
	if not store then
		return
	end
	local items = {}
	for name, rec in pairs(store) do
		if (rec.ts or 0) > 0 then
			table.insert(items, string.format("%s=%d", name, rec.ts))
		end
	end
	table.sort(items)
	self:SendChunked("I:" .. self.token .. ":", items, ",", true)
	self.lastInventory = now
	self.dirty = false
end

function Comm:ScheduleRecord(name, delay)
	local at = GetTime() + delay
	local cur = self.pendingRecords[name]
	if not cur or at < cur then
		self.pendingRecords[name] = at
	end
end

function Comm:RequestRoster()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end

-- Login, guild change: tell everyone about ourselves and what we know.
function Comm:Announce()
	if not self:Enabled() then
		return
	end
	self:RequestRoster()
	self:SendOwn()
	self:SendInventory(true)
end

-- The guild board was opened.
function Comm:OnBoardOpened()
	self:RequestRoster()
	self:SendInventory(false)
end

-------------------------------------------------------------------------------
-- Receiving
-------------------------------------------------------------------------------

function Comm:OnMessage(text, sender)
	local kind, token, body = text:match("^(%a):([^:]*):?(.*)$")
	if not kind or token == self.token then
		return
	end
	local from = NS.ShortName(sender)
	if from and self.playerName and from:lower() == self.playerName:lower() then
		return
	end
	if from then
		self.seen[from] = GetTime()
	end
	if not self:Store() then
		return
	end
	if kind == "R" then
		self:OnRecord(body)
	elseif kind == "I" then
		self:OnInventory(body)
	elseif kind == "Q" then
		self:OnRequest(body)
	end
end

function Comm:OnRecord(body)
	local name, class, unlocked, total, ts, list = body:match("^([^:]*):([^:]*):(%d+):(%d+):(%d+):(.*)$")
	if not name or name == "" then
		return
	end
	local best = {}
	for level, score in list:gmatch("(%d+)=(%d+)") do
		best[tonumber(level)] = tonumber(score)
	end
	local rec = { name = name, class = class, unlocked = tonumber(unlocked), total = tonumber(total), ts = tonumber(ts), best = best }
	self.recent[name] = { ts = rec.ts, at = GetTime() }
	if self:Merge(rec) then
		NS.UI:OnGuildDataChanged()
	end
end

function Comm:OnInventory(body)
	local store = self:Store()
	if not store or not self:Enabled() then
		return
	end
	self:RefreshOwn()
	local theirs = {}
	for name, ts in body:gmatch("([^=,]+)=(%d+)") do
		theirs[name] = tonumber(ts)
	end
	-- What we have that is newer than theirs: offer it (jittered, suppressed).
	for name, rec in pairs(store) do
		local ts = rec.ts or 0
		if ts > 0 and (theirs[name] == nil or theirs[name] < ts) then
			self:ScheduleRecord(name, 2 + math.random() * 6)
		end
	end
	-- What they have that is newer than ours: ask for it.
	local want = false
	for name, ts in pairs(theirs) do
		local rec = store[name]
		if not rec or (rec.ts or 0) < ts then
			self.wanted[name] = true
			want = true
		end
	end
	if want and not self.wantedAt then
		self.wantedAt = GetTime() + 2 + math.random() * 4
	end
end

function Comm:OnRequest(body)
	local store = self:Store()
	if not store or not self:Enabled() then
		return
	end
	local now = GetTime()
	for name in body:gmatch("[^,]+") do
		self.askedByOthers[name] = now
		local rec = store[name]
		if rec and (rec.ts or 0) > 0 then
			self:ScheduleRecord(name, 1 + math.random() * 3)
		end
	end
end

function Comm:UpdateRoster()
	if not GetNumGuildMembers or not GetGuildRosterInfo then
		return
	end
	local online = {}
	for i = 1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
		if name and isOnline then
			online[NS.ShortName(name) or name] = true
		end
	end
	self.roster = online
	NS.UI:OnGuildDataChanged()
end

function Comm:OnEvent(event, prefix, text, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == NS.PREFIX and channel == "GUILD" and type(text) == "string" then
			self:OnMessage(text, sender)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(8, function()
			Comm:Announce()
		end)
	elseif event == "PLAYER_GUILD_UPDATE" then
		if IsInGuild() then
			C_Timer.After(5, function()
				Comm:Announce()
			end)
		end
	elseif event == "GUILD_ROSTER_UPDATE" then
		self:UpdateRoster()
	end
end

-- Every 0.2 s: flush one queued message, send due records, ask for wanted
-- ones, periodic inventory.
function Comm:OnTick(elapsed)
	self.tickAcc = (self.tickAcc or 0) + elapsed
	if self.tickAcc < 0.2 then
		return
	end
	self.tickAcc = 0
	local now = GetTime()

	if #self.queue > 0 and now - (self.lastSent or 0) >= SEND_RATE then
		local msg = table.remove(self.queue, 1)
		if IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
			pcall(C_ChatInfo.SendAddonMessage, NS.PREFIX, msg, "GUILD")
		end
		self.lastSent = now
	end

	if not self:Enabled() then
		return
	end
	local hasPending = next(self.pendingRecords) ~= nil
	if not hasPending and not self.wantedAt and not self.dirty then
		return
	end
	local store = self:Store()
	if not store then
		return
	end

	if hasPending then
		for name, at in pairs(self.pendingRecords) do
			if now >= at then
				self.pendingRecords[name] = nil
				local rec = store[name]
				local seen = self.recent[name]
				local covered = seen and seen.ts >= (rec and rec.ts or 0) and now - seen.at < RECENT_WINDOW
				if rec and (rec.ts or 0) > 0 and not covered then
					self:SendRecord(rec)
				end
			end
		end
	end

	if self.wantedAt and now >= self.wantedAt then
		self.wantedAt = nil
		local names = {}
		for name in pairs(self.wanted) do
			local seen = self.recent[name]
			local asked = self.askedByOthers[name]
			local arrived = seen and now - seen.at < RECENT_WINDOW
			local askedRecently = asked and now - asked < ASKED_WINDOW
			if not arrived and not askedRecently then
				table.insert(names, name)
			end
		end
		self.wanted = {}
		table.sort(names)
		if #names > 0 then
			self:SendChunked("Q:" .. self.token .. ":", names, ",", false)
		end
	end

	if self.dirty and now - (self.lastInventory or 0) > PERIODIC then
		self:SendInventory(true)
	end
end

-------------------------------------------------------------------------------
-- Lists for the window
-------------------------------------------------------------------------------

function Comm:IsOnline(name)
	if name == self.playerName then
		return true
	end
	if self.roster[name] then
		return true
	end
	local at = self.seen[name]
	return at ~= nil and GetTime() - at < ONLINE_WINDOW
end

function Comm:HasAddon(name)
	if name == self.playerName then
		return true
	end
	local at = self.seen[name]
	return at ~= nil and GetTime() - at < ONLINE_WINDOW
end

-- Everyone with a score on this level, best first.
function Comm:LevelBoard(level)
	local store = self:Store()
	if not store then
		return {}
	end
	self:RefreshOwn()
	local list = {}
	for name, rec in pairs(store) do
		local score = rec.best and rec.best[level]
		if score and score > 0 then
			table.insert(list, {
				name = name, class = rec.class, score = score, ts = rec.ts,
				me = (name == self.playerName), online = self:IsOnline(name), addon = self:HasAddon(name),
			})
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)
	return list
end

-- Everyone known, highest level first, then total.
function Comm:ProgressBoard()
	local store = self:Store()
	if not store then
		return {}
	end
	self:RefreshOwn()
	local list = {}
	for name, rec in pairs(store) do
		table.insert(list, {
			name = name, class = rec.class, cleared = math.max(0, (rec.unlocked or 1) - 1), total = rec.total or 0, ts = rec.ts,
			me = (name == self.playerName), online = self:IsOnline(name), addon = self:HasAddon(name),
		})
	end
	table.sort(list, function(a, b)
		if a.cleared ~= b.cleared then
			return a.cleared > b.cleared
		end
		if a.total ~= b.total then
			return a.total > b.total
		end
		return a.name < b.name
	end)
	return list
end

-- Our rank on a level with the given score, and how many are on the board.
function Comm:GuildRank(level, score)
	local list = self:LevelBoard(level)
	if #list == 0 then
		return nil, 0
	end
	local rank = 1
	for _, entry in ipairs(list) do
		if not entry.me and entry.score > score then
			rank = rank + 1
		end
	end
	return rank, #list
end
