# MauCookie

Cookie Clicker inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`). A private build for two friends; see Art below.

Version 0.5.0 is a rebuild that follows the original (Orteil / DashNet, version 2.052) as closely as the game allows: the same twenty buildings, the same 880-odd upgrades and 640-odd achievements with their texts and icons, the same production, price, golden cookie, wrinkler, sugar lump, Santa, dragon, season and ascension rules, and the original's three-column layout with its art.

Type `/mck` (or `/cookie`), click the cookie on the minimap, or just take a flight: the bakery opens. Click the big cookie for cookies. Spend them in the store on buildings that bake cookies every second; every building you buy makes the next one of its kind 15% dearer, and you can sell them back for a quarter of the price. Buy or sell 1, 10, 100 or as many as you can afford with the buttons above the buildings.

The bakery keeps baking while the window is closed, as long as you are logged in. Nothing happens while you are logged out; research, pledges, seasons and buffs only run while you are logged in too. Sugar lumps ripen on real time like the original, and the ones that fell while you were away are harvested when you log in.

## The window

- **Left**: your bakery's name, the cookie count and production, the big cookie, your running buffs at the top right with their timers, the wrinklers crawling up during the Grandmapocalypse, the milk rising with your achievements, and the Santa and dragon tabs at the bottom once you have them.
- **Middle**: the Options, Stats, Info, Legacy and Guild buttons (the sugar lump sits under Stats once lumps start), the news ticker (click a fortune to claim it), and a row per building you own, filled with as many of them as fit.
- **Right**: the upgrades you can buy, in sections (Upgrades, Switches, Research, Vault), then the buildings. Hover anything for the original's description, flavour text and price.

## Upgrades and achievements

Fifteen tiers per building, mice, cookie flavours, kittens, grandma types, research, synergies, seasonal drops, dragon drops, garden drops: all of them, with the original's unlock conditions. Every achievement in the normal pool gives 4% milk, which kittens turn into production; shadow achievements are listed too. The Stats page shows what you own.

## Golden cookies and friends

Golden cookies appear every 5 to 15 minutes while the window is open (never while it is closed, so none are missed), stay for thirteen seconds and bring Frenzy, Lucky, Click frenzy, building specials, cookie chains, cookie storms, and with the dragon, Dragon harvest and Dragonflight. Once the grandmas are awake, wrath cookies bring Clot, Ruin, Elder frenzy and the Cursed finger instead; wrinklers eat a twentieth of your production each and give it back with interest when you burst them; the Elder Pledge and the Elder Covenant are in the store's Switches. Reindeer cross the window at Christmas, eggs drop at Easter, heart biscuits come on Valentine's day, the buildings become business ventures on Business day, and Halloween cookies drop from wrinklers; the Season switcher heavenly upgrade lets you start any season.

## Sugar lumps, Santa, the dragon

Once you have baked a billion cookies in total, a sugar lump starts growing under the Stats button: mature after 20 hours, ripe after 23, falling after 24 (real time). Lumps level up buildings (+1% each) and buy a few switches.

## Minigames

Level 1 of a building opens its minigame from the button on its store row, in the building's row in the middle: the **Garden** (farms: a plot that grows with the farm level, 34 plants that mature, spread and mutate into new seeds, soils, passive effects, harvest drops), the **Stock market** (banks: eighteen goods whose prices drift every minute, brokers, five office levels paid in cursors, loans), the **Pantheon** (temples: eleven spirits in three slots with weaker effects the lower the slot, three worship swaps) and the **Grimoire** (wizard towers: a magic meter and nine spells that may backfire). The minigames follow the original's rules and tick on bakery time. A festive hat (Christmas) brings Santa, who evolves fourteen times for presents; a crumbly egg (after the heavenly upgrade How to bake your dragon) brings Krumblor, who trains on cookies and buildings and grants auras.

## Ascension

The Legacy button shows the heavenly tree. Once you have baked a trillion cookies, ascending turns them into prestige levels (the cube root of all cookies forfeited divided by a trillion) and the same number of heavenly chips. Every prestige level adds 1% to production, unlocked step by step by the Heavenly chip secret, cookie stand, bakery, confectionery and key. Chips buy the original's heavenly upgrades (each needs its parents first): permanent upgrade slots, starter kits, luck, kittens, seasons, the Golden switch, the dragon, sugar lump perks, synergy volumes, unshackling, and so on. Reincarnate starts the new run.

## Guild board

The Guild button shows five boards: cookies baked over all runs, cookies baked this run, cookies per second, prestige level and achievements, with who is online. Every guild member who uses MauCookie sends a snapshot of their bakery over the guild addon channel (never guild chat) when something changes, at most once a minute; snapshots are kept in your saved variables and passed on, so people who are offline stay on the board. The newest snapshot always wins, which is what makes wiping or ascending safe. Sharing can be turned off in the options.

## Flying

By default the bakery opens by itself when you take a flight path or take off on a flying mount, and closes again when the flight ends if it opened itself. Each of the three behaviours is a setting.

## Art

The addon reads its images from a `Textures` folder inside the addon (the cookie, the icon sheet, the buildings sheet, the row backgrounds and sprites, milks, backgrounds, frames, Santa and the dragon, the heavenly sky...), all uncompressed 32-bit TGA. That folder is **not part of this repository** and is not packed into the release zips: it is kept locally, because the images are the original Cookie Clicker's, which are copyrighted by their makers (Orteil / DashNet) and are only ever used privately. `tools/convert-art.ps1` builds the folder from the original image files and writes `Art.lua` (sizes only). Without the folder the pictures are empty squares. The client only picks up new files after a full restart, not after `/reload`.

## Options

The Options button in the window, `/mck options`, or Escape > Options > AddOns > MauCookie: sounds, click popups, fancy graphics, short numbers, window size, flying, minimap button, guild sharing, and the wipe button (asks twice). Key bindings for opening the bakery and for clicking the cookie are under Options > Key Bindings > AddOns, and the bakery is in the minimap's addon compartment. The save is account wide; a 0.4.0 save is carried over on first load (prestige recomputed with the original's formula, chips refunded).

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauCookie`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauCookie* in the AddOns list at the character screen.

