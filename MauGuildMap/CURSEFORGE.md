MauGuildMap shows your guild mates on the world map.

Everyone in the guild who runs the addon sends their position over the guild addon channel every couple of seconds while they move. Everyone else with the addon sees them as small round race icons on the world map, on the zone map as well as the continent and world views. Hover an icon and you get the name, level, race, class, the zone they are in and how old the position is.

If someone is inside a dungeon, raid or battleground the game does not give out their position, so the addon shows them at the spot where they went in, slightly greyed out, with the instance name in the tooltip.

Icons disappear when a member logs out, hides themselves, or hasn't sent anything for a minute. Nothing is drawn on the minimap.

**A few things to know**

- Both sides need the addon. You only see guild members who have it installed, and they only see you if they do.
- It works across the whole world. Nobody has to be nearby or in your group.
- Your position goes to the whole guild. If you would rather not be seen, `/mgm hide` stops sending and the others drop you right away. `/mgm show` turns it back on.
- The messages are tiny, under 60 bytes, and only go out when you actually moved, so it does not add any noticeable chat traffic.

**Commands**

- `/mgm` - status and the list of commands
- `/mgm hide` and `/mgm show` - stop or resume sending your own position
- `/mgm disable` and `/mgm enable` - stop or resume drawing other members
- `/mgm list` - who is shown, where they are and when they last updated
- `/mgm test` - puts a handful of pretend guild members on the Eastern Kingdoms map so you can see what it looks like without waiting for anyone else

Made for World of Warcraft: Forever (the 1.60 client). It uses Blizzard's own map pin system, so it gets along with the regular map and with other map addons.

If something breaks, a screenshot or the error text from `/console scriptErrors 1` helps a lot.
