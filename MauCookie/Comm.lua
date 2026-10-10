-- MauCookie guild board: bakeries shared with guild members over the addon
-- channel, kept in the saved variables, relayed for people who are offline.
--
-- Unlike MauPeggle's records, a bakery can shrink (wipe, ascension), so a
-- record is a snapshot stamped with the owner's server time and the newest
-- stamp wins outright; relays carry the owner's stamp, so every copy agrees
-- and a wipe simply replaces the old numbers everywhere.  Messages:
--
--   S:<token>:<name>:<class>:<ts>:<prestige>:<allTime>:<run>:<cps>:<buildings>:<feats>:<golden>:<ascensions>
--   I:<token>:<name>=<ts>,...     inventory: who I know and how fresh
--   Q:<token>:<name>,...          please send these records
--
-- Traffic: your own snapshot goes out when something notable changed
-- (purchase, achievement, ascension, wipe; coalesced to one per 10 s) and
-- otherwise once a minute while the numbers move.  Logging in sends the
-- snapshot and an inventory; peers answer only with records newer than
-- what you listed, after a random delay, skipping records somebody else
-- already sent, and ask for what you have that they lack.  The inventory
-- also goes out when the board is opened (at most every 5 min) and every
-- 15 min if anything changed.  One message per 0.25 s leaves the queue.

local _, NS = ...

NS.PREFIX = "MauCookie"

local Comm = CreateFrame("Frame")
NS.Comm = Comm

local MAX_PAYLOAD = 235
local SEND_RATE = 0.25
local OWN_GAP = 10
local OWN_PERIOD = 60
local INVENTORY_GAP = 300
local PERIODIC = 900
local RECENT_WINDOW = 30
local ASKED_WINDOW = 10
local ONLINE_WINDOW = 600
local QUEUE_CAP = 60

NS.BOARDS = {
	{ key = "allTime", name = "All time", label = "cookies baked, all runs" },
	{ key = "run", name = "This run", label = "cookies baked this run" },
	{ key = "cps", name = "Per second", label = "cookies per second" },
	{ key = "prestige", name = "Prestige", label = "prestige level" },
	{ key = "feats", name = "Feats", label = "achievements" },
}

function Comm:Start()
	if self.started then
		return
	end
	self.started = true
	self.playerName = NS.ShortName(UnitName("player"))
	self.token = string.format("%x", math.random(1, 0xffffff))
	self.queue = {}
	self.recent = {}
	self.pendingRecords = {}
	self.wanted = {}
	self.askedByOthers = {}
	self.seen = {}
	self.roster = {}
	self.lastOwn = GetTime()   -- the login announce sends the first snapshot
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

function Comm:Store()
	if not IsInGuild() then
		return nil
	end
	local guild = GetGuildInfo("player")
	if not guild then
		return nil
	end
	MauCookieDB.guild[guild] = MauCookieDB.guild[guild] or {}
	return MauCookieDB.guild[guild]
end

-------------------------------------------------------------------------------
-- Records
-------------------------------------------------------------------------------

function Comm:OwnRecord(ts)
	local game, save = NS.Game, NS.Game.save
	local _, classFile = UnitClass("player")
	return {
		name = self.playerName, class = classFile, ts = ts or self.ownTs or 0,
		prestige = save.prestige or 0, allTime = game:AllTime(), run = save.earned or 0, cps = game:Cps(),
		buildings = game:TotalBuildings(), feats = game:AchievementsUnlocked(), golden = save.goldenClicks or 0,
		ascensions = save.resets or 0,
	}
end

-- Newest snapshot wins.  Returns true when the store changed.
function Comm:Merge(rec)
	local store = self:Store()
	if not store or not rec.name or rec.name == "" then
		return false
	end
	local cur = store[rec.name]
	if cur and (cur.ts or 0) >= (rec.ts or 0) then
		return false
	end
	store[rec.name] = rec
	self.dirty = true
	return true
end

local function Signature(rec)
	return string.format("%.3g:%.3g:%.3g:%d:%d:%d:%d:%d", rec.allTime, rec.run, rec.cps, rec.prestige, rec.buildings, rec.feats, rec.golden, rec.ascensions)
end

