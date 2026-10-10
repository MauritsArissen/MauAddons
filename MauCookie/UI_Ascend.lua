-- MauCookie ascension screen: the heavenly tree over a starry sky, with
-- the original's positions (posX, posY from the data), links between
-- parents and children, heavenly chips to spend and the Reincarnate
-- button.  The Legacy button opens it as a preview (nothing can be bought
-- until you ascend); ascending shows it for real and stops the bakery.

local _, NS = ...

local UI = NS.UI
local FONT, TITLE_FONT, WHITE = UI.FONT, UI.TITLE_FONT, UI.WHITE
local CRATE = 48

-- LibGraph's line trick: a solid texture with rotated texcoords.
local function DrawLine(T, C, sx, sy, ex, ey, w)
	local dx, dy = ex - sx, ey - sy
	local cx, cy = (sx + ex) / 2, (sy + ey) / 2
	if dx < 0 then
		dx, dy = -dx, -dy
	end
	local l = math.sqrt(dx * dx + dy * dy)
	if l == 0 then
		T:Hide()
		return
	end
	local s, c = -dy / l, dx / l
	local sc = s * c
	local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
	if dy >= 0 then
		Bwid = ((l * c) - (w * s)) / 2
		Bhgt = ((w * c) - (l * s)) / 2
		BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
		BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
		TRy = BRx
	else
		Bwid = ((l * c) + (w * s)) / 2
		Bhgt = ((w * c) + (l * s)) / 2
		BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
		BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
		TRx = TLy
	end
	T:ClearAllPoints()
	T:SetPoint("BOTTOMLEFT", C, "CENTER", cx - Bwid, cy - Bhgt)
	T:SetPoint("TOPRIGHT", C, "CENTER", cx + Bwid, cy + Bhgt)
	T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
	T:Show()
end

function UI:CreateAscend(f)
	local a = CreateFrame("Frame", nil, f)
	a:SetPoint("TOPLEFT", 0, -UI.TOP)
	a:SetPoint("BOTTOMRIGHT", 0, 0)
	a:SetFrameLevel(f:GetFrameLevel() + 50)
	a:EnableMouse(true)
	a:SetClipsChildren(true)
	a.Bg = a:CreateTexture(nil, "BACKGROUND")
	a.Bg:SetAllPoints()
	a.Bg:SetTexture(NS.Art("starbg"), "REPEAT", "REPEAT")
	a.Bg:SetHorizTile(true)
	a.Bg:SetVertTile(true)
	a.Ring1 = a:CreateTexture(nil, "BACKGROUND", nil, 1)
	NS.SetArt(a.Ring1, "heavenRing1")
	a.Ring1:SetBlendMode("ADD")
	a.Ring1:SetAlpha(0.5)
	a.Ring2 = a:CreateTexture(nil, "BACKGROUND", nil, 2)
	NS.SetArt(a.Ring2, "heavenRing2")
	a.Ring2:SetBlendMode("ADD")
	a.Ring2:SetAlpha(0.5)

	-- The pannable, zoomable content.
	local content = CreateFrame("Frame", nil, a)
	content:SetSize(10, 10)
	content:SetPoint("CENTER", a, "CENTER", 0, 0)
	a.Content = content
	a.offX, a.offY, a.zoom = 0, 0, 0.7
	a.Links = {}
	a.Crates = {}
	a:EnableMouseWheel(true)
	a:SetScript("OnMouseWheel", function(self, delta)
		self.zoom = NS.Clamp(self.zoom + delta * 0.1, 0.35, 1.2)
		UI:LayoutAscend()
	end)
	a:SetScript("OnMouseDown", function(self)
		self.dragging = true
		local x, y = GetCursorPosition()
		self.dragX, self.dragY = x, y
		self.dragOffX, self.dragOffY = self.offX, self.offY
	end)
	a:SetScript("OnMouseUp", function(self)
		self.dragging = nil
	end)

	-- Overlay: chips, prestige, buttons.
	a.Chips = a:CreateFontString(nil, "OVERLAY")
	a.Chips:SetFont(TITLE_FONT, 20, "")
	a.Chips:SetShadowOffset(1, -1)
	a.Chips:SetPoint("TOP", 0, -12)
	a.Chips:SetTextColor(0.6, 0.9, 1)
	a.Sub = UI.Text(a, 12, "OUTLINE")
	a.Sub:SetPoint("TOP", a.Chips, "BOTTOM", 0, -4)
	a.Sub:SetJustifyH("CENTER")
	a.Sub:SetWidth(UI.W - 40)
	a.Sub:SetTextColor(0.9, 0.9, 0.9)
	a.Hint = UI.Text(a, 11, "OUTLINE")
	a.Hint:SetPoint("BOTTOMLEFT", 12, 10)
	a.Hint:SetTextColor(0.6, 0.6, 0.6)
	a.Hint:SetText("Drag to pan, mouse wheel to zoom. Click an upgrade to buy it.")
	a.Reincarnate = UI.FancyButton(a, "Reincarnate", 160, 30, function()
		UI:Prompt("Reincarnate", "Are you ready to return to the mortal world?", {
			{ "Yes", function()
				NS.Game:Reincarnate()
			end },
			{ "No" },
		})
	end)
	a.Reincarnate:SetPoint("BOTTOM", 0, 12)
	a.AscendButton = UI.FancyButton(a, "Ascend", 160, 30, function()
		local toGet = NS.Game:AscendInfo()
		local text = "Do you REALLY want to ascend? You will lose your progress and start over from scratch. All your cookies will be converted into prestige and heavenly chips."
		if toGet < 1 then
			text = text .. "\n\nAscending now would grant you no prestige at all. You need a trillion cookies for the first level."
		else
			text = text .. string.format("\n\nYou will gain %s prestige level%s and %s heavenly chip%s.", NS.Beautify(toGet), toGet == 1 and "" or "s", NS.Beautify(toGet), toGet == 1 and "" or "s")
		end
		UI:Prompt("Ascend", text, {
			{ "Yes!", function()
				NS.Game:Ascend()
			end },
			{ "No" },
		})
	end)
	a.AscendButton:SetPoint("BOTTOM", 0, 12)
	a.Close = UI.FancyButton(a, "Back", 80, 24, function()
		UI:ShowAscend(false)
	end)
	a.Close:SetPoint("TOPRIGHT", -12, -12)
	a:Hide()
	self.ascend = a
