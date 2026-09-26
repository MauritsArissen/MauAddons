# MauGuildMap

Shows the guild members who run this addon on the world map, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Every member with the addon sends a tiny position message to the guild every few seconds while moving. Everyone else with the addon sees a race icon per member on the world map. Hover an icon for the name, level, race, class, zone and how old the position is. Members inside a dungeon, raid or battleground are drawn at the spot where they entered it, slightly dimmed.

## What you see

* One round race icon per online guild member with the addon, with a thin ring in their class colour, on the zone map, the continent map and the world map. Optionally their name under it.
* Hover: class-coloured name, level, race, class, health, mana/rage/energy, experience to the next level, zone, and "updated N s ago". For members in an instance: the instance name and "shown at the entrance".
* Dead members get a skull, and their icon stays where they died until they are back up.
* Icons move as members move (an update goes out every 2 seconds while moving, every 20 seconds when standing still).
* An icon disappears when the member logs out, hides themselves, or stops sending for 60 seconds.

Health, power and experience are only shown if the member shares them; each player decides that in their own options, and everything is shared by default.

Nothing is drawn on the minimap.

While the game is in the background (alt-tabbed) the addon goes quiet: it stops sampling your position, only sends a heartbeat now and then so you stay on your guild mates' maps, and holds incoming updates until the game is back.

## Options

`/mgm` opens the addon's page in the game's options (Escape > Options > AddOns > MauGuildMap). Everything is there:

* Map: show guild members on the map, skull on dead members, icon size in pixels, icon zoom, opacity for members inside an instance.
* Class ring: on or off, and its width in pixels.
* Name labels: on or off, font, text size, outline, above or below the icon, distance from the icon, class colour or white.
* Tooltip: show health, show mana/rage/energy, show experience.
* Privacy, what you send to the guild: send my position, share my health, share my mana/rage/energy, share my experience.

All of it is on by default except the name labels. Turning off "send my position" removes you from everyone's map at once.

There is also a hidden `/mgm test` for development: it simulates a guild of eight spread over the Eastern Kingdoms, two idle in cities, three inside dungeons at the real entrances, three wandering through zones with health, power and experience moving about, some sharing less than others, one dying and getting up again, one logging out, one timing out. Run it again to stop early.

## How it works

* Messages go over the guild addon channel (`C_ChatInfo.SendAddonMessage` with the prefix `MauGuildMap`). Only clients with the addon react to them; the server delivers them to every online guild member anywhere in the world, so no one has to be nearby.
* A message is under 60 bytes: map, position, level, race, sex, class, an outdoors/instance flag and the instance name.
* Inside an instance the client refuses to give a map position, so the last outdoor position, sampled at most 2 seconds before the loading screen, is sent instead. That is the entrance. If the addon is loaded while already inside, the encounter journal is asked for the entrance.
* Pins are Blizzard's own world map pin system (a map canvas data provider), the same thing HandyNotes and TomTom use.

## Install

The folder that contains this README *is* the addon folder. The game has to see it under the name `MauGuildMap`, either copied into `_classic_beta_\Interface\AddOns\` or linked there with a directory junction (see the repository README).

Enable *MauGuildMap* in the AddOns list at the character screen. Both you and the guild members you want to see need the addon.

## Files

* `MauGuildMap.toc` - addon manifest.
* `MauGuildMap.lua` - helpers, saved variables, events, `/mgm`.
* `Options.lua` - the page in the game's Settings > AddOns panel.
* `Roster.lua` - the members currently known, timeouts, guild presence, placement on any map.
* `Comm.lua` - wire format, position and stats sampling, sending, receiving.
* `MapPins.lua` + `MauGuildMap.xml` - the world map data provider, the pin and its tooltip.
* `Test.lua` - `/mgm test`.
* `CLAUDE.md` - full technical documentation.