local function Encode(token, rec)
	return string.format("S:%s:%s:%s:%d:%d:%.6g:%.6g:%.6g:%d:%d:%d:%d", token, rec.name, rec.class or "",
		math.floor(rec.ts or 0), math.floor(rec.prestige or 0), rec.allTime or 0, rec.run or 0, rec.cps or 0,
		math.floor(rec.buildings or 0), math.floor(rec.feats or 0), math.floor(rec.golden or 0), math.floor(rec.ascensions or 0))
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

function Comm:Enqueue(msg)
	if #self.queue < QUEUE_CAP then
		table.insert(self.queue, msg)
	end
end

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

function Comm:SendRecord(name, rec)
	rec.name = rec.name or name
	self:Enqueue(Encode(self.token, rec))
	self.recent[name] = { ts = rec.ts or 0, at = GetTime() }
end

-- A fresh snapshot of our own bakery, stored and sent.
function Comm:SendOwn()
	if not self:Enabled() then
		return
	end
	local rec = self:OwnRecord(NS.Now())
	self.ownTs = rec.ts
	self.ownSig = Signature(rec)
	self:Merge(rec)
	self:SendRecord(rec.name, rec)
	self.lastOwn = GetTime()
end

-- Game.lua: a purchase, achievement, ascension or wipe.  One send per 10 s.
function Comm:OnChanged()
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

function Comm:RefreshOwn()
	if self.playerName and self:Store() then
		local rec = self:OwnRecord()
		rec.ts = math.max(rec.ts, (self:Store()[self.playerName] or {}).ts or 0)
		self:Store()[self.playerName] = rec
	end
end

function Comm:SendInventory(force)
	if not self:Enabled() then
		return
	end
	local now = GetTime()
	if not force and now - (self.lastInventory or 0) < INVENTORY_GAP then
		return
	end
	local store = self:Store()
	if not store then
		return
	end
	local items = {}
	for name, rec in pairs(store) do
		if (rec.ts or 0) > 0 then
			table.insert(items, string.format("%s=%d", name, math.floor(rec.ts)))
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

function Comm:Announce()
	if not self:Enabled() then
		return
	end
	self:RequestRoster()
	self:SendOwn()
	self:SendInventory(true)
end

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
	if kind == "S" then
		self:OnRecord(body)
	elseif kind == "I" then
		self:OnInventory(body)
	elseif kind == "Q" then
		self:OnRequest(body)
	end
end

function Comm:OnRecord(body)
	local name, class, ts, prestige, allTime, run, cps, buildings, feats, golden, ascensions = strsplit(":", body)
	if not name or name == "" or not ts then
		return
	end
	if name == self.playerName then
		return -- our own bakery is ours to describe
	end
	local rec = {
		name = name, class = class ~= "" and class or nil, ts = tonumber(ts) or 0,
		prestige = tonumber(prestige) or 0, allTime = tonumber(allTime) or 0, run = tonumber(run) or 0, cps = tonumber(cps) or 0,
		buildings = tonumber(buildings) or 0, feats = tonumber(feats) or 0, golden = tonumber(golden) or 0, ascensions = tonumber(ascensions) or 0,
	}
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
	for name, rec in pairs(store) do
		local ts = rec.ts or 0
		if ts > 0 and (theirs[name] == nil or theirs[name] < ts) then
			self:ScheduleRecord(name, 2 + math.random() * 6)
		end
	end
	local want = false
	for name, ts in pairs(theirs) do
		local rec = store[name]
		if name ~= self.playerName and (not rec or (rec.ts or 0) < ts) then
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

	-- Once a minute while the numbers move.
	if now - (self.lastOwn or 0) >= OWN_PERIOD and not self.ownPending then
		local rec = self:OwnRecord()
		if Signature(rec) ~= self.ownSig then
			self:SendOwn()
		else
			self.lastOwn = now
		end
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
					self:SendRecord(name, rec)
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

-- Everyone known, sorted by the board's field.
function Comm:Board(key)
	local store = self:Store()
	if not store then
		return {}
	end
	self:RefreshOwn()
	local list = {}
	for name, rec in pairs(store) do
		local entry = {}
		for k, v in pairs(rec) do
			entry[k] = v
		end
		entry.name = name
		entry.value = rec[key] or 0
		entry.me = (name == self.playerName)
		entry.online = self:IsOnline(name)
		entry.addon = self:HasAddon(name)
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		if (a.allTime or 0) ~= (b.allTime or 0) then
			return (a.allTime or 0) > (b.allTime or 0)
		end
		return a.name < b.name
	end)
	return list
end
