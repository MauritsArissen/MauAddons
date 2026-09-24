# MauUndercut

Bulk auction posting and a full auction house scanner for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Forever runs the modern (retail-style) auction house, so this addon is built on `C_AuctionHouse`. It adds two tabs to the auction house window. For a complete technical and functional description see `CLAUDE.md`.

## Posting (MauUndercut tab)

1. Tick the bag stacks you want to sell (or press **All**) and press **Start posting**.
2. For each stack the addon searches the auction house for the lowest listed price of that exact item.
3. Your price is pre-filled as *lowest price minus your undercut* (1 copper by default). If the cheapest auction is already yours it matches that price instead of undercutting yourself.
4. If that price would be below what a vendor pays for the item, the stack is skipped automatically and shown as *below vendor* in the list.
5. Press **OK** (or Enter in the price box) to post. The addon immediately moves to the next stack and starts its search while the post goes out.
6. **Skip** moves on without posting, **Retry search** re-runs the price lookup, **Stop** ends the run.

Every post needs a real click because Blizzard protects the posting functions; the searching part is automatic.

## Scanner (MauScan tab)

1. Press **Scan auction house**. The addon asks the server for a dump of every auction (`C_AuctionHouse.ReplicateItems`). The server allows this once every 15 minutes (verified on Forever: an earlier request simply never gets an answer), so the button shows a countdown until the next one. Chat reports how long the dump took and how many entries it holds.
2. The dump is walked twice in small batches. Only a few numbers are kept per item (lowest price, listed quantity, vendor price, profit), never a table per auction, and nothing from the scan is saved to disk, so memory stays small even on a big auction house.
3. Every item is listed with its listed quantity, lowest price each and vendor price. Items that have auctions below *vendor price x quantity* come first, highlighted, with the profit of buying and vendoring those auctions in the last column. Hover a row for the details.
4. Click a row to open the item on the Buy tab (commodities open directly, gear runs a name search). Shift-click links it in chat. Buying is done through the normal Buy tab; the addon never buys anything itself.
5. Filters: "Only items below vendor price", a name filter, and "Hide deals under N copper profit". Your own auctions are never counted as deals.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauUndercut` (the project folder itself can keep any name if you link it under that name, which is how it is set up here).

Either copy it to

```
C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\MauUndercut
```

or keep it where it is and link it (edits show up in the game after `/reload`):

```powershell
New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\MauUndercut" -Target "C:\Users\Gamer\Documents\Nightfall"
```

Then enable *MauUndercut* in the AddOns list at the character screen.

`/mu` (or `/mauundercut`) jumps to the posting tab while the auction house is open, `/mu scan` to the scanner tab.

## Notes and limits

* Copper prices: the addon asks the client (`C_AuctionHouse.SupportsCopperValues()`). If the realm only allows whole silver, the undercut is raised to 1 silver automatically.
* Equipment with random suffixes ("of the Bear") is matched on the exact suffix and item level first. If no exact match is listed, the lowest similar variant is used and the panel says so.
* If nothing is listed, the price you last posted for that item is used, then vendor price x2, otherwise you type a price.
* Durations are 2, 8 or 24 hours (duration index 1, 2, 3 of the auction house API).
* Quantity defaults to everything you own of that item, not just the ticked stack, because the modern auction house pulls from all stacks. Other ticked stacks of the same item are then shown as *included* rather than posted again.
* Posting a non-stackable item with quantity above 1 creates one auction per item (Blizzard's multi-sell). The OK button waits until that batch is done.
* If Auctionator is installed, the tabs are added through its LibAHTab so all extra tabs line up next to each other.
* Settings (duration, undercut, scan filters) and the remembered prices live in `WTF\Account\<account>\SavedVariables\MauUndercut.lua`.

## Files

* `MauUndercut.toc` - addon manifest.
* `MauUndercut.lua` - helpers, saved variables, bag scanning, auction house tabs, slash command.
* `Poster.lua` - search and post state machine.
* `UI.lua` - the posting panel.
* `Scanner.lua` - full auction house dump, lowest price per item and below-vendor-price detection.
* `ScanUI.lua` - the scanner panel.
* `CLAUDE.md` - full technical and functional documentation.
