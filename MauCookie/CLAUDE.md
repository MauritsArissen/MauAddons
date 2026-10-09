# MauCookie — guide for future work

Complete reference for the MauCookie addon. Read it before changing anything. Target client, install loop, syntax check (node + luaparse) and the Blizzard source branch are the same as for MauUndercut (`../MauUndercut/CLAUDE.md` sections 2 and 3); window, options, key binding and compartment follow the MauPlinko pattern (`../MauPlinko/CLAUDE.md` section 6 lists the client facts).

## 1. What it is

A Cookie Clicker homage built 2026-10-09 on the user's request. Click the cookie, buy the original's first fourteen buildings at the original prices and rates, upgrades, golden cookies with Frenzy / Lucky / Click Frenzy, achievements worth +1% production each, ascension for heavenly chips with a small heavenly shop (0.2.0), a guild board with five leaderboards (0.2.0), optional user-supplied art (0.2.0). `/mck` toggles the window. The save is account wide (`MauCookieDB.save`). **No offline production**: the user explicitly does not want cookies for time logged out (0.1.0 had it, 0.2.0 removed it); the bakery runs only while logged in, window open or not.

## 2. Files

| File | Role |
|---|---|
| `MauCookie.toc` | Load order: MauCookie.lua, Data.lua, Game.lua, Comm.lua, UI.lua, Options.lua. |
| `MauCookie.lua` | Namespace `NS` (`_G.MauCookie`), `NS.DEFAULTS` (`sounds`, `popups`, `shareScores`, `scale`), constants (`PRICE_GROWTH` 1.15, `PRESTIGE_BASE` 1e10, `ART_ROOT`), helpers (`Print`, `Guard`, `PlayKit`, `Clamp`, `Now`, `Commas`, `Beautify`, `BeautifyRate`, `FormatDuration`, `ShortName`, `ClassColor`, `Art`), `NewSave`, `InitDB`, events (`PLAYER_LOGIN` → `Game:Start`, `Comm:Start`), `/mck`, binding names, compartment function. |
| `Data.lua` | `NS.BUILDINGS` (14), `NS.UPGRADES` (5 tiers × 14, 5 mice, 12 flavours, 2 luck), `NS.HEAVENLY` (5), `NS.ACHIEVEMENTS` (46: baked, cps, handmade, buildings, grandmas/cursors, golden, upgrades, ascensions) with lookup tables. |
| `Game.lua` | `NS.Game`: `Start` (ticker), `Tick(dt)`, `Cps`, `BuildingCps`, `GlobalMult`, `ClickPower`, `Click`, `Price`/`PriceFor`/`Buy`, `IsRevealed`, upgrades, `Changed` (version bump, UI refresh, Comm), ascension (`PrestigeFor`, `AscendPreview`, `CookiesToNextChip`, `Ascend`, `BuyHeavenly`), golden cookies, buffs, `CheckAchievements`, `Wipe`. |
| `Comm.lua` | `NS.Comm`: the guild board (section 5), `NS.BOARDS`. |
| `UI.lua` | `NS.UI`: window `MauCookieFrame`, left panel, store rows, upgrade grid, four buttons, overlays `stats`, `achievements`, `heaven`, `guild`, golden cookie, `ApplyArt`, `Refresh(force)` at 10 Hz. |
| `Options.lua` | Settings > AddOns category. |
| `Bindings.xml` | `MAUCOOKIE_TOGGLE`, `MAUCOOKIE_CLICK`; packed by `build.ps1`. |

Save (`MauCookieDB.save`): `cookies`, `baked` (this run), `clicks`, `handmade`, `buildings[id]`, `upgrades[id]`, `achievements[id]`, `golden`, `playTime`, `started`, `prestige`, `chips` (unspent), `heavenly[id]`, `allTime` (cookies baked in previous runs; `Game:AllTime()` adds the current run), `ascensions`. `MauCookieDB.guild[guildName][playerName]` holds snapshots. Buffs are not saved.

## 3. Rules

- Production per second: Σ count × `b.cps` × 2^(tiers bought) × `GlobalMult`, with `GlobalMult = (1 + 0.02 × flavours) × (1 + 0.01 × achievements) × (1 + 0.01 × prestige) × 1.1 if Heavenly cookies × 1.25 if Heavenly key`; times 7 during Frenzy. Click power: `(2^cursorTiers + Cps(true) × 0.01 × mice) × GlobalMult`, times 777 during Click Frenzy.
- Prices `floor(base × 1.15^owned)`; `Buy(b, n)` buys as many as affordable (shift = 10). Buildings show two past the highest owned.
- Upgrades: building tier k at 1/5/25/50/100 owned, cost base × 10/50/500/5000/50000; mice and flavours at `cost / 10` baked this run; luck at 7 / 27 golden clicks. Grid shows available ones cheapest first, 28 max.
- Golden cookie: next in 120–360 s ÷ 2^(luck upgrades + Heavenly luck), counted only while the window is shown, 13 s on screen. 8% Click Frenzy, 47% Frenzy, else Lucky `min(bank × 0.15, cps × 900) + 13`.
- Ascension: prestige level = `floor((allTime / 1e10)^(1/3))`; `Ascend` requires at least one new chip, moves `baked` into `allTime`, sets `prestige`, adds the chips, resets cookies/buildings/upgrades, applies starter kits, bumps `ascensions`. Heavenly upgrades cost chips and persist. `Wipe` resets everything including prestige and heavenly upgrades.
- `Game:Changed()` is the single hook after purchases, achievements, ascension and wipe: bumps `version` (upgrade grid rescan), refreshes the window, tells Comm.
- The ticker frame is never hidden; `Tick` caps dt at 5 s, checks achievements once a second. No logout/login accounting at all.

