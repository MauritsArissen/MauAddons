# MauLootbox

Every loot window becomes a lootbox, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

When you loot a corpse, a chest, a clam or anything else, Blizzard's loot window stays closed. Instead a window with one slot machine reel per item appears, side by side: icons scroll past, slow down and stop on the item you got, with a flash, the name in its quality colour and a sound, and the item goes into your bags the moment its reel stops. The reels start one after the other with a growing delay, so they land in a cascade. Coins are taken straight away.

## How looting works with it

* The game's own auto-loot option is switched off while the addon is enabled, because with it on the client takes everything the instant the window opens and nothing can delay that. The addon does the auto-looting itself: you never click an item, it just arrives after the reel stops.
* Shift-clicking a corpse still triggers the game's instant auto-loot; the reel then plays as a reveal of what you already got.
* **Take all** skips the rest of the show and takes everything at once. The close button leaves the rest on the corpse, like closing the normal window.
* Anything that could not be taken, because your bags are full or because it is not yours to take in a group, is listed afterwards; click an item to take it.
* Bind-on-pickup items are confirmed for you when you are not in a group. In a group the normal confirmation dialog appears.
* Walking away closes the loot as usual and ends the show.

## Options

`/mlb` opens the addon's page in the game's options (Escape > Options > AddOns > MauLootbox):

* Replace the loot window with the lootbox (off restores Blizzard's window and your previous auto-loot setting).
* Spin for items of at least a given quality; everything below is taken without a spin. The default is Poor, so everything spins.
* Take coins without a spin.
* Spin length, sounds, bind-on-pickup confirmation when solo.
* Reels: the delay before the second reel starts, how much longer each further gap is (0.2 and 0.1 give gaps of 0.2, 0.3, 0.4 seconds), and how many reels sit in a row before wrapping.
* Window size. Drag the window to move it; the position is remembered.

`/mlb test` plays a demo with five made-up items of every quality without touching any real loot.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauLootbox`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauLootbox* in the AddOns list at the character screen.

## Files

* `MauLootbox.toc` - addon manifest.
* `MauLootbox.lua` - settings, helpers, the takeover of Blizzard's loot window and the auto-loot option, `/mlb`.
* `Reel.lua` - the slot machine window and its animation.
* `Loot.lua` - loot events, taking items, leftovers.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Test.lua` - `/mlb test`.
* `CLAUDE.md` - full technical documentation.