## Files

* `MauCookie.toc` - addon manifest.
* `MauCookie.lua` - settings, saved variables and the 0.4.0 migration, helpers, `/mck`, key binding names, addon compartment entry.
* `Art.lua` - sizes of the local textures (generated).
* `Data_Buildings.lua`, `Data_Upgrades.lua`, `Data_Achievements.lua`, `Data_Misc.lua` - the original's data, generated by `tools/extract.js` and `tools/gen-lua.js`.
* `Data_Extra.lua`, `Data_Ticker.lua` - milks, backgrounds, Business day names, buff names, ticker lines.
* `Index.lua` - lookups by name over the data.
* `Game.lua` - production, clicking, prices, buying and selling, unlocks, achievements, research, seasons, the tick.
* `Buffs.lua`, `Shimmers.lua`, `Wrinklers.lua`, `Lumps.lua`, `Specials.lua`, `Ascend.lua`, `Ticker.lua` - buffs, golden cookies and reindeer, wrinklers, sugar lumps, Santa and the dragon and fortunes, ascension, the news ticker.
* `Comm.lua` - the guild board: snapshot exchange and relay over the addon channel.
* `UI.lua`, `UI_Store.lua`, `UI_Rows.lua`, `UI_Menus.lua`, `UI_Ascend.lua` - the window.
* `Minigames.lua`, `Minigame_Garden.lua`, `Minigame_Market.lua`, `Minigame_Pantheon.lua`, `Minigame_Grimoire.lua` - the four minigames.
* `Minimap.lua` - the minimap button.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key bindings.
* `tools/` - the data generator, the art converter and the syntax checker.
* `CLAUDE.md` - full technical documentation.
