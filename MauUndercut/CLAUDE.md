# MauUndercut — guide for future work

This file is the complete reference for the MauUndercut addon: what it does, how it is built, why it is built that way, and what was tried and rejected. Read it before changing anything.

## 1. What it is

MauUndercut is a World of Warcraft addon with four features:

1. **MauUndercut tab (posting)**, inside Blizzard's auction house window: tick bag stacks, the addon looks up the lowest listed price of each one, pre-fills *lowest minus undercut*, and posts when the user clicks OK, then moves to the next stack.
2. **MauScan tab (scanner)**, same window: one full dump of the auction house, listing every item with its lowest price, with the items listed below vendor sell price first and the profit of buying and vendoring them.
3. **Price database + tooltip line** (0.7): the lowest auction price of every item ever seen (searches, browse results, scans), persisted in the saved variables, shown as an "Auction price" tooltip line; Shift shows the stack value.
4. **Crafting profit** (0.7): profit per recipe in Blizzard's professions window, from the price database (reagents at auction or vendor price, product at auction price after the 5% cut).

Nothing else. Features that were added and later removed are listed in section 9; do not bring them back without asking.

## 2. Target client (the facts that matter most)

- The game is **World of Warcraft: Forever**, Blizzard's internal project name "Camelot". Installed as `C:\Program Files (x86)\World of Warcraft\_classic_beta_` (product `wow_classic_beta`, exe `WowB.exe`).
- Version **1.60.1**, TOC `## Interface: 16001`. The 1.x number is misleading: the client runs the **modern retail engine and UI** (12.x-era FrameXML: Edit Mode, ScrollBox, TooltipDataProcessor, `C_Item`, `C_Container`, `C_AddOns`), and `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`.
- The auction house is the **modern one**: `C_AuctionHouse`, commodities vs items, item keys, throttled queries, `Blizzard_AuctionHouseUI` with `AuctionHouseFrame`. The Classic API (`QueryAuctionItems`, `AuctionFrame`) does not exist here.
- Forever-specific API: `C_AuctionHouse.SupportsCopperValues()` says whether prices may contain copper. Retail rounds to silver; Forever allows copper (the addon adapts either way).
- Blizzard's UI source for this client is public: GitHub `Gethe/wow-ui-source`, branch **`forever`**. Files are split into `Shared/`, `Mainline/`, `Camelot/` folders; TOCs use `[Family]` (= Mainline here) and the game-type token `camelot`. API docs: `Interface/AddOns/Blizzard_APIDocumentationGenerated/`. Every template and function used by this addon was verified against that branch.
- Reference implementations on this machine: Auctionator (with LibAHTab) is installed under `_classic_\Interface\AddOns\Auctionator`; its `Source_ModernAH` folder shows the same API in use.
- **Client bug, SavedVariables never read (2026-09-17 to 2026-09-25)**: beta builds 1.60.1.69893–69913 wrote every addon's SavedVariables at logout/reload but never opened the files again at login (all addons, account-wide and per-character; Blizzard forum thread "SavedVariables never load in the beta — all addon settings reset on login (69913)"). In this addon that looked like settings, last-posted prices, `scan.lastScanTime` and the whole price database being "lost" after every relog, while the file on disk was complete, and then the near-empty in-memory table overwrote the file at the next logout. Build **1.60.1.70009** (patched 2026-09-25 08:31) opens the files again. How it was verified: NTFS last-access times on `WTF\Account\<acct>\SavedVariables\*.lua` equal the login time on 70009 and were never touched on 69913. If persistence ever looks broken again: check the file on disk first (`WTF\Account\<acct>\SavedVariables\MauUndercut.lua`, the `.bak` is the previous save), then the access times, then `/mu prices`. Community workaround for the broken builds was nobewayo/ForeverSVFix (a junction exposing the SavedVariables folder inside the addon plus a TOC line that loads the file as ordinary addon code); not needed on 70009.

