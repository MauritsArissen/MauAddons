# MauCookie

Cookie Clicker inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`). A private build for two friends; see Art below.

Type `/mck` (or `/cookie`), click the cookie on the minimap, or just take a flight: the bakery opens. Click the big cookie for cookies. Spend them in the store on the original's twenty buildings, from cursors and grandmas through prisms and chancemakers up to idleverses, cortex bakers and You, each baking cookies every second; every building you buy makes the next one of its kind 15% dearer, and you can sell them back for a quarter of the price. Buy or sell 1, 10 or 100 at a time with the buttons above the store.

The bakery keeps baking while the window is closed, as long as you are logged in. Nothing happens while you are logged out, and the timers in the game (research, pledges) only run while you are logged in too.

## Upgrades

Five upgrades per building double its output once you own 1, 5, 25, 50 and 100 of them. Mice add 1% of your production to every click. Cookie flavours add 2% to everything. Kittens turn your milk into production (4% milk per achievement). Grandma types (once you have 15 grandmas and 15 of a building) double the grandmas and give the building a cut per grandma. Synergies (behind two heavenly volumes) make pairs of buildings boost each other. Luck upgrades make golden cookies come twice as often and last twice as long. The Golden switch (heavenly) trades golden cookies for +50% production.

## Golden cookies

Every 5 to 15 minutes (halved by each luck upgrade) a golden cookie appears somewhere in the window for thirteen seconds. Effects, as in the original: Frenzy (x7 for 77 s), Lucky (15% of your bank, capped at 15 minutes of production), Click frenzy (clicks x777 for 13 s), Building special (one building you own 10+ of gets x(1 + count/10) for 30 s), Cookie chain (7, 77, 777... until it breaks or hits six hours of production) and Cookie storm (a shower of small cookies to click for seven seconds). Golden cookies wait while the window is closed, so none are missed.

## The Grandmapocalypse

Own seven grandma types and the Bingo center/Research facility appears. It unlocks a chain of ten discoveries, one every ten minutes of bakery time, each a production bonus. Three of them wake the grandmas: after One mind a third of the golden cookies turn into red wrath cookies, after Communal brainsweep two thirds, after the Elder Pact all of them. Wrath cookies bring Clot (production halved for 66 s), Ruin (lose 5% of your bank), rarely Elder frenzy (x666 for 6 s) and Cursed finger (no production for 10 s but each click gives 10 s of it), and sometimes still a Frenzy or a Lucky. While the grandmas are awake, wrinklers crawl up and attach themselves under the cookie, up to ten (twelve with Elder spice): each eats 5% of your production, and when you click one three times it bursts and gives back everything it ate times 1.1. An Elder Pledge (costing eight times more each time) calms the grandmas for 30 minutes (an hour with Sacrificial rolling pins) and bursts every wrinkler; the Elder Covenant ends it for good at the price of 5% production, and can be revoked.

## Achievements and milk

Sixty-odd achievements for cookies baked, production, clicking, buildings, golden cookies, upgrades, ascensions, wrinklers and the elders. Each one adds 1% to production and 4% milk. The Feats button lists them.

## Ascension

Once the numbers get big, the Heaven button lets you ascend: cookies, buildings and upgrades go, achievements stay, and you get heavenly chips, one per prestige level, where the prestige level is the cube root of all cookies you ever baked divided by ten billion. Every prestige level adds 1% to production forever (more with Angels, Archangels and Virtues), and chips buy nineteen heavenly upgrades that last across ascensions: production bonuses, starter buildings, golden cookie luck and duration, kitten angels, halo gloves, the two synergy volumes, the Golden switch, wrinkler perks.

## Guild board

The Guild button shows five boards: cookies baked over all runs, cookies baked this run, cookies per second, prestige level and achievements, with who is online. Every guild member who uses MauCookie sends a snapshot of their bakery over the guild addon channel (never guild chat) when something changes, at most once a minute; snapshots are kept in your saved variables and passed on, so people who are offline stay on the board. The newest snapshot always wins, which is what makes wiping or ascending safe. Sharing can be turned off in the options.

## Flying

By default the bakery opens by itself when you take a flight path or take off on a flying mount, and closes again when the flight ends if it opened itself. Each of the three behaviours is a setting.

## Art

The addon reads its images from a `Textures` folder inside the addon: the cookie, the golden and wrath cookies, the twenty building icons (plus the three angrier grandmas), the upgrade icon cells, the background, store tile, shine, milk and wrinklers, all uncompressed 32-bit TGA. That folder is **not part of this repository** and is not packed into the release zips: it is kept locally, because the images in use are the original Cookie Clicker's, which are copyrighted by their makers (Orteil / DashNet) and are only ever used privately. Without the folder the pictures are empty squares. The client only picks up new files after a full restart, not after `/reload`.

## Options

`/mck options` or Escape > Options > AddOns > MauCookie: sounds, click popups, window size, flying, minimap button, guild sharing. The Stats page has the wipe button for starting over (two clicks). Key bindings for opening the bakery and for clicking the cookie are under Options > Key Bindings > AddOns, and the bakery is in the minimap's addon compartment. The save is account wide.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauCookie`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauCookie* in the AddOns list at the character screen.

## Files

* `MauCookie.toc` - addon manifest.
* `MauCookie.lua` - settings, saved variables, helpers (number words, art paths), `/mck`, key binding names, addon compartment entry.
* `Data.lua` - buildings, upgrades, grandma types, research, synergies, kittens, heavenly upgrades, achievements, ticker lines.
* `Game.lua` - production, clicking, buying and selling, golden and wrath cookies, buffs, wrinklers, pledges, achievements, ascension, flight auto-open.
* `Comm.lua` - the guild board: snapshot exchange and relay over the addon channel.
* `UI.lua` - the window: cookie, wrinklers, store, upgrades, statistics, achievements, heaven, guild board, golden cookie, storm drops, ticker.
* `Minimap.lua` - the minimap button.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key bindings.
* `CLAUDE.md` - full technical documentation.
