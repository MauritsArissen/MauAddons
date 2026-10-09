# MauPlinko — guide for future work

Complete reference for the MauPlinko addon. Read it before changing anything. Target client, install loop, syntax check (node + luaparse) and the Blizzard source branch (`Gethe/wow-ui-source`, branch `forever`) are the same as for MauUndercut; see `../MauUndercut/CLAUDE.md` sections 2 and 3.

## 1. What it is

A Plinko game played for made-up chips, built 2026-10-09 on the user's request ("allow playing plinko in-game for whenever I am bored, make something great out of this"). `/mpk` toggles a window with a peg board (8–16 rows), bet / risk / rows controls, a Drop button and auto mode, a side panel with the last drops, statistics and a guild leaderboard. Payout tables follow the well known online version of the game (edges pay big, middle pays little, about 99% return). Chips are account wide (`MauPlinkoDB` is not per character), start at 1,000 and can be topped up for free when below the minimum bet; the top-up count is shown in the statistics.

## 2. Files

| File | Role |
|---|---|
| `MauPlinko.toc` | Load order: MauPlinko.lua, Tables.lua, Game.lua, Board.lua, UI.lua, Comm.lua, Options.lua. `## IconTexture` and `## AddonCompartmentFunc: MauPlinko_OnAddonCompartmentClick` put it in the minimap's addon compartment. |
| `MauPlinko.lua` | Namespace `NS` (also `_G.MauPlinko`, which `Bindings.xml` uses), constants (`START_BALANCE` 1000, `TOP_UP` 1000, `MIN_BET` 10, `MAX_BET` 1e6, `MAX_BALLS` 40, `HISTORY_SIZE` 12), `NS.DEFAULTS` / `NS.RANGES` / `NS.GAME_DEFAULTS`, helpers (`Print`, `Guard`, `PlayKit`, `Round`, `Commas`, `Signed`, `FormatMult`, `FormatPercent`, `ShortName`, `ClassColor`, `NewStats`), `InitDB`, events, `/mpk`, `BINDING_*` strings, compartment function. |
| `Tables.lua` | `NS.TABLES[risk][rows]` (rows + 1 multipliers, symmetric), `GetMultipliers`, `Binomial`, `BucketProbability`, `RTP`, `BucketColor` (yellow centre to red edges by position), `TierColor` (text colour by multiplier). |
| `Game.lua` | `NS.Game`: bank and rules. `Drop` (deducts the bet, flips one coin per row, hands the ball to the board), `OnLanded` (pays `Round(bet × mult)`, records stats and history, celebrates, announces, pokes Comm), `SetBet/SetRisk/SetRows`, auto mode (`StartAuto/AutoTick/StopAuto`, `C_Timer.NewTicker`), `TopUp`, `ResetStats`, `ResetBank`, `SettleAll`, `MaybeAnnounce`. |
| `Board.lua` | `NS.Board`: fixed 420×430 frame, `Build(rows, risk)` lays out pegs and buckets, `Launch(ball)` computes the peg-to-peg nodes, one `OnUpdate` animates balls, peg flashes, bucket dips, floating texts and the board flash. `Celebrate`, `SettleAll`, bucket tooltip. |
| `UI.lua` | `NS.UI`: window `MauPlinkoFrame` (BackdropTemplate, movable, position in `MauPlinkoDB.position`, scale option), controls, side tabs (Last drops / Stats / Guild), `Refresh*`, `Confirm` (second click within 4 s), `Show/Hide/Toggle`. |
| `Comm.lua` | `NS.Comm`: guild addon channel, prefix `MauPlinko`, score exchange, `SortedScores` for the Guild tab. |
| `Options.lua` | `NS.Options`: Settings > AddOns category (same helpers as MauLootbox). |
| `Bindings.xml` | `MAUPLINKO_TOGGLE` → `MauPlinko.UI:Toggle()`, `MAUPLINKO_DROP` → `MauPlinko.Game:DropFromBinding()`, category `ADDONS`. Not listed in the TOC (the game loads it by name); `build.ps1` copies it explicitly. |