## 3. Install and dev loop

- The project folder is `C:\Users\Gamer\Documents\MauAddons\MauUndercut`, inside the MauAddons git repository (https://github.com/MauritsArissen/MauAddons). The addon was renamed from Nightfall to MauUndercut and moved out of `Documents\Nightfall` on 2026-09-24.
- A directory junction makes the game see it as `_classic_beta_\Interface\AddOns\MauUndercut`. The folder name the game sees must equal the TOC name (`MauUndercut.toc`). Recreate with:
  `New-Item -ItemType Junction -Path "<AddOns>\MauUndercut" -Target "C:\Users\Gamer\Documents\MauAddons\MauUndercut"`
- Edit files in place, `/reload` in game. No build step.
- There is no Lua interpreter on this machine. Syntax-check with node + the `luaparse` npm package (parse each file with `luaVersion: '5.1'`). Runtime behaviour can only be verified in the game; ask the user for error text (`/console scriptErrors 1` or BugSack).
- Saved variables: `MauUndercutDB` (account-wide) in `WTF\Account\<account>\SavedVariables\MauUndercut.lua`.

## 4. Files

| File | Role |
|---|---|
| `MauUndercut.toc` | Manifest. Load order: MauUndercut.lua, Prices.lua, Poster.lua, UI.lua, Scanner.lua, ScanUI.lua, Tooltip.lua, Crafting.lua. |
| `MauUndercut.lua` | Namespace `NS` (also `_G.MauUndercut`), helpers (money formatting, quality colours, item keys, sanitising prices), saved variables and defaults, bag scanning, auction house tab injection, event frame, `/mu` slash command. |
| `Prices.lua` | `NS.Prices`: the persistent price database (auction search results, browse results, scan batches, vendor purchase prices) and its version counter. |
| `Poster.lua` | `NS.Poster`: the posting state machine (queue, search, price suggestion, auto-skip, post, bookkeeping of created auctions). |
| `UI.lua` | `NS.UI`: the posting panel (bag list with checkboxes on the left, current item / price / quantity / duration / OK on the right). |
| `Scanner.lua` | `NS.Scanner`: the full-dump scanner (ReplicateItems, two passes, item data loading, results, bulk update of the price database). |
| `ScanUI.lua` | `NS.ScanUI`: the scanner panel (scan button, filters, results list). |
| `Tooltip.lua` | `NS.Tooltip`: the "Auction price" tooltip line (TooltipDataProcessor post call, Shift for stack value). |
| `Crafting.lua` | `NS.Crafting`: profit per recipe in `ProfessionsFrame` (row value + detail line). |
| `README.md` | User-facing description. |

All files share the addon-private table via `local _, NS = ...`. No libraries are embedded. Indentation is tabs.

## 5. Functional description

### 5.1 Posting tab

- Left: every bag stack the auction house accepts (`C_AuctionHouse.IsSellItemValid`), sorted by name, each with a checkbox, icon, name, stack count and a status column. Buttons: All, None, Refresh, Start posting (N) / Stop.
- Right: current item (icon, name, stack, bag/slot, commodity/equipment/item), the lookup result line, price input (gold/silver/copper, copper hidden when the realm does not support it), quantity input with Max, duration (2 h / 8 h / 24 h), deposit and total, the undercut amount setting, OK / Skip / Retry search, a hint line, and a short log.
- Flow per stack: validate it is still in the bags → look up the lowest price → suggest a price → wait for OK → post → next stack. The lookup for the next stack starts immediately after a post, so the price is usually visible before the user reads it.
- Price suggestion, in order:
  1. Lowest listed price of the exact item minus the undercut (default 1 copper; forced to whole silver on realms without copper support).
  2. If the lowest auction is the user's own, match it (no self-undercut).
  3. Equipment: exact item level and suffix first; if none listed, the lowest similar variant, flagged as such.
  4. Nothing listed: the price last posted for that item (saved), else vendor price × 2, else empty (user types a price).
- **Auto-skip**: if the suggested price is below the item's vendor sell price, the stack is skipped without asking, logged, and shown as *below vendor* (orange) in the list. Counted as skipped in the end summary.
- Quantity defaults to everything the character owns of that item (`C_AuctionHouse.GetAvailablePostCount`), because the modern auction house pulls from all stacks. Further ticked stacks of the same item then show *included*.
- Statuses in the list: posted, posting..., confirm (Blizzard asked for confirmation), failed, skipped, not found, included, below vendor.
- `/mu` selects this tab while the auction house is open.

### 5.2 Scanner tab

- Scan button with a 15-minute countdown (the Forever server ignores a second `ReplicateItems` within 15 minutes; tested 2026-09-24, the second request never answers, so the client-side cooldown must stay).
- After a scan the list shows every item in the dump: icon, name, listed quantity, lowest price each, vendor price each, and vendor profit for items that have auctions below vendor price (those rows come first, sorted by profit, tinted green). Own auctions never count as deals.
- Filters: "Only items below vendor price" checkbox, a name filter box, "Hide deals under N copper profit". Settings persist.
- Row click: commodities open directly on the Buy tab (`AuctionHouseFrame:SelectBrowseResult`), other items run a name search (`SearchBar:SetSearchText` + `StartSearch`). Shift-click links the item. The addon never buys anything.
- Chat reports when the dump was requested, how long it took, how many entries, and the final counts.
- `/mu scan` selects this tab.

### 5.3 Price database and tooltip line

- Every item the client has seen on the auction house has one lowest unit price and the time it was seen, kept across sessions. Sources: any commodity/item search result event (the Buy tab, the posting tab, other addons), browse results (Buy tab list), and the full scan (bulk update at the end). Own auctions count; equipment variants share the item ID's price.
- Merchant windows record the vendor's unit price per item (extended-cost items excluded) for the crafting calculation.
- Tooltip: `Auction price (age)` with the price, on `GameTooltip` and `ItemRefTooltip` only. With Shift held: `Auction price xN` with price × N, where N is the hovered bag/bank stack (exact) or the button's count, else the item's maximum stack size (shown as "(full stack)"). No line when the item has never been seen.
- No settings, no toggle; the user asked for it to be always on.

### 5.4 Crafting profit

- In Blizzard's professions window every recipe row that produces an item gets a right-aligned value: `+1.2g` / `-45s` (green / red) or a grey `?` when the product price or any reagent price is unknown.
- The selected recipe shows a line under its name: `Reagents: <cost> (n without a known price) - Sells for: <unit price> xQ - Profit: <signed> (after 5% cut)`. Q is the average of quantityMin/quantityMax when it is not 1.
- Reagent unit cost = min(auction price, vendor price) when both are known, otherwise whichever exists. Profit = sell × Q × (1 − 0.05) − cost, only when nothing is missing.
- Enchants, salvage and gathering "recipes" (no `outputItemID` or not `TradeskillRecipeType.Item`) show nothing.

## 6. Technical details

### 6.1 Tab injection (`MauUndercut.lua`)

`Blizzard_AuctionHouseUI` is load-on-demand, so tabs are created on `ADDON_LOADED` for it (or on `AUCTION_HOUSE_SHOW`, or at `PLAYER_LOGIN` if it is already loaded). Two paths:

- **Native**: create a button from `AuctionHouseFrameDisplayModeTabTemplate` parented to `AuctionHouseFrame` (its `PanelTabButtonTemplate` has `parentArray="Tabs"`, so it lands in `AuctionHouseFrame.Tabs`), register an empty display mode table in `AuctionHouseFrameDisplayMode[id]`, map it in `AuctionHouseFrame.tabsForDisplayMode`, call `PanelTemplates_SetNumTabs`. Blizzard's `SetDisplayMode` then hides all of its own sub-frames for our mode and selects our tab; a `hooksecurefunc` on `SetDisplayMode` shows/hides our panels and sets the title.
- **LibAHTab**: if `LibStub("LibAHTab-1-0")` exists (Auctionator installed), tabs are created through it so all extra tabs line up.

Panels are plain frames parented to `AuctionHouseFrame`, anchored `TOPLEFT (8, -32)` / `BOTTOMRIGHT (-8, 30)` (the frame is 800×538, the money frame sits bottom-left).

### 6.2 Posting state machine (`Poster.lua`)

States: `idle → searching | waitingKey | waitingThrottle → ready → (post) → next`. Key points:

- Item identity: `C_AuctionHouse.GetItemKeyFromItem(itemLocation)`; `GetItemKeyInfo` gives `isCommodity` / `isEquipment` (may be nil until `ITEM_KEY_ITEM_INFO_RECEIVED`).
- Searches: commodities `SendSearchQuery(MakeItemKey(itemID), sorts Price asc, true)`; equipment `SendSellSearchQuery(MakeItemKey(itemID), sorts Buyout asc, true)` (item level and suffix must be cleared for sell searches, results carry the real keys); other items `SendSearchQuery(full key, ...)`.
- Results arrive on `COMMODITY_SEARCH_RESULTS_UPDATED(itemID)` / `ITEM_SEARCH_RESULTS_UPDATED(itemKey)`. The Auctionator workaround is used: if `HasSearchResults` is false, or results are not full with zero quantity, retry (max 4 attempts). For items, more pages are requested while nothing usable is loaded (max 5).
- Throttling: `C_AuctionHouse.IsThrottledMessageSystemReady()` gates both searching and posting; `AUCTION_HOUSE_THROTTLED_SYSTEM_READY` resumes. Search queries are limited to 100 per minute by the server.
- Posting: `C_AuctionHouse.PostCommodity(location, duration, quantity, unitPrice)` or `PostItem(location, duration, quantity, nil, buyout)`. Both **require a hardware event**, so they are only called from the OK button's OnClick (Enter in the inputs triggers `okButton:Click()`). They return `needsConfirmation`; if true the addon caches the parameters on Blizzard's own sell frame (`CachePendingPost`) so Blizzard's `AUCTION_HOUSE_POST_WARNING` popup confirms our post.
- After posting: `AUCTION_HOUSE_AUCTION_CREATED(auctionID)` marks the entry posted (multi-sell items fire once per unit; `GetAuctionInfoByID` is used to attribute when possible, otherwise FIFO), `AUCTION_HOUSE_POST_ERROR` / `AUCTION_HOUSE_SHOW_ERROR` mark it failed. `AUCTION_MULTISELL_*` events block the OK button until a multi-sell batch is done.
- Stack validation before each item: location exists, same item ID, still sellable; otherwise the item is searched for in other slots (`NS.RelocateEntry`), else marked *not found* — or *included* if an earlier post of the same item already consumed it.
- Timers use `C_Timer.NewTimer` with a generation counter so stale callbacks are ignored after Skip/Stop/Next.
- Deposits: `CalculateCommodityDeposit(itemID, duration, quantity)` / `CalculateItemDeposit(location, duration, quantity)`. Duration index 1/2/3 = 2 h / 8 h / 24 h on Forever.
- Price sanitising (`NS.SanitizePrice`): minimum 1 copper, or 1 silver and rounded up to whole silver when `SupportsCopperValues()` is false.

### 6.3 Scanner (`Scanner.lua`)

- `C_AuctionHouse.ReplicateItems()` → `REPLICATE_ITEM_LIST_UPDATE` → `GetNumReplicateItems()` and `GetReplicateItemInfo(index)` (zero-based; returns name, texture, count, quality, ..., buyoutPrice at position 10, owner at 14, itemID at 17, hasAllInfo at 18). The replicate list stays readable while the auction house is open.
- **Memory design** (this matters, see 9): never a table per auction. Pass 1 walks the list in batches of 500 per frame and keeps per item only `{itemID, name, icon, quality, low, quantity, vendor, dealQuantity, dealCount, profit}`. Then item data is loaded for items the client has not cached (`C_Item.GetItemInfo` → vendor price is return value 11; missing items are requested with `C_Item.RequestLoadItemDataByID` and resolved on `GET_ITEM_INFO_RECEIVED` / `ITEM_DATA_LOAD_RESULT`, 40 s timeout). Pass 2 walks the list again and accumulates, per item, the auctions whose buyout is below vendor × count (own auctions excluded). Results are the per-item records themselves, sorted deals-first by profit then name, kept only in memory, and `collectgarbage("collect")` runs at the end.
- A scan is cancelled (state `failed`) if the auction house closes or no list arrives within 90 s.
- `lastScanTime` is saved so the 15-minute countdown survives `/reload`.
- `Finish()` hands `self.byItem` to `NS.Prices:UpdateFromScan` (one `Set` per item, one version bump) before the per-item tables are dropped.

### 6.4 Saved variables (`MauUndercutDB`)

- `settings.undercut` (copper, default 1), `settings.duration` (1–3, default from the `auctionHouseDurationDropdown` CVar).
- `prices[itemKeyString] = {price, time}`: last posted price per item key, used as a fallback suggestion.
- `scan.lastScanTime`, `scan.minProfit`, `scan.onlyDeals`.
- `market[itemID] = copper` and `marketTime[itemID] = unixTime`: the price database (0.7). Integer keys, number values, nothing else per item.
- `vendorBuy[itemID] = copper`: vendor purchase price per unit (0.7).
- `priceCache` and `ledger` keys are deleted on load (leftovers of removed features; note `priceCache` from 0.4 is a different key than `market`).

### 6.6 Price database (`Prices.lua`)

- `NS.Prices` is a frame registered for `COMMODITY_SEARCH_RESULTS_UPDATED/ADDED(itemID)`, `ITEM_SEARCH_RESULTS_UPDATED/ADDED(itemKey)`, `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` (reads `C_AuctionHouse.GetBrowseResults()`), `AUCTION_HOUSE_BROWSE_RESULTS_ADDED(addedBrowseResults)`, `MERCHANT_SHOW`, `MERCHANT_UPDATE`. It reads the same result lists Blizzard's UI reads, so it costs nothing extra on the server side.
- Commodity results: minimum `unitPrice`. Item results: minimum `buyoutAmount / quantity`, keyed by `itemKey.itemID`. Browse results: `minPrice` per `itemKey.itemID`. At most 1000 entries per event are looked at.
- Merchants: `GetMerchantNumItems()`, `GetMerchantItemID(i)`, `C_MerchantFrame.GetItemInfo(i)` (`price`, `stackCount`, `hasExtendedCost`, `currencyID`; the client loads the Mainline `MerchantFrame.lua`, verified in the `Blizzard_UIPanels_Game` TOC) with a fallback to the legacy `GetMerchantItemInfo`.
- API: `Get(itemID) → price, time`, `GetVendorBuy(itemID)`, `GetUnitCost(itemID)` (min of both), `Set`, `UpdateFromScan(byItem)`, `Count()`. `Prices.version` increments on every change (`Changed()`), which also pokes `NS.Crafting:OnPricesChanged()`.
- Why this is safe where 0.4 was not: two numeric tables keyed by integer item IDs (a few thousand items is well under a megabyte), no table or string per item, no per-frame work, no `GetItemInfo` calls on the tooltip path, no closures created in event handlers. If memory or FPS ever degrade again, measure before touching the design.

### 6.7 Tooltip line (`Tooltip.lua`)

- `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`; `fn(tooltip, data)` uses `data.id` (verified in `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua` and `TooltipUtil.GetDisplayedItem`). Only `GameTooltip` and `ItemRefTooltip` get the line (comparison and embedded tooltips are skipped).
- Stack count: the tooltip owner's `GetBagID()`/`GetID()` → `C_Container.GetContainerItemInfo(...).stackCount` (bag and bank buttons), else the owner's `.count` field set by `SetItemButtonCount` (merchant, mail, trade buttons), else `C_Item.GetItemMaxStackSizeByID(itemID)`.
- Shift toggling: bag tooltips are rebuilt by Blizzard's `OnUpdate` every 0.2 s (`ContainerFrameItemButtonMixin:OnUpdate` calls `SetBagItem` again). For everything else `MODIFIER_STATE_CHANGED` (LSHIFT/RSHIFT) calls `tooltip:RefreshData()` (`GameTooltipDataMixin:RefreshData` → `RebuildFromTooltipInfo`, re-runs the getter and all post calls) when the tooltip is shown and `IsTooltipType(Item)`.

### 6.8 Crafting profit (`Crafting.lua`)

- Forever uses the modern `Blizzard_Professions` addon with a `Camelot/` override layer (`ProfessionsFrame`, `CraftingPage`, `RecipeList` 304 px wide, `SchematicForm` 493×484; `Blizzard_Professions.toc` loads `[Game]\...` files for `camelot`). Load-on-demand: `NS.Crafting:TryInit()` runs on `ADDON_LOADED` for `Blizzard_Professions`, at `PLAYER_LOGIN` if already loaded, and on `TRADE_SKILL_SHOW`.
- Rows: `ScrollUtil.AddInitializedFrameCallback(ProfessionsFrame.CraftingPage.RecipeList.ScrollBox, cb, owner, false)`; the callback receives `(owner, row, node)` and runs after `ProfessionsRecipeListRecipeMixin:Init`. `node:GetData().recipeInfo` identifies the recipe (categories/dividers have none → hide). The value is a `GameFontHighlightSmall` string anchored `RIGHT -6` (or left of `LockedIcon`); the `Label` width is reduced so names never run under it (same formula as Blizzard's Init, plus the value width). `iterateExisting` is false on purpose because `ForEachFrame` passes `(frame, elementData)` while the callback expects `(owner, frame, elementData)`.
- Detail line: `hooksecurefunc(SchematicForm, "Init", ...)` (called as `SchematicForm:Init(recipeInfo)`); a `GameFontNormalSmall` string anchored `TOPLEFT` to `OutputText` `BOTTOMLEFT (0, -4)`, width 430. `OutputSubText` is never used on this client (no callers of `SetOutputSubText`), so that space is free; the vertical layout organizer for description/tools/cooldown starts 12 px below the 53 px icon, below our line.
- Data: `C_TradeSkillUI.GetRecipeSchematic(recipeID, false)` → `recipeType`, `outputItemID`, `quantityMin/Max`, `reagentSlotSchematics[i]` with `reagentType == Enum.CraftingReagentType.Basic` (1), `reagents[1].itemID`, `quantityRequired`. Ranked recipes use `Professions.GetHighestLearnedRecipe(recipeInfo)` like Blizzard's row. Results are cached per recipe against `NS.Prices.version`; `OnPricesChanged` re-decorates visible rows (`ScrollBox:ForEachFrame`) and the form after a 0.2 s coalescing timer while the window is shown.
- `AH_CUT = 0.05` is a constant in `Crafting.lua`; the scanner and poster do not apply a cut anywhere.

### 6.5 UI building blocks (all verified in the `forever` branch)

`UIPanelButtonTemplate`, `InputBoxTemplate`, `UICheckButtonTemplate` (text via `.Text`), `InsetFrameTemplate`, `LargeMoneyInputFrameTemplate` (`GoldBox/SilverBox/CopperBox`, `SetAmount/GetAmount/Clear/SetOnValueChangedCallback`; copper hidden manually when unsupported, mirroring Blizzard's `useAuctionHouseCopperValue`), `WowScrollBoxList` + `MinimalScrollBar` + `CreateScrollBoxListLinearView()` + `ScrollUtil.InitScrollBoxListWithScrollBar` + `CreateDataProvider` (rows are plain `"Button"` frames built in the element initializer), `AuctionHouseFrameDisplayModeTabTemplate`, `PanelTemplates_*`. Money text comes from `C_CurrencyInfo.GetCoinTextureString` with a manual fallback. Quality colours from `ColorManager.GetColorDataForItemQuality` with `ITEM_QUALITY_COLORS` fallback.

## 7. Decisions made with the user

- Addon and folder name: **MauUndercut**, living as `MauUndercut/` inside the MauAddons repository.
- Durations 2 / 8 / 24 hours. Quantity defaults to the maximum available. Undercut 1 copper. Auto-skip below vendor price.
- Scanner shows every item, deals first, with the vendor-flip profit next to them; results are not persisted.
- The 15-minute scan cooldown is a server rule and must stay in the client too.
- Keep the addon lean; memory and FPS were an explicit concern.
- 2026-09-24: the user explicitly asked for a **persistent** price database again (every auction lookup and every scan update it, prices survive logout), an always-on tooltip line with Shift for the stack value, and profit per recipe in the professions window. This supersedes the "session-only" rule from the 0.4 removal; the design constraints in 6.6 are what makes it acceptable.
- Crafting profit is shown after a 5% auction house cut; reagents are priced at the lower of auction and vendor price; vendor prices are learned by visiting vendors.

## 8. How to verify changes

1. Syntax: node + luaparse over every `.lua` file.
2. In game: `/reload`, open an auctioneer, both tabs must appear after Buy/Sell/Auctions. Post one cheap commodity and one piece of gear; run one scan; watch the AddOns memory column for growth.
3. Price database and tooltip: search an item on the Buy tab, close the auction house, hover that item in the bags: the "Auction price" line must show; hold Shift for `xN`. After `/reload` the line must still be there (saved variables). `/mu prices` prints the number of stored prices; it must not drop across a `/reload` or relog (see the client bug note in section 2 if it does).
4. Crafting: open a profession after a scan; rows show values, selecting a recipe shows the detail line; visit a vendor selling a reagent (vials, thread) and the cost of recipes using it should drop to the vendor price.
5. If Blizzard's UI changes, re-check against the `forever` branch before assuming an API or template.

## 9. Removed features (do not reintroduce without asking)

- **Sales ledger / `/mu stats` window** (v0.3–0.5): recorded every created auction ID and matched "Auction successful" mail invoices (`GetInboxInvoiceInfo`, hooks on `TakeInboxMoney` / `AutoLootMailItem`) to report gold earned. Worked, but the user asked for it to be removed to keep the addon to posting and scanning.
- **Persistent price cache + tooltip line, first version** (v0.4): stored the lowest seen price of every item (scans, searches, Buy-tab browsing) in saved variables and added a tooltip line via `TooltipDataProcessor.AddTooltipPostCall`. Removed because memory grew and FPS dropped to ~20 over time. Re-introduced on request in 0.7 as `Prices.lua` / `Tooltip.lua` with the constraints in 6.6 (numbers only, integer keys, no per-frame work). If the problem returns, profile before ripping it out: the requirement is persistence.
- **Per-auction scan data** (v0.2–0.4): the first scanner kept a table per auction; replaced by the two-pass, numbers-only design above for the same memory reason.
- **Client-side cooldown removal** (tested once): the server enforces 15 minutes, so the cooldown was restored.

## 10. Useful references

- Blizzard UI source for this client: https://github.com/Gethe/wow-ui-source/tree/forever (auction house under `Interface/AddOns/Blizzard_AuctionHouseUI/`).
- Auctionator reference copy: `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\Auctionator\Source_ModernAH`.
- Forever addon notes (interface number, load conditions): https://wow4ever.quest/en/addons