end

local function GetLink(a, i)
	local t = a.Links[i]
	if not t then
		t = a.Content:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(WHITE)
		a.Links[i] = t
	end
	return t
end

local function GetCrate(self, a, i)
	local c = a.Crates[i]
	if c then
		return c
	end
	c = CreateFrame("Button", nil, a.Content)
	c:SetSize(CRATE, CRATE)
	c.Frame = c:CreateTexture(nil, "BORDER")
	c.Frame:SetPoint("TOPLEFT", -6, 6)
	c.Frame:SetPoint("BOTTOMRIGHT", 6, -6)
	c.Shade = UI.Solid(c, "BACKGROUND", 0.06, 0.45, 0.5, 0.35)
	c.Shade:SetAllPoints()
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetAllPoints()
	c:RegisterForClicks("LeftButtonUp")
	c:SetScript("OnClick", function(self)
		local u = self.upgrade
		if not u then
			return
		end
		local game = NS.Game
		if NS.PERMANENT_SLOT_INDEX[u.name] and game.save.up[u.name] then
			UI:PickPermanentSlot(NS.PERMANENT_SLOT_INDEX[u.name])
			return
		end
		if not game.save.onAscend then
			return
		end
		if game:BuyPrestige(u) then
			UI:LayoutAscend()
		end
	end)
	c:SetScript("OnEnter", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 2, 1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.upgrade then
			NS.Guard("tooltip", UI.UpgradeTooltip, UI, self.upgrade, "ascend")
			if NS.PERMANENT_SLOT_INDEX[self.upgrade.name] and NS.Game.save.up[self.upgrade.name] then
				GameTooltip:AddLine("Click to pick the upgrade for this slot.", 0.5, 0.5, 0.5)
			end
		end
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function(self)
		NS.SetSheetCell(self.Frame, "upgradeFrame", 60, 60, 0, 1)
		GameTooltip:Hide()
	end)
	a.Crates[i] = c
	return c
end

function UI:ShowAscend(preview)
	self:Create()
	local a = self.ascend
	if not preview and not NS.Game.save.onAscend then
		self.ascendPreview = false
		a:Hide()
		return
	end
	self.ascendPreview = preview and not NS.Game.save.onAscend
	a:Show()
	self:LayoutAscend()
	self:RefreshAscend()
end

function UI:OnAscendChanged()
	if not self.ascend then
		return
	end
	local S = NS.Game.save
	if S.onAscend then
		self.ascendPreview = false
		self.ascend:Show()
		self:LayoutAscend()
	elseif not self.ascendPreview then
		self.ascend:Hide()
	end
	self:RefreshAscend()
	self:Refresh(true)
end

