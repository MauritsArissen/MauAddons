# MauCookie

Cookie Clicker inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Type `/mck` (or `/cookie`) and a bakery opens. Click the big cookie for cookies. Spend them in the store on cursors, grandmas, farms, mines, factories, banks, temples, wizard towers, shipments, alchemy labs, portals, time machines, antimatter condensers and prisms, each baking cookies every second; every building you buy makes the next one of its kind 15% dearer. Upgrades on the right double a building's output once you own enough of them, mice add a share of your production to every click, cookie flavours add 2% to everything, and two luck upgrades make golden cookies come more often.

## Golden cookies

Every few minutes a golden cookie appears somewhere in the window for thirteen seconds. Click it for a Frenzy (production x7 for 77 seconds), a Lucky windfall (15% of your bank, capped at 15 minutes of production), or, rarely, a Click Frenzy (clicks x777 for 13 seconds). Golden cookies wait while the window is closed, so none are missed.

## Achievements

Forty-odd achievements for cookies baked, production, clicking, buildings, golden cookies and upgrades. Each one adds 1% to production. The Feats button lists them; the Stats button shows the numbers and has the wipe button for starting over.

## Idle

The bakery keeps baking while the window is closed, as long as you are logged in. Time logged out is paid at half rate for up to eight hours when you log back in (can be turned off).

## Options

`/mck options` or Escape > Options > AddOns > MauCookie: sounds, click popups, offline cookies, window size. Key bindings for opening the bakery and for clicking the cookie are under Options > Key Bindings > AddOns, and the bakery is in the minimap's addon compartment. The save is account wide.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauCookie`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauCookie* in the AddOns list at the character screen.

## Files

* `MauCookie.toc` - addon manifest.
* `MauCookie.lua` - settings, saved variables, helpers (number words), `/mck`, key binding names, addon compartment entry.
* `Data.lua` - buildings, upgrades, achievements.
* `Game.lua` - production, clicking, buying, golden cookies, buffs, achievements, offline cookies.
* `UI.lua` - the window: cookie, store, upgrades, statistics and achievements, golden cookie.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key bindings.
* `CLAUDE.md` - full technical documentation.
