-- MauCookie building rows (the original's #rows): one 128 px strip per
-- owned building, the building's background tile with as many sprites as
-- you own (up to what fits), placed with the original's seeded jitter; a
-- minigame panel can replace a row's canvas (Minigame_*.lua draw into it).

local _, NS = ...

local UI = NS.UI
local FONT, WHITE = UI.FONT, UI.WHITE
local ROW_H = 128
local ROW_GAP = 16
local ROW_PAD = 16
local MINIGAME_H = 300

-- Deterministic pseudo-random per sprite, like the original's seedrandom.
local function Rand(seed)
	seed = (seed * 9301 + 49297) % 233280
	return seed / 233280, seed
end

local function SpriteSize(key)
	local a = NS.ART[key]
	if not a then
		return 64, 64, 1
	end
	local frames = 1
	if a[1] > a[2] and a[1] % a[2] == 0 and a[2] <= 64 then
		frames = a[1] / a[2]
	end
	return a[1] / frames, a[2], frames
end

function UI:CreateRows(host)
	local scroll = UI.Scroll(host, host:GetWidth() or (UI.MID_W), host:GetHeight() or (UI.CONTENT_H - UI.BAR_H - UI.TICKER_H))
	scroll:SetAllPoints(host)
	self.rowsScroll = scroll
	local c = scroll.Child
	self.rows = {}
	for _, b in ipairs(NS.BUILDINGS) do
		if b.id >= 1 then
			local row = CreateFrame("Frame", nil, c)
			row:SetSize(UI.MID_W - ROW_PAD, ROW_H)
			row.building = b
			local canvas = CreateFrame("Frame", nil, row)
			canvas:SetAllPoints()
			canvas:SetClipsChildren(true)
			canvas.Black = UI.Solid(canvas, "BACKGROUND", 0, 0, 0, 1)
			canvas.Black:SetAllPoints()
			canvas.Bg = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
			canvas.Bg:SetAllPoints()
			local bgKey = b.art.base .. "Background"
			if NS.HasArt(bgKey) then
				canvas.Bg:SetTexture(NS.Art(bgKey), "REPEAT", "REPEAT")
				canvas.Bg:SetHorizTile(true)
				canvas.Bg:SetVertTile(true)
				canvas.Bg:SetTexCoord(0, (UI.MID_W - ROW_PAD) / 128, 0, ROW_H / 128)
			end
			canvas.Sprites = {}
			canvas.Name = canvas:CreateFontString(nil, "OVERLAY")
			canvas.Name:SetFont(FONT, 11, "OUTLINE")
			canvas.Name:SetPoint("TOPLEFT", 6, -4)
			canvas.Name:SetTextColor(1, 1, 1, 0.6)
			row.Canvas = canvas
			canvas:EnableMouse(true)
			UI.SetTooltip(canvas, function(self)
				local bb = self:GetParent().building
				local r = NS.Game:Bld(bb.name)
				GameTooltip:SetText(string.format("%s %s", NS.Commas(r.n), r.n == 1 and bb.single or bb.plural))
				local entry = NS.Game.cpsBy[bb.name]
				if entry then
					GameTooltip:AddLine(string.format("producing %s cookies per second", NS.Beautify(entry.total * (NS.Game.globalMult or 1), 1)), 1, 1, 1)
				end
			end)
			-- Minigame host (filled by the minigame modules).
			local special = CreateFrame("Frame", nil, row)
			special:SetPoint("TOPLEFT")
			special:SetPoint("TOPRIGHT")
			special:SetHeight(MINIGAME_H)
			special.Bg = special:CreateTexture(nil, "BACKGROUND")
			special.Bg:SetAllPoints()
			special.Bg:SetTexture(NS.Art("mapBG"))
			special.Bg:SetTexCoord(0, 600 / 1024, 0, 600 / 1024)
			special.Title = special:CreateFontString(nil, "OVERLAY")
			special.Title:SetFont(UI.TITLE_FONT, 14, "")
			special.Title:SetPoint("TOPLEFT", 8, -6)
			special.Title:SetText(b.minigame or "")
			special.Note = UI.Text(special, 11, "")
			special.Note:SetPoint("TOPLEFT", 8, -28)
			special.Note:SetPoint("RIGHT", -8, 0)
			special.Note:SetWordWrap(true)
			special.Note:SetTextColor(0.8, 0.8, 0.8)
			special.Note:SetText("This minigame is not available yet in MauCookie.")
			special:Hide()
			row.Special = special
			row.count = -1
			row:Hide()
			self.rows[b.id] = row
		end
	end
end

-- Which grandma sprites are in the pool right now.
local function GrandmaPics(game)
	local list = { "grandma" }
	for name, pic in pairs(NS.GRANDMA_PICS) do
		if game:Has(name) and NS.HasArt(pic) then
			table.insert(list, pic)
		end
	end
	table.sort(list)
	local S = game.save
	if S.season == "christmas" and NS.HasArt("elfGrandma") then table.insert(list, "elfGrandma") end
	if S.season == "easter" and NS.HasArt("bunnyGrandma") then table.insert(list, "bunnyGrandma") end
	return list
end

local function GetSprite(canvas, i)
	local s = canvas.Sprites[i]
	if s then
		return s
	end
	s = canvas:CreateTexture(nil, "ARTWORK")
	canvas.Sprites[i] = s
	return s
end

-- Rebuild a row's sprites following the original's draw(): seeded jitter,
-- rows of sprites, random frame for sheets, random grandma types.
function UI:LayoutRow(row)
	local game = NS.Game
	local b = row.building
	local canvas = row.Canvas
	local art = b.art
	local amount = game:Count(b.name)
	local pics = (b.id == 1) and GrandmaPics(game) or nil
	local key = art.base
	if b.id == 1 then
		key = "grandma"
	end
	local _, h, frames = SpriteSize(key)
	-- art.w is the horizontal spacing between sprites, not the sprite width.
	local w = art.w or 64
	local rows = art.rows or 1
	local xV, yV = art.xV or 0, art.yV or 0
	local offX, offY = art.x or 0, art.y or 0
	local width = canvas:GetWidth()
	if not width or width < 10 then
		width = UI.MID_W - ROW_PAD
	end
	local maxI = math.floor(width / (w / rows) + 1)
	local n = math.min(amount, maxI)
	local seed = (b.id + 1) * 7919 + (game.save.startDate or 0) % 1000
	local list = {}
	for i = 0, n - 1 do
		local r1, r2, r3, r4
		local s = seed + i * 131
		r1, s = Rand(s)
		r2, s = Rand(s)
		r3, s = Rand(s)
		r4, s = Rand(s)
		local x, y
		if rows ~= 1 then
			x = math.floor(i / rows) * w + ((i % rows) / rows) * w + math.floor((r1 - 0.5) * xV) + offX
			y = 32 + math.floor((r2 - 0.5) * yV) + ((-rows / 2) * 16 + (i % rows) * 16) + offY
		else
			x = i * w + math.floor((r1 - 0.5) * xV) + offX
			y = 32 + math.floor((r2 - 0.5) * yV) + offY
		end
		local pic = key
		if pics then
			pic = pics[math.floor(r3 * #pics) + 1]
		end
		local frame = 0
		if frames > 1 then
			frame = math.floor(r4 * frames)
		end
		table.insert(list, { x = x, y = y, pic = pic, frame = frame })
	end
	table.sort(list, function(p, q)
		return p.y < q.y
	end)
	for i, item in ipairs(list) do
		local s = GetSprite(canvas, i)
		local sw, sh, sframes = SpriteSize(item.pic)
		local a = NS.ART[item.pic]
		if a then
			s:SetTexture(NS.Art(item.pic))
			if sframes > 1 then
				s:SetTexCoord(item.frame * sw / a[3], (item.frame + 1) * sw / a[3], 0, sh / a[4])
			else
				s:SetTexCoord(0, a[1] / a[3], 0, a[2] / a[4])
			end
			s:SetSize(sw, sh)
		else
			s:SetTexture(WHITE)
			s:SetVertexColor(0.3, 0.3, 0.3)
			s:SetSize(w, h)
		end
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", canvas, "TOPLEFT", item.x, -item.y)
		s:SetDrawLayer("ARTWORK", math.min(7, math.floor(i / 8)))
		s:Show()
	end
	for i = #list + 1, #canvas.Sprites do
		canvas.Sprites[i]:Hide()
	end
	canvas.Name:SetText(string.format("%s %s", NS.Commas(amount), amount == 1 and b.single or b.plural))
	row.count = amount
	row.picsKey = pics and table.concat(pics, ",") or ""
end

function UI:RefreshRows(force)
	if not self.rows or self.menu then
		return
	end
	local game = NS.Game
	local c = self.rowsScroll.Child
	local y = 0
	for _, b in ipairs(NS.BUILDINGS) do
		local row = self.rows[b.id]
		if row then
			local amount = game:Count(b.name)
			if amount > 0 then
				local picsKey = row.picsKey
				if force or row.count ~= amount or (b.id == 1 and picsKey ~= table.concat(GrandmaPics(game), ",")) then
					self:LayoutRow(row)
				end
				local onMinigame = self.openMinigame == b.name
				local h = ROW_H
				if onMinigame then
					h = NS.Minigames and NS.Minigames:PanelHeight(b) or MINIGAME_H
					row.Special:SetHeight(h)
				end
				row.Canvas:SetShown(not onMinigame)
				row.Special:SetShown(onMinigame)
				row:SetHeight(h)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", c, "TOPLEFT", ROW_PAD, -y)
				row:Show()
				y = y + h + ROW_GAP
			else
				row:Hide()
			end
		end
	end
	if y ~= self.rowsHeight then
		self.rowsHeight = y
		self.rowsScroll:SetContentHeight(y)
	end
end

function UI:ToggleMinigame(b)
	if self.openMinigame == b.name then
		self.openMinigame = nil
	else
		self.openMinigame = b.name
	end
	if NS.Minigames and NS.Minigames.OnToggle then
		NS.Minigames:OnToggle(b, self.openMinigame == b.name, self.rows[b.id] and self.rows[b.id].Special)
	end
	self:RefreshRows(true)
	self:RefreshStore(true)
end
