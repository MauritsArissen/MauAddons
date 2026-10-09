# MauLootbox — guide for future work

Complete reference for the MauLootbox addon. Read it before changing anything. Target client, install loop, syntax check (node + luaparse) and the Blizzard source branch (`Gethe/wow-ui-source`, branch `forever`) are the same as for MauUndercut; see `../MauUndercut/CLAUDE.md` sections 2 and 3.

## 1. What it is

Blizzard's loot window is kept from opening. On `LOOT_OPENED` the addon reads every slot, takes coins and anything below the minimum quality at once, and feeds the rest to a single-column slot machine reel that spins once per item and lands on it; the item is taken (`LootSlot`) the moment the reel lands. Whatever cannot be taken is listed afterwards with click-to-take buttons. The game's auto-loot option is switched off while the addon is enabled and emulated by the addon. Options in Settings > AddOns; `/mlb` opens them, `/mlb test` plays a demo. Built 2026-10-09 on the user's request, with everything (even Poor and Common) spinning by default so it can be tested.

## 2. Files

| File | Role |
|---|---|
| `MauLootbox.toc` | Load order: MauLootbox.lua, Reel.lua, Loot.lua, Options.lua, Test.lua. |
| `MauLootbox.lua` | Namespace `NS` (also `_G.MauLootbox`), `NS.DEFAULTS` / `NS.RANGES` / `NS.QUALITIES`, helpers (`QualityColor`, `QualityName`), saved variables (`MauLootboxDB.settings`, `MauLootboxDB.position`, `MauLootboxDB.savedAutoLoot`), `NS.ApplyTakeover`, event frame, `/mlb`. |
| `Reel.lua` | `NS.Reel`: the window (`MauLootboxFrame`, BackdropTemplate, movable), `Begin(items, callbacks)`, the spin (`Spin`/`Render`/`Land`/`OnUpdate`), `FinishNow`, `Abort`, `ShowLeftovers`. |
| `Loot.lua` | `NS.Loot`: `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `LOOT_CLOSED`, `LOOT_BIND_CONFIRM`, `UI_ERROR_MESSAGE`; `Take`, `Finish`, `Close`. |
| `Options.lua` | `NS.Options`: Settings > AddOns category (same pattern as MauGuildMap's). |
| `Test.lua` | `NS.Test`: `/mlb test` demo; sets `Loot.testMode` so real loot events are ignored meanwhile. |

Settings (`MauLootboxDB.settings`, defaults in `NS.DEFAULTS`): `enabled` true, `minQuality` 0 (Enum.ItemQuality; dropdown values are numbers), `coinsInstant` true, `speed` 100 (percent of the spin and hold times, 50–200), `sounds` true, `autoConfirmBind` true, `scale` 100 (60–150).

## 3. Facts about the loot API on this client (verified in the `forever` branch)

- `Blizzard_UIPanels_Game/Mainline/LootFrame.lua`: `LootFrameMixin:OnLoad` registers `LOOT_OPENED` and `LOOT_CLOSED`; `OnEvent(LOOT_OPENED)` receives `(isAutoLoot, acquiredFromItem)` and calls `Open()`, which reads slots with `GetNumLootItems()` / `GetLootSlotInfo(slot)` → `texture, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive, isCoin`, plus `GetLootSlotType(slot)` (`Enum.LootSlotType`: None 0, Item 1, Money 2, Currency 3) and `GetLootSlotLink(slot)`. **`OnHide` calls `CloseLoot()`**, so Blizzard's frame must never open while the show runs: `NS.ApplyTakeover` does `LootFrame:UnregisterEvent("LOOT_OPENED")` while enabled and re-registers it when disabled.
- **Auto-loot is native.** With the `autoLootDefault` CVar on (or a shift-click), the client takes every slot itself right after `LOOT_OPENED`; Blizzard's Lua only animates the slide-outs on `LOOT_SLOT_CLEARED`. Nothing in Lua can delay it. The addon therefore remembers the CVar in `MauLootboxDB.savedAutoLoot`, sets it to `0` while enabled, and restores it when disabled via its option. If `LOOT_OPENED` still arrives with `autoLoot` true (shift-click), the reel plays anyway; `Take` skips slots already in `Loot.cleared`.
- `LootSlot(slot)`, `CloseLoot()`, `ConfirmLootSlot(slot)` are legacy globals (not in the generated API docs); Blizzard calls `LootSlot` from a click handler and auto-loot addons call it from events, so it is not expected to need a hardware event. If it ever turns out to be blocked, the leftover list's click-to-take buttons are the fallback (hardware event).
- Bind-on-pickup: `LOOT_BIND_CONFIRM(slot)`; the standard `LOOT_BIND` dialog (`Blizzard_StaticPopup_Game/GameDialogDefs.lua`) accepts with `ConfirmLootSlot(slot)`. The addon confirms itself when `autoConfirmBind` and not `IsInGroup()`, then hides the dialog; in a group Blizzard's dialog is left alone.
- Bags full: `UI_ERROR_MESSAGE(errorType, message)` with `message == ERR_INV_FULL`; the addon sets `bagsFull` and stops taking non-coin slots.
- Sounds: `PlaySound(SOUNDKIT.X)` returns `willPlay, handle`; `StopSound(handle)`. Used: `UI_BONUS_LOOT_ROLL_START`, `UI_BONUS_LOOT_ROLL_LOOP` (spin), `UI_RAID_LOOT_TOAST_LESSER_ITEM_WON`, `UI_EPICLOOT_TOAST`, `UI_LEGENDARY_LOOT_TOAST`, `IG_MAINMENU_OPTION_CHECKBOX_ON` (landing by quality). All guarded with `SOUNDKIT[key]` checks.
- Quality colours: `C_Item.GetItemQualityColor(quality)` with `ITEM_QUALITY_COLORS` fallback.

## 4. The session (`Loot.lua`)

1. `LOOT_OPENED`: build `entries[slot]`; locked slots get the reason "Not yours to take" and are never taken; coins (`isCoin` or slot type Money) and items below `minQuality` → `Take` at once; the rest → `Reel:Begin(list, callbacks)`.
2. `Reel` callbacks: `onLanded(entry)` → `Take(entry)` (`LootSlot`, unless cleared/locked/bags full); `onFinished` → `Finish`; `onSkip` → `Reel:FinishNow` (lands every remaining item now, i.e. takes them all); `onClose` → `Loot:Close` (`CloseLoot`).
3. `Finish`: after `CLEAR_TIMEOUT` (0.8 s), any entry whose slot still has a texture and was not cleared becomes a leftover (reason: bags full / could not be taken / not yours) shown by `Reel:ShowLeftovers` with click-to-take buttons; with no leftovers `Close` (`CloseLoot`), although the client normally closes an empty window by itself.
4. `LOOT_CLOSED` (walked away, closed, emptied): state idle, reel aborted.
5. `Loot.testMode` (set by `Test.lua`) makes every handler a no-op so the demo cannot touch real loot.

## 5. The reel (`Reel.lua`)

- Window: 220×320, BackdropTemplate with the dialog box art, movable (position saved in `MauLootboxDB.position`), scale from `settings.scale`, strata HIGH. A clipping `View` (`SetClipsChildren(true)`) 80×192 shows three rows of 64 px; five textures are reused for the rows on screen. Shades dim the top and bottom rows, `Border` (`Interface\Buttons\UI-ActionButton-Border`, ADD) frames the middle row and takes the quality colour on landing, `Flash` (white, ADD) fades out over 0.45 s.
- Strip: 16–24 random icons from `FILLER_ICONS` (classic icon files that every client has) plus the icons of the current loot, with the real item last. `Render(position)` places strip index `base + k` at `-(k - frac) × 64` from the centre for k = −2..2, so the strip moves upward and ends with the real item centred.
- Timing: `SPIN_TIME` / `HOLD_TIME` per quality (1.3 s / 0.7 s for Poor up to 4.2 s / 2.0 s for Legendary) times `speed / 100`; cubic ease-out (`EaseOutCubic`) so the reel decelerates. The loop sound starts with the spin and is stopped on landing; the landing sound depends on quality.
- `FinishNow` fires `onLanded` for every item not yet landed (the current one too if still spinning) and then `onFinished`. `Abort` stops sounds and hides. `ShowLeftovers(entries, onTake)` reuses the window: buttons in the view, tooltip with the reason.

## 6. How to verify

1. Syntax: node + luaparse over every `.lua`.
2. `/mlb test`: five spins of increasing quality, flash, name and sound on each, "Take all" ends it early, the close button aborts.
3. Real loot: kill something, the reel spins per item and the items arrive after each landing; coins arrive at once; the window goes away by itself. Loot with full bags → leftover list, free a slot, click the item. Shift-click a corpse → items arrive at once, reel still plays. In a group with group loot: items above threshold roll as usual and appear as "Not yours to take" leftovers if locked. Disable the addon in its options → Blizzard's window and the previous auto-loot setting are back.
4. If `LootSlot` from the reel does nothing (every item ends up in the leftover list with "Could not be taken" while bags are not full), the client requires a hardware event for it; switch the design to click-to-take on landing.
