# MauPeggle — guide for future work

Complete reference for the MauPeggle addon. Read it before changing anything. Target client, install loop, syntax check (node + luaparse) and the Blizzard source branch (`Gethe/wow-ui-source`, branch `forever`) are the same as for MauUndercut; see `../MauUndercut/CLAUDE.md` sections 2 and 3. Window, options and key binding follow the MauPlinko pattern (`../MauPlinko/CLAUDE.md` section 6 lists the client facts: no `StaticPopup`, guarded `UISpecialFrames`, bindings category `ADDONS`, addon compartment signature).

## 1. What it is

A Peggle clone built 2026-10-09 on the user's request ("peggle inside of the game, with proper physics of the ball and levels"). A 560×420 board, a launcher at the top centre, ten balls per level, orange pegs to clear, moving bucket, free balls, powers on green pegs, a moving purple peg, Extreme Fever with bonus bins, twelve designed levels plus endless procedural ones, progress and best scores in the saved variables. `/pgl` toggles the window; the window starts the last played level when nothing is running.

## 2. Files

| File | Role |
|---|---|
| `MauPeggle.toc` | Load order: MauPeggle.lua, Physics.lua, Levels.lua, Game.lua, Board.lua, UI.lua, Options.lua. |
| `MauPeggle.lua` | Namespace `NS` (`_G.MauPeggle` for Bindings.xml), `NS.DEFAULTS` (`sounds`, `popups`, `slowmo`, `scale`), `NS.POWERS` / `NS.POWER_INFO`, helpers (`Print`, `Guard`, `PlayKit`, `Clamp`, `Commas`, `NewStats`), `InitDB` (`MauPeggleDB.settings/position/progress/stats`), events, `/pgl`, binding name, compartment function. |
| `Physics.lua` | `NS.Physics` (`P`): constants, `NewBall`, `Direction(angle)`, `Touching`, `Step(ball, world, onHit)`, `Predict(...)` for the aim guide. |
| `Levels.lua` | `NS.Levels`: `Rng` (Park-Miller), `Builder` (Circle, Brick, Line, Row, Arc, Ring, Scatter, Finish), `LIST` of twelve designed boards, `Name(index)`, `DefaultPower(index)`, `Build(index)` → `{ name, power, pegs }`. |
| `Game.lua` | `NS.Game`: state machine and rules. `StartLevel`, `Fire`, `Update(dt)`, `PhysicsStep`, `OnPegHit` / `Light`, `ActivatePower`, `StartFever`, `FeverBin`, `EndShot` / `AfterClear`, `LevelWon` / `LevelLost`, `MovePurple`, `Unstick`, `Multiplier`, `AddScore` / `FreeBall`. |
| `Board.lua` | `NS.Board`: the play field frame, pools of peg visuals (circle and brick), balls, launcher beads, guide dots, bucket, fever bins, effects (pop, vanish, blast), popups, banner queue, flash; mouse aiming and firing; `OnUpdate` drives `Game:Update`. |
| `UI.lua` | `NS.UI`: window `MauPeggleFrame`, header texts, footer buttons (power cycle, Levels, Restart), overlays `result` and `levels` on top of the board, `RefreshStatus`, show/hide. |
| `Options.lua` | Settings > AddOns category. |
| `Bindings.xml` | `MAUPEGGLE_TOGGLE` → `MauPeggle.UI:Toggle()`; packed by `build.ps1` although not in the TOC. |

Saved variables: `settings`, `position`, `progress = { unlocked, last, best[level], total }`, `stats = { levelsCleared, shots, pegs, fevers, freeBalls, bestShot, bestLevel }`.

## 3. Physics (`Physics.lua`)

