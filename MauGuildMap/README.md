# MauGuildMap

Shows the guild members who run this addon on the world map, for **World of Warcraft: Forever** (the `_classic_beta_` client, version 1.60.x, interface `16001`).

Every member with the addon sends a tiny position message to the guild every few seconds while moving. Everyone else with the addon sees a race icon per member on the world map. Hover an icon for the name, level, race, class, zone and how old the position is. Members inside a dungeon, raid or battleground are drawn at the spot where they entered it, slightly dimmed.

## What you see

* One round race icon per online guild member with the addon, on the zone map, the continent map and the world map.
* Hover: class-coloured name, level, race, class, zone, and "updated N s ago". For members in an instance: the instance name and "shown at the entrance".
* Icons move as members move (an update goes out every 2 seconds while moving, every 20 seconds when standing still).
* An icon disappears when the member logs out, hides themselves, or stops sending for 60 seconds.

Nothing is drawn on the minimap.

## Commands

* `/mgm` - status and this list of commands.
* `/mgm hide` - stop sending your own position (others drop you at once). `/mgm show` resumes.
* `/mgm disable` - stop showing other members on the map. `/mgm enable` shows them again.
* `/mgm list` - the members, where they are and when they last updated.

Both switches are remembered between sessions.
* `/mgm test` - simulate three members around you so you can see it work without a second player. They walk around, one enters a dungeon after 20 s, one logs out after 30 s, one goes silent after 30 s and drops off 60 s later. Run it again to stop early.

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
* `Roster.lua` - the members currently known, timeouts, guild presence, placement on any map.
* `Comm.lua` - wire format, position sampling, sending, receiving.
* `MapPins.lua` + `MauGuildMap.xml` - the world map data provider, the pin and its tooltip.
* `Test.lua` - `/mgm test`.
* `CLAUDE.md` - full technical documentation.