Saved variables (`MauPlinkoDB`): `settings` (see `NS.DEFAULTS`: `sounds`, `pegSounds`, `speed` 50–200 %, `autoDelay` 0.1–1 s, `scale` 60–150 %, `shareScores`, `announceGuild` false, `announceFrom` 10–1000), `game` (`bet`, `risk`, `rows`, `autoCount`; where the player left the controls), `bank` (`balance`, `topUps`), `stats` (`NewStats` shape: `drops`, `wagered`, `returned`, `bestMult/-Rows/-Risk`, `bestWin/-Bet/-Mult`, `hist[rows][bucket]`), `history` (newest first, `{m, win, bet, k, rows, risk}`), `position`. `Game.session` is a second `NewStats` in memory.

## 3. The game model

- A ball through N rows bounces N times, left or right with equal chance (`math.random(0, 1)` per row in `Game:Drop`), and lands in bucket k = number of rights (0..N). Bucket probabilities are binomial, so the tables pay little in the middle and much at the edges. Every table in `Tables.lua` returns 98.9–99.2%; `scratchpad\check-tables.js` (node) recomputes that from the file and checks symmetry and counts, run it after touching a table.
- The bet leaves the bank at the drop; the win arrives when the board reports the landing (`Game:OnLanded(ball, animated)`). Closing the window or logging out settles every ball in the air without animation (`SettleAll` from `UI:OnHide` and `PLAYER_LOGOUT`), so nothing is ever lost or double paid. Rows and risk are locked while `Game.inFlight > 0`.
- Payout is `Round(bet × mult)`; with the minimum bet 10 and one-decimal multipliers this is exact, and rounding also hides float noise like `0.7 × 10 = 7.000000000000001`.
- Auto mode: ticker at `settings.autoDelay`; stops when the count is reached (0 = endless), the bank cannot afford the minimum bet, or Stop. When `MAX_BALLS` are in the air it waits a tick. A bet above the balance is lowered to the balance with a chat line.
- Top-up only when `balance < MIN_BET`; `bank.topUps` counts them. Reset bank → 1,000 and zero top-ups; Reset stats clears all-time, session and history.

## 4. The board (`Board.lua`)

- Geometry in `Build`: spacing `s = min((W − 24) / (rows + 2), (H − 60) / (rows + 1.6))`, row height `0.9 s`, peg radius `max(2.2, 0.11 s)`, ball radius `max(4.5, 0.27 s)`, bucket height `clamp(0.75 s, 18, 28)`. Row r has r + 2 pegs at `x = (j − (r + 1) / 2) s`; bucket k is at `x = (k − rows / 2) s`, width `s − 3`. Everything is anchored to the board's `TOP` with y ≤ 0.
- `Launch`: node 0 is above the top peg; node r (1..rows) is on peg `right + 1` of row r at `x = (right − (r − 1) / 2) s`, where `right` counts the rights so far; node rows + 1 is the bucket. Segment i (node i → i + 1) takes `FIRST_STEP` 0.22 s, `STEP` 0.14 s or `LAST_STEP` 0.2 s divided by `speed / 100`; position `x` linear, `y = ya + (yb − ya) t² + hop · sin(πt)` with `hop = 0.3 rowH` from the second segment on. Reaching a node flashes that peg (`FlashPeg`, bigger and golden, decays over 0.3 s) and ticks (`PegSound`, rate limited to one per 0.05 s).
- Landing: bucket dips 8 px and brightens (`bounce` decays over 0.28 s), `Game:OnLanded`, then `Celebrate`: landing sound by tier (`LandingSound`, rate limited), floating text (`Float`) for ≥ 5x rising 45 px over 1.4 s, board flash for ≥ 100x.
- Circles are `WHITE8X8` textures behind a `MaskTexture` of `Interface\CharacterFrame\TempPortraitAlphaMask` (the MauGuildMap pin trick). 16 rows = 168 pegs; balls are pooled frames with a body and a shine, colours cycle through `BALL_COLORS`.
- `OnUpdate` only runs while the window is shown, which is why hiding settles the balls.