- Board units: `W 560 × H 420`, origin top left, y down. Converted to frame anchors with `SetPoint("CENTER", frame, "TOPLEFT", x, -y)`.
- Constants: `BALL_R 6`, `PEG_R 8`, `RIM_R 5` (bucket rims), `GRAVITY 640`, `LAUNCH_SPEED 400`, `PEG_BOUNCE 0.74`, `WALL_BOUNCE 0.85`, `MAX_SPEED 950`, `DT 1/240`, launcher pivot `(280, 18)`, ball starts `MUZZLE 40` along the aim, `MAX_ANGLE 1.45` rad either side of straight down. These are the tuning knobs; the ball feels about like the original at these values but nothing has been measured in game yet.
- `Step`: gravity, speed clamp, move, walls (left/right/top bounce), then every peg in order: circle contact pushes the ball out along the centre line and reflects the normal velocity component with `PEG_BOUNCE`; brick contact uses the closest point on the axis-aligned box (centre-inside case leaves through the nearest face). Fireballs are not solid: they only register contact with a 5 unit margin. Bucket rims are solid circles; `"caught"` when the ball is below the rim line and between the rims; `"out"` below the bottom edge. The move per step is at most `MAX_SPEED × DT ≈ 4`, well under the 14 units of peg plus ball, so there is no tunnelling.
- `Predict` runs the same `Step` on a throwaway ball without the bucket, sampling points every 0.035 s, stopping at the first peg (normal guide, 0.7 s) or going through for 2.2 s (Super Guide). `Board:UpdateAim` recomputes it only when the aim angle changed.
- Bricks cannot be rotated: `Texture:SetRotation` only rotates texture coordinates, a solid-colour rectangle would not visibly turn, and a rotation animation held in place is a hack. Diagonal structures are built from lines of circles instead.

## 4. Levels (`Levels.lua`)

