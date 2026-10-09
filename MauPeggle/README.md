# MauPeggle

Peggle inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Type `/pgl` (or `/peggle`) and a board of pegs opens with a launcher at the top. Move the mouse over the board to aim, click to shoot. The ball falls under gravity, bounces off pegs, bricks and walls, and lights every peg it touches; when it is gone, the lit pegs vanish. You have ten balls per level. Clear all the orange pegs and the level is yours.

## The rules, as in the original

* **Pegs**: blue are filler (10 points), **orange** are the ones you must clear (100), the two **green** ones trigger the level's power (10), and the **purple** one is worth 500 and moves to another peg every shot.
* **Multiplier**: as orange pegs go, every peg pays more: x2 with 10 of the 25 cleared, x3 at 15, x5 at 19, x10 at 22. Hitting many pegs in one shot also raises what each blue peg is worth.
* **Free balls**: the bucket moving along the bottom catches the ball for a free ball. 25,000 points in a single shot is a free ball too, then 75,000 and 125,000.
* **Long shot**: a ball that flies a long way between two pegs earns 25,000.
* **Extreme Fever**: the last orange peg slows the game down for a moment, the bucket disappears and five bins appear at the bottom: 10,000, 50,000, 100,000, 50,000 and 10,000. Every ball you still had on the launcher pays 10,000 at the end.
* **Stuck ball**: a ball resting on pegs for a couple of seconds makes those pegs disappear.
* Out of balls with orange pegs left means the level is lost; try again, the orange pegs are placed anew.

## Powers

Each level comes with a power, and the button under the board lets you pick another one. A green peg triggers it:

* **Super Guide**: shows the full path of the ball, bounces included, for the next three shots.
* **Multiball**: splits off a second ball.
* **Fireball**: the next ball burns straight through every peg in its way.
* **Space Blast**: lights every peg around the green one.
* **Spooky Ball**: the ball comes back in from the top once it falls off the bottom.
* **Flower Power**: lights one in ten of the pegs still on the board.

## Levels

Twelve designed boards with Azeroth names (Goldshire Grid, Dun Morogh Diamonds, Barrens Rings, Westfall Chevrons, Stormwind Pillars, Thunder Bluff Smile, Darkshore Waves, Maelstrom Spiral, Un'Goro Honeycomb, Ironforge Fortress, Thousand Needles Stairs, Deadmines Scatter), then "Uncharted" boards for as long as you like. Clearing a level unlocks the next. The Levels button shows what is unlocked, your best score per level and your overall statistics.

## Options

`/pgl options` or Escape > Options > AddOns > MauPeggle: sounds, score popups, fever slow motion and the window size. A key binding for opening the game is under Options > Key Bindings > AddOns, and the game is listed in the minimap's addon compartment.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauPeggle`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauPeggle* in the AddOns list at the character screen.

## Files

* `MauPeggle.toc` - addon manifest.
* `MauPeggle.lua` - settings, saved variables, helpers, `/pgl`, key binding name, addon compartment entry.
* `Physics.lua` - the ball simulation: gravity, pegs, bricks, walls, bucket, aim prediction.
* `Levels.lua` - the designed boards and the procedural ones.
* `Game.lua` - the rules: shots, scoring, powers, fever, level progress.
* `Board.lua` - everything drawn inside the play field.
* `UI.lua` - the window, the status lines, the level select and result screens.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the key binding.
* `CLAUDE.md` - full technical documentation.