## 5. Comm (`Comm.lua`)

Prefix `MauPlinko`, channel `GUILD`. `S:<token>:<class>:<bestMult>:<bestWin>:<drops>:<net>` is a score, `Q:<token>` asks everyone for theirs. The token (random per session) and the player name filter our own echo. A score goes out 5 s after `PLAYER_ENTERING_WORLD`, on `PLAYER_GUILD_UPDATE`, in answer to a Q (0.5–2.5 s jitter), and after a drop changed it, coalesced to at most one every 15 s (`OnScoreChanged` / `SendScore`); nothing is sent with zero drops, when `shareScores` is off or outside a guild. `Ask` at most once a minute (window open, login). `Comm.scores[name]` is session only; `SortedScores` adds the player and sorts by best hit, then net. Guild chat announcements (`Game:MaybeAnnounce`) use `SendChatMessage(msg, "GUILD")` in a pcall; the API is marked `HasRestrictions` in the docs but guild chat has never needed a hardware event (DBM posts to raid chat from timers the same way). If it ever errors, the option simply does nothing.

## 6. Client facts used (verified in the `forever` branch)

- `StaticPopup_Show` no longer exists on this client (dialogs are `GameDialog` in `Blizzard_StaticPopup_Game`), which is why the reset buttons confirm with a second click instead of a popup.
- `UISpecialFrames` could not be found anywhere in the branch; the insert is guarded, so Escape may or may not close the window.
- Key bindings (`Blizzard_SettingsDefinitions_Frame/Keybindings.lua`): the `category` attribute names the section; `_G[category]` is used as the display name if it is a string, so `category="ADDONS"` shows under "AddOns". Names come from `BINDING_NAME_<name>` globals.
- Addon compartment (`Blizzard_Minimap/Mainline/AddonCompartment.lua`): `## AddonCompartmentFunc` is called as `_G[func](addonName, buttonName)`; the icon comes from `## IconTexture`.
- Templates used: `BackdropTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, `InputBoxTemplate` (all in `Blizzard_SharedXML`). Sound kits used: `IG_MAINMENU_OPTION_CHECKBOX_ON/OFF`, `IG_BACKPACK_COIN_OK`, `UI_RAID_LOOT_TOAST_LESSER_ITEM_WON`, `UI_EPICLOOT_TOAST`, `UI_LEGENDARY_LOOT_TOAST`, `LOOT_WINDOW_COIN_SOUND` (all in `SoundKitConstants.lua`), guarded with `SOUNDKIT[key]`.
- `C_ClassColor.GetClassColor` with `RAID_CLASS_COLORS` fallback for the guild list.

## 7. How to verify

1. Syntax: node + luaparse over every `.lua`; `node scratchpad\check-tables.js MauPlinko\Tables.lua` for the payout tables.
2. `/mpk`: the board shows 12 rows, 13 buckets with multipliers, 1,000 chips, bet 10. Drop: a ball falls, pegs flash, it lands, the bucket dips, chips change by the right amount, the Last drops tab gets a row. Change rows 8 and 16: the board relayouts and stays inside the frame; buckets are readable at 16 rows. Change risk: labels change, colours stay. Drop several balls quickly: each lands independently; rows/risk buttons are disabled meanwhile and come back.
3. Auto drop 25 at 0.3 s: a stream of balls; Stop halts it; closing the window mid-stream pays out everything at once (balance correct, "in the air" back to 0).
4. Bet larger than the bank: lowered with a chat line. Bank below 10: Drop disabled, Top up appears, click adds 1,000 and the statistics count it.
5. Stats tab: numbers add up (returned − wagered = net, return rate near 99% after many drops). Reset buttons need two clicks.
6. Guild tab with another member running the addon: both appear after a drop; `/reload` on one side re-populates within a few seconds (Q on login). With sharing off the note says so.
7. Options: speed, interval, sounds, scale, sharing, announcement. Key bindings under AddOns. Compartment entry opens the board.
