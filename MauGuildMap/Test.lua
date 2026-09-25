-- MauGuildMap test mode: /mgm test
--
-- Simulates three guild members around the player's current position.  Their
-- messages go through the same decoder and roster as real ones, so the wire
-- format, the map pins, the entrance display, the goodbye message and the
-- timeout are all exercised without a second player.
--
-- Timeline (seconds after start):
--    0  three members appear near you and start moving
--   20  Testbob enters "Test Dungeon": his pin stays at the entrance, dimmed
--   30  Testcarol logs out (sends goodbye) and disappears at once
--   30  Testalice stops sending; she is dropped after NS.TIMEOUT seconds
--  end  a few seconds after that the test stops and Testbob is removed

local _, NS = ...

local Test = {}
NS.Test = Test

local ALLIANCE = {
	{ name = "Testalice", race = "NightElf", sex = 3, class = "HUNTER", level = 23 },
	{ name = "Testbob", race = "Dwarf", sex = 2, class = "PALADIN", level = 40 },
	{ name = "Testcarol", race = "Human", sex = 3, class = "MAGE", level = 12 },
}
local HORDE = {
	{ name = "Testalice", race = "Troll", sex = 3, class = "HUNTER", level = 23 },
	{ name = "Testbob", race = "Orc", sex = 2, class = "WARRIOR", level = 40 },
	{ name = "Testcarol", race = "Scourge", sex = 3, class = "MAGE", level = 12 },
}

local DUNGEON_AT = 20
local LOGOUT_AT = 30
local SILENT_AT = 30
local CIRCLE_RADIUS = 0.02
local STEP = 0.004

local function Clamp(v)
	return math.max(0.02, math.min(0.98, v))
end

function Test:Toggle()
	if self.running then
		self:Stop("stopped")
	else
		self:Start()
	end
end

function Test:Start()
	local origin = NS.Comm.lastOutdoor
	if not origin then
		local mapID, x, y = NS.Comm:SampleOutdoor()
		if mapID then
			origin = { mapID = mapID, x = x, y = y }
		end
	end
	if not origin then
		NS.Print("Go outdoors first: your own map position is the starting point for the test members.")
		return
	end

	local defs = (UnitFactionGroup("player") == "Horde") and HORDE or ALLIANCE
	self.fakes = {}
	for i, def in ipairs(defs) do
		local angle = (i - 1) * (2 * math.pi / #defs)
		self.fakes[i] = {
			name = def.name,
			race = def.race,
			sex = def.sex,
			class = def.class,
			level = def.level,
			x = Clamp(origin.x + math.cos(angle) * 0.03),
			y = Clamp(origin.y + math.sin(angle) * 0.03),
			angle = angle,
			alive = true,
			silent = false,
			inInstance = false,
		}
	end
	self.origin = origin
	self.t = 0
	self.running = true
	NS.Print("Test started: 3 test members around you in %s. Open the map (M) and hover their icons.", NS.MapName(origin.mapID) or "this zone")
	if not NS.GetSettings().display then
		NS.Print("Note: display is off, so nothing is drawn. /mgm enable turns it on.")
	end
	NS.Print("Testbob enters a dungeon at %d s, Testcarol logs out at %d s, Testalice goes silent at %d s and drops off %d s later.",
		DUNGEON_AT, LOGOUT_AT, SILENT_AT, NS.TIMEOUT)
	self.ticker = C_Timer.NewTicker(1, function()
		self:Tick()
	end)
	self:Tick()
end

function Test:Stop(reason)
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	self.running = false
	self.fakes = nil
	NS.Roster:RemoveTestEntries()
	NS.Print("Test %s; test members removed.", reason or "stopped")
end

local function Move(fake)
	if fake.name == "Testalice" then
		fake.angle = fake.angle + 0.15
		fake.x = Clamp(fake.baseX + math.cos(fake.angle) * CIRCLE_RADIUS)
		fake.y = Clamp(fake.baseY + math.sin(fake.angle) * CIRCLE_RADIUS)
	else
		fake.x = Clamp(fake.x + (math.random() - 0.5) * STEP)
		fake.y = Clamp(fake.y + (math.random() - 0.5) * STEP)
	end
end

function Test:Tick()
	if not self.running then
		return
	end
	local t = self.t
	self.t = t + 1

	for _, fake in ipairs(self.fakes) do
		if fake.name == "Testalice" and not fake.baseX then
			fake.baseX, fake.baseY = fake.x, fake.y
		end
		if fake.name == "Testbob" and t == DUNGEON_AT and not fake.inInstance then
			fake.inInstance = true
			NS.Print("Testbob entered Test Dungeon; his icon stays at the entrance, dimmed.")
		end
		if fake.name == "Testcarol" and t == LOGOUT_AT and fake.alive then
			fake.alive = false
			NS.Comm:OnMessage("B", fake.name, true)
		end
		if fake.name == "Testalice" and t == SILENT_AT and not fake.silent then
			fake.silent = true
			NS.Print("Testalice stopped sending; she is removed after %d s without an update.", NS.TIMEOUT)
		end

		if fake.alive and not fake.silent then
			if not fake.inInstance then
				Move(fake)
			end
			local text = NS.Comm:Encode({
				mapID = self.origin.mapID,
				x = fake.x,
				y = fake.y,
				level = fake.level,
				race = fake.race,
				sex = fake.sex,
				class = fake.class,
				flag = fake.inInstance and "I" or "O",
				instance = fake.inInstance and "Test Dungeon" or "",
			})
			NS.Comm:OnMessage(text, fake.name, true)
		end
	end

	if t >= SILENT_AT + NS.TIMEOUT + 8 then
		self:Stop("finished")
	end
end
