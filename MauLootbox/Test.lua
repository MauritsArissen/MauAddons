-- MauLootbox demo: /mlb test (not announced anywhere)
--
-- Plays the reel with made-up items of every quality without touching any
-- real loot, so the window can be tried and tuned anywhere.

local _, NS = ...

local Test = {}
NS.Test = Test

local ITEMS = {
	{ texture = "Interface\\Icons\\INV_Misc_Food_15", name = "Tough Jerky", quantity = 3, quality = 0 },
	{ texture = "Interface\\Icons\\INV_Fabric_Linen_01", name = "Linen Cloth", quantity = 5, quality = 1 },
	{ texture = "Interface\\Icons\\INV_Chest_Cloth_17", name = "Robe of the Whale", quantity = 1, quality = 2 },
	{ texture = "Interface\\Icons\\INV_Sword_04", name = "Cruel Barb", quantity = 1, quality = 3 },
	{ texture = "Interface\\Icons\\INV_Staff_08", name = "Staff of Jordan", quantity = 1, quality = 4 },
}

function Test:Run()
	if NS.Loot.testMode then
		NS.Reel:Abort()
		NS.Loot.testMode = false
		NS.Print("Demo stopped.")
		return
	end
	NS.Loot.testMode = true
	NS.Print("Demo: five made-up items, nothing is looted. /mlb test again stops it.")
	NS.Reel:Begin(ITEMS, {
		onLanded = function() end,
		onFinished = function()
			C_Timer.After(1.5, function()
				NS.Reel:Abort()
				NS.Loot.testMode = false
			end)
		end,
		onSkip = function()
			NS.Reel:FinishNow()
		end,
		onClose = function()
			NS.Reel:Abort()
			NS.Loot.testMode = false
		end,
	})
end
