# MauPlinko

Plinko inside the game, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`). For whenever you are bored.

Type `/mpk` (or `/plinko`) and a board opens: a triangle of pegs with a row of buckets underneath. Pick a bet, a risk level and the number of rows, press Drop and a ball falls down the board, bouncing left or right off every peg until it lands in a bucket. The bucket's multiplier times your bet goes back into your bank. The middle buckets are hit most often and pay the least; the edges are rare and pay the most, up to 1000x on 16 rows at high risk.

Everything is played with chips, a made-up currency that only exists inside the addon. No gold is involved, nothing is traded and nobody can take chips from anyone. You start with 1,000 chips; when you are out, one click tops you up again, and the top-up counter in the statistics keeps you honest. The bank is shared by all your characters.

## Playing

* **Bet**: chips per ball, at least 10. Type a number, or use 1/2, x2, Min and Max.
* **Risk**: Low, Medium or High. Low pays about the bet almost everywhere and a few times it at the edges. High loses most of the bet in the middle and pays hundreds of times it at the edges.
* **Rows**: 8 to 16. More rows means more buckets, bigger multipliers at the edges and a longer fall. Risk and rows lock while balls are in the air; the balls were paid for on the board they were dropped on.
* **Drop**: one ball. Press it as often as you like, up to 40 balls can be falling at once.
* **Auto drop**: drops the given number of balls one after the other (0 keeps going) until you press Stop or run out of chips.
* Hover a bucket for its payout, the chance of landing there, how often you have hit it and the return of the current table. Every table returns about 99% of what is wagered over the long run, like the well known online version of the game, so the bank drifts down slowly and the big hits are what you play for.
* The right side shows your last drops, your statistics (all time and this session, with reset buttons that ask for a second click) and the guild board.

## Guild board

Guild members who use MauPlinko exchange their best hit, biggest win, number of drops and net result over the guild addon channel, and the Guild tab lists everyone, best hit first. This is on by default and can be turned off. Nothing goes to guild chat unless you turn on the announcement option, which posts one line when you hit a big multiplier (100x by default, adjustable).

## Options

`/mpk options` or Escape > Options > AddOns > MauPlinko: ball speed, auto drop interval, sounds and the tick on every peg, window size, score sharing, and the guild chat announcement with its threshold.

Key bindings for opening the board and for dropping a ball are under Options > Key Bindings > AddOns. The board is also listed in the minimap's addon compartment.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauPlinko`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README). Enable *MauPlinko* in the AddOns list at the character screen.

## Files

* `MauPlinko.toc` - addon manifest.
* `MauPlinko.lua` - settings, saved variables, helpers, `/mpk`, key binding names, addon compartment entry.
* `Tables.lua` - payout tables for every risk and row count, odds, colours.
* `Game.lua` - the rules: bets, drops, payouts, statistics, history, auto mode, top-ups, resets.
* `Board.lua` - the pegs, buckets and the ball animation.
* `UI.lua` - the window: controls on the left, last drops, statistics and guild board on the right.
* `Comm.lua` - score exchange with guild members.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Bindings.xml` - the two key bindings.
* `CLAUDE.md` - full technical documentation.