## 4. Art

`UI:ApplyArt` sets the cookie, golden cookie and store icons (and the building upgrades' icons in `Refresh`) from `Interface\AddOns\MauCookie\Textures\<key>.tga` (`cookie` 512×512, `golden` 128×128, `building_<id>` 64×64; uncompressed 32-bit TGA written bottom-up with an 8-bit alpha descriptor, files are indexed at client start). 0.2.2 used PNG files with extension-less paths and nothing showed: an extension-less path only resolves to .blp/.tga, so 0.2.3 switched to TGA (converted with LockBits + a hand-written 18-byte header in PowerShell). On the user's machine those files were cut from the original game's `perfectCookie.png`, `goldCookie.png` and `buildings.png` (sheet: column 0 is the plain icon, 64 px rows, row 0 Cursor, row 1 Grandma, row 2 grandma faces, rows 3–14 Farm to Prism) with System.Drawing in PowerShell on 2026-10-09, for private play with one friend. That art is copyrighted (Orteil / DashNet), so **the `Textures` folder is git-ignored and `build.ps1` does not pack it**: the repository and the zips never contain it, the user copies the folder by hand where it is wanted. Without the folder the cookie and the store icons are empty squares. Mice, flavours and luck upgrades still use classic icon files. The 0.2.0 "customArt" option and the item-icon fallback were removed in 0.2.2.

## 5. Guild board (`Comm.lua`)

- A snapshot `{ name, class, ts, prestige, allTime, run, cps, buildings, feats, golden, ascensions }` stamped with the owner's server time; **newest ts wins outright** (`Merge`), because wipes and ascensions make numbers shrink (MauPeggle's max-merge would not work here). Relays carry the owner's ts. Own name in a received record is ignored.
- Wire: `S:<token>:<name>:<class>:<ts>:<prestige>:<allTime>:<run>:<cps>:<buildings>:<feats>:<golden>:<ascensions>` (one message; big numbers as `%.6g`, parsed with `tonumber`, split with `strsplit`), `I:<token>:<name>=<ts>,…`, `Q:<token>:<name>,…` (chunked at 235 bytes). Queue drained one per 0.25 s from the frame's OnTick (0.2 s accumulator).
- When: `SendOwn` on `Game:Changed` coalesced to one per 10 s, and once a minute if `Signature` (3-significant-digit numbers) changed; `Announce` (own + inventory) 8 s after `PLAYER_ENTERING_WORLD`, 5 s after a guild change, when sharing is switched on; inventory on board open (≥ 5 min apart) and every 15 min if dirty. Inventory handling, requests, jitter and suppression are the same as MauPeggle's (`../MauPeggle/CLAUDE.md` section 8).
- Online: roster from `GetGuildRosterInfo` on `GUILD_ROSTER_UPDATE` (refreshed via `C_GuildInfo.GuildRoster()`), `seen` for "bakery running". `Board(key)` sorts by the board's field, then `allTime`, then name; `NS.BOARDS` lists the five boards (allTime, run, cps, prestige, feats).

## 6. How to verify

1. Syntax: node + luaparse over every `.lua`.
2. `/mck`: counter, cookie, Cursor and Grandma grey. Click: +1 float and sound. Buy a cursor; shift-click buys ten; upgrades appear at 1 / 5 / 25 cursors.
3. Close the window, wait, reopen: cookies kept coming. Log out and back in: no "away" cookies and no chat line.
4. Golden cookie within 2–6 minutes with the window open; Frenzy countdown under the cookie.
5. Heaven: with under 1e10 all-time cookies it shows how many more are needed and Ascend is disabled; at 1e10 "+1 chip", two clicks ascend, the store is empty again, prestige 1 shows under the cookie and production is +1%; buy Heavenly cookies with 3 chips (after 2.7e11 all time) and see +10%.
6. Stats: 17 lines including prestige, chips, ascensions, all runs. Wipe needs two clicks and zeroes everything.
7. Guild board with another member: their bakery appears within a minute of their first purchase, tabs switch the ordering, tooltips show everything, online/offline marks. Wipe on one side: the other sees the zeroed snapshot after the next send.
8. Art: the big cookie, the golden cookie and the store icons are the Cookie Clicker images; an empty square means the client was started before the file existed (full restart) or the file is missing.