function UI:LayoutAscend()
	local a = self.ascend
	if not a or not a:IsShown() then
		return
	end
	local game = NS.Game
	local S = game.save
	local zoom = a.zoom
	local content = a.Content
	content:SetScale(zoom)
	content:ClearAllPoints()
	content:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
	a.Ring1:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
	a.Ring1:SetSize(1200 * zoom, 1200 * zoom)
	a.Ring2:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
	a.Ring2:SetSize(1800 * zoom, 1800 * zoom)
	a.Bg:SetTexCoord(-a.offX / 1024 * 0.25, (UI.W - a.offX * 0.25) / 1024, -a.offY / 1024 * 0.25, (UI.CONTENT_H - a.offY * 0.25) / 1024)
	local ci, linkI = 0, 0
	for _, u in ipairs(NS.PRESTIGE_UPGRADES) do
		local visible, ghosted = game:PrestigeVisible(u)
		if visible or S.up[u.name] then
			ci = ci + 1
			local c = GetCrate(self, a, ci)
			c.upgrade = u
			local icon = u.icon
			if NS.PERMANENT_SLOT_INDEX[u.name] and S.up[u.name] then
				icon = game:PermanentSlotIcon(NS.PERMANENT_SLOT_INDEX[u.name])
			end
			NS.SetIcon(c.Icon, icon)
			NS.SetSheetCell(c.Frame, "upgradeFrame", 60, 60, 0, 1)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", content, "CENTER", (u.posX or 0), -(u.posY or 0))
			local bought = S.up[u.name]
			if bought then
				c:SetAlpha(1)
				c.Icon:SetDesaturated(false)
			elseif ghosted then
				c:SetAlpha(0.25)
				c.Icon:SetDesaturated(true)
			else
				local can = (S.chips or 0) >= game:UpgradePrice(u) and S.onAscend
				c:SetAlpha(can and 1 or 0.6)
				c.Icon:SetDesaturated(not can)
			end
			c:Show()
			for _, p in ipairs(u.parentList or {}) do
				if S.up[p.name] or game:CanBuyPrestige(p) then
					linkI = linkI + 1
					local t = GetLink(a, linkI)
					t:SetVertexColor(bought and 1 or 0.6, bought and 0.9 or 0.8, bought and 0.6 or 0.9, bought and 0.9 or 0.4)
					DrawLine(t, content, (p.posX or 0) + 24, -((p.posY or 0) + 24), (u.posX or 0) + 24, -((u.posY or 0) + 24), 3)
				end
			end
		end
	end
	for i = ci + 1, #a.Crates do
		a.Crates[i].upgrade = nil
		a.Crates[i]:Hide()
	end
	for i = linkI + 1, #a.Links do
		a.Links[i]:Hide()
	end
end

function UI:RefreshAscend()
	local a = self.ascend
	if not a or not a:IsShown() then
		return
	end
	local game = NS.Game
	local S = game.save
	local toGet, level, cookiesToNext = game:AscendInfo()
	if S.onAscend then
		a.Chips:SetText(string.format("%s heavenly chip%s", NS.Beautify(S.chips or 0), (S.chips or 0) == 1 and "" or "s"))
		a.Sub:SetText(string.format("Prestige level %s. Spend your chips on heavenly upgrades, then reincarnate to start a new run.", NS.Beautify(S.prestige or 0)))
		a.Reincarnate:Show()
		a.AscendButton:Hide()
		a.Close:Hide()
	else
		a.Chips:SetText(string.format("%s heavenly chip%s", NS.Beautify(S.chips or 0), (S.chips or 0) == 1 and "" or "s"))
		local text
		if toGet < 1 then
			text = string.format("Ascending now would grant you no prestige. You need %s more cookies for the next level.", NS.Beautify(cookiesToNext))
		else
			text = string.format("Ascending now would grant you %s prestige level%s (+%s%% CpS) and %s heavenly chip%s to spend.", NS.Beautify(toGet), toGet == 1 and "" or "s", NS.Beautify(toGet), NS.Beautify(toGet), toGet == 1 and "" or "s")
		end
		if (S.prestige or 0) > 0 then
			text = string.format("Your prestige level is currently %s (CpS +%s%%). ", NS.Beautify(S.prestige), NS.Beautify(S.prestige)) .. text
		end
		a.Sub:SetText(text)
		a.Reincarnate:Hide()
		a.AscendButton:Show()
		a.AscendButton:SetEnabledLook(true)
		a.Close:Show()
	end
end

function UI:UpdateAscend(dt)
	local a = self.ascend
	if a.dragging then
		local x, y = GetCursorPosition()
		local scale = a:GetEffectiveScale()
		a.offX = a.dragOffX + (x - a.dragX) / scale
		a.offY = a.dragOffY + (y - a.dragY) / scale
		a.Content:ClearAllPoints()
		a.Content:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
		a.Ring1:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
		a.Ring2:SetPoint("CENTER", a, "CENTER", a.offX, a.offY)
	end
	local t = GetTime()
	a.Ring1:SetRotation(t * 0.02)
	a.Ring2:SetRotation(-t * 0.012)
end

-- Permanent upgrade slot picker.
function UI:PickPermanentSlot(slot)
	local game = NS.Game
	local S = game.save
	local list = game:PermanentSlotCandidates(slot)
	if #list == 0 then
		self:Prompt("Permanent upgrade slot", "You have not bought any upgrades this run that could go in a slot. Buy some, and pick one before you ascend next time.", { { "Close" } })
		return
	end
	local chosen = S.perma[slot]
	local grid = {}
	for _, u in ipairs(list) do
		table.insert(grid, { icon = u.icon, name = u.name, desc = u.desc, selected = S.perma[slot] == u.name, onPick = function()
			chosen = u.name
		end })
	end
	self:Prompt("Pick an upgrade to make permanent", "Here are all the upgrades you have purchased in this run. Pick one to permanently gain its effects across every ascension.", {
		{ "Confirm", function()
			game:SetPermanentSlot(slot, chosen)
			UI:LayoutAscend()
		end },
		{ "Cancel" },
	}, grid)
end
