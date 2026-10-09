# MauCookie

Cookie Clicker inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Type `/mck` (or `/cookie`) and a bakery opens. Click the big cookie for cookies. Spend them in the store on cursors, grandmas, farms, mines, factories, banks, temples, wizard towers, shipments, alchemy labs, portals, time machines, antimatter condensers and prisms, each baking cookies every second; every building you buy makes the next one of its kind 15% dearer. Upgrades on the right double a building's output once you own enough of them, mice add a share of your production to every click, cookie flavours add 2% to everything, and two luck upgrades make golden cookies come more often.

The bakery keeps baking while the window is closed, as long as you are logged in. Nothing happens while you are logged out.

## Golden cookies

Every few minutes a golden cookie appears somewhere in the window for thirteen seconds. Click it for a Frenzy (production x7 for 77 seconds), a Lucky windfall (15% of your bank, capped at 15 minutes of production), or, rarely, a Click Frenzy (clicks x777 for 13 seconds). Golden cookies wait while the window is closed, so none are missed.

## Achievements

Forty-odd achievements for cookies baked, production, clicking, buildings, golden cookies, upgrades and ascensions. Each one adds 1% to production. The Feats button lists them.

## Ascension

Once the numbers get big, the Heaven button lets you ascend: cookies, buildings and upgrades go, achievements stay, and you get heavenly chips, one per prestige level, where the prestige level is the cube root of all cookies you ever baked divided by ten billion. Every prestige level adds 1% to production forever, and chips buy heavenly upgrades that last across ascensions: Heavenly cookies (+10%), Starter kit (10 cursors at every start), Heavenly luck (golden cookies twice as often), Starter kitchen (5 grandmas at every start), Heavenly key (+25%). The Heaven page shows what an ascension would give right now and how far the next chip is.

## Guild board

The Guild button shows five boards: cookies baked over all runs, cookies baked this run, cookies per second, prestige level and achievements, with who is online. Every guild member who uses MauCookie sends a snapshot of their bakery over the guild addon channel (never guild chat) when something changes, at most once a minute; snapshots are kept in your saved variables and passed on, so people who are offline stay on the board. The newest snapshot always wins, which is what makes wiping or ascending safe: your new, smaller numbers simply replace the old ones everywhere. Sharing can be turned off in the options.

## Art

The addon reads its images from a `Textures` folder inside the addon: `cookie` (the big cookie, 512x512), `golden` (the golden cookie, 128x128) and `building_<id>` for the fourteen buildings (64x64), as PNG, TGA or BLP. That folder is **not part of this repository** and is not packed into the release zips: it is kept locally, because the images in use are the original Cookie Clicker's, which are copyrighted by their makers (Orteil / DashNet) and are only ever used privately. Without the folder the cookie and the store icons show as empty squares; put your own images there under those names. The client only picks up new files after a full restart, not after `/reload`.

## Options

`/mck options` or Escape > Options > AddOns > MauCookie: sounds, click popups, window size, guild sharing. The Stats page has the wipe button for starting over (two clicks). Key bindings for opening the bakery and for clicking the cookie are under Options > Key Bindings > AddOns, and the bakery is in the minimap's addon compartment. The save is account wide.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauCookie`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauCookie* in the AddOns list at the character screen.

## Files

* `MauCookie.toc` - addon manifest.
* `MauCookie.lua` - settings, saved variables, helpers (number words), `/mck`, key binding names, addon compartment entry.
* `Data.lua` - buildings, upgrades, heavenly upgrades, achievements.
* `Game.lua` - production, clicking, buying, golden cookies, buffs, achievements, ascension.
* `Comm.lua` - the guild board: snapshot exchange and relay over the addon channel.
* `UI.lua` - the window: cookie, store, upgrades, statistics, achievements, heaven, guild board, golden cookie.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key bindings.
* `Textures\` - the images (see Art).
* `CLAUDE.md` - full technical documentation.
