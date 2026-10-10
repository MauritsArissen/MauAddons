-- MauCookie minimap button: the cookie on the minimap's edge.  Click opens
-- the bakery, drag moves it around the rim (the angle is saved).

local _, NS = ...

local MM = {}
NS.Minimap = MM

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function MM:Create()
	if self.button or not Minimap then
		return
	end
	local b = CreateFrame("Button", "MauCookieMinimapButton", Minimap)
	self.button = b
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:SetMovable(true)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")

	b.Bg = b:CreateTexture(nil, "BACKGROUND")
	b.Bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	b.Bg:SetSize(24, 24)
	b.Bg:SetPoint("CENTER", 0, 1)
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetTexture(NS.Art("cookie"))
	b.Icon:SetSize(20, 20)
	b.Icon:SetPoint("CENTER", 0, 1)
	local mask = b:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(b.Icon)
	b.Icon:AddMaskTexture(mask)
	b.Border = b:CreateTexture(nil, "OVERLAY")
	b.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b.Border:SetSize(54, 54)
	b.Border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	b:SetScript("OnClick", function()
		NS.UI:Toggle()
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("MauCookie")
		local game = NS.Game
		if game.save then
			GameTooltip:AddLine(NS.Beautify(game.save.cookies) .. " cookies, " .. NS.BeautifyRate(game:Cps(true)) .. " per second", 1, 1, 1)
		end
		GameTooltip:AddLine("Click to open the bakery. Drag to move this button.", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnDragStart", function(self)
		self.dragging = true
	end)
	b:SetScript("OnDragStop", function(self)
		self.dragging = nil
	end)
	b:SetScript("OnUpdate", function(self)
		if not self.dragging then
			return
		end
		local mx, my = Minimap:GetCenter()
		local scale = Minimap:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		cx, cy = cx / scale, cy / scale
		NS.GetSettings().minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
		MM:Position()
	end)
	self:Position()
	self:Apply()
end

function MM:Position()
	local b = self.button
	if not b then
		return
	end
	local angle = math.rad(NS.GetSettings().minimapAngle or 200)
	local radius = (Minimap:GetWidth() or 140) / 2 + 6
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MM:Apply()
	if self.button then
		self.button:SetShown(NS.GetSettings().minimapButton)
	end
end
