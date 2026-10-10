-- MauCookie shimmers: golden and wrath cookies, reindeer and the cookie
-- storm drops, ported from the original's Game.shimmerTypes.  The spawn
-- timers only run while the window is shown (a cookie you cannot see is a
-- cookie you would miss); the rest is the original's numbers.  Each active
-- shimmer is a table in Game.shimmers; the window draws them.

local _, NS = ...

local Game = NS.Game
local FPS = 30
local Choose = NS.Choose

function Game:InitShimmers()
	self.shimmers = {}
	self.shimmerN = 0
	self.shimmerTypes = {
		golden = { n = 0, spawned = false, time = 0, minTime = 0, maxTime = 0, chain = 0, totalFromChain = 0, last = "" },
		reindeer = { n = 0, spawned = false, time = 0, minTime = 0, maxTime = 0 },
	}
	for key, t in pairs(self.shimmerTypes) do
		t.key = key
		t.minTime = self:ShimmerMinTime(key)
		t.maxTime = self:ShimmerMaxTime(key)
	end
end

function Game:GoldenOnScreen()
	return self.shimmerTypes and self.shimmerTypes.golden.n or 0
end

-------------------------------------------------------------------------------
-- Timing (seconds; the original's getTimeMod in minutes)
-------------------------------------------------------------------------------

function Game:GoldenTimeMod(m)
	local S = self.save
	if self:Has("Lucky day") then m = m / 2 end
	if self:Has("Serendipity") then m = m / 2 end
	if self:Has("Golden goose egg") then m = m * 0.95 end
	if self:Has("Heavenly luck") then m = m * 0.95 end
	if self:Has("Green yeast digestives") then m = m * 0.99 end
	m = m * (1 - self:AuraMult("Arcane Aura") * 0.05)
	if self:HasBuff("Sugar blessing") then m = m * 0.9 end
	if S.season == "easter" and self:Has("Starspawn") then m = m * 0.98
	elseif S.season == "halloween" and self:Has("Starterror") then m = m * 0.98
	elseif S.season == "valentines" and self:Has("Starlove") then m = m * 0.98
	elseif S.season == "fools" and self:Has("Startrade") then m = m * 0.95 end
	m = m * (1 / self:Eff("goldenCookieFreq"))
	local godLvl = self:HasGod("industry")
	if godLvl == 1 then m = m * 1.1 elseif godLvl == 2 then m = m * 1.06 elseif godLvl == 3 then m = m * 1.03 end
	godLvl = self:HasGod("mother")
	if godLvl == 1 then m = m * 1.15 elseif godLvl == 2 then m = m * 1.1 elseif godLvl == 3 then m = m * 1.05 end
	if S.season ~= "" then
		godLvl = self:HasGod("seasons")
		if S.season ~= "fools" then
			if godLvl == 1 then m = m * 0.97 elseif godLvl == 2 then m = m * 0.98 elseif godLvl == 3 then m = m * 0.99 end
		else
			if godLvl == 1 then m = m * 0.955 elseif godLvl == 2 then m = m * 0.97 elseif godLvl == 3 then m = m * 0.985 end
		end
	end
	if self.shimmerTypes.golden.chain > 0 then m = 0.05 end
	if self:Has("Gold hoard") then m = 0.01 end
	return math.ceil(60 * m)
end

function Game:ReindeerTimeMod(m)
	if self:Has("Reindeer baking grounds") then m = m / 2 end
	if self:Has("Starsnow") then m = m * 0.95 end
	local godLvl = self:HasGod("seasons")
	if godLvl == 1 then m = m * 0.9 elseif godLvl == 2 then m = m * 0.95 elseif godLvl == 3 then m = m * 0.97 end
	m = m * (1 / self:Eff("reindeerFreq"))
	if self:Has("Reindeer season") then m = 0.01 end
	return math.ceil(60 * m)
end

function Game:ShimmerMinTime(key)
	if key == "golden" then
		return self:GoldenTimeMod(5)
	end
	return self:ReindeerTimeMod(3)
end

function Game:ShimmerMaxTime(key)
	if key == "golden" then
		return self:GoldenTimeMod(15)
	end
	return self:ReindeerTimeMod(5)
end

function Game:ShimmerSpawnConditions(key)
	if key == "golden" then
		return not self:Has("Golden switch [off]")
	end
	return self.save.season == "christmas"
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

-- obj: { type = forced effect, wrath = true, noWrath = true }; noCount for storm drops.
function Game:SpawnShimmer(key, obj, noCount)
	local me = { type = key, id = self.shimmerN, forceObj = obj or false, force = obj and obj.type or "", noCount = noCount, popped = false }
	self.shimmerN = self.shimmerN + 1
	if not noCount then
		self.shimmerTypes[key].n = self.shimmerTypes[key].n + 1
		self.recalc = true
	end
	if key == "golden" then
		self:GoldenInit(me)
	else
		self:ReindeerInit(me)
	end
	table.insert(self.shimmers, me)
	if NS.UI and NS.UI.OnShimmerAdded then
		NS.UI:OnShimmerAdded(me)
	end
	return me
end

function Game:GoldenInit(me)
	local S = self.save
	local t = self.shimmerTypes.golden
	local fo = me.forceObj
	me.wrath = false
	if (not fo or not fo.noWrath) and ((fo and fo.wrath) or (S.elderWrath == 1 and math.random() < 1 / 3) or (S.elderWrath == 2 and math.random() < 2 / 3) or S.elderWrath == 3 or self:HasGod("scorn") > 0) then
		me.wrath = true
	end
	local dur = 13
	if self:Has("Lucky day") then dur = dur * 2 end
	if self:Has("Serendipity") then dur = dur * 2 end
	if self:Has("Decisive fate") then dur = dur * 1.05 end
	if self:Has("Lucky digit") then dur = dur * 1.01 end
	if self:Has("Lucky number") then dur = dur * 1.01 end
	if self:Has("Lucky payout") then dur = dur * 1.01 end
	if not me.wrath then dur = dur * self:Eff("goldenCookieDur") else dur = dur * self:Eff("wrathCookieDur") end
	dur = dur * (0.95 ^ (t.n - 1))
	if t.chain > 0 then
		dur = math.max(2, 10 / t.chain)
	end
	me.dur = dur
	me.life = dur
	me.sizeMult = 1
	if not t.spawned and me.force ~= "cookie storm drop" and S.ascensionMode ~= 1 then
		NS.PlayKit(me.wrath and "IG_CREATURE_AGGRO_SELECT" or "UI_GARRISON_TOAST_FOLLOWER_GAINED")
	end
end

function Game:ReindeerInit(me)
	local dur = 4
	if self:Has("Weighted sleighs") then dur = dur * 2 end
	dur = dur * self:Eff("reindeerDur")
	me.dur = dur
	me.life = dur
	me.sizeMult = 1
	NS.PlayKit("UI_GARRISON_TOAST_FOLLOWER_GAINED")
end

function Game:DieShimmer(me)
	local t = self.shimmerTypes[me.type]
	if me.spawnLead then
		t.time = 0
		t.spawned = false
		t.minTime = self:ShimmerMinTime(me.type)
		t.maxTime = self:ShimmerMaxTime(me.type)
	end
	for i, s in ipairs(self.shimmers) do
		if s == me then
			table.remove(self.shimmers, i)
			break
		end
	end
	if not me.noCount then
		t.n = math.max(0, t.n - 1)
		self.recalc = true
	end
	if NS.UI and NS.UI.OnShimmerRemoved then
		NS.UI:OnShimmerRemoved(me)
	end
end

function Game:KillShimmers()
	for i = #self.shimmers, 1, -1 do
		self:DieShimmer(self.shimmers[i])
	end
	for key, t in pairs(self.shimmerTypes) do
		if key == "golden" then
			t.chain, t.totalFromChain, t.last = 0, 0, ""
		end
		t.n = 0
		t.time = 0
		t.spawned = false
		t.minTime = self:ShimmerMinTime(key)
		t.maxTime = self:ShimmerMaxTime(key)
	end
end

function Game:UpdateShimmers(dt)
	if not (NS.UI and NS.UI:IsShown()) then
		return
	end
	local frames = dt * FPS
	for i = #self.shimmers, 1, -1 do
		local me = self.shimmers[i]
		me.life = me.life - dt
		if me.life <= 0 then
			if me.type == "golden" then
				self:GoldenMiss(me)
			end
			self:DieShimmer(me)
		end
	end
	if self:HasBuff("Cookie storm") then
		-- The original rolls 50% every frame; cap the shower for the window.
		local drops = 0
		for _, s in ipairs(self.shimmers) do
			if s.force == "cookie storm drop" then
				drops = drops + 1
			end
		end
		local wanted = math.min(40 - drops, math.floor(frames * 0.5 + math.random()))
		for _ = 1, wanted do
			local d = self:SpawnShimmer("golden", { type = "cookie storm drop" }, true)
			d.dur = math.ceil(math.random() * 4 + 1)
			d.life = d.dur
			d.sizeMult = math.random() * 0.75 + 0.25
		end
	end
	for key, t in pairs(self.shimmerTypes) do
		if self:ShimmerSpawnConditions(key) and not t.spawned then
			t.time = t.time + dt
			local q = math.max(0, (t.time - t.minTime) / math.max(1, t.maxTime - t.minTime)) ^ 5
			local p = 1 - (1 - math.min(1, q)) ^ frames
			if math.random() < p then
				local me = self:SpawnShimmer(key)
				me.spawnLead = true
				if self:Has("Distilled essence of redoubled luck") and math.random() < 0.01 then
					self:SpawnShimmer(key)
				end
				t.spawned = true
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Popping
-------------------------------------------------------------------------------

function Game:PopShimmer(me)
	if me.popped then
		return
	end
	me.popped = true
	self:LoseShimmeringVeil("shimmer")
	if me.type == "golden" then
		self:GoldenPop(me)
	else
		self:ReindeerPop(me)
	end
end

function Game:GoldenMiss(me)
	local t = self.shimmerTypes.golden
	if t.chain > 0 and t.totalFromChain > 0 then
		NS.Notify("Cookie chain broken.", "You made " .. NS.Beautify(t.totalFromChain) .. " cookies.", {10,14})
		t.chain, t.totalFromChain = 0, 0
	end
	if me.spawnLead then
		self.save.missedGolden = (self.save.missedGolden or 0) + 1
	end
end

function Game:GoldenPop(me)
	local S = self.save
	local t = self.shimmerTypes.golden
	if me.spawnLead then
		S.goldenClicks = (S.goldenClicks or 0) + 1
		S.goldenClicksLocal = (S.goldenClicksLocal or 0) + 1
		local g = S.goldenClicks
		if g >= 1 then self:Win("Golden cookie") end
		if g >= 7 then self:Win("Lucky cookie") end
		if g >= 27 then self:Win("A stroke of luck") end
		if g >= 77 then self:Win("Fortune") end
		if g >= 777 then self:Win("Leprechaun") end
		if g >= 7777 then self:Win("Black cat's paw") end
		if g >= 27777 then self:Win("Seven horseshoes") end
		if g >= 7 then self:Unlock("Lucky day") end
		if g >= 27 then self:Unlock("Serendipity") end
		if g >= 77 then self:Unlock("Get lucky") end
		if me.life > me.dur - 1 then self:Win("Early bird") end
		if me.life < 1 then self:Win("Fading luck") end
		if me.wrath then self:Win("Wrath cookie") end
	end
	if self.forceUnslotGod and self.forceUnslotGod("asceticism") and self.useSwap then
		self.useSwap(1000000)
	end

	local list = {}
	local function push(...)
		for _, v in ipairs({ ... }) do
			table.insert(list, v)
		end
	end
	if me.wrath then push("clot", "multiply cookies", "ruin cookies") else push("frenzy", "multiply cookies") end
	if me.wrath and self:HasGod("scorn") > 0 then push("clot", "ruin cookies", "clot", "ruin cookies") end
	if me.wrath and math.random() < 0.3 then push("blood frenzy", "chain cookie", "cookie storm")
	elseif math.random() < 0.03 and S.earned >= 100000 then push("chain cookie", "cookie storm") end
	if math.random() < 0.05 and S.season == "fools" then push("everything must go") end
	if math.random() < 0.1 and (math.random() < 0.05 or not self:HasBuff("Dragonflight")) then push("click frenzy") end
	if me.wrath and math.random() < 0.1 then push("cursed finger") end
	if self:BuildingsOwned() >= 10 and math.random() < 0.25 then push("building special") end
	if self:CanLumps() and math.random() < 0.0005 then push("free sugar lump") end
	if (not me.wrath and math.random() < 0.15) or math.random() < 0.05 then
		if math.random() < self:AuraMult("Reaper of Fields") then push("dragon harvest") end
		if math.random() < self:AuraMult("Dragonflight") then push("dragonflight") end
	end
	if t.last ~= "" and math.random() < 0.8 then
		for i = #list, 1, -1 do
			if list[i] == t.last then
				table.remove(list, i)
			end
		end
		if #list == 0 then
			push(me.wrath and "clot" or "frenzy")
		end
	end
	if math.random() < 0.0001 then push("blab") end
	local choice = Choose(list)
	if t.chain > 0 then choice = "chain cookie" end
	if me.force ~= "" then
		t.chain = 0
		choice = me.force
		me.force = ""
	end
	if choice ~= "chain cookie" then t.chain = 0 end
	t.last = choice

	local effectDurMod = 1
	if self:Has("Get lucky") then effectDurMod = effectDurMod * 2 end
	if self:Has("Lasting fortune") then effectDurMod = effectDurMod * 1.1 end
	if self:Has("Lucky digit") then effectDurMod = effectDurMod * 1.01 end
	if self:Has("Lucky number") then effectDurMod = effectDurMod * 1.01 end
	if self:Has("Green yeast digestives") then effectDurMod = effectDurMod * 1.01 end
	if self:Has("Lucky payout") then effectDurMod = effectDurMod * 1.01 end
	effectDurMod = effectDurMod * (1 + self:AuraMult("Epoch Manipulator") * 0.05)
	if not me.wrath then effectDurMod = effectDurMod * self:Eff("goldenCookieEffDur") else effectDurMod = effectDurMod * self:Eff("wrathCookieEffDur") end
	local godLvl = self:HasGod("decadence")
	if godLvl == 1 then effectDurMod = effectDurMod * 1.07 elseif godLvl == 2 then effectDurMod = effectDurMod * 1.05 elseif godLvl == 3 then effectDurMod = effectDurMod * 1.02 end

	local mult = 1
	if me.wrath then mult = mult * (1 + self:AuraMult("Unholy Dominion") * 0.1)
	else mult = mult * (1 + self:AuraMult("Ancestral Metamorphosis") * 0.1) end
	if self:Has("Green yeast digestives") then mult = mult * 1.01 end
	if self:Has("Dragon fang") then mult = mult * 1.03 end
	if not me.wrath then mult = mult * self:Eff("goldenCookieGain") else mult = mult * self:Eff("wrathCookieGain") end

	local cps = self.cps or 0
	local title, text, icon = "", "", {10,14}
	if choice == "building special" then
		local time = math.ceil(30 * effectDurMod)
		local candidates = {}
		for _, b in ipairs(NS.BUILDINGS) do
			if self:Count(b.name) >= 10 then
				table.insert(candidates, b.id)
			end
		end
		if #candidates == 0 then
			choice = "frenzy"
		else
			local id = Choose(candidates)
			local pow = self:Count(NS.BY_ID[id].name) / 10 + 1
			local buff
			if me.wrath and math.random() < 0.3 then
				buff = self:GainBuff("building debuff", time, pow, id)
			else
				buff = self:GainBuff("building buff", time, pow, id)
			end
			title, text, icon = buff.name, buff.desc, buff.icon
		end
	end
	if choice == "free sugar lump" then
		self:GainLumps(1)
		title, text, icon = "Sweet!", "Found 1 sugar lump!", {29,14}
	elseif choice == "frenzy" then
		local buff = self:GainBuff("frenzy", math.ceil(77 * effectDurMod), 7)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "dragon harvest" then
		local buff = self:GainBuff("dragon harvest", math.ceil(60 * effectDurMod), 15)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "everything must go" then
		local buff = self:GainBuff("everything must go", math.ceil(8 * effectDurMod), 5)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "multiply cookies" then
		local moni = mult * math.min(S.cookies * 0.15, cps * 60 * 15) + 13
		self:Earn(moni)
		title, text, icon = "Lucky!", "+" .. NS.Beautify(moni) .. " cookies!", {27,6}
	elseif choice == "ruin cookies" then
		local moni = math.min(S.cookies * 0.05, cps * 60 * 10) + 13
		moni = math.min(S.cookies, moni)
		self:Spend(moni)
		title, text, icon = "Ruin!", "Lost " .. NS.Beautify(moni) .. " cookies!", {15,5}
	elseif choice == "blood frenzy" then
		local buff = self:GainBuff("blood frenzy", math.ceil(6 * effectDurMod), 666)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "clot" then
		local buff = self:GainBuff("clot", math.ceil(66 * effectDurMod), 0.5)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "cursed finger" then
		local buff = self:GainBuff("cursed finger", math.ceil(10 * effectDurMod), cps * math.ceil(10 * effectDurMod))
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "click frenzy" then
		local buff = self:GainBuff("click frenzy", math.ceil(13 * effectDurMod), 777)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "dragonflight" then
		local buff = self:GainBuff("dragonflight", math.ceil(10 * effectDurMod), 1111)
		if math.random() < 0.8 then
			self:KillBuff("Click frenzy")
		end
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "chain cookie" then
		if t.chain == 0 then
			t.totalFromChain = 0
		end
		t.chain = t.chain + 1
		local digit = me.wrath and 6 or 7
		if t.chain == 1 then
			t.chain = t.chain + math.max(0, math.ceil(math.log10(math.max(1, S.cookies))) - 10)
		end
		local maxPayout = math.min(cps * 60 * 60 * 6, S.cookies * 0.5) * mult
		local moni = math.max(digit, math.min(math.floor(1 / 9 * (10 ^ t.chain) * digit * mult), maxPayout))
		local nextMoni = math.max(digit, math.min(math.floor(1 / 9 * (10 ^ (t.chain + 1)) * digit * mult), maxPayout))
		t.totalFromChain = t.totalFromChain + moni
		if math.random() < 0.01 or nextMoni >= maxPayout then
			t.chain = 0
		end
		self:Earn(moni)
		title, text, icon = "Cookie chain", "+" .. NS.Beautify(moni) .. " cookies!", {10,14}
	elseif choice == "cookie storm" then
		local buff = self:GainBuff("cookie storm", math.ceil(7 * effectDurMod), 7)
		title, text, icon = buff.name, buff.desc, buff.icon
	elseif choice == "cookie storm drop" then
		local moni = math.max(mult * (cps * 60 * math.floor(math.random() * 7 + 1)), math.floor(math.random() * 7 + 1))
		self:Earn(moni)
		title, text = "", "+" .. NS.Beautify(moni)
	elseif choice == "blab" then
		title, text = Choose(NS.BLAB), ""
	end
	self:DropEgg(0.9)
	if choice == "cookie storm drop" then
		if NS.UI and NS.UI.Popup then
			NS.UI:Popup(text, me)
		end
	else
		NS.Notify(title, text, icon)
		NS.PlayKit("UI_EPICLOOT_TOAST")
	end
	self:DieShimmer(me)
	self:Changed()
end

function Game:ReindeerPop(me)
	local S = self.save
	if me.spawnLead then
		S.reindeerClicked = (S.reindeerClicked or 0) + 1
	end
	local val = (self.cps or 0) * 60
	if self:HasBuff("Elder frenzy") then val = val * 0.5 end
	if self:HasBuff("Frenzy") then val = val * 0.75 end
	local moni = math.max(25, val)
	if self:Has("Ho ho ho-flavored frosting") then moni = moni * 2 end
	moni = moni * self:Eff("reindeerGain")
	self:Earn(moni)
	if self:HasBuff("Elder frenzy") then self:Win("Eldeer") end
	local cookie = ""
	local failRate = 0.8
	if self:HasAchiev("Let it snow") then failRate = failRate * 0.8 end
	if self:Has("Starsnow") then failRate = failRate * 0.95 end
	local godLvl = self:HasGod("seasons")
	if godLvl == 1 then failRate = failRate * 0.9 elseif godLvl == 2 then failRate = failRate * 0.95 elseif godLvl == 3 then failRate = failRate * 0.97 end
	failRate = failRate ^ self:DropRateMult()
	if math.random() > failRate then
		cookie = Choose(NS.REINDEER_DROPS)
		if not self:HasUnlocked(cookie) and not self:Has(cookie) then
			self:Unlock(cookie)
		else
			cookie = ""
		end
	end
	NS.Notify("You found " .. Choose(NS.REINDEER_NAMES) .. "!", "The reindeer gives you " .. NS.Beautify(moni) .. " cookies." .. (cookie ~= "" and (" You are also rewarded with " .. cookie .. "!") or ""), {12,9})
	NS.PlayKit("UI_EPICLOOT_TOAST")
	self:DieShimmer(me)
	self:Changed()
end

function Game:DropEgg(failRate)
	local S = self.save
	if S.season ~= "easter" then
		return
	end
	if self:HasAchiev("Hide & seek champion") then failRate = failRate * 0.8 end
	if self:Has("Omelette") then failRate = failRate * 0.9 end
	if self:Has("Starspawn") then failRate = failRate * 0.9 end
	local godLvl = self:HasGod("seasons")
	if godLvl == 1 then failRate = failRate * 0.9 elseif godLvl == 2 then failRate = failRate * 0.95 elseif godLvl == 3 then failRate = failRate * 0.97 end
	failRate = failRate ^ self:DropRateMult()
	if math.random() > failRate then
		local drop
		if math.random() < 0.1 then drop = Choose(NS.RARE_EGG_DROPS) else drop = Choose(NS.EGG_DROPS) end
		if self:Has(drop) or self:HasUnlocked(drop) then
			if math.random() < 0.1 then drop = Choose(NS.RARE_EGG_DROPS) else drop = Choose(NS.EGG_DROPS) end
		end
		if self:Has(drop) or self:HasUnlocked(drop) then
			return
		end
		self:Unlock(drop)
		NS.Notify("You found an egg!", drop, NS.U[drop] and NS.U[drop].icon)
	end
end