- `Finish()` keeps pegs in creation order, dropping any that are out of bounds (x inside the board, y between 78 and 352 with the peg's own extent) or closer than `GAP = 2 × PEG_R + 6 = 22` to a kept peg (brick distance measured from the nearest point of the box), so a ball always fits between pegs. Designed boards place pegs with that in mind and let `Finish` prune the odd corner.
- Designed list in order: Goldshire Grid, Dun Morogh Diamonds, Barrens Rings, Westfall Chevrons, Stormwind Pillars, Thunder Bluff Smile, Darkshore Waves, Maelstrom Spiral, Un'Goro Honeycomb, Ironforge Fortress, Thousand Needles Stairs, Deadmines Scatter (each 60–90 pegs by construction). Beyond: `Scatter(76 + 2 per extra level up to 24, 10 + 1 per extra level up to 8)` with seed `index × 7919 + 17`, named "Uncharted N". The default power cycles through `NS.POWERS` for procedural levels and is set per designed level.
- Layout randomness uses the file's own generator, so a level is the same every time; which pegs are orange, green and purple is `math.random` in `Game:StartLevel` (orange `min(25, 40% of pegs)`, two greens, one purple chosen among unlit blue pegs after every shot).

## 5. Rules (`Game.lua`)

- States: `idle`, `aim`, `shot`, `clear`, `fever`, `won`, `lost`. `Update(dt)` (from `Board:OnUpdate`) moves the bucket (`x = W/2 + (W/2 − half − 8) sin(0.9 t)`), runs fixed physics steps from an accumulator (frame dt capped at 0.05 s, at most 30 steps per frame, time scale 0.3 while `slowmo > 0`), and in `clear` removes lit pegs every 0.05 s in the order they were lit.
- `Fire(angle)`: one ball from the muzzle; `nextFire` makes it a fireball; Super Guide shots count down here. `OnPegHit` runs every step a ball touches a peg; the first touch of an unlit peg goes to `Light`: value = blue 10/20/30/50/100 by pegs hit this shot (≤10/15/20/25/more), orange 100, green 10, purple 500, times `Multiplier()` (x2/x3/x5/x10 at 10/15/19/22 of 25 cleared, scaled for smaller totals). Long Shot: at least one peg already hit and ≥ 320 units travelled since, +25,000 once per shot. `AddScore` hands out free balls at 25k/75k/125k shot score. Bucket catch = free ball.
- Powers (`ActivatePower`): guide → `guideShots = 3`; multiball → second ball at the same spot with mirrored vx; fire → `nextFire`; blast → every unlit peg within 95 units is lit (collected first, then lit, so nested greens work); spooky → `ball.spooky + 1`, consumed in `PhysicsStep` when the ball leaves the bottom (re-enters at the top, same x); flower → lights 10% (ceil) of the unlit pegs at random.
- Fever: the last orange sets `state = "fever"`, slow motion 1.3 s (option), bucket removed from the world, bins shown. A ball leaving the bottom scores the bin under it (`FEVER_BINS` by fifths of the width). Pegs lit during fever still score. When no ball is left: clear, then `LevelWon`: ball bonus 10,000 × balls left, total = pegs + bins + ball bonus, progress and stats updated, result overlay.
- Stuck: a ball under 30 units/s for 1.6 s removes every peg it touches (`P.Touching` with margin 2) and nudges the ball. An orange removed that way still counts as cleared.
- `Restart`/`NextLevel`/`StartLevel(i)` are the only entry points; `StartLevel` releases old ball visuals, rebuilds pegs, resets everything.

## 6. Drawing (`Board.lua`)

- Layers inside the board frame: `pegLayer` (+1: glow BACKGROUND, body ARTWORK, shine/bevel OVERLAY), `ballLayer` (+3), `topLayer` (+4: launcher, guide dots, bucket, bins, blast ring, popups, banner, flash). UI overlays sit at +10 and take the mouse, so clicks on them never fire.
- Circles are masked `WHITE8X8` textures (`TempPortraitAlphaMask`), bricks plain rectangles with a lighter bevel strip. `RecolorPeg` applies the colour (lit: body lerped 55% to white, glow alpha 0.55; unlit orange/green/purple keep a faint glow). Visual pools are per kind; `released` guards against a double release when a vanish animation and a level unload meet.
- Aiming: `CursorOnBoard` converts `GetCursorPosition()` with the board's effective scale and `GetLeft/GetTop`; angle = `atan2(dx, dy)` from the pivot, dy clamped ≥ 20 so aiming above the pivot still points down; the three beads and the waiting ball sit along the aim. Left click on the board = `Game:Fire`.
- Effects list: `pop` (lit peg scales up 40% over 0.22 s), `vanish` (grows and fades over 0.18 s, then released), `blast` ring. Popups rise 24 units over 0.9 s. Banners are queued and shown one after another at 42% height, fading in and out. The board flash is additive.
- Sounds: `IG_MAINMENU_OPTION_CHECKBOX_ON` (blue/green peg), `IG_BACKPACK_COIN_OK` (orange), `IG_BACKPACK_COIN_SELECT` (purple), `IG_MAINMENU_OPTION_CHECKBOX_OFF` (peg cleared), `IG_CHARACTER_INFO_TAB` (launch), `LOOT_WINDOW_COIN_SOUND` (free ball), `UI_AUTO_QUEST_COMPLETE` (long shot), `UI_PET_BATTLE_START` (power), `UI_WORLDQUEST_COMPLETE` (fever), `UI_EPICLOOT_TOAST` / `UI_LEGENDARY_LOOT_TOAST` (bins), `LFG_REWARDS` (level cleared), `UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL` (lost); all exist in `SoundKitConstants.lua` and are guarded.

## 7. How to verify

1. Syntax: node + luaparse over every `.lua`.
2. `/pgl`: level 1 appears with a banner, pegs in a staggered grid, 25 orange among them, two green, one purple, ten balls, bucket sweeping. Moving the mouse turns the beads and the guide dots; the dots end at the first peg. Click: the ball flies, pegs light with a pop and a +points popup, the status line shows the shot score, the ball leaves the bottom or lands in the bucket (banner "Free ball!"), lit pegs vanish in order, the purple peg moves, aiming resumes.
3. Physics feel: the ball should bounce a few times and keep falling, never pass through a peg or a brick (level 5 for bricks), never fly off through a wall. If it feels floaty or too bouncy, tune `GRAVITY`, `LAUNCH_SPEED`, `PEG_BOUNCE` in `Physics.lua`. If it rests on a brick, the stuck rule removes the brick after 1.6 s.
4. Clear all orange: slow motion, "EXTREME FEVER!", bins at the bottom, ball lands in one with its bonus, result overlay with pegs, bin, ball bonus, total, next level unlocked. Run out of balls: "Out of balls" overlay, Try again.
5. Powers: hit a green peg with each power selected (button under the board). Super Guide shows a long yellow dotted path through bounces for three shots (status line counts them). Multiball adds a ball. Fireball: the status line says "Fireball ready", the waiting ball turns orange, the next ball burns through. Space Blast lights a circle. Spooky: the ball comes back from the top once. Flower Power lights scattered pegs.
6. Levels overlay: unlocked buttons enabled, best scores starred, stats line. Restart resets the level. Options and key binding work. Closing the window mid-shot pauses the game (OnUpdate stops), reopening continues it.
7. Performance: 16 ms frames are expected even on level 9 (about 90 pegs × 4 steps per frame plus the guide only when the aim changes). If the guide lags on Super Guide, lower its `maxTime` in `Board:UpdateAim`.
