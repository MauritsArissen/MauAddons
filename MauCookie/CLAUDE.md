# MauCookie — guide for future work

Complete reference for the MauCookie addon. Read it before changing anything. Target client, install loop, syntax check (node + luaparse) and the Blizzard source branch are the same as for MauUndercut (`../MauUndercut/CLAUDE.md` sections 2 and 3); window, options, key binding and compartment follow the MauPlinko pattern (`../MauPlinko/CLAUDE.md` section 6 lists the client facts).

## 1. What it is

A Cookie Clicker homage built 2026-10-09 on the user's request ("make a new addon, cookie clicker"). Click the cookie, buy the original's first fourteen buildings at the original prices and rates, upgrades, golden cookies with Frenzy / Lucky / Click Frenzy, achievements worth +1% production each, offline cookies. `/mck` toggles the window. The save is account wide (`MauCookieDB.save`).

## 2. Files

| File | Role |
|---|---|
| `MauCookie.toc` | Load order: MauCookie.lua, Data.lua, Game.lua, UI.lua, Options.lua. |
| `MauCookie.lua` | Namespace `NS` (`_G.MauCookie`), `NS.DEFAULTS` (`sounds`, `popups`, `offline`, `scale`), constants (`OFFLINE_RATE` 0.5, `OFFLINE_CAP` 8 h, `PRICE_GROWTH` 1.15), helpers (`Print`, `Guard`, `PlayKit`, `Clamp`, `Now`, `Commas`, `Beautify`, `BeautifyRate`, `FormatDuration`), `NewSave`, `InitDB`, events (`PLAYER_LOGIN` → `Game:Start`, `PLAYER_LOGOUT` → `Game:Save`), `/mck`, binding names, compartment function. |
| `Data.lua` | `NS.BUILDINGS` (14, with `index`, `iconPath`), `NS.UPGRADES` (5 tiers × 14 buildings, 5 mice, 12 flavours, 2 luck) and `NS.UPGRADE_BY_ID`, `NS.ACHIEVEMENTS` (`{ id, name, desc, check(save, game) }`) and `NS.ACHIEVEMENT_BY_ID`. |
| `Game.lua` | `NS.Game`: `Start` (ticker frame, offline), `Tick(dt)`, `Cps(withBuffs)`, `BuildingCps(b)`, `GlobalMult`, `ClickPower`, `Click`, `Price`/`PriceFor`/`Buy`, `IsRevealed`, `UpgradeUnlocked`/`AvailableUpgrades`/`BuyUpgrade`, golden cookies (`RollGolden`, `ClickGolden`), buffs (`AddBuff`, `BuffLeft`), `CheckAchievements`, `Offline`, `Wipe`, `Save`. |
| `UI.lua` | `NS.UI`: window `MauCookieFrame`, left panel (counter, cookie button, buffs, banner, floats), store rows, upgrade grid, overlays `stats` and `achievements`, golden cookie button, `Refresh(force)` at 10 Hz from `OnUpdate`. |
| `Options.lua` | Settings > AddOns category. |
| `Bindings.xml` | `MAUCOOKIE_TOGGLE`, `MAUCOOKIE_CLICK` (`MauCookie.Game:Click()`), category `ADDONS`; packed by `build.ps1`. |

Save (`MauCookieDB.save`): `cookies` (bank), `baked` (all time), `clicks`, `handmade`, `buildings[id] = count`, `upgrades[id] = true`, `achievements[id] = true`, `golden` (clicked), `playTime` (seconds logged in with the addon), `started`, `lastSeen` (server time, written every 5 s and at logout). Buffs are not saved.

## 3. Rules

- Production per second: Σ count × `b.cps` × 2^(tiers of that building bought) × `GlobalMult`, where `GlobalMult = (1 + 0.02 × flavours) × (1 + 0.01 × achievements)`; times 7 during Frenzy. Click power: `(2^cursorTiers + Cps(true) × 0.01 × mice) × GlobalMult`, times 777 during Click Frenzy.
- Prices: `floor(base × 1.15^owned)`; `Buy(b, n)` buys as many of n as affordable (shift-click = 10). Buildings show up to two past the highest owned (`IsRevealed`).
- Upgrades: building tier k unlocks at `TIER_OWNED[k]` = 1/5/25/50/100 owned, costs base × `TIER_COST[k]` = 10/50/500/5000/50000; mice and flavours unlock at `cost / 10` cookies baked; luck upgrades at 7 / 27 golden cookies clicked. The upgrade grid shows available ones cheapest first, 28 at most ("and N more").
- Golden cookie: next in 120–360 s divided by 2^luck, only counted down while the window is shown; shown for 13 s at a random spot in the window. Click: 8% Click Frenzy (x777 clicks, 13 s), 47% Frenzy (x7, 77 s), else Lucky (`min(bank × 0.15, cps × 900) + 13`).
- Achievements are checked once a second; unlocking prints to chat, shows a banner in the left panel and bumps `Game.version` (which also changes on purchases) so the upgrade list is rescanned; the list is also rescanned every 2 s to catch unlocks by cookies baked.
- Offline: at `Game:Start`, `away = now − lastSeen`; if ≥ 60 s and the option is on, `Cps(false) × min(away, 8 h) × 0.5` is added with a chat line. `/reload` is under 60 s so it does not pay.
- The ticker frame is never hidden, so production runs with the window closed; `Tick` caps a frame's dt at 5 s. The window's own `OnUpdate` refreshes texts at 10 Hz and animates floats, the banner and the golden cookie pulse.

## 4. Client facts

- Cookie icon: `C_Item.GetItemIconByID(17197)` (Gingerbread Cookie) with `Interface\Icons\INV_Misc_Food_19` as fallback; building icons are classic icon files (`Data.lua`). Icons are rounded with the `TempPortraitAlphaMask` mask (same as MauGuildMap / MauPlinko), including the cookie button's highlight texture.
- `Texture:SetDesaturated(true)` greys out unaffordable store icons and upgrades.
- Numbers are doubles; `Beautify` uses words from million to duodecillion (`math.log10`), `Commas` for below a million.

## 5. How to verify

1. Syntax: node + luaparse over every `.lua`.
2. `/mck`: the window shows 0 cookies, the cookie, Cursor and Grandma in the store (grey). Click the cookie: +1 float, counter rises, click sound. Buy a cursor at 15: counter drops, owned shows 1, production 0.1/s, the counter creeps. Shift-click buys up to 10.
3. Own 1 cursor: "Reinforced index finger" appears in the upgrades grid (grey until 150 cookies); buying it doubles cursor output and the click.
4. Close the window, wait, reopen: cookies kept coming. `/reload`: no offline line (under a minute). Log out for a few minutes: an "away" chat line with half-rate cookies.
5. Golden cookie: wait 2–6 minutes with the window open; it appears, pulses, and clicking gives a banner with the effect; Frenzy shows under the cookie with a countdown and the per-second number is x7.
6. Stats and Feats overlays; Wipe save needs two clicks; achievements print and add 1% each (Stats shows the percentage).
