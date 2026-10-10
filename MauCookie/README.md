# MauCookie

Cookie Clicker inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`). A private build for two friends; see Art below.

Type `/mck` (or `/cookie`), click the cookie on the minimap, or just take a flight: the bakery opens. Click the big cookie for cookies. Spend them in the store on the original's twenty buildings, from cursors and grandmas through prisms and chancemakers up to idleverses, cortex bakers and You, each baking cookies every second; every building you buy makes the next one of its kind 15% dearer. Upgrades on the right double a building's output once you own enough of them, mice add a share of your production to every click, cookie flavours add 2% to everything, kittens turn your milk into production, and luck upgrades make golden cookies come more often and last longer.

The bakery keeps baking while the window is closed, as long as you are logged in. Nothing happens while you are logged out.

## Golden cookies

Every few minutes a golden cookie appears somewhere in the window for thirteen seconds. Click it for a Frenzy (production x7 for 77 seconds), a Lucky windfall (15% of your bank, capped at 15 minutes of production), or, rarely, a Click Frenzy (clicks x777 for 13 seconds). Golden cookies wait while the window is closed, so none are missed.

## Achievements and milk

Fifty-odd achievements for cookies baked, production, clicking, buildings, golden cookies, upgrades and ascensions. Each one adds 1% to production and 4% milk; the eight kitten upgrades multiply production by (1 + milk x factor) each. The Feats button lists them.

## Ascension

Once the numbers get big, the Heaven button lets you ascend: cookies, buildings and upgrades go, achievements stay, and you get heavenly chips, one per prestige level, where the prestige level is the cube root of all cookies you ever baked divided by ten billion. Every prestige level adds 1% to production forever, and chips buy heavenly upgrades that last across ascensions: Heavenly cookies (+10%), Starter kit (10 cursors at every start), Heavenly luck (golden cookies twice as often), Starter kitchen (5 grandmas at every start), Heavenly key (+25%).

## Guild board

The Guild button shows five boards: cookies baked over all runs, cookies baked this run, cookies per second, prestige level and achievements, with who is online. Every guild member who uses MauCookie sends a snapshot of their bakery over the guild addon channel (never guild chat) when something changes, at most once a minute; snapshots are kept in your saved variables and passed on, so people who are offline stay on the board. The newest snapshot always wins, which is what makes wiping or ascending safe. Sharing can be turned off in the options.

## Flying

By default the bakery opens by itself when you take a flight path or take off on a flying mount, and closes again when the flight ends if it opened itself. Each of the three behaviours is a setting.

## Art

The addon reads its images from a `Textures` folder inside the addon: `cookie.tga` (512x512), `golden.tga` (128x128), `building_<id>.tga` for the twenty buildings (64x64), `icon_<col>_<row>.tga` for upgrades and heavenly upgrades (48x48 cells padded to 64x64), `bgBlue.tga`, `storeTile.tga`, `shine.tga` and `milk.tga`, all uncompressed 32-bit TGA. That folder is **not part of this repository** and is not packed into the release zips: it is kept locally, because the images in use are the original Cookie Clicker's, which are copyrighted by their makers (Orteil / DashNet) and are only ever used privately. Without the folder the pictures are empty squares. The client only picks up new files after a full restart, not after `/reload`.

## Options

`/mck options` or Escape > Options > AddOns > MauCookie: sounds, click popups, window size, flying, minimap button, guild sharing. The Stats page has the wipe button for starting over (two clicks). Key bindings for opening the bakery and for clicking the cookie are under Options > Key Bindings > AddOns, and the bakery is in the minimap's addon compartment. The save is account wide.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauCookie`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauCookie* in the AddOns list at the character screen.

## Files

* `MauCookie.toc` - addon manifest.
* `MauCookie.lua` - settings, saved variables, helpers (number words, art paths), `/mck`, key binding names, addon compartment entry.
* `Data.lua` - buildings, upgrades, kittens, heavenly upgrades, achievements.
* `Game.lua` - production, clicking, buying, golden cookies, buffs, achievements, ascension, flight auto-open.
* `Comm.lua` - the guild board: snapshot exchange and relay over the addon channel.
* `UI.lua` - the window: cookie, store, upgrades, statistics, achievements, heaven, guild board, golden cookie.
* `Minimap.lua` - the minimap button.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key bindings.
* `CLAUDE.md` - full technical documentation.
